# linux/rw_x11.c

## File Purpose
Implements the Linux X11 software rendering window and input backend for Quake 2. It provides the platform-specific `SWimp_*` entry points required by the software renderer, and handles X11 window creation, framebuffer management (with optional MIT-SHM), keyboard/mouse event processing, and palette management.

## Core Responsibilities
- Open and manage an X11 display, window, GC, and visual
- Allocate and manage double-buffered framebuffers (standard XImage or MIT-SHM XShmImage)
- Present the rendered frame via `XShmPutImage` or `XPutImage` each frame
- Translate X11 key events to Quake key codes and queue them
- Track mouse motion and button state; apply sensitivity/filtering to produce movement deltas
- Convert 8-bit indexed palette to 16-bit RGB pixel values for non-8bpp visuals
- Register signal handlers for graceful shutdown on SIGINT/SIGTERM

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `PIXEL` | typedef (`unsigned short`) | 16-bit pixel type for RGB conversion |
| `keyq[]` | struct array (anonymous) | Circular queue of 64 key events (`key`, `down`) |
| `XShmSegmentInfo x_shminfo[2]` | struct array | Shared memory segment descriptors for double-buffered SHM frames |
| `in_state_t *in_state` | pointer to struct | Engine input state (view angles, callbacks) passed in at init |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `x_disp` | `Display *` | static | Active X11 display connection |
| `x_win` | `Window` | static | Main application window |
| `x_gc` | `GC` | static | Graphics context for XPutImage |
| `x_vis` / `x_visinfo` | `Visual*` / `XVisualInfo*` | static | Selected visual and its info |
| `x_framebuffer[2]` | `XImage*[2]` | static | Double-buffered render targets |
| `x_shminfo[2]` | `XShmSegmentInfo[2]` | static | SHM descriptors for above |
| `doShm` | `qboolean` | static | Whether MIT-SHM path is active |
| `oktodraw` | `qboolean` | static | SHM completion gate flag |
| `X11_active` | `qboolean` | static | Guards shutdown/palette idempotency |
| `current_framebuffer` | `int` | global | Index of the buffer currently being written |
| `keyq` / `keyq_head` / `keyq_tail` | struct array / int / int | global | Key event circular queue and indices |
| `st2d_8to16table[256]` | `PIXEL[256]` | static | Precomputed 8→16-bit palette LUT |
| `mouse_buttonstate` / `mouse_oldbuttonstate` | `int` | static | Current and previous mouse button bitmasks |
| `mx`, `my` | `int` | static | Accumulated mouse delta this frame |

## Key Functions

### SWimp_Init
- **Signature:** `int SWimp_Init(void *hInstance, void *wndProc)`
- **Purpose:** Opens the X11 display and installs signal handlers; does not create the window.
- **Inputs:** Unused `hInstance`/`wndProc` (Win32 compatibility shim).
- **Outputs/Return:** `true` on success; calls `Sys_Error` on failure.
- **Side effects:** Sets `x_disp`; installs `TragicDeath` on SIGINT/SIGTERM.
- **Calls:** `XOpenDisplay`, `sigaction`, `Sys_Error`

### SWimp_InitGraphics
- **Signature:** `static qboolean SWimp_InitGraphics(qboolean fullscreen)`
- **Purpose:** Selects X visual, creates the window and GC, maps it, then allocates framebuffers (SHM or plain).
- **Inputs:** `fullscreen` flag (currently unused; always runs windowed).
- **Outputs/Return:** `true` on success.
- **Side effects:** Populates `x_win`, `x_gc`, `x_vis`, `x_visinfo`, `x_framebuffer[]`, `vid.buffer`, `vid.rowbytes`; calls `SWimp_Shutdown` first to free prior state; notifies engine via `ri.Vid_NewWindow`.
- **Calls:** `SWimp_Shutdown`, `XAutoRepeatOff`, `XGetVisualInfo`, `XCreateWindow`, `XCreateGC`, `XMapWindow`, `XShmQueryExtension`, `ResetSharedFrameBuffers` / `ResetFrameBuffer`, `CreateNullCursor`

### SWimp_EndFrame
- **Signature:** `void SWimp_EndFrame(void)`
- **Purpose:** Blits the current framebuffer to the X window; swaps buffers in SHM mode.
- **Inputs:** None (reads globals `current_framebuffer`, `doShm`, `x_framebuffer`).
- **Side effects:** Calls `st2_fixup` for non-8bpp; blocks on SHM completion event; advances `current_framebuffer`; updates `vid.buffer`.
- **Calls:** `st2_fixup`, `XShmPutImage`, `GetEvent`, `XPutImage`, `XSync`

