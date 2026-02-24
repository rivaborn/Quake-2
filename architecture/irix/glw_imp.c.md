# irix/glw_imp.c

## File Purpose
Implements the IRIX/X11-specific OpenGL window and input management layer for the Quake 2 GL renderer. Despite the header comment claiming "Linux specific stuff," this file is the IRIX port's GLX window creation, keyboard/mouse input handling, and renderer lifecycle management.

## Core Responsibilities
- Create and manage an X11/GLX window for OpenGL rendering
- Initialize and destroy the GLX rendering context
- Translate X11 key events to Quake 2 key codes
- Process X11 mouse motion and button events
- Apply mouse input to player view angles and movement commands
- Register signal handlers for clean shutdown
- Expose the `GLimp_*` and `RW_IN_*` / `KBD_*` entry points required by the renderer/input plugin interface

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `keyq[]` | struct array (anonymous) | Ring buffer (64 entries) holding pending key events (key code + down state) |
| `in_state_t` | typedef (defined elsewhere) | Pointer-based state struct passed in from the client; holds view angles, input callbacks |
| `MotifWmHints` | struct (Motif/X11) | Used to strip window decorations in fullscreen mode via `_MOTIF_WM_HINTS` |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `gl_cx` | `GLXContext` | global | Active GLX rendering context |
| `x_disp` | `Display *` | static | X11 display connection |
| `x_win` | `Window` | static | Main X11 window handle |
| `x_vis` / `x_visinfo` | `Visual *` / `XVisualInfo *` | static | Selected X11 visual |
| `x_gc` | `GC` | static | X11 graphics context |
| `x_cmap` | `Colormap` | static | X11 colormap (8-bit path) |
| `oktodraw` | `qboolean` | static | Set true after first Expose event; gates rendering |
| `X11_active` | `qboolean` | static | Set true after successful window init |
| `keyq_head/tail` | `int` | file | Ring buffer head/tail indices |
| `mx`, `my` | `int` | static | Accumulated mouse delta since last frame |
| `mouse_buttonstate` | `int` | static | Bitmask of current mouse button states |
| `_windowed_mouse` | `cvar_t *` | static | Controls pointer grab / relative mouse mode |
| `Key_Event_fp` | `Key_Event_fp_t` | file | Callback pointer for dispatching keyboard events |
| `in_state` | `in_state_t *` | static | Input state provided by engine at `RW_IN_Init` |
| `config_notify` / `_width` / `_height` | `int` | file | Pending window resize notification |

## Key Functions

### GLimp_InitGraphics
- **Signature:** `qboolean GLimp_InitGraphics(qboolean fullscreen)`
- **Purpose:** Opens the X display, selects a GLX visual (preferring SGIS multisample), creates the X11 window, creates and activates the GLX context.
- **Inputs:** `fullscreen` — if true, strips Motif decorations and positions window at 0,0.
- **Outputs/Return:** `true` on success; calls `Sys_Error` on fatal failures.
- **Side effects:** Allocates X11 resources (`x_disp`, `x_win`, `x_gc`, `gl_cx`); sets `X11_active = true`; calls `ri.Vid_NewWindow`.
- **Calls:** `XOpenDisplay`, `glXChooseVisual`, `XCreateWindow`, `glXCreateContext`, `glXMakeCurrent`, `CreateNullCursor`, `ri.Vid_NewWindow`, `Sys_Error`.
- **Notes:** Falls back from `StudlyRGBattributes` (SGIS AA) to plain `RGBattributes` if the preferred visual is unavailable. MITSHM code is `#if 0`'d out.

### GLimp_SetMode
- **Signature:** `int GLimp_SetMode(int *pwidth, int *pheight, int mode, qboolean fullscreen)`
- **Purpose:** Validates the requested video mode, shuts down any existing window, then calls `GLimp_InitGraphics`.
- **Inputs:** Mode index, output width/height pointers, fullscreen flag.
- **Outputs/Return:** `rserr_ok` or `rserr_invalid_mode`.
- **Side effects:** Calls `GLimp_Shutdown` first; updates `*pwidth`/`*pheight`; notifies via `ri.Vid_NewWindow`.
- **Calls:** `GLimp_Shutdown`, `GLimp_InitGraphics`, `ri.Vid_GetModeInfo`, `ri.Vid_NewWindow`.

