# win32/winquake.h

## File Purpose
Central Win32-specific header for the Quake 2 engine, aggregating Windows and DirectSound system handles, window state, and input callback declarations used across Win32 platform modules.

## Core Responsibilities
- Pulls in `<windows.h>` and `<dsound.h>` for Win32 and DirectSound APIs
- Declares the application `HINSTANCE` global
- Declares DirectSound interface pointers and buffer size
- Declares the main window handle and application focus/minimize state
- Defines the non-resizable window style constant
- Declares input activation and mouse event entry points
- Exports window geometry state (center coordinates and rect)

## Key Types / Data Structures
None (header only; all types come from Win32 SDK includes).

## Global / File-Static State
| Name | Type | Scope (global) | Purpose |
|---|---|---|---|
| `global_hInstance` | `HINSTANCE` | global | Application instance handle passed to `WinMain` |
| `pDS` | `LPDIRECTSOUND` | global | DirectSound device interface |
| `pDSBuf` | `LPDIRECTSOUNDBUFFER` | global | Primary/secondary DirectSound playback buffer |
| `gSndBufSize` | `DWORD` | global | Size in bytes of the DirectSound buffer |
| `cl_hwnd` | `HWND` | global | Client window handle (used by input, video, sound) |
| `ActiveApp` | `qboolean` | global | Whether the app currently has focus |
| `Minimized` | `qboolean` | global | Whether the window is minimized |
| `window_center_x` | `int` | global | Cached X center of the window (for mouse locking) |
| `window_center_y` | `int` | global | Cached Y center of the window (for mouse locking) |
| `window_rect` | `RECT` | global | Bounding rectangle of the client window |

## Key Functions

### IN_Activate
- **Signature:** `void IN_Activate(qboolean active)`
- **Purpose:** Notifies the input subsystem that the application has gained or lost focus, enabling/disabling mouse capture and raw input accordingly.
- **Inputs:** `active` — `true` if gaining focus, `false` if losing it.
- **Outputs/Return:** void
- **Side effects:** Modifies mouse grab/clip state; defined in `win32/in_win.c`.
- **Calls:** Not inferable from this file.
- **Notes:** Typically invoked from the `WM_ACTIVATE` window message handler.

### IN_MouseEvent
- **Signature:** `void IN_MouseEvent(int mstate)`
- **Purpose:** Delivers a mouse button state bitmask to the input subsystem for processing button press/release events.
- **Inputs:** `mstate` — bitmask of currently held mouse buttons.
- **Outputs/Return:** void
- **Side effects:** Queues input events; defined in `win32/in_win.c`.
- **Calls:** Not inferable from this file.
- **Notes:** Called from the window procedure on `WM_LBUTTONDOWN` / `WM_RBUTTONDOWN` etc.

## Control Flow Notes
This is a pure header — it participates in init/frame/shutdown only through the globals it exposes. `cl_hwnd` is set during video initialization; `ActiveApp`/`Minimized` are toggled by the window procedure in `sys_win.c`; DirectSound globals are initialized in `snd_win.c`.

## External Dependencies
- `<windows.h>` — Win32 core API
- `<dsound.h>` — DirectSound 3 interfaces
- `qboolean` — defined in `qcommon/qcommon.h` or `game/q_shared.h`
- All declared globals are **defined elsewhere** (`sys_win.c`, `snd_win.c`, `in_win.c`, `vid_dll.c`)
