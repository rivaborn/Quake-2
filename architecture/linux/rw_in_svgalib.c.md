# linux/rw_in_svgalib.c

## File Purpose
Implements keyboard and mouse input for the Linux SVGAlib software renderer backend. It maps raw keyboard scancodes to Quake 2 key constants and translates SVGAlib mouse events into engine movement and button commands.

## Core Responsibilities
- Initialize SVGAlib keyboard with a scancode-to-key translation table
- Pump keyboard events each frame via SVGAlib callbacks
- Initialize SVGAlib mouse device using cvars for device path and sample rate
- Accumulate relative mouse deltas and button state changes each frame
- Convert mouse deltas into view angle changes or movement commands
- Register `+mlook`/`-mlook` and `force_centerview` console commands

## Key Types / Data Structures
None (uses types from included headers).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `scantokey[128]` | `unsigned char[]` | static | Maps PC scancodes to Quake key constants |
| `Key_Event_fp` | `Key_Event_fp_t` | static | Keyboard event callback into engine |
| `UseMouse` | `qboolean` | static | Whether mouse was successfully initialized |
| `mouserate` | `int` | static | Mouse sample rate (default from SVGAlib) |
| `mouse_buttons` | `int` | static | Number of mouse buttons (hardcoded 3) |
| `mouse_buttonstate` | `int` | static | Current button bitmask from SVGAlib |
| `mouse_oldbuttonstate` | `int` | static | Previous frame button bitmask for edge detection |
| `mouse_x, mouse_y` | `float` | static | Filtered/scaled mouse delta this frame |
| `old_mouse_x, old_mouse_y` | `float` | static | Previous frame deltas for filtering |
| `mx, my` | `int` | static | Raw accumulated mouse deltas from SVGAlib |
| `in_state` | `in_state_t *` | static | Engine input state pointer (view angles, callbacks) |
| `m_filter`, `in_mouse`, `sensitivity`, etc. | `cvar_t *` | static | Cached cvar references for mouse behavior |
| `mlooking` | `qboolean` | static | Whether `+mlook` is currently active |

## Key Functions

### `KBD_Init`
- Signature: `void KBD_Init(Key_Event_fp_t fp)`
- Purpose: Fills `scantokey[]` table, stores the key event callback, then initializes SVGAlib keyboard with `keyhandler` as the event handler.
- Inputs: `fp` — engine key event callback
- Outputs/Return: void; calls `Sys_Error` on failure
- Side effects: Populates `scantokey[]`, sets `Key_Event_fp`, calls `keyboard_init`, `keyboard_seteventhandler`, `keyboard_translatekeys`
- Calls: `keyboard_init`, `keyboard_seteventhandler`, `keyboard_translatekeys`, `Sys_Error`
- Notes: Scancodes 58 (Caps Lock), 69 (Num Lock), 70 (Scroll Lock), 84–86, 89–95 are explicitly skipped (left as space).

### `keyhandler`
- Signature: `static void keyhandler(int scancode, int state)`
- Purpose: SVGAlib keyboard callback; strips the high bit of the scancode and dispatches through `Key_Event_fp`.
- Inputs: `scancode` — raw SVGAlib scancode; `state` — `KEY_EVENTPRESS` or release
- Outputs/Return: void
- Side effects: Calls `Key_Event_fp`
- Calls: `Key_Event_fp`

### `KBD_Update` / `KBD_Close`
- `KBD_Update`: drains the SVGAlib keyboard event queue by calling `keyboard_update` in a loop.
- `KBD_Close`: calls `keyboard_close` to release the keyboard device.

### `RW_IN_Init`
- Signature: `void RW_IN_Init(in_state_t *in_state_p)`
- Purpose: Registers mouse-related cvars and console commands, detects the SVGAlib mouse type, and opens the mouse device.
- Inputs: `in_state_p` — engine input state with view angle array and callbacks
- Outputs/Return: void; sets `UseMouse = false` on failure
- Side effects: Registers cvars via `ri.Cvar_Get`, registers commands via `ri.Cmd_AddCommand`, calls `mouse_init` and `mouse_seteventhandler`
- Calls: `ri.Cvar_Get`, `ri.Cmd_AddCommand`, `vga_getmousetype`, `mouse_init`, `mouse_seteventhandler`, `ri.Con_Printf`

### `RW_IN_Commands`
- Signature: `void RW_IN_Commands(void)`
- Purpose: Polls mouse button state and fires key press/release events on edge transitions.
- Inputs: none (reads file-static state)
- Outputs/Return: void
- Side effects: Calls `in_state->Key_Event_fp` / `Key_Event_fp` for button events; updates `mouse_oldbuttonstate`
- Calls: `mouse_update`, `in_state->Key_Event_fp`, `Key_Event_fp`
- Notes: Middle button handling inconsistently uses the file-static `Key_Event_fp` instead of `in_state->Key_Event_fp` — likely a bug.

### `RW_IN_Move`
- Signature: `void RW_IN_Move(usercmd_t *cmd)`
- Purpose: Converts accumulated mouse deltas into view angle changes (yaw/pitch) or movement commands (sidemove/forwardmove) depending on mlook and strafe state.
- Inputs: `cmd` — player command struct to modify
- Outputs/Return: void; modifies `cmd->sidemove`, `cmd->forwardmove`, `in_state->viewangles`
- Side effects: Resets `mx`/`my` to 0; calls `mouse_update`
- Calls: `mouse_update`
- Notes: Optional exponential smoothing filter when `m_filter->value` is set.

### `mousehandler`
- Signature: `static void mousehandler(int buttonstate, int dx, int dy)`
- Purpose: SVGAlib mouse callback; accumulates deltas into `mx`/`my` and stores button state.
- Side effects: Modifies `mouse_buttonstate`, `mx`, `my`

### `RW_IN_Shutdown` / `RW_IN_Frame` / `RW_IN_Activate`
- `RW_IN_Shutdown`: calls `mouse_close`.
- `RW_IN_Frame` and `RW_IN_Activate`: empty stubs satisfying the platform input interface.

## Control Flow Notes
This file is called from the SVGAlib renderer/window system layer. `KBD_Init` and `RW_IN_Init` are called at renderer startup. `KBD_Update` and `RW_IN_Commands`/`RW_IN_Move` are called each client frame to pump events and generate movement. `KBD_Close` and `RW_IN_Shutdown` are called at shutdown.

## External Dependencies
- `vga.h`, `vgakeyboard.h`, `vgamouse.h` — SVGAlib library (defined elsewhere, system library)
- `../ref_soft/r_local.h` — soft renderer locals including `ri` (refimport_t)
- `../client/keys.h` — Quake key constants (`K_ESCAPE`, `K_F1`, etc.)
- `../linux/rw_linux.h` — `in_state_t`, `Key_Event_fp_t` definitions
- `Sys_Error` — defined elsewhere in engine
- `ri.Cvar_Get`, `ri.Cmd_AddCommand`, `ri.Con_Printf` — engine import table calls
