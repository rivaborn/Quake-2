# server/sv_game.c

## File Purpose
This file implements the server-side interface (game import table) between the Quake 2 engine and the game DLL. It bridges engine services to the game module by populating a `game_import_t` struct with function pointers, and manages loading/unloading of the game DLL.

## Core Responsibilities
- Populate the `game_import_t` function pointer table passed to the game DLL at init time
- Provide `PF_*` (print/format) callbacks for game-to-engine communication
- Wrap multicast buffer write operations for game use
- Expose PVS/PHS visibility queries to game logic
- Manage game DLL lifecycle (load via `SV_InitGameProgs`, unload via `SV_ShutdownGameProgs`)

## Key Types / Data Structures
None defined in this file; uses types from `server.h` and `game.h`.

## Global / File-Static State
| Name | Type | Scope | Purpose |
|------|-------|-------|---------|
| `ge` | `game_export_t *` | global | Pointer to the loaded game DLL's exported function table |

## Key Functions

### PF_Unicast
- **Signature:** `void PF_Unicast(edict_t *ent, qboolean reliable)`
- **Purpose:** Flushes `sv.multicast` buffer to a single client
- **Inputs:** Target entity, reliability flag
- **Outputs/Return:** void
- **Side effects:** Writes to `client->netchan.message` or `client->datagram`; clears `sv.multicast`
- **Calls:** `NUM_FOR_EDICT`, `SZ_Write`, `SZ_Clear`
- **Notes:** Silently returns if entity index is out of client range

### PF_cprintf
- **Signature:** `void PF_cprintf(edict_t *ent, int level, char *fmt, ...)`
- **Purpose:** Sends a formatted print message to a specific client or the server console
- **Inputs:** Target entity (NULL = console), print level, format string + varargs
- **Outputs/Return:** void
- **Side effects:** Calls `SV_ClientPrintf` or `Com_Printf`
- **Calls:** `NUM_FOR_EDICT`, `Com_Error`, `SV_ClientPrintf`, `Com_Printf`
- **Notes:** Calls `Com_Error(ERR_DROP)` if ent maps to a non-client index

### PF_centerprintf
- **Signature:** `void PF_centerprintf(edict_t *ent, char *fmt, ...)`
- **Purpose:** Sends a centerprint message to a single client via multicast
- **Inputs:** Target entity, format string + varargs
- **Outputs/Return:** void
- **Side effects:** Writes to `sv.multicast`, calls `PF_Unicast`
- **Calls:** `NUM_FOR_EDICT`, `MSG_WriteByte`, `MSG_WriteString`, `PF_Unicast`

### PF_setmodel
- **Signature:** `void PF_setmodel(edict_t *ent, char *name)`
- **Purpose:** Assigns a model to an entity; for inline BSP models (`*`), copies bounds and links entity
- **Inputs:** Entity, model name string
- **Outputs/Return:** void
- **Side effects:** Sets `ent->s.modelindex`; for inline models sets `ent->mins/maxs` and calls `SV_LinkEdict`
- **Calls:** `SV_ModelIndex`, `CM_InlineModel`, `VectorCopy`, `SV_LinkEdict`

### PF_Configstring
- **Signature:** `void PF_Configstring(int index, char *val)`
- **Purpose:** Sets a configstring in `sv.configstrings` and broadcasts the update to all clients during active play
- **Inputs:** Configstring index, value string
- **Outputs/Return:** void
- **Side effects:** Modifies `sv.configstrings[index]`; multicasts `svc_configstring` when not in loading state
- **Calls:** `Com_Error`, `strcpy`, `SZ_Clear`, `MSG_WriteChar/Short/String`, `SV_Multicast`

### PF_inPVS / PF_inPHS
- **Signature:** `qboolean PF_inPVS(vec3_t p1, vec3_t p2)` / `qboolean PF_inPHS(vec3_t p1, vec3_t p2)`
- **Purpose:** Tests whether two world points are mutually visible (PVS) or audible (PHS), also enforcing area portal connectivity
- **Inputs:** Two world-space positions
- **Outputs/Return:** `true` if connected, `false` if occluded
- **Calls:** `CM_PointLeafnum`, `CM_LeafCluster`, `CM_LeafArea`, `CM_ClusterPVS/PHS`, `CM_AreasConnected`

### SV_InitGameProgs
- **Signature:** `void SV_InitGameProgs(void)`
- **Purpose:** Loads the game DLL, fully populates the `game_import_t` table, and calls `ge->Init()`
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** Sets global `ge`; calls `SV_ShutdownGameProgs` if already loaded; fatal on version mismatch
- **Calls:** `SV_ShutdownGameProgs`, `Sys_GetGameAPI`, `Com_Error`, `ge->Init`

### SV_ShutdownGameProgs
- **Signature:** `void SV_ShutdownGameProgs(void)`
- **Purpose:** Calls `ge->Shutdown()`, unloads the game DLL, and nulls `ge`
- **Calls:** `ge->Shutdown`, `Sys_UnloadGame`

## Control Flow Notes
`SV_InitGameProgs` is called during map load (from `sv_init.c`). `SV_ShutdownGameProgs` is called on server shutdown or game directory change. The `PF_*` functions are invoked at runtime by the game DLL through the imported function pointers established at init time.

## External Dependencies
- `server.h` — pulls in `svs`, `sv`, `client_t`, `edict_t`, server message APIs
- `CM_*` — collision model / BSP area functions (defined in `qcommon/cmodel.c`)
- `SV_Multicast`, `SV_LinkEdict`, `SV_UnlinkEdict`, `SV_Trace`, `SV_StartSound`, `SV_ClientPrintf` — defined in other `server/sv_*.c` files
- `Sys_GetGameAPI`, `Sys_UnloadGame` — platform-specific DLL loader (defined in platform layer)
- `Z_TagMalloc`, `Z_Free`, `Z_FreeTags` — zone memory allocator (defined in `qcommon`)
- `SCR_DebugGraph` — declared extern here, defined in client rendering code
