# client/keys.c

## File Purpose
Implements the client-side keyboard input system, managing key bindings, console line editing, chat message input, and routing of key events to the appropriate subsystem (console, menu, game, or message).

## Core Responsibilities
- Maintain and serialize key-to-command bindings (`keybindings[]`)
- Route key events to console, menu, chat, or game based on `cls.key_dest`
- Provide interactive console line editing with history (32-line ring buffer)
- Handle tab-completion for commands and cvars in the console
- Track modifier key state (`shift_down`, `keydown[]`) and autorepeat filtering
- Map key numbers to/from string names for config file serialization
- Register `bind`/`unbind`/`unbindall`/`bindlist` console commands

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `keyname_t` | struct | Maps a string name (e.g. `"TAB"`) to a `K_*` keynum integer |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `key_lines[32][MAXCMDLINE]` | `char[][]` | global | Console input history ring buffer (32 entries × 256 chars) |
| `key_linepos` | `int` | global | Cursor position in current console input line |
| `shift_down` | `int` | global | Non-zero when K_SHIFT is held |
| `anykeydown` | `int` | global | Count of keys currently pressed; used for `BUTTON_ANY` |
| `edit_line` | `int` | global | Index of current console input line in ring buffer |
| `history_line` | `int` | global | Index being browsed during history recall |
| `key_waiting` | `int` | global | Used by `Key_GetKey` modal wait; -1 = waiting |
| `keybindings[256]` | `char*[]` | global | Heap-allocated command strings per key index |
| `consolekeys[256]` | `qboolean[]` | global | Keys consumed by console mode, not rebindable while in console |
| `menubound[256]` | `qboolean[]` | global | Keys that always route to menu handler |
| `keyshift[256]` | `int[]` | global | Shift-mapped character for each key (US layout) |
| `key_repeats[256]` | `int[]` | global | Per-key press count; filters autorepeat |
| `keydown[256]` | `qboolean[]` | global | Current pressed state per key |
| `chat_team` | `qboolean` | static (file) | Whether current chat is team-only |
| `chat_buffer[MAXCMDLINE]` | `char[]` | static (file) | Active chat input buffer |
| `chat_bufferlen` | `int` | static (file) | Length of `chat_buffer` |
| `keynames[]` | `keyname_t[]` | global | Null-terminated table of name↔keynum mappings |

## Key Functions

### Key_Init
- **Signature:** `void Key_Init (void)`
- **Purpose:** One-time initialization of all key system state; registers console commands.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** Populates `key_lines`, `consolekeys`, `keyshift`, `menubound`; calls `Cmd_AddCommand` for `bind`, `unbind`, `unbindall`, `bindlist`.
- **Calls:** `Cmd_AddCommand`
- **Notes:** Backtick/tilde explicitly excluded from `consolekeys` (hardcoded console toggle). F1–F12 and Escape hardcoded into `menubound`.

---

### Key_Event
- **Signature:** `void Key_Event (int key, qboolean down, unsigned time)`
- **Purpose:** Central dispatch for all key press/release events; handles autorepeat, shift state, binding execution, and modal routing.
- **Inputs:** `key` — keynum; `down` — press or release; `time` — event timestamp for `+button` timing.
- **Outputs/Return:** None
- **Side effects:** Updates `keydown[]`, `key_repeats[]`, `anykeydown`, `shift_down`; appends commands to `Cbuf`; may call `Con_ToggleConsole_f`, `M_Keydown`, `Key_Console`, `Key_Message`, `M_Menu_Main_f`.
- **Calls:** `Con_ToggleConsole_f`, `Cbuf_AddText`, `Com_sprintf`, `Key_Message`, `M_Keydown`, `M_Menu_Main_f`, `Key_Console`, `Com_Error`
- **Notes:** Key-up events only fire `+button` releases. Backtick/tilde toggle is hardcoded and cannot be rebound. Attract-loop forces any key to `K_ESCAPE`.

---

### Key_Console
- **Signature:** `void Key_Console (int key)`
- **Purpose:** Handles keyboard input while the console is active — line editing, history navigation, scrollback, clipboard paste.
- **Inputs:** `key` — keynum (numpad keys remapped to ASCII at entry)
- **Outputs/Return:** None
- **Side effects:** Modifies `key_lines`, `key_linepos`, `edit_line`, `history_line`, `con.display`; calls `Cbuf_AddText`, `SCR_UpdateScreen`, `CompleteCommand`, `Sys_GetClipboardData`.
- **Calls:** `Cbuf_AddText`, `Com_Printf`, `SCR_UpdateScreen`, `CompleteCommand`, `Sys_GetClipboardData`, `free`
- **Notes:** History is a 32-entry ring; skips blank entries during recall. Ctrl+V / Shift+Ins paste from clipboard.

---

### Key_SetBinding
- **Signature:** `void Key_SetBinding (int keynum, char *binding)`
- **Purpose:** Allocates and stores a command string binding for a given keynum, freeing any previous binding.
- **Inputs:** `keynum` — index into `keybindings[]`; `binding` — command string to copy.
- **Outputs/Return:** None
- **Side effects:** `Z_Free` on old binding, `Z_Malloc` for new; modifies `keybindings[keynum]`.
- **Calls:** `Z_Free`, `Z_Malloc`, `strcpy`

---

### Key_WriteBindings
- **Signature:** `void Key_WriteBindings (FILE *f)`
- **Purpose:** Serializes all active bindings to a config file as `bind <key> "<command>"` lines.
- **Inputs:** Open `FILE*` for writing.
- **Side effects:** `fprintf` to file.
- **Calls:** `Key_KeynumToString`, `fprintf`

---

### Key_GetKey
- **Signature:** `int Key_GetKey (void)`
- **Purpose:** Blocking modal wait for a single keypress; used for key-capture UI (e.g., rebind dialogs).
- **Inputs:** None
- **Outputs/Return:** Keynum of the first key pressed.
- **Side effects:** Spins calling `Sys_SendKeyEvents` until `key_waiting` is set by `Key_Event`.
- **Calls:** `Sys_SendKeyEvents`

---

### Key_ClearStates
- **Signature:** `void Key_ClearStates (void)`
- **Purpose:** Synthesizes key-up events for all currently held keys, then zeroes state arrays.
- **Calls:** `Key_Event`

- **Notes on minor functions:** `CompleteCommand` tries `Cmd_CompleteCommand` then `Cvar_CompleteVariable` and fills `key_lines[edit_line]`. `Key_Message` handles chat buffer editing and submission. `Key_StringToKeynum`/`Key_KeynumToString` do linear search through `keynames[]`.

## Control Flow Notes
`Key_Init` is called once at client startup. Per-frame, the platform layer calls `Key_Event` for each OS key event (via `Sys_SendKeyEvents`). `Key_Event` dispatches based on `cls.key_dest` (`key_game`, `key_console`, `key_menu`, `key_message`). Binding commands are injected into `Cbuf` for execution at the next command buffer flush.

## External Dependencies
- **Includes:** `client.h` (pulls in all client state: `cls`, `cl`, `con`)
- **Defined elsewhere:** `Cmd_CompleteCommand`, `Cvar_CompleteVariable`, `Cbuf_AddText`, `Com_sprintf`, `Com_Printf`, `Com_Error`, `Con_ToggleConsole_f`, `M_Keydown`, `M_Menu_Main_f`, `SCR_UpdateScreen`, `Sys_SendKeyEvents`, `Sys_GetClipboardData`, `Z_Malloc`, `Z_Free`; key constants `K_*` from `keys.h`
