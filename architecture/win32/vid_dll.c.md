# win32/vid_dll.c

## File Purpose
Win32-specific video system manager that handles loading/unloading the refresh (renderer) DLL at runtime, processes the main window's message loop, and manages video mode changes. It acts as the glue layer between the engine client and the dynamically-loaded rendering backend.

## Core Responsibilities
- Load and unload the renderer DLL (`ref_gl.dll`, `ref_soft.dll`) at runtime via `VID_LoadRefresh`
- Build and pass a `refimport_t` vtable into the renderer DLL on load
- Register and process the Win32 `WndProc` (`MainWndProc`) for the main game window
- Translate Win32 scan codes and messages into Quake key events
- Handle app activation/deactivation (input, audio, alt-tab suppression)
- Check each frame for `vid_ref` changes and hot-reload the renderer (`VID_CheckChanges`)
- Expose video mode resolution table and query interface (`VID_GetModeInfo`)

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `vidmode_t` | struct | Stores a video mode's description, width, height, and mode index |
| `refexport_t` | typedef (extern) | Function table exported by the renderer DLL |
| `refimport_t` | typedef (extern) | Function table passed into the renderer DLL on load |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `re` | `refexport_t` | global | Active renderer DLL export table |
| `viddef` | `viddef_t` | global | Current video dimensions; shared with other modules |
| `cl_hwnd` | `HWND` | global | Main Win32 window handle |
| `reflib_library` | `HINSTANCE` | global | Handle to the loaded renderer DLL |
| `reflib_active` | `qboolean` | global | Whether a renderer DLL is currently loaded |
| `win_noalttab` | `cvar_t *` | global | Cvar controlling alt-tab suppression |
| `vid_ref` | `cvar_t *` | global | Name of the active renderer DLL (e.g. `"gl"`, `"soft"`) |
| `vid_xpos/ypos` | `cvar_t *` | global | Window position cvars |
| `vid_fullscreen` | `cvar_t *` | global | Fullscreen toggle cvar |
| `vid_gamma` | `cvar_t *` | global | Gamma cvar |
| `s_alttab_disabled` | `qboolean` | static | Tracks whether alt-tab is currently suppressed |
| `MSH_MOUSEWHEEL` | `UINT` | static | Registered message ID for legacy mouse wheel support |
| `vid_modes[]` | `vidmode_t[]` | static (file) | Table of 10 supported video modes (320x240–1600x1200) |
| `scantokey[128]` | `byte[]` | static (file) | Scan code to Quake key mapping table |

## Key Functions

### VID_Init
- **Signature:** `void VID_Init(void)`
- **Purpose:** Initializes all video cvars, registers console commands, and triggers initial renderer load.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** Allocates cvars, registers `vid_restart`/`vid_front` commands, calls `VID_CheckChanges` to load the renderer.
- **Calls:** `Cvar_Get`, `Cmd_AddCommand`, `putenv`, `VID_CheckChanges`
- **Notes:** The 3Dfx mode-clamping block is disabled via `#if 0`.

### VID_CheckChanges
- **Signature:** `void VID_CheckChanges(void)`
- **Purpose:** Called once per frame; detects cvar-driven changes to `vid_ref`, reloads the renderer DLL, and repositions the window.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** May call `VID_LoadRefresh`, stop sounds, toggle the console, update window position.
- **Calls:** `WIN_DisableAltTab`, `WIN_EnableAltTab`, `S_StopAllSounds`, `VID_LoadRefresh`, `Cvar_Set`, `Con_ToggleConsole_f`, `VID_UpdateWindowPosAndSize`
- **Notes:** Uses a `while` loop on `vid_ref->modified` to handle fallback to `"soft"` renderer if the requested DLL fails to load.

### VID_LoadRefresh
- **Signature:** `qboolean VID_LoadRefresh(char *name)`
- **Purpose:** Loads a renderer DLL by name, constructs the `refimport_t` vtable, retrieves `GetRefAPI`, validates API version, and initializes the renderer.
- **Inputs:** `name` — DLL filename (e.g. `"ref_gl.dll"`)
- **Outputs/Return:** `true` on success, `false` on failure
- **Side effects:** Sets `reflib_library`, `reflib_active`, `re`; sets `vidref_val` to distinguish GL/soft/other.
- **Calls:** `LoadLibrary`, `GetProcAddress`, `GetRefAPI` (from DLL), `re.Init`, `re.Shutdown`, `VID_FreeReflib`, `Com_Error`
- **Notes:** Shuts down any previously active renderer before loading. Fatal error if API version mismatches.

