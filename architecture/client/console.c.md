# client/console.c

## File Purpose
Implements the Quake 2 in-game console: text buffer management, output printing, input line rendering, notify overlay, and the full console draw pass. All engine text output routes through `Con_Print` so it is captured and displayed here.

## Core Responsibilities
- Maintain a circular text buffer (`con.text`) with line-wrap and resize logic
- Print engine/game text with carriage-return and color-mask handling
- Draw the full drop-down console (background, scrollback, version string, download bar, input line)
- Draw the transient notify overlay (last N lines shown briefly over the game view)
- Register and handle console commands: `toggleconsole`, `clear`, `condump`, `messagemode`, etc.
- Manage console state transitions (key destination, pause on singleplayer open)

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `console_t con` | struct (defined in `console.h`) | All console state: text buffer, dimensions, scroll position, notify timestamps |
| `cvar_t *con_notifytime` | typedef (pointer) | Controls how long notify lines remain visible (seconds) |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `con` | `console_t` | global | Sole console instance; all functions operate on it |
| `con_notifytime` | `cvar_t *` | global | Notify display duration cvar |
| `cr` | `static int` (inside `Con_Print`) | static local | Tracks pending carriage-return to overwrite previous line |

## Key Functions

### Con_Init
- Signature: `void Con_Init(void)`
- Purpose: Bootstrap the console subsystem at engine startup.
- Inputs: None.
- Outputs/Return: None.
- Side effects: Sets `con.linewidth = -1`, calls `Con_CheckResize`, registers cvar `con_notifytime`, registers six console commands, sets `con.initialized = true`.
- Calls: `Con_CheckResize`, `Com_Printf`, `Cvar_Get`, `Cmd_AddCommand` ×6.
- Notes: Must be called before any `Com_Printf` output is visible in the console.

### Con_CheckResize
- Signature: `void Con_CheckResize(void)`
- Purpose: Reformat the circular text buffer when video width changes.
- Inputs: Reads `viddef.width`, current `con` state.
- Outputs/Return: None.
- Side effects: Rewrites `con.text`, updates `con.linewidth`, `con.totallines`, `con.current`, `con.display`; calls `Con_ClearNotify`.
- Calls: `Con_ClearNotify`.
- Notes: Uses a local `tbuf[CON_TEXTSIZE]` stack copy for the reformat; safe to call repeatedly each frame.

### Con_Print
- Signature: `void Con_Print(char *txt)`
- Purpose: Central text sink — writes a string into the circular console buffer with word-wrap, color mask, CR/LF handling.
- Inputs: NUL-terminated string; leading byte `1` or `2` enables the high-bit color mask.
- Outputs/Return: None.
- Side effects: Advances `con.x`, `con.current`; calls `Con_Linefeed`; timestamps notify lines via `con.times`.
- Calls: `Con_Linefeed`.
- Notes: Guard on `con.initialized` prevents output before `Con_Init`. Static `cr` flag causes the current line to be overwritten on the next character.

### Con_DrawConsole
- Signature: `void Con_DrawConsole(float frac)`
- Purpose: Render the full drop-down console covering `frac` of screen height.
- Inputs: `frac` — fraction of screen height [0,1].
- Outputs/Return: None.
- Side effects: Calls `re.DrawStretchPic`, `re.DrawChar` extensively; calls `SCR_AddDirtyPoint`; calls `Con_DrawInput`.
- Calls: `re.DrawStretchPic`, `re.DrawChar`, `Com_sprintf`, `SCR_AddDirtyPoint`, `strrchr`, `strncpy`, `strcat`, `sprintf`, `Con_DrawInput`.
- Notes: Draws a download progress bar (ZOID extension) when `cls.download` is non-null. Scrollback indicator (`^` arrows) drawn when `con.display != con.current`.

