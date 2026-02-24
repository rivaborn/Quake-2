# win32/qgl_win.c

## File Purpose
Windows-specific implementation of the QGL abstraction layer that binds all OpenGL and WGL function pointers by dynamically loading `opengl32.dll` at runtime. It also provides an optional logging/tracing layer that can intercept every GL call and record it to a file for debugging.

## Core Responsibilities
- Declare global `qgl*` function pointer variables used by all GL rendering code
- Load `opengl32.dll` via `LoadLibrary` and resolve every GL/WGL symbol via `GetProcAddress`
- NULL out all function pointers on shutdown and free the library handle
- Maintain a parallel set of `dll*` direct-dispatch pointers alongside `log*` interceptor wrappers
- Route all `qgl*` calls through logging wrappers when logging is enabled, writing call names/args to a file
- Set 3Dfx gamma environment variables unconditionally during `QGL_Init`
- Zero-initialize optional extension pointers (`EXT`, `SGIS`) that are bound later

## Key Types / Data Structures
None defined in this file; all types come from `<windows.h>` and OpenGL headers.

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `qgl*` (~200 vars) | function pointers (`APIENTRY *`) | global | Active GL dispatch pointers used by all render code |
| `qwgl*` (~20 vars) | function pointers (`WINAPI *`) | global | Active WGL context-management dispatch pointers |
| `dll*` (~200 vars) | function pointers (`APIENTRY *`) | static | Direct-to-DLL pointers; preserved when logging is enabled |
| `qwglSwapIntervalEXT` | `BOOL (WINAPI *)` | global | Extension; initialized to 0, bound externally |
| `qwglGetDeviceGammaRampEXT` / `qwglSetDeviceGammaRampEXT` | function pointers | global | Gamma ramp extension; bound externally |
| `qglPointParameterfEXT`, `qglColorTableEXT`, `qglSelectTextureSGIS`, `qglMTexCoord2fSGIS` | function pointers | global | Extension pointers initialized to 0 |

## Key Functions

### QGL_Init
- Signature: `qboolean QGL_Init( const char *dllname )`
- Purpose: Loads the named OpenGL DLL, resolves all core GL and WGL function pointers, and sets 3Dfx gamma env vars.
- Inputs: `dllname` — filename of the OpenGL DLL (e.g., `"opengl32.dll"`)
- Outputs/Return: `true` on success, `false` if `LoadLibrary` fails
- Side effects: Populates `glw_state.hinstOpenGL`; assigns all `qgl*`/`dll*` and `qwgl*` pointers; sets `gl_config.allow_cds = true`; calls `putenv` for `SSTV2_GAMMA`/`SST_GAMMA`; prints error via `ri.Con_Printf` on failure
- Calls: `LoadLibrary`, `GetProcAddress` (via `GPA` macro), `putenv`, `Com_sprintf`, `FormatMessage`, `ri.Con_Printf`
- Notes: Extension pointers (`EXT`, `SGIS`) are explicitly zeroed — callers must bind them separately after checking extension strings.

### QGL_Shutdown
- Signature: `void QGL_Shutdown( void )`
- Purpose: Frees the OpenGL DLL and NULLs every `qgl*` and `qwgl*` pointer.
- Inputs: None
- Outputs/Return: void
- Side effects: Calls `FreeLibrary( glw_state.hinstOpenGL )`; sets `glw_state.hinstOpenGL = NULL`; NULLs ~220 function pointers
- Calls: `FreeLibrary`
- Notes: Safe to call even if `QGL_Init` was never called (pointer checks are implicit via NULL assign).

### GLimp_EnableLogging
- Signature: `void GLimp_EnableLogging( qboolean enable )`
- Purpose: Switches all `qgl*` pointers between the logging interceptors and the direct `dll*` pointers.
- Inputs: `enable` — if true, redirect to `log*` wrappers; if false, restore `dll*` direct dispatch
- Outputs/Return: void
- Side effects: On first enable, opens `<gamedir>/gl.log` and writes a timestamp; redirects ~200 `qgl*` pointers
- Calls: `time`, `localtime`, `asctime`, `fopen`, `fprintf`, `ri.FS_Gamedir`, `Com_sprintf`
- Notes: `glw_state.log_fp` is checked before opening to avoid reopening on repeated enable calls.

### GLimp_LogNewFrame
- Signature: `void GLimp_LogNewFrame( void )`
- Purpose: Writes a frame boundary marker to the GL log file.
- Inputs: None
- Outputs/Return: void
- Side effects: Writes `"*** R_BeginFrame ***\n"` to `glw_state.log_fp`
- Notes: Must only be called when logging is active; no null-check on `log_fp`.

## Control Flow Notes
- `QGL_Init` is called during renderer init (from `glw_imp.c` / `GLimp_Init`) before any GL calls are made.
- `QGL_Shutdown` is called during renderer shutdown.
- `GLimp_EnableLogging` is driven by a cvar toggle in the GL renderer's misc/init code, not per-frame.
- `GLimp_LogNewFrame` is called at the start of each rendered frame when logging is enabled.

## External Dependencies
- `../ref_gl/gl_local.h` — provides `glw_state` (contains `hinstOpenGL`, `log_fp`), `gl_config`, `ri`, `qboolean`
- `glw_win.h` — Windows GL window state types
- `<float.h>` — included but not visibly used
- `glw_state` — defined in `win32/glw_imp.c`
- `ri` (refimport_t) — defined in `ref_gl/gl_rmain.c`
- `gl_config` — defined in `ref_gl/gl_rmain.c`
- `Com_sprintf` — defined in `qcommon/common.c`