### MainWndProc
- **Signature:** `LONG WINAPI MainWndProc(HWND, UINT, WPARAM, LPARAM)`
- **Purpose:** Win32 window procedure; dispatches window messages to engine subsystems.
- **Inputs:** Standard Win32 `WndProc` parameters.
- **Outputs/Return:** `LONG` — 0 if handled, or `DefWindowProc` result.
- **Side effects:** Fires `Key_Event`, `IN_MouseEvent`, `AppActivate`, `re.AppActivate`, `SCR_DirtyScreen`, `CDAudio_MessageHandler`, updates cvars on `WM_MOVE`.
- **Calls:** `Key_Event`, `IN_MouseEvent`, `AppActivate`, `SCR_DirtyScreen`, `Cvar_SetValue`, `IN_Activate`, `CDAudio_MessageHandler`, `DefWindowProc`
- **Notes:** Handles both legacy `MSH_MOUSEWHEEL` (Win95) and `WM_MOUSEWHEEL` (NT4/Win98+). `Alt+Enter` toggles fullscreen via `vid_fullscreen` cvar.

### AppActivate
- **Signature:** `void AppActivate(BOOL fActive, BOOL minimize)`
- **Purpose:** Responds to application focus changes; activates/deactivates input, audio, and alt-tab suppression.
- **Inputs:** `fActive` — whether the window is active; `minimize` — whether minimized.
- **Outputs/Return:** None
- **Side effects:** Sets `ActiveApp`, `Minimized`; calls `IN_Activate`, `CDAudio_Activate`, `S_Activate`, alt-tab helpers.
- **Calls:** `Key_ClearStates`, `IN_Activate`, `CDAudio_Activate`, `S_Activate`, `WIN_EnableAltTab`, `WIN_DisableAltTab`

### MapKey
- **Signature:** `int MapKey(int key)`
- **Purpose:** Converts a Win32 `lParam` keydown/keyup value into a Quake key number, distinguishing numpad from extended keys.
- **Inputs:** `key` — Win32 lParam from `WM_KEYDOWN`/`WM_KEYUP`.
- **Outputs/Return:** Quake key constant (`int`).
- **Notes:** Non-extended numpad keys are remapped to `K_KP_*` variants.

### Notes
- `VID_Printf` and `VID_Error` are thin wrappers forwarding renderer DLL log/error calls to `Com_Printf`/`Com_Error`.
- `WIN_DisableAltTab`/`WIN_EnableAltTab` use `RegisterHotKey` on non-Win95 and `SPI_SCREENSAVERRUNNING` hack on Win95.
- `VID_GetModeInfo`, `VID_NewWindow`, `VID_UpdateWindowPosAndSize`, `VID_FreeReflib` are small utility functions.

## Control Flow Notes
- **Init:** `VID_Init` is called during engine startup; it registers cvars and immediately calls `VID_CheckChanges` to load the renderer.
- **Per-frame:** `VID_CheckChanges` is called at the top of each client frame to detect and apply renderer changes.
- **Shutdown:** `VID_Shutdown` calls `re.Shutdown` and `VID_FreeReflib`.
- The `WndProc` runs on the Windows message pump, feeding input and window events into the engine asynchronously.

## External Dependencies
- `../client/client.h` — `cl`, `cls`, `ActiveApp`, `Minimized`, `vidref_val`, `Key_Event`, `IN_Activate`, etc.
- `winquake.h` — `global_hInstance`, `s_win95`
- `qcommon.h` (via client.h) — `Com_Printf`, `Com_Error`, `Cvar_*`, `Cmd_*`, `FS_*`
- `re` (refexport_t) — populated at load time from the renderer DLL's `GetRefAPI`
- `CDAudio_Activate`, `S_Activate`, `S_StopAllSounds` — defined in audio modules
- `SCR_DirtyScreen`, `Con_ToggleConsole_f` — defined in client screen/console modules
- `sys_msg_time` — defined in `win32/sys_win.c`
