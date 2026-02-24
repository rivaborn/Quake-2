# game/g_main.c

## File Purpose
This is the game DLL entry point and main frame loop for the Quake 2 game module. It initializes the game-engine interface, registers all exported game functions, and drives the per-frame simulation of every entity in the world.

## Core Responsibilities
- Expose `GetGameAPI` as the DLL entry point, wiring all game callbacks into `game_export_t`
- Maintain global game state: `game`, `level`, `gi`, `globals`, `st`
- Drive the per-frame entity update loop (`G_RunFrame`)
- Enforce deathmatch win conditions (timelimit, fraglimit) via `CheckDMRules`
- Manage level transitions: map cycling, intermission, and exit
- Provide `Sys_Error`/`Com_Printf` stubs for non-hard-linked builds

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `game_locals_t` | struct | Persistent game state (clients array, etc.) |
| `level_locals_t` | struct | Per-level transient state (framenum, time, intermission, etc.) |
| `game_import_t` | struct | Engine→game function table (gi) |
| `game_export_t` | struct | Game→engine function table (globals) |
| `spawn_temp_t` | struct | Temporary spawn key/value storage |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `game` | `game_locals_t` | global | Persistent game state across level loads |
| `level` | `level_locals_t` | global | Current level transient state |
| `gi` | `game_import_t` | global | Engine import table (engine services) |
| `globals` | `game_export_t` | global | Game export table returned to engine |
| `st` | `spawn_temp_t` | global | Temporary spawn parameters |
| `g_edicts` | `edict_t *` | global | Pointer to the entity array |
| `sm_meat_index` | `int` | global | Model index for meat/gibs |
| `snd_fry` | `int` | global | Sound index for frying sound |
| `meansOfDeath` | `int` | global | Tracks current death cause for obituary logic |
| `deathmatch`, `coop`, `dmflags`, `skill`, `fraglimit`, `timelimit`, `password`, `spectator_password`, `maxclients`, `maxspectators`, `maxentities`, `g_select_empty`, `dedicated`, `filterban`, `sv_maxvelocity`, `sv_gravity`, `sv_rollspeed`, `sv_rollangle`, `gun_x/y/z`, `run_pitch/roll`, `bob_up/pitch/roll`, `sv_cheats`, `flood_msgs/persecond/waitdelay`, `sv_maplist` | `cvar_t *` | global | All game-side console variable handles |

## Key Functions

### GetGameAPI
- **Signature:** `game_export_t *GetGameAPI(game_import_t *import)`
- **Purpose:** DLL entry point; copies the engine import table and fills in all game export callbacks.
- **Inputs:** `import` — engine-provided function/data table
- **Outputs/Return:** Pointer to `globals` (game export table)
- **Side effects:** Writes `gi` global; sets all `globals.*` function pointers and `edict_size`
- **Calls:** None (pure assignment)
- **Notes:** Called once at game DLL load; `GAME_API_VERSION` must match engine expectation.

### ShutdownGame
- **Signature:** `void ShutdownGame(void)`
- **Purpose:** Frees all tagged memory allocations before DLL unload.
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** Calls `gi.FreeTags(TAG_LEVEL)` and `gi.FreeTags(TAG_GAME)`
- **Calls:** `gi.dprintf`, `gi.FreeTags`
- **Notes:** Registered as `globals.Shutdown`; engine calls this on game shutdown.

### G_RunFrame
- **Signature:** `void G_RunFrame(void)`
- **Purpose:** Advances the game simulation by one frame (FRAMETIME = 0.1s); iterates all entities, runs client frames, and checks end-of-level conditions.
- **Inputs:** None (operates on global `level`, `g_edicts`, `globals.num_edicts`)
- **Outputs/Return:** void
- **Side effects:** Increments `level.framenum`/`level.time`; mutates entity state; may trigger `ExitLevel`
- **Calls:** `AI_SetSightClient`, `ExitLevel`, `M_CheckGround`, `ClientBeginServerFrame`, `G_RunEntity`, `CheckDMRules`, `ClientEndServerFrames`
- **Notes:** Client entities (indices 1–maxclients) go through `ClientBeginServerFrame` and skip `G_RunEntity`. Ground-entity staleness is detected and corrected here.

### CheckDMRules
- **Signature:** `void CheckDMRules(void)`
- **Purpose:** Checks if timelimit or fraglimit has been reached; ends the DM level if so.
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** May call `EndDMLevel` → `BeginIntermission`; broadcasts print messages via `gi.bprintf`
- **Calls:** `EndDMLevel`, `gi.bprintf`
- **Notes:** Returns immediately if intermission is already active or deathmatch is off.

### EndDMLevel
- **Signature:** `void EndDMLevel(void)`
- **Purpose:** Determines the next map when a DM limit is hit; respects `DF_SAME_LEVEL`, `sv_maplist`, `level.nextmap`, and existing `target_changelevel` entities.
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** Calls `BeginIntermission`; uses `strdup`/`strtok`/`free` for maplist parsing
- **Calls:** `BeginIntermission`, `CreateTargetChangeLevel`, `G_Find`, `Q_stricmp`, `strdup`, `strtok`, `free`
- **Notes:** Map list parsing uses destructive `strtok`; first map in list is saved as fallback.

### ExitLevel
- **Signature:** `void ExitLevel(void)`
- **Purpose:** Executes the actual map change after intermission ends.
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** Issues `gamemap` console command via `gi.AddCommandString`; resets intermission state; clamps player health to max
- **Calls:** `Com_sprintf`, `gi.AddCommandString`, `ClientEndServerFrames`

### ClientEndServerFrames
- **Signature:** `void ClientEndServerFrames(void)`
- **Purpose:** Calls `ClientEndServerFrame` for every connected client to finalize their view/playerstate.
- **Calls:** `ClientEndServerFrame`

### CreateTargetChangeLevel
- **Signature:** `edict_t *CreateTargetChangeLevel(char *map)`
- **Purpose:** Spawns a transient `target_changelevel` entity pointing to the specified map name.
- **Calls:** `G_Spawn`, `Com_sprintf`

## Control Flow Notes

`GetGameAPI` is called at DLL load time (init). Each server frame the engine calls `G_RunFrame` (frame loop), which owns the entire entity simulation. On DM limit, `CheckDMRules` → `EndDMLevel` → `BeginIntermission` starts the intermission phase; on the next frame after `level.exitintermission` is set, `ExitLevel` issues the map change command. `ShutdownGame` is called at teardown.

## External Dependencies
- `g_local.h` — pulls in all game types, constants, and forward declarations
- `AI_SetSightClient`, `M_CheckGround` — defined in `g_ai.c` / `g_monster.c`
- `G_RunEntity`, `G_Find`, `G_Spawn` — defined in `g_utils.c` / `g_phys.c`
- `ClientBeginServerFrame`, `ClientEndServerFrame`, `BeginIntermission` — defined in `p_client.c`
- `ServerCommand` — defined in `g_svcmds.c`
- All `gi.*` functions — provided by engine at runtime via `GetGameAPI`
