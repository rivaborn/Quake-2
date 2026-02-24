# null/vid_null.c

## File Purpose
Provides a null/stub video driver for porting Quake 2 to new platforms, assuming a renderer (ref) is statically linked into the executable rather than loaded as a dynamic library. It bridges the engine's video subsystem to a statically-linked `refexport_t` implementation.

## Core Responsibilities
- Exposes `viddef` (global video state) and `re` (renderer export table)
- Builds a `refimport_t` function table and passes it to `GetRefAPI()` at init time
- Routes renderer print/error callbacks to engine `Com_Printf`/`Com_Error`
- Provides a static mode table for standard resolutions (320×240 through 1600×1200)
- Implements stub functions for menu and change-detection hooks not needed in this null driver

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `vidmode_t` | struct | Associates a mode index with a description string, width, and height |
| `viddef_t` | typedef (from client.h) | Global video state: current width/height |
| `refexport_t` | typedef (from client.h) | Renderer-exported function table |
| `refimport_t` | typedef (from client.h) | Engine-imported function table passed into the renderer |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `viddef` | `viddef_t` | global | Current video dimensions, consumed engine-wide |
| `re` | `refexport_t` | global | Active renderer function table, used throughout the client |
| `vid_modes[]` | `vidmode_t[10]` | file-static (implicit) | Fixed resolution table for mode queries |

## Key Functions

### VID_Printf
- **Signature:** `void VID_Printf(int print_level, char *fmt, ...)`
- **Purpose:** Variadic print callback passed to the renderer via `refimport_t`; routes to engine console.
- **Inputs:** `print_level` (`PRINT_ALL` or debug), format string and args.
- **Outputs/Return:** None.
- **Side effects:** Calls `Com_Printf` or `Com_DPrintf`.
- **Calls:** `vsprintf`, `Com_Printf`, `Com_DPrintf`
- **Notes:** Buffer is fixed at 4096 bytes; no overflow protection.

### VID_Error
- **Signature:** `void VID_Error(int err_level, char *fmt, ...)`
- **Purpose:** Variadic error callback passed to the renderer; escalates to engine fatal error.
- **Inputs:** `err_level`, format string and args.
- **Outputs/Return:** None (noreturn in practice).
- **Side effects:** Calls `Com_Error`, which triggers engine error handling.
- **Calls:** `vsprintf`, `Com_Error`

### VID_NewWindow
- **Signature:** `void VID_NewWindow(int width, int height)`
- **Purpose:** Renderer callback to notify the engine of a window/resolution change.
- **Inputs:** New `width` and `height`.
- **Side effects:** Updates `viddef.width` / `viddef.height`.

### VID_GetModeInfo
- **Signature:** `qboolean VID_GetModeInfo(int *width, int *height, int mode)`
- **Purpose:** Returns resolution for a given mode index from the static table.
- **Inputs:** Mode index; output pointers for width and height.
- **Outputs/Return:** `true` on valid mode, `false` if out of range.
- **Side effects:** None.

### VID_Init
- **Signature:** `void VID_Init(void)`
- **Purpose:** Initializes the video subsystem: sets default resolution, populates `refimport_t`, calls `GetRefAPI()` to obtain the renderer table, validates API version, and calls `re.Init`.
- **Inputs:** None.
- **Outputs/Return:** None.
- **Side effects:** Populates global `re`; calls `Com_Error(ERR_FATAL)` on version mismatch or renderer init failure.
- **Calls:** `GetRefAPI`, `Com_Error`, `re.Init`, and all engine functions assigned to `ri`.
- **Notes:** `re.Init` is called with `NULL, NULL` — no HWND or HINSTANCE, confirming platform-agnostic/headless use.

### VID_Shutdown
- **Signature:** `void VID_Shutdown(void)`
- **Purpose:** Tears down the renderer if it was initialized.
- **Side effects:** Calls `re.Shutdown()` if the function pointer is non-null.

- **Notes:** `VID_CheckChanges`, `VID_MenuInit`, `VID_MenuDraw`, and `VID_MenuKey` are all no-op stubs required by the engine's video interface contract.

## Control Flow Notes
- `VID_Init` is called during engine startup (from `CL_Init` or equivalent).
- `VID_Shutdown` is called on engine exit.
- `VID_CheckChanges` would normally handle `vid_restart` logic but is a no-op here — dynamic renderer switching is unsupported in this null driver.
- The renderer (`re`) is statically linked; `GetRefAPI` is declared extern and resolved at link time rather than via `dlopen`.

## External Dependencies
- `../client/client.h` — pulls in `viddef_t`, `refexport_t`, `refimport_t`, `PRINT_ALL`, `API_VERSION`, `ERR_FATAL`
- `Com_Printf`, `Com_DPrintf`, `Com_Error` — engine common layer (defined in `qcommon/common.c`)
- `Cmd_AddCommand`, `Cmd_RemoveCommand`, `Cmd_Argc`, `Cmd_Argv`, `Cbuf_ExecuteText` — command system
- `FS_LoadFile`, `FS_FreeFile`, `FS_Gamedir` — filesystem layer
- `Cvar_Get`, `Cvar_Set`, `Cvar_SetValue` — cvar system
- `GetRefAPI` — declared extern, defined in whichever statically-linked renderer is compiled in
