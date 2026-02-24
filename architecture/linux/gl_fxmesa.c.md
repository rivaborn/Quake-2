# linux/gl_fxmesa.c

## File Purpose
Implements the Linux-specific OpenGL initialization and frame management layer for the 3Dfx Glide/fxMesa software rasterizer backend. It provides the `GLimp_*` interface required by the GL refresh module when targeting Voodoo/3Dfx hardware via the fxMesa context API.

## Core Responsibilities
- Create and destroy fxMesa rendering contexts for 3Dfx hardware
- Map engine video modes to supported 3Dfx hardware resolutions
- Register OS signal handlers for clean shutdown on crashes or termination
- Implement the `GLimp_*` entry points expected by `ref_gl`
- Perform double-buffer swap at end of each frame
- Provide a palette-setting shim (`Fake_glColorTableEXT`) bridging fxMesa's palette extension

## Key Types / Data Structures
| Name | Kind | Purpose |
|---|---|---|
| `fxMesaContext` | typedef (external) | Opaque handle to an fxMesa rendering context |
| `resolutions[NUM_RESOLUTIONS][3]` | static array | Table mapping width/height pairs to `GR_RESOLUTION_*` enums |

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `fc` | `fxMesaContext` | static | Active fxMesa rendering context; NULL when inactive |
| `resolutions` | `static int[3][3]` | static | Lookup table of supported 3Dfx resolutions |
| `vid_fullscreen` | `cvar_t *` | global (extern) | Fullscreen mode cvar from engine |
| `vid_ref` | `cvar_t *` | global (extern) | Video renderer selection cvar from engine |

## Key Functions

### findres
- **Signature:** `static int findres(int *width, int *height)`
- **Purpose:** Finds the smallest supported 3Dfx resolution that fits the requested dimensions; clamps to 640×480 on failure.
- **Inputs:** Pointers to requested width/height (modified in place)
- **Outputs/Return:** `GR_RESOLUTION_*` enum value; width/height updated to actual resolution
- **Side effects:** Writes back clamped resolution values through pointer args
- **Calls:** None
- **Notes:** Linear scan; falls through to 640×480 default if no resolution fits

### signal_handler
- **Signature:** `static void signal_handler(int sig)`
- **Purpose:** Catches fatal OS signals, shuts down the GL context, and hard-exits.
- **Inputs:** Signal number `sig`
- **Outputs/Return:** Does not return (`_exit(0)`)
- **Side effects:** Calls `GLimp_Shutdown`, terminates process
- **Calls:** `GLimp_Shutdown`, `_exit`

### InitSig
- **Signature:** `static void InitSig(void)`
- **Purpose:** Registers `signal_handler` for all relevant crash/termination signals.
- **Side effects:** Installs signal handlers for SIGHUP, SIGQUIT, SIGILL, SIGTRAP, SIGIOT, SIGBUS, SIGFPE, SIGSEGV, SIGTERM

### GLimp_SetMode
- **Signature:** `int GLimp_SetMode(int *pwidth, int *pheight, int mode, qboolean fullscreen)`
- **Purpose:** Tears down any existing fxMesa context and creates a new one for the requested video mode.
- **Inputs:** Width/height pointers (output), engine mode index, fullscreen flag (unused here)
- **Outputs/Return:** `rserr_ok` on success, `rserr_invalid_mode` on failure
- **Side effects:** Destroys old context via `GLimp_Shutdown`; allocates new fxMesa context; makes it current; notifies engine via `ri.Vid_NewWindow`
- **Calls:** `ri.Con_Printf`, `ri.Vid_GetModeInfo`, `GLimp_Shutdown`, `findres`, `fxMesaCreateContext`, `ri.Vid_NewWindow`, `fxMesaMakeCurrent`
- **Notes:** `fullscreen` parameter is accepted but not applied — 3Dfx hardware is always fullscreen

### GLimp_Shutdown
- **Signature:** `void GLimp_Shutdown(void)`
- **Purpose:** Destroys the active fxMesa context and nulls the handle.
- **Side effects:** Frees fxMesa context; sets `fc = NULL`
- **Calls:** `fxMesaDestroyContext`
- **Notes:** Safe to call when `fc` is already NULL

### GLimp_Init
- **Signature:** `int GLimp_Init(void *hinstance, void *wndproc)`
- **Purpose:** OS-level GL initialization entry point; installs signal handlers.
- **Inputs:** `hinstance`, `wndproc` — unused on this platform
- **Outputs/Return:** Always returns `true`
- **Calls:** `InitSig`

### GLimp_EndFrame
- **Signature:** `void GLimp_EndFrame(void)`
- **Purpose:** Flushes the GL pipeline and swaps the front/back buffers.
- **Calls:** `glFlush`, `fxMesaSwapBuffers`

### Fake_glColorTableEXT
- **Signature:** `void Fake_glColorTableEXT(GLenum target, GLenum internalformat, GLsizei width, GLenum format, GLenum type, const GLvoid *table)`
- **Purpose:** Converts an RGB palette table to BGRA+alpha and uploads it to the 3Dfx hardware via the proprietary palette extension.
- **Side effects:** Calls `gl3DfxSetPaletteEXT` with the reformatted palette
- **Notes:** `target`, `internalformat`, `width`, `format`, `type` are all ignored; only the raw byte stream of `table` is used

## Control Flow Notes
- `GLimp_Init` is called once at renderer startup (installs signals only)
- `GLimp_SetMode` is called during video mode changes to (re)create the fxMesa context
- `GLimp_BeginFrame` and `GLimp_AppActivate` are stubs with no behavior
- `GLimp_EndFrame` is called once per rendered frame to present the buffer
- `GLimp_Shutdown` is called on mode changes and process exit

## External Dependencies
- `<GL/fxmesa.h>` — fxMesa/Glide context API (`fxMesaCreateContext`, `fxMesaDestroyContext`, `fxMesaMakeCurrent`, `fxMesaSwapBuffers`, `GR_RESOLUTION_*`)
- `../ref_gl/gl_local.h` — `ri` refimport interface, `rserr_*` codes, `qboolean`
- `../client/keys.h` — included but not directly used in this file
- `../linux/rw_linux.h` — Linux window/input shared header
- `gl3DfxSetPaletteEXT` — defined externally (3Dfx GL extension, linked from fxMesa or Glide)
- `ri.Con_Printf`, `ri.Vid_GetModeInfo`, `ri.Vid_NewWindow` — engine callbacks via `refimport_t`