### SWimp_SetPalette
- **Signature:** `void SWimp_SetPalette(const unsigned char *palette)`
- **Purpose:** Rebuilds `st2d_8to16table` from a 4-byte-per-entry xRGB palette; also uploads to X colormap on 8-bit PseudoColor visuals.
- **Calls:** `xlib_rgb`, `XStoreColors`

### SWimp_Shutdown
- **Signature:** `void SWimp_Shutdown(void)`
- **Purpose:** Detaches SHM segments or frees plain framebuffers, destroys the window, re-enables key auto-repeat.
- **Side effects:** Clears `x_framebuffer[]`, sets `X11_active = false`.
- **Calls:** `XShmDetach`, `shmdt`, `XDestroyWindow`, `XAutoRepeatOn`

### RW_IN_Init / RW_IN_Move / RW_IN_Commands
- **RW_IN_Init:** Registers input cvars and `+mlook`/`-mlook`/`force_centerview` commands; sets `mouse_avail = true`.
- **RW_IN_Move:** Applies optional 2-frame filter, sensitivity scaling, and maps deltas to `viewangles` or `usercmd_t` based on `mlooking`/`freelook`/`lookstrafe` state.
- **RW_IN_Commands:** Generates `Key_Event_fp` calls for mouse button transitions (3 buttons).

### KBD_Update
- **Signature:** `void KBD_Update(void)`
- **Purpose:** Drains all pending X events via `GetEvent`, then dispatches queued key events through `Key_Event_fp`.
- **Calls:** `XPending`, `GetEvent`, `Key_Event_fp`

### GetEvent
- **Signature:** `void GetEvent(void)`
- **Purpose:** Pops one X event and dispatches: key press/release → `keyq`, motion → `mx`/`my` accumulation (with optional warp-to-center), button → `mouse_buttonstate`, configure → resize notification, SHM completion → `oktodraw`.
- **Side effects:** May call `XWarpPointer`, `XGrabPointer`/`XUngrabPointer` on `_windowed_mouse` change.

### XLateKey
- **Signature:** `int XLateKey(XKeyEvent *ev)`
- **Purpose:** Maps X `KeySym` values to Quake `K_*` constants via a large switch; falls back to ASCII for unmapped keys.

### Notes
- `shiftmask_init` / `xlib_rgb`: Compute channel shift amounts from visual masks once; `xlib_rgb` converts r,g,b to a packed `PIXEL`.
- `st2_fixup`: In-place converts 8-bit indexed scanlines to 16-bit in the XImage buffer, iterating in 8-pixel unrolled strips (right-to-left to avoid overwrite).
- `ResetFrameBuffer` / `ResetSharedFrameBuffers`: Allocate/reallocate framebuffers to match current `vid.width`/`vid.height`.
- `CreateNullCursor`: Creates a 1×1 invisible cursor to hide the system cursor inside the window.
- `Sys_MakeCodeWriteable`: Uses `mprotect` to mark a code region writable (for self-modifying assembly paths); not X11-specific.

## Control Flow Notes
- **Init:** `SWimp_Init` (display open) → `SWimp_SetMode` → `SWimp_InitGraphics` (window + framebuffers).
- **Per-frame:** Engine renders into `vid.buffer`; `SWimp_EndFrame` blits to screen; `KBD_Update` and `RW_IN_Commands`/`RW_IN_Move` pump input.
- **Shutdown:** `SWimp_Shutdown` tears down window and framebuffers.

## External Dependencies
- `<X11/Xlib.h>`, `<X11/extensions/XShm.h>`, `<sys/shm.h>`: X11 display, SHM extension
- `../ref_soft/r_local.h`: `vid`, `sw_state`, `d_8to24table`, `ri` refimport, `R_GammaCorrectAndSetPalette`
- `../client/keys.h`: `K_*` key constants, `Key_Event_fp_t`
- `../linux/rw_linux.h`: `in_state_t` definition
- `Sys_Error`, `ri.Con_Printf`, `ri.Cvar_Get`, `ri.Cmd_AddCommand`, `ri.Vid_NewWindow`, `ri.Vid_GetModeInfo`: defined elsewhere in engine/renderer import table
