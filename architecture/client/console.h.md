# client/console.h

## File Purpose
Declares the console subsystem interface for Quake 2's in-game developer/chat console. Defines the console buffer structure and exposes rendering, printing, and lifecycle functions implemented in `client/console.c`.

## Core Responsibilities
- Define the fixed-size circular text buffer (`console_t`) for console output
- Expose initialization and resize hooks for the console subsystem
- Declare rendering entry points for the full console overlay and transient notify lines
- Declare print functions for general and centered console text output
- Expose console toggle and clear commands

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `console_t` | struct | Holds all state for the console: text ring buffer, cursor position, scroll position, line geometry, notify timestamps, and color mask |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `con` | `console_t` | global (extern) | Singleton console state shared across the client subsystem |

## Key Functions

### Con_Init
- Signature: `void Con_Init(void)`
- Purpose: Initializes the console subsystem; sets up buffer and registers commands.
- Inputs: None
- Outputs/Return: void
- Side effects: Writes to `con`; registers console commands (e.g., `clear`, `toggleconsole`)
- Calls: Not inferable from this file
- Notes: Must be called once at client startup before any console output

### Con_CheckResize
- Signature: `void Con_CheckResize(void)`
- Purpose: Recalculates `linewidth` and `totallines` based on current screen width; reflows the text buffer if necessary.
- Inputs: None
- Outputs/Return: void
- Side effects: Mutates `con.linewidth`, `con.totallines`
- Calls: Not inferable from this file
- Notes: Should be called on vid mode changes

### Con_DrawConsole
- Signature: `void Con_DrawConsole(float frac)`
- Purpose: Renders the console overlay covering `frac` fraction of the screen height.
- Inputs: `frac` — 0.0–1.0 proportion of screen to cover
- Outputs/Return: void
- Side effects: Issues renderer draw calls
- Calls: `Con_DrawCharacter` (likely)
- Notes: Called each frame when console is open

### Con_DrawNotify
- Signature: `void Con_DrawNotify(void)`
- Purpose: Renders recent console lines as transient HUD notify messages using `times[]` timestamps.
- Inputs: None
- Outputs/Return: void
- Side effects: Issues renderer draw calls; reads `cls.realtime` for fade-out logic
- Calls: Not inferable from this file
- Notes: Uses `NUM_CON_TIMES` (4) slots; lines fade after a fixed duration

### Con_Print
- Signature: `void Con_Print(char *txt)`
- Purpose: Appends a string to the console ring buffer, advancing `current` and `x`.
- Inputs: `txt` — null-terminated string to append
- Outputs/Return: void
- Side effects: Mutates `con.text`, `con.current`, `con.x`
- Calls: Not inferable from this file
- Notes: `ormask` is applied to characters to support colored text

### Con_CenteredPrint
- Signature: `void Con_CenteredPrint(char *text)`
- Purpose: Prints a string centered on the current console line.
- Inputs: `text` — string to center
- Outputs/Return: void
- Side effects: Mutates console buffer
- Calls: `Con_Print` (likely)

### Con_DrawCharacter
- Signature: `void Con_DrawCharacter(int cx, int line, int num)`
- Purpose: Renders a single character glyph at a given column/line position.
- Inputs: `cx` — column pixel offset; `line` — screen line; `num` — character index into the font atlas
- Outputs/Return: void
- Side effects: Issues a renderer draw call
- Notes: Low-level helper used by `Con_DrawConsole` and `Con_DrawNotify`

### Notes
- `Con_Clear_f`, `Con_ClearNotify`, `Con_ToggleConsole_f` are command callbacks; trivial wrappers that reset buffer state or toggle `cls` console flags.

## Control Flow Notes
- `Con_Init` is called once during client init.
- `Con_CheckResize` is called on video mode changes.
- `Con_DrawConsole` and `Con_DrawNotify` are called each render frame from the 2D HUD pass.
- `Con_Print` is driven by `Com_Printf` / `Com_DPrintf` throughout the engine lifetime.

## External Dependencies
- `qcommon.h` / `client.h` — `qboolean`, `cls.realtime`
- `Con_DrawCharacter` depends on the active renderer for glyph drawing
- `CON_TEXTSIZE` (32768) defines a fixed ring buffer; no dynamic allocation