### GLimp_Shutdown
- **Signature:** `void GLimp_Shutdown(void)`
- **Purpose:** Tears down the X11 display connection; re-enables key auto-repeat.
- **Side effects:** Closes `x_disp`; sets `x_disp = NULL`.
- **Calls:** `XSynchronize`, `XAutoRepeatOn`, `XCloseDisplay`.

### GLimp_EndFrame
- **Signature:** `void GLimp_EndFrame(void)`
- **Purpose:** Flushes GL commands and swaps the front/back buffers.
- **Calls:** `glFlush`, `glXSwapBuffers`.

### XLateKey
- **Signature:** `int XLateKey(XKeyEvent *ev)`
- **Purpose:** Translates an X11 `KeySym` to a Quake 2 `K_*` key code.
- **Outputs/Return:** Integer Quake key code; defaults to ASCII for unrecognized symbols.

### GetEvent
- **Signature:** `void GetEvent(void)`
- **Purpose:** Reads one X11 event and routes it: keys → `keyq`, mouse motion → `mx`/`my`, buttons → `mouse_buttonstate`, configure → `config_notify_*`.
- **Side effects:** May `XWarpPointer` to re-center mouse in grabbed mode; may `XGrabPointer`/`XUngrabPointer` on `_windowed_mouse` toggle.

### KBD_Update
- **Signature:** `void KBD_Update(void)`
- **Purpose:** Drains pending X events, then dispatches queued key events via `Key_Event_fp`.
- **Calls:** `XPending`, `GetEvent`, `Key_Event_fp`.

### RW_IN_Init
- **Signature:** `void RW_IN_Init(in_state_t *in_state_p)`
- **Purpose:** Initializes mouse input; registers cvars and `+mlook`/`-mlook`/`force_centerview` commands.
- **Side effects:** Populates `in_state`; sets `mouse_avail = true`.

### RW_IN_Move
- **Signature:** `void RW_IN_Move(usercmd_t *cmd)`
- **Purpose:** Converts accumulated mouse deltas into view angle changes or strafe/forward movement in `cmd`.
- **Side effects:** Clears `mx`/`my`; modifies `cmd->sidemove`, `cmd->forwardmove`, `in_state->viewangles`.

### Sys_MakeCodeWriteable
- **Signature:** `void Sys_MakeCodeWriteable(unsigned long startaddr, unsigned long length)`
- **Purpose:** Calls `mprotect` to mark a memory region read/write/execute (used for self-modifying ASM stubs).
- **Side effects:** Changes process memory protection; calls `Sys_Error` on failure.

## Control Flow Notes
- **Init:** `GLimp_Init` → signal setup only. Actual window creation deferred to `GLimp_SetMode` → `GLimp_InitGraphics`.
- **Per-frame input:** `KBD_Update` drains X events each frame; `RW_IN_Commands` + `RW_IN_Move` apply mouse state to the usercmd.
- **Per-frame render:** `GLimp_EndFrame` is the final render call — flushes and swaps buffers.
- **Shutdown:** `GLimp_Shutdown` called on exit or before mode changes; also wired to `SIGINT`/`SIGTERM`.

## External Dependencies
- `<X11/Xlib.h>`, `<X11/extensions/XShm.h>`, `<Xm/MwmUtil.h>`, `<GL/glx.h>` — X11 and GLX platform headers
- `../ref_gl/gl_local.h` — `ri` (refimport_t), `vid`, renderer types
- `../client/keys.h` — `K_*` key constants, `Key_Event_fp_t`
- `../linux/rw_linux.h` — `in_state_t`, shared Linux/IRIX input interface
- `ri.Cvar_Get`, `ri.Cmd_AddCommand`, `ri.Vid_NewWindow`, `ri.Vid_GetModeInfo`, `ri.Con_Printf` — engine import table (defined in engine core)
- `Sys_Error` — defined in platform sys layer