### Con_DrawNotify
- Signature: `void Con_DrawNotify(void)`
- Purpose: Draw the most-recent console lines as a transparent HUD overlay and the chat input line.
- Inputs: Reads `con`, `cls`, `con_notifytime`, `chat_buffer`, `viddef`.
- Outputs/Return: None.
- Side effects: Calls `re.DrawChar`, `SCR_AddDirtyPoint`, `DrawString`.
- Calls: `re.DrawChar`, `DrawString`, `SCR_AddDirtyPoint`.
- Notes: Lines expire after `con_notifytime` seconds; chat overlay shown only when `cls.key_dest == key_message`.

### Con_DrawInput
- Signature: `void Con_DrawInput(void)`
- Purpose: Draw the console command-input line with a blinking cursor.
- Inputs: `key_lines[edit_line]`, `key_linepos`, `cls.realtime`, `con.vislines`, `con.linewidth`.
- Outputs/Return: None.
- Side effects: Temporarily writes cursor character and spaces into `key_lines[edit_line]`; restores after draw.
- Calls: `re.DrawChar`.
- Notes: Horizontal scroll: if `key_linepos >= con.linewidth`, the text pointer is offset so the cursor stays visible.

### Con_ToggleConsole_f
- Signature: `void Con_ToggleConsole_f(void)`
- Purpose: Command handler to open/close the console; pauses singleplayer when opened.
- Inputs: Global `cl`, `cls` state.
- Outputs/Return: None.
- Side effects: Modifies `cls.key_dest`; calls `Cvar_Set("paused", ...)`, `Cbuf_AddText`, `M_ForceMenuOff`, `Con_ClearNotify`, `Key_ClearTyping`.
- Notes: Intercepts attract-loop and disconnected states with special handling.

### Con_Dump_f
- Signature: `void Con_Dump_f(void)`
- Purpose: Write current console contents to a `.txt` file in the game directory.
- Inputs: Command argument (filename), `con` buffer.
- Outputs/Return: None.
- Side effects: File I/O (`fopen`/`fprintf`/`fclose`); strips high bits from characters before writing.
- Calls: `Cmd_Argc`, `Cmd_Argv`, `Com_sprintf`, `FS_Gamedir`, `Com_Printf`, `FS_CreatePath`, `fopen`, `strncpy`, `fprintf`, `fclose`.

**Notes on trivial helpers:**
- `DrawString` / `DrawAltString`: render a C string via `re.DrawChar` at 8px steps; `DrawAltString` sets bit 7 for alternate palette.
- `Con_ClearNotify`: zeroes all `con.times[]` entries.
- `Con_Linefeed`: advances `con.current`, clears the new line, scrolls `con.display`.
- `Con_CenteredPrint`: pads a string to center it then calls `Con_Print`.
- `Con_MessageMode_f` / `Con_MessageMode2_f`: set `cls.key_dest = key_message` and `chat_team` flag.
- `Con_Clear_f`: `memset`s `con.text` to spaces.

## Control Flow Notes
`Con_Init` is called once during client startup. Each frame, `SCR_UpdateScreen` (in `cl_scrn.c`) calls `Con_DrawConsole` if the console is open and `Con_DrawNotify` unconditionally during gameplay. `Con_Print` is invoked by `Com_Printf` throughout the engine lifetime.

## External Dependencies
- `client.h` — pulls in `console.h`, `cl_*.h`, `ref.h`, `qcommon.h`
- `re` (refexport_t) — `DrawChar`, `DrawStretchPic` defined in active renderer DLL
- `cls` (client_static_t), `cl` (client_state_t), `viddef` — defined in `cl_main.c` / `vid_*.c`
- `chat_buffer`, `chat_team`, `chat_bufferlen` — defined in `keys.c`
- `key_lines`, `edit_line`, `key_linepos` — defined in `keys.c`
- `SCR_EndLoadingPlaque`, `SCR_AddDirtyPoint` — defined in `cl_scrn.c`
- `M_ForceMenuOff` — defined in `menu.c`
- `Com_ServerState`, `Cbuf_AddText`, `Cvar_*`, `Cmd_*`, `FS_*` — defined in `qcommon/`
