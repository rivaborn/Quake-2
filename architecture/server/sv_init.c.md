# server/sv_init.c

## File Purpose
Handles server initialization, map loading, and level transitions for the Quake 2 server. It manages the per-level `sv` structure and the persistent `svs` structure, orchestrating the full lifecycle of spawning a new server instance.

## Core Responsibilities
- Maintain and initialize the global `sv` (per-level) and `svs` (persistent) server state structures
- Register and look up model, sound, and image indices in the configstring table
- Load BSP maps, inline models, and spawn game entities via the game DLL interface
- Create entity baselines for delta-compressed client updates
- Handle savegame detection and level-return logic
- Parse and dispatch `map` command strings (cinematics, demos, PCX screens, BSP levels)
- Bootstrap a full game session including client slot allocation and network configuration

## Key Types / Data Structures
None defined here; uses types from `server.h`.

## Global / File-Static State
| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `svs` | `server_static_t` | global | Persistent server state (clients, spawn count, heartbeat timing) |
| `sv` | `server_t` | global | Per-level server state (configstrings, baselines, map name, time) |

## Key Functions

### SV_FindIndex
- Signature: `int SV_FindIndex(char *name, int start, int max, qboolean create)`
- Purpose: Searches the configstring table for an existing resource name; optionally registers a new one.
- Inputs: Resource name, configstring base offset, max count, create flag.
- Outputs/Return: Index into the configstring sub-table (1-based), or 0 if not found/empty name.
- Side effects: Writes to `sv.configstrings`; if not in `ss_loading`, broadcasts a `svc_configstring` update via `sv.multicast`.
- Calls: `SZ_Clear`, `MSG_WriteChar`, `MSG_WriteShort`, `MSG_WriteString`, `SV_Multicast`, `Com_Error`.
- Notes: Overflows trigger `ERR_DROP`. Uses `strncpy` with `sizeof(sv.configstrings[i])` — a latent bug: should be `sv.configstrings[start+i]`.

### SV_CreateBaseline
- Signature: `void SV_CreateBaseline(void)`
- Purpose: Snapshots current entity state into `sv.baselines[]` for delta-compression of subsequent client updates.
- Inputs: None (reads `ge->num_edicts` and all live edicts).
- Outputs/Return: Populates `sv.baselines[entnum]` for each qualifying entity.
- Side effects: Writes to `sv.baselines`; sets `s.number` and copies `origin` to `old_origin` on each entity.
- Calls: `EDICT_NUM`, `VectorCopy`.
- Notes: Skips entities with no modelindex, sound, or effects — purely visual/audible entities participate in delta.

### SV_CheckForSavegame
- Signature: `void SV_CheckForSavegame(void)`
- Purpose: Detects an existing save file for the current level and restores world state from it.
- Inputs: None (uses `sv.name`, cvars).
- Outputs/Return: None.
- Side effects: Calls `SV_ClearWorld`, `SV_ReadLevelFile`; if not a loadgame, runs 100 game frames (temporarily suppressing reliable data via `ss_loading`).
- Calls: `Cvar_VariableValue`, `FS_Gamedir`, `Com_sprintf`, `fopen`/`fclose`, `SV_ClearWorld`, `SV_ReadLevelFile`, `ge->RunFrame`.
- Notes: Skipped in deathmatch or when `sv_noreload` is set. The 100-frame warmup comment references rlava2 overflow as the motivation.

