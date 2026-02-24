# irix/vid_so.c

## File Purpose
This is the IRIX platform video/refresh DLL management module, responsible for dynamically loading and unloading the renderer shared library, wiring up the input subsystem (keyboard and mouse), and dispatching video mode changes each frame.

## Core Responsibilities
- Load/unload the refresh DLL (`ref_*.so`) at runtime via `dlopen`/`dlsym`
- Populate the `refimport_t` interface struct and retrieve `refexport_t` from the DLL
- Manage video mode metadata and window dimension updates
- Route keyboard and mouse input through function pointers resolved from the refresh DLL
- Check each frame for `vid_ref->modified` and reload the renderer accordingly
- Drop root privileges after renderer initialization (`setreuid`/`setegid`)

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `vidmode_t` | struct | Associates a display mode index with a description, width, and height |
| `refexport_t` | typedef (external) | Functions exported by the refresh DLL to the engine |
| `refimport_t` | typedef (external) | Engine callback table passed into the refresh DLL |
| `in_state_t` | typedef (external) | Input state passed to the mouse/input subsystem in the DLL |
| `viddef_t` | typedef (external) | Global video state (width/height) shared across modules |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `re` | `refexport_t` | global | Exported function table from the loaded refresh DLL |
| `viddef` | `viddef_t` | global | Current video dimensions, shared with other modules |
| `reflib_library` | `void *` | global | `dlopen` handle to the loaded refresh DLL |
| `reflib_active` | `qboolean` | global | Whether a refresh DLL is currently loaded and active |
| `vid_ref` | `cvar_t *` | global | CVar naming the active renderer (`soft`, `gl`, etc.) |
| `vid_xpos`, `vid_ypos` | `cvar_t *` | global | Window position CVars |
| `vid_fullscreen` | `cvar_t *` | global | Fullscreen toggle CVar |
| `vid_gamma` | `cvar_t *` | global | Gamma correction CVar |
| `in_state` | `in_state_t` | global | Input state struct passed to DLL input functions |
| `vid_modes[]` | `vidmode_t[]` | static (file) | Table of 10 supported video modes (320×240 – 1600×1200) |
| `KBD_*_fp` | function pointers | global | Keyboard init/update/close resolved from DLL |
| `RW_IN_*_fp` | function pointers | global | Mouse/input functions resolved from DLL |

## Key Functions

### VID_LoadRefresh
- **Signature:** `qboolean VID_LoadRefresh( char *name )`
- **Purpose:** Loads a named refresh DLL, resolves all required symbols, initializes the renderer and input subsystems, and drops root privileges.
- **Inputs:** `name` — filename of the `.so` (e.g., `ref_gl.so`)
- **Outputs/Return:** `true` on success, `false` on failure
- **Side effects:** Mutates `reflib_library`, `reflib_active`, `re`, all `KBD_*_fp` and `RW_IN_*_fp` pointers; calls `re.Init`, `KBD_Init_fp`, `Real_IN_Init`; drops root via `setreuid`/`setegid`
- **Calls:** `dlopen`, `dlsym`, `FS_NextPath`, `GetRefAPI`, `re.Init`, `re.Shutdown`, `VID_FreeReflib`, `KBD_Init_fp`, `Real_IN_Init`, `Com_Error`, `Sys_Error`
- **Notes:** Under `REF_HARD_LINKED`, skips all `dlopen`/`dlsym` and assigns function pointers directly. Returns early error path if `re.api_version != API_VERSION`.

### VID_CheckChanges
- **Signature:** `void VID_CheckChanges( void )`
- **Purpose:** Called once per frame; detects `vid_ref->modified` and reloads the renderer DLL, falling back to `ref_soft.so` on failure.
- **Inputs:** None (reads CVars)
- **Outputs/Return:** void
- **Side effects:** May call `VID_LoadRefresh`, `S_StopAllSounds`, `Con_ToggleConsole_f`; resets `cl.refresh_prepped`, `cls.disable_screen`
- **Calls:** `S_StopAllSounds`, `VID_LoadRefresh`, `Cvar_Get`, `Cvar_SetValue`, `Cvar_Set`, `Com_Error`, `Con_ToggleConsole_f`
- **Notes:** Loop continues while `vid_ref->modified` is true, allowing a fallback reload to itself trigger another pass.

### VID_Init
- **Signature:** `void VID_Init( void )`
- **Purpose:** Registers all video CVars, adds the `vid_restart` command, disables the 3Dfx splash, and performs the initial renderer load.
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** Registers CVars, adds console command, calls `VID_CheckChanges`
- **Calls:** `Cvar_Get`, `Cmd_AddCommand`, `putenv`, `VID_CheckChanges`

### VID_Shutdown
- **Signature:** `void VID_Shutdown( void )`
- **Purpose:** Shuts down keyboard and input, calls renderer shutdown, and unloads the DLL.
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** Calls `KBD_Close_fp`, `RW_IN_Shutdown_fp`, `re.Shutdown`, `VID_FreeReflib`

### VID_FreeReflib
- **Signature:** `void VID_FreeReflib( void )`
- **Purpose:** Closes the DLL handle, nulls all function pointers, zeroes `re`, and clears `reflib_active`.
- **Side effects:** `dlclose(reflib_library)`, zeroes all input/kbd function pointers and `re`

### VID_Printf / VID_Error
- Thin wrappers forwarding renderer-originated print/error calls to `Com_Printf`/`Com_DPrintf`/`Com_Error`. Provided as callbacks inside `refimport_t`.

### Input stubs (`IN_Init`, `IN_Shutdown`, `IN_Commands`, `IN_Move`, `IN_Frame`, `IN_Activate`)
- All delegate through corresponding `RW_IN_*_fp` function pointers. `IN_Init` only registers the `in_joystick` CVar; actual initialization is deferred to `Real_IN_Init` (called from `VID_LoadRefresh`).

### Do_Key_Event
- **Signature:** `void Do_Key_Event( int key, qboolean down )`
- **Purpose:** Bridge from DLL-side key callbacks into the engine key event system, stamping with `Sys_Milliseconds()`.
- **Calls:** `Key_Event`

## Control Flow Notes
- **Init:** `VID_Init` → `VID_CheckChanges` → `VID_LoadRefresh` performs first DLL load at startup.
- **Per-frame:** `VID_CheckChanges` is called at the top of each client frame to detect renderer changes.
- **Shutdown:** `VID_Shutdown` tears down the renderer and input on engine exit.

## External Dependencies
- `../client/client.h` — `cvar_t`, `cl`, `cls`, client state
- `../linux/rw_linux.h` — `in_state_t`, `Key_Event_fp_t`, shared Linux/IRIX input definitions
- `<dlfcn.h>` — `dlopen`, `dlsym`, `dlclose` (ELF dynamic linking)
- External symbols: `Com_Printf`, `Com_DPrintf`, `Com_Error`, `Cmd_AddCommand`, `Cvar_Get`, `Cvar_Set`, `FS_NextPath`, `FS_LoadFile`, `Key_Event`, `Sys_Milliseconds`, `S_StopAllSounds`, `Con_ToggleConsole_f`, `in_strafe` (defined elsewhere)
