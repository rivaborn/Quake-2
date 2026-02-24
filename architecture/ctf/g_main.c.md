# ctf/g_main.c

## File Purpose
Entry point and frame driver for the CTF game DLL. Registers all game API callbacks with the engine via `GetGameAPI`, and advances the game world one frame at a time through `G_RunFrame`. It is the CTF variant counterpart to `game/g_main.c`.

## Core Responsibilities
- Export the game DLL interface (`GetGameAPI`) to the engine
- Drive the per-frame entity update loop (`G_RunFrame`)
- Enforce deathmatch end conditions (timelimit, fraglimit, CTF-specific rules)
- Handle level transitions and intermission exit (`EndDMLevel`, `ExitLevel`)
- Declare and register all global CVars used by the game module
- Provide stub implementations of `Sys_Error` and `Com_Printf` for shared code linkage

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `game_locals_t` | struct | Persistent game-wide state (clients, etc.) |
| `level_locals_t` | struct | Per-level transient state (time, intermission, mapname) |
| `game_import_t` | struct | Engine → game function table (gi) |
| `game_export_t` | struct | Game → engine function table (globals) |
| `spawn_temp_t` | struct | Temporary spawn-time entity fields |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `game` | `game_locals_t` | global | Persistent game state |
| `level` | `level_locals_t` | global | Current level state |
| `gi` | `game_import_t` | global | Engine import function table |
| `globals` | `game_export_t` | global | Game export function table returned to engine |
| `st` | `spawn_temp_t` | global | Temporary spawn fields |
| `g_edicts` | `edict_t *` | global | Pointer to the entity array |
| `sm_meat_index` | `int` | global | Model index for meat/gib |
| `snd_fry` | `int` | global | Sound index for frying |
| `meansOfDeath` | `int` | global | Tracks cause of current death |
| `deathmatch`, `timelimit`, `fraglimit`, `capturelimit`, `instantweap`, etc. | `cvar_t *` | global | CVar handles registered at init |

## Key Functions

### GetGameAPI
- **Signature:** `game_export_t *GetGameAPI(game_import_t *import)`
- **Purpose:** Called once by the engine to exchange function tables. Populates `globals` with all game callbacks and returns it.
- **Inputs:** `import` — engine-provided function table
- **Outputs/Return:** Pointer to `globals` (game export table)
- **Side effects:** Writes `gi` global; sets all `globals` function pointers and `edict_size`
- **Calls:** None directly; assigns externally declared functions
- **Notes:** This is the sole DLL export entry point. `GAME_API_VERSION` must match engine expectation.

### ShutdownGame
- **Signature:** `void ShutdownGame(void)`
- **Purpose:** Frees all level and game memory tags on DLL unload.
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** Calls `gi.FreeTags(TAG_LEVEL)` and `gi.FreeTags(TAG_GAME)`
- **Calls:** `gi.dprintf`, `gi.FreeTags`

### G_RunFrame
- **Signature:** `void G_RunFrame(void)`
- **Purpose:** Main per-frame tick: increments time, runs all entities, checks DM end conditions, finalizes player frames.
- **Inputs:** None (uses globals)
- **Outputs/Return:** void
- **Side effects:** Mutates `level.framenum`, `level.time`, `level.current_entity`; calls think/physics on all active edicts
- **Calls:** `AI_SetSightClient`, `ExitLevel`, `ClientBeginServerFrame`, `G_RunEntity`, `M_CheckGround`, `CheckDMRules`, `ClientEndServerFrames`
- **Notes:** Clients (indices 1–maxclients) take the `ClientBeginServerFrame` path; all others go through `G_RunEntity`.

### CheckDMRules
- **Signature:** `void CheckDMRules(void)`
- **Purpose:** Tests timelimit, fraglimit, and CTF-specific win conditions each frame; triggers `EndDMLevel` on expiry.
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** May call `EndDMLevel`; prints to all clients via `gi.bprintf`
- **Calls:** `CTFCheckRules`, `CTFInMatch`, `EndDMLevel`, `gi.bprintf`

### EndDMLevel
- **Signature:** `void EndDMLevel(void)`
- **Purpose:** Selects the next map (respecting `DF_SAME_LEVEL`, `forcemap`, `sv_maplist`, `nextmap`, or existing changelevel entity) and begins intermission.
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** Calls `BeginIntermission`; allocates/frees string via `strdup`/`free`
- **Calls:** `BeginIntermission`, `CreateTargetChangeLevel`, `G_Find`, `Q_stricmp`, `strdup`, `strtok`, `free`

### ExitLevel
- **Signature:** `void ExitLevel(void)`
- **Purpose:** After intermission timer expires, issues `gamemap` command to engine and resets level state.
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** Calls `gi.AddCommandString`; resets `level.exitintermission`, `level.intermissiontime`, `level.changemap`; clamps player health
- **Calls:** `CTFNextMap`, `gi.AddCommandString`, `ClientEndServerFrames`

### ClientEndServerFrames
- **Signature:** `void ClientEndServerFrames(void)`
- **Purpose:** Iterates all client slots and calls `ClientEndServerFrame` to finalize player view state after all physics.
- **Calls:** `ClientEndServerFrame`

**Notes:**
- `Sys_Error` and `Com_Printf` are stub wrappers (conditionally compiled under `#ifndef GAME_HARD_LINKED`) that forward to `gi.error` and `gi.dprintf` for shared-code linkage.
- `CreateTargetChangeLevel` is a trivial helper that spawns a transient `target_changelevel` entity.

## Control Flow Notes
`GetGameAPI` → engine stores callbacks → per frame: engine calls `G_RunFrame` → entity loop → `CheckDMRules` → `ClientEndServerFrames`. On limit hit: `EndDMLevel` → `BeginIntermission` → eventually `ExitLevel` → `gi.AddCommandString("gamemap ...")`.

## External Dependencies
- **Includes:** `g_local.h` (pulls in all CTF game types, `qcommon.h`, etc.)
- **Defined elsewhere:** `SpawnEntities`, `ClientThink`, `ClientConnect`, `ClientUserinfoChanged`, `ClientDisconnect`, `ClientBegin`, `ClientCommand`, `G_RunEntity`, `WriteGame`, `ReadGame`, `WriteLevel`, `ReadLevel`, `InitGame`, `ClientBeginServerFrame`, `ClientEndServerFrame`, `BeginIntermission`, `AI_SetSightClient`, `M_CheckGround`, `G_Find`, `G_Spawn`, `CTFCheckRules`, `CTFInMatch`, `CTFNextMap`, `ServerCommand`
