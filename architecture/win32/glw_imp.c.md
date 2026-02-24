# win32/glw_imp.c

## File Purpose
Implements all Win32-specific OpenGL platform layer (GLimp) functions for the Quake 2 GL renderer. It manages the Win32 window lifecycle, pixel format selection, WGL context creation, display mode switching, and per-frame buffer management.

## Core Responsibilities
- Register and create the Win32 window (`WNDCLASS` / `CreateWindowEx`)
- Configure and set the OpenGL pixel format descriptor (PFD)
- Create and activate the WGL rendering context
- Handle fullscreen mode via `ChangeDisplaySettings` (CDS), including dual-monitor fallback
- Provide per-frame begin/end hooks (stereo buffer selection, buffer swap)
- Shut down the GL context, DC, window, and display mode cleanly
- Detect OS version to gate display depth change capability

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `glwstate_t` | struct (defined in `glw_win.h`) | Win32 GL window state: HWND, HDC, HGLRC, hInstance, wndproc, flags |
| `DEVMODE` | struct (Win32) | Display mode descriptor used with `ChangeDisplaySettings` |
| `PIXELFORMATDESCRIPTOR` | struct (Win32) | Describes desired OpenGL pixel format (color depth, z-buffer, stereo, etc.) |
| `rserr_t` | typedef/enum (defined elsewhere) | Return code from `GLimp_SetMode` |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `glw_state` | `glwstate_t` | global | Central Win32 GL window state shared across the GL renderer |
| `vid_fullscreen` | `cvar_t *` | global (extern) | Whether the game runs fullscreen |
| `vid_ref` | `cvar_t *` | global (extern) | Active renderer reference name |

## Key Functions

### VerifyDriver
- **Signature:** `static qboolean VerifyDriver(void)`
- **Purpose:** Rejects software-only GDI Generic renderer unless `mcd_accelerated` flag is set.
- **Inputs:** None (reads `glw_state.mcd_accelerated`, calls `qglGetString(GL_RENDERER)`)
- **Outputs/Return:** `qboolean` — false if running GDI Generic without acceleration
- **Side effects:** None
- **Calls:** `qglGetString`, `strcpy`, `strlwr`, `strcmp`
- **Notes:** Guard against accidentally running with the Microsoft software GL fallback.

---

### VID_CreateWindow
- **Signature:** `qboolean VID_CreateWindow(int width, int height, qboolean fullscreen)`
- **Purpose:** Registers the Win32 window class, creates the application window, and initializes the GL context for it.
- **Inputs:** Desired width/height, fullscreen flag
- **Outputs/Return:** `qboolean` — false on GL init failure
- **Side effects:** Registers `WNDCLASS`; creates and shows `HWND`; stores in `glw_state.hWnd`; calls `ri.Vid_NewWindow` to notify engine subsystems
- **Calls:** `RegisterClass`, `AdjustWindowRect`, `CreateWindowEx`, `ShowWindow`, `UpdateWindow`, `GLimp_InitGL`, `SetForegroundWindow`, `SetFocus`, `ri.Vid_NewWindow`, `ri.Cvar_Get`, `ri.Sys_Error`
- **Notes:** Uses `vid_xpos`/`vid_ypos` cvars for windowed positioning; fullscreen windows are `WS_POPUP | WS_VISIBLE | WS_EX_TOPMOST`.

---

### GLimp_SetMode
- **Signature:** `rserr_t GLimp_SetMode(int *pwidth, int *pheight, int mode, qboolean fullscreen)`
- **Purpose:** Resolves a video mode index to a resolution, attempts CDS for fullscreen with dual-monitor fallback, then creates the window.
- **Inputs:** Output width/height pointers, mode index, fullscreen flag
- **Outputs/Return:** `rserr_ok`, `rserr_invalid_mode`, or `rserr_invalid_fullscreen`
- **Side effects:** Calls `GLimp_Shutdown` to destroy any existing window; calls `ChangeDisplaySettings`; sets `gl_state.fullscreen`
- **Calls:** `GLimp_Shutdown`, `ri.Vid_GetModeInfo`, `ChangeDisplaySettings`, `VID_CreateWindow`, `GetDC`, `GetDeviceCaps`, `ReleaseDC`, `ri.Con_Printf`
- **Notes:** Dual-monitor fallback doubles `dmPelsWidth`; if all CDS attempts fail, falls back to windowed mode returning `rserr_invalid_fullscreen`.

---

