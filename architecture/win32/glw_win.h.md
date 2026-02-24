# win32/glw_win.h

## File Purpose
Declares the Win32-specific OpenGL window state structure (`glwstate_t`) and its single global instance. It acts as the shared interface between the Win32 GL window implementation (`glw_imp.c`) and the GL renderer.

## Core Responsibilities
- Defines the `glwstate_t` struct holding all Win32 OpenGL window handles
- Exposes the global `glw_state` instance to other translation units
- Guards against inclusion on non-Win32 platforms via a compile-time `#error`

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `glwstate_t` | struct | Aggregates Win32 handles and flags needed to manage an OpenGL rendering window |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `glw_state` | `glwstate_t` | global (extern) | Singleton window state shared across the Win32 GL subsystem; defined in `glw_imp.c` |

## Key Functions
None. This is a header-only declaration file.

## Control Flow Notes
This header is included by `glw_imp.c` (where `glw_state` is defined) and by the GL renderer (`ref_gl/`) to access window handles during initialization, frame rendering, and shutdown. The typical lifecycle is:
- **Init**: `hInstance`, `hWnd`, `hDC`, `hGLRC`, and `hinstOpenGL` are populated during window creation and GL context setup.
- **Frame**: `hDC`/`hGLRC` are used for buffer swapping.
- **Shutdown**: Handles are released and zeroed.

## External Dependencies
- `<windows.h>` (implicit) — provides `HINSTANCE`, `HDC`, `HWND`, `HGLRC`, `FILE`
- `qboolean` — defined in `qcommon/qcommon.h` or `game/q_shared.h`
- `glw_imp.c` — defines `glw_state`; not visible from this header

### Notes on `glwstate_t` fields
- `wndproc` is typed as `void *` rather than `WNDPROC` to avoid a forward-declaration dependency on the window procedure signature
- `minidriver`, `allowdisplaydepthchange`, `mcd_accelerated` are boolean flags controlling GL driver selection and display mode behavior
- `log_fp` suggests optional GL call logging to a file, consistent with the `QGL_*` wrapper layer present in `ref_gl/`
