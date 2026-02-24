# linux/vid_so.c

## File Purpose
Linux-specific video system manager that dynamically loads and unloads the renderer ("refresh") DLL at runtime via `dlopen`/`dlsym`. It also proxies keyboard and mouse input through function pointers resolved from the same shared library.

## Core Responsibilities
- Read `/etc/quake2.conf` to locate the refresh `.so` library on disk
- Enforce root-ownership security checks before loading the renderer library
- Resolve renderer (`GetRefAPI`), keyboard (`KBD_*`), and mouse (`RW_IN_*`) entry points from the loaded `.so`
- Initialize and populate the `refimport_t` struct passed into `GetRefAPI`
- Monitor `vid_ref->modified` each frame and hot-reload the renderer when it changes
- Provide thin wrappers (`IN_*`) that delegate to function pointers from the loaded library
- Manage privilege escalation/dropping (`seteuid`/`setreuid`) around `.so` loading

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `vidmode_t` | struct | Associates a mode index with a description string and width/height |
| `refexport_t` | typedef (defined elsewhere) | Function table exported by the renderer DLL |
| `refimport_t` | typedef (defined elsewhere) | Function table the engine provides to the renderer DLL |
| `in_state_t` | typedef (defined elsewhere) | Input state block passed to the input subsystem in the renderer |
| `viddef_t` | typedef (defined elsewhere) | Global video state (width, height, etc.) |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `re` | `refexport_t` | global | Live function table from the loaded renderer DLL |
| `viddef` | `viddef_t` | global | Current video dimensions; read by other modules |
| `reflib_library` | `void *` | global | `dlopen` handle to the active renderer `.so` |
| `reflib_active` | `qboolean` | global | Whether a renderer is currently loaded and live |
| `vid_ref` | `cvar_t *` | global | Cvar naming the active renderer (e.g. `"softx"`, `"gl"`) |
| `vid_xpos/vid_ypos` | `cvar_t *` | global | Window position cvars |
| `vid_fullscreen` | `cvar_t *` | global | Fullscreen toggle cvar |
| `vid_gamma` | `cvar_t *` | global | Gamma cvar |
| `in_state` | `in_state_t` | global | Input state block wired to engine callbacks |
| `KBD_Init/Update/Close_fp` | function pointers | global | Keyboard entry points from renderer `.so` |
| `RW_IN_*_fp` | function pointers (×6) | global | Mouse/input entry points from renderer `.so` |
| `in_joystick` | `cvar_t *` | global | Joystick enable cvar |
| `vid_modes[]` | `vidmode_t[]` | file-static (effectively global) | Table of 10 supported video modes |

## Key Functions

### VID_LoadRefresh
- **Signature:** `qboolean VID_LoadRefresh( char *name )`
- **Purpose:** Loads a named renderer `.so`, resolves all entry points, initializes input and renderer subsystems.
- **Inputs:** `name` — filename of the renderer shared library (e.g. `ref_softx.so`)
- **Outputs/Return:** `true` on success, `false` on failure
- **Side effects:** Sets `re`, all `KBD_*_fp` and `RW_IN_*_fp` globals; calls `re.Init`, `Real_IN_Init`, `KBD_Init_fp`; drops root privileges after load
- **Calls:** `seteuid`, `fopen`/`fgets`/`fclose`, `stat`, `dlopen`, `dlsym`, `re.Shutdown`, `VID_FreeReflib`, `Real_IN_Init`, `KBD_Init_fp`, `Sys_Error`, `Com_Error`, `Com_Printf`

### VID_CheckChanges
- **Signature:** `void VID_CheckChanges(void)`
- **Purpose:** Called once per frame; detects `vid_ref->modified` and reloads the renderer DLL, with fallback to `soft` on failure.
- **Inputs:** None (reads global cvars)
- **Outputs/Return:** void
- **Side effects:** May call `S_StopAllSounds`, `VID_LoadRefresh`, `Cvar_Set/SetValue`, `Con_ToggleConsole_f`; resets `cl.refresh_prepped` and `cls.disable_screen`
- **Calls:** `S_StopAllSounds`, `VID_LoadRefresh`, `Cvar_Get`, `Cvar_Set`, `Cvar_SetValue`, `Com_Error`, `Con_ToggleConsole_f`

### VID_FreeReflib
- **Signature:** `void VID_FreeReflib(void)`
- **Purpose:** Shuts down the active renderer and closes the `.so` handle, nulling all function pointers.
- **Side effects:** Calls `KBD_Close_fp`, `RW_IN_Shutdown_fp`, `dlclose`; zeroes `re`; clears `reflib_library`/`reflib_active`

### VID_Init / VID_Shutdown
- **Signature:** `void VID_Init(void)` / `void VID_Shutdown(void)`
- **Purpose:** Engine-facing init/shutdown. `VID_Init` registers cvars, adds `vid_restart` console command, sets `FX_GLIDE_NO_SPLASH`, and calls `VID_CheckChanges`. `VID_Shutdown` tears down keyboard/input and calls `VID_FreeReflib`.

### Do_Key_Event
- **Signature:** `void Do_Key_Event(int key, qboolean down)`
- **Purpose:** Bridge from renderer-side keyboard events into the engine key event system.
- **Calls:** `Key_Event`, `Sys_Milliseconds`

- **Notes (trivial wrappers):** `IN_Init`, `Real_IN_Init`, `IN_Shutdown`, `IN_Commands`, `IN_Move`, `IN_Frame`, `IN_Activate` are all one-liner guards that call the corresponding `RW_IN_*_fp` if non-null. `VID_Printf`/`VID_Error` forward variadic messages to `Com_Printf`/`Com_DPrintf`/`Com_Error`. `VID_GetModeInfo` and `VID_NewWindow` are simple table lookups/setters.

## Control Flow Notes
- **Init:** `VID_Init` → `VID_CheckChanges` → `VID_LoadRefresh` (loads `.so`, inits renderer + input)
- **Per-frame:** `VID_CheckChanges` is called before rendering; if `vid_ref->modified`, it tears down and reloads the renderer mid-session
- **Shutdown:** `VID_Shutdown` → `KBD_Close_fp` + `RW_IN_Shutdown_fp` + `re.Shutdown` + `VID_FreeReflib`

## External Dependencies
- `<dlfcn.h>` — `dlopen`, `dlclose`, `dlsym`, `dlerror`
- `../client/client.h` — `cl`, `cls`, `Key_Event`, `IN_CenterView`, `in_strafe`, `Cvar_*`, `Cmd_*`, `Com_*`, `FS_*`, `S_StopAllSounds`, `Cbuf_ExecuteText`
- `../linux/rw_linux.h` — `in_state_t`, `Key_Event_fp_t`
- `saved_euid` — declared `extern`, defined in `linux/sys_linux.c`
- `GetRefAPI_t`, `refexport_t`, `refimport_t`, `API_VERSION` — defined in `client/ref.h`
- `viddef_t` — defined elsewhere (likely `client/vid.h`)