### GLimp_Shutdown
- **Signature:** `void GLimp_Shutdown(void)`
- **Purpose:** Tears down the WGL context, DC, window, log file, and resets display settings.
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** Nulls `glw_state.hGLRC`, `.hDC`, `.hWnd`; closes `log_fp`; unregisters window class; calls `ChangeDisplaySettings(0,0)` to restore desktop
- **Calls:** `qwglMakeCurrent`, `qwglDeleteContext`, `ReleaseDC`, `DestroyWindow`, `fclose`, `UnregisterClass`, `ChangeDisplaySettings`
- **Notes:** Safe to call even when partially initialized; each resource is checked before release.

---

### GLimp_Init
- **Signature:** `qboolean GLimp_Init(void *hinstance, void *wndproc)`
- **Purpose:** Stores `hInstance`/`wndproc` into `glw_state` and detects OS version to set `allowdisplaydepthchange`.
- **Inputs:** Win32 HINSTANCE, window procedure pointer
- **Outputs/Return:** `qboolean` — false if `GetVersionEx` fails
- **Side effects:** Writes `glw_state.allowdisplaydepthchange`, `.hInstance`, `.wndproc`
- **Calls:** `GetVersionEx`
- **Notes:** `allowdisplaydepthchange` requires Win95 OSR2 (build ≥ 1111) or WinNT 4+.

---

### GLimp_InitGL
- **Signature:** `qboolean GLimp_InitGL(void)`
- **Purpose:** Selects an OpenGL pixel format, creates the WGL context, makes it current, and verifies hardware acceleration.
- **Inputs:** None (uses `glw_state.hWnd`, cvars `cl_stereo`, `gl_driver`, `gl_allow_software`)
- **Outputs/Return:** `qboolean` — false on any WGL failure
- **Side effects:** Sets `glw_state.hDC`, `.hGLRC`, `.minidriver`, `.mcd_accelerated`; sets `gl_state.stereo_enabled`
- **Calls:** `GetDC`, `qwglChoosePixelFormat`, `qwglSetPixelFormat`, `ChoosePixelFormat`, `SetPixelFormat`, `DescribePixelFormat`, `qwglCreateContext`, `qwglMakeCurrent`, `VerifyDriver`, `ri.Cvar_Get`, `ri.Cvar_SetValue`, `ri.Con_Printf`
- **Notes:** Minidriver path uses `qwgl*` wrappers instead of standard GDI pixel format calls. On failure, releases DC and context before returning.

---

### GLimp_BeginFrame
- **Signature:** `void GLimp_BeginFrame(float camera_separation)`
- **Purpose:** Per-frame setup: handles `gl_bitdepth` cvar changes and selects the appropriate stereo draw buffer.
- **Inputs:** `camera_separation` — negative = left eye, positive = right eye, zero = mono
- **Outputs/Return:** void
- **Side effects:** May reset `gl_bitdepth` cvar; calls `qglDrawBuffer`
- **Calls:** `qglDrawBuffer`, `ri.Cvar_SetValue`, `ri.Con_Printf`

---

### GLimp_EndFrame
- **Signature:** `void GLimp_EndFrame(void)`
- **Purpose:** Asserts no GL error, then swaps the back buffer via WGL if drawing to `GL_BACK`.
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** Calls `qwglSwapBuffers`; fatal error on swap failure
- **Calls:** `qglGetError`, `qwglSwapBuffers`, `stricmp`, `ri.Sys_Error`

---

### GLimp_AppActivate
- **Signature:** `void GLimp_AppActivate(qboolean active)`
- **Purpose:** Minimizes the window on deactivation (fullscreen only) or restores/foregrounds it on activation.
- **Inputs:** `active` flag
- **Calls:** `SetForegroundWindow`, `ShowWindow`

## Control Flow Notes
- **Init:** `GLimp_Init` (store hInstance/wndproc) → `GLimp_SetMode` (CDS + `VID_CreateWindow`) → `GLimp_InitGL` (PFD + WGL context)
- **Per-frame:** `GLimp_BeginFrame` (buffer select) → rendering → `GLimp_EndFrame` (swap)
- **Shutdown:** `GLimp_Shutdown` (context → DC → window → display reset)

## External Dependencies
- `../ref_gl/gl_local.h` — `gl_state`, `gl_bitdepth`, `gl_drawbuffer`, `gl_driver`, `gl_allow_software`, `ri` (refimport), `rserr_t`, `qgl*` wrappers
- `glw_win.h` — `glwstate_t` definition, `WINDOW_STYLE`
- `winquake.h` — Win32 Quake environment definitions
- `qwglCreateContext`, `qwglMakeCurrent`, `qwglSwapBuffers`, etc. — defined in `win32/qgl_win.c` (WGL function pointers)
- `ri.Vid_GetModeInfo`, `ri.Vid_NewWindow`, `ri.Sys_Error`, `ri.Con_Printf`, `ri.Cvar_Get`, `ri.Cvar_SetValue` — engine import table, defined elsewhere