### SV_SpawnServer
- Signature: `void SV_SpawnServer(char *server, char *spawnpoint, server_state_t serverstate, qboolean attractloop, qboolean loadgame)`
- Purpose: Core map-change routine — wipes per-level state, loads the BSP, spawns entities, runs settle frames, and establishes baselines.
- Inputs: Map name, spawn point, target server state, attract loop and loadgame flags.
- Outputs/Return: None.
- Side effects: Zeroes `sv`, increments `svs.spawncount`, sets `sv.state` twice (loading → serverstate), loads BSP via CM, calls into game DLL, updates `mapname` cvar.
- Calls: `CM_LoadMap`, `CM_NumInlineModels`, `CM_InlineModel`, `CM_EntityString`, `SV_ClearWorld`, `SV_CreateBaseline`, `SV_CheckForSavegame`, `ge->SpawnEntities`, `ge->RunFrame` (×2), `Cvar_FullSet`, `Com_SetServerState`.
- Notes: Non-game server states (cinematic, demo, pic) load an empty map (`""`). Two `RunFrame` calls allow physics/trigger settling before clients receive the baseline.

### SV_InitGame
- Signature: `void SV_InitGame(void)`
- Purpose: Full game bootstrap — shuts down any existing game, allocates client arrays, configures networking, and loads the game DLL.
- Inputs: None.
- Outputs/Return: None.
- Side effects: Calls `SV_Shutdown` or `CL_Drop`; allocates `svs.clients` and `svs.client_entities` via `Z_Malloc`; calls `NET_Config` and `SV_InitGameProgs`; sets master server address.
- Calls: `SV_Shutdown`, `CL_Drop`, `SCR_BeginLoadingPlaque`, `Cvar_GetLatchedVars`, `NET_Config`, `NET_StringToAdr`, `SV_InitGameProgs`, `Z_Malloc`, `EDICT_NUM`.
- Notes: Enforces game mode constraints (coop+dm conflict, dedicated → dm default, maxclients clamping). Hardcodes id master IP `192.246.40.37`.

### SV_Map
- Signature: `void SV_Map(qboolean attractloop, char *levelstring, qboolean loadgame)`
- Purpose: Parses the full map command string and dispatches to `SV_SpawnServer` with the appropriate server state.
- Inputs: Attract loop flag, raw level string (may include `+nextserver` and `$spawnpoint` syntax), loadgame flag.
- Outputs/Return: None.
- Side effects: Sets `nextserver` cvar; calls `SCR_BeginLoadingPlaque`, `SV_BroadcastCommand` ("changing\n" and "reconnect\n"), `SV_SendClientMessages`, `Cbuf_CopyToDefer`.
- Calls: `SV_InitGame`, `SV_SpawnServer`, `SV_BroadcastCommand`, `SV_SendClientMessages`, `SCR_BeginLoadingPlaque`, `Cbuf_CopyToDefer`, `Cvar_Set`.
- Notes: Dispatches `.cin`→`ss_cinematic`, `.dm2`→`ss_demo`, `.pcx`→`ss_pic`, all others→`ss_game`. ZOID coop `victory.pcx` hack forces a return to `*base1`.

## Control Flow Notes
- **Init**: `SV_InitGame` is called once (or on restart) before any map loads. It is triggered by `SV_Map` when `sv.state == ss_dead`.
- **Per-map**: `SV_Map` → `SV_SpawnServer` is the frame-0 map transition path. State is `ss_loading` during entity spawn, then promoted to the target state.
- **Frame**: No per-frame logic lives here; `ge->RunFrame` is called only during spawn/savegame restore.
- **Shutdown**: `SV_Shutdown` is called indirectly via `SV_InitGame` on restart.

## External Dependencies
- `server.h` — all shared server types and declarations
- `ge` — game export interface (`ge->SpawnEntities`, `ge->RunFrame`, `ge->num_edicts`); defined in `sv_game.c`
- `CM_*` — collision model subsystem (`qcommon/cmodel.c`)
- `SV_ClearWorld`, `SV_ReadLevelFile` — defined in `sv_world.c` / `sv_game.c`
- `SV_InitGameProgs`, `SV_Shutdown` — defined in `sv_game.c` / `sv_main.c`
- `NET_Config`, `NET_StringToAdr` — network layer (`qcommon/net_chan.c` / platform net)
- `Z_Malloc`, `Cvar_*`, `Com_*`, `MSG_*`, `SZ_*` — qcommon utilities
