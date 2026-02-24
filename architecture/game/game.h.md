# game/game.h

## File Purpose
Defines the ABI contract between the Quake 2 server engine and the game DLL. It establishes the two-way function pointer tables (`game_import_t` / `game_export_t`) and the minimal shared entity types the server must see without knowing game-internal details.

## Core Responsibilities
- Declare `GAME_API_VERSION` to enforce ABI compatibility checks at load time
- Define `solid_t` enum and `SVF_*` flags used by both server and game for collision/visibility
- Provide stub `edict_s` / `gclient_s` structs for server-side use when `GAME_INCLUDE` is not defined
- Expose `game_import_t`: all engine services callable by the game DLL
- Expose `game_export_t`: all entry points and shared data the server calls into the game DLL
- Declare `GetGameApi`, the single DLL entry point used to bootstrap the interface

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `solid_t` | enum | Entity solidity mode: none, trigger, bbox, or BSP brush |
| `link_t` | struct | Doubly-linked list node for spatial area partitioning |
| `edict_s` (stub) | struct | Minimal server-visible entity: state, client ptr, link, clusters, solid info |
| `gclient_s` (stub) | struct | Minimal server-visible client: `player_state_t` and ping |
| `game_import_t` | struct (function table) | Engine services provided to the game DLL |
| `game_export_t` | struct (function table + data) | Game DLL entry points and shared edict array exposed to server |

## Global / File-Static State

None.

## Key Functions

### GetGameApi
- **Signature:** `game_export_t *GetGameApi(game_import_t *import)`
- **Purpose:** Single exported DLL symbol; bootstraps the interface by receiving engine callbacks and returning game entry points.
- **Inputs:** `import` — pointer to engine-filled `game_import_t`
- **Outputs/Return:** Pointer to the game's `game_export_t`
- **Side effects:** Defined in `game/g_main.c`; stores import table globally and initializes game export table.
- **Calls:** Not inferable from this file (declaration only).
- **Notes:** Called once by the server at DLL load time before any other game function.

### Notes on `game_import_t` members (grouped)
- **Messaging:** `bprintf`, `dprintf`, `cprintf`, `centerprintf` — broadcast/directed console/center print at a given print level.
- **Audio:** `sound`, `positioned_sound` — emit sounds from entities or world positions.
- **Asset indexing:** `modelindex`, `soundindex`, `imageindex`, `setmodel` — register assets and assign config string slots.
- **Collision:** `trace`, `pointcontents`, `inPVS`, `inPHS`, `BoxEdicts`, `Pmove` — spatial queries and player movement shared with client prediction.
- **Area portals:** `SetAreaPortalState`, `AreasConnected` — open/close portals and test area connectivity.
- **Entity linking:** `linkentity`, `unlinkentity` — must be called whenever an entity's position or solid changes.
- **Network write:** `multicast`, `unicast` + `Write*` family — build and dispatch messages to clients.
- **Memory:** `TagMalloc`, `TagFree`, `FreeTags` — tagged heap; freed in bulk on level change.
- **CVars:** `cvar`, `cvar_set`, `cvar_forceset` — console variable access.
- **Command args:** `argc`, `argv`, `args` — read parameters from current client/server command.

### Notes on `game_export_t` members (grouped)
- **Lifecycle:** `Init` (once per game session), `Shutdown`, `SpawnEntities` (each level).
- **Persistence:** `WriteGame`/`ReadGame` (cross-level client/server data), `WriteLevel`/`ReadLevel` (per-level state for save games).
- **Client events:** `ClientConnect`, `ClientBegin`, `ClientUserinfoChanged`, `ClientDisconnect`, `ClientCommand`, `ClientThink` — full client lifecycle.
- **Frame pump:** `RunFrame` — called every server frame to advance game logic.
- **Shared edict array:** `edicts`, `edict_size`, `num_edicts`, `max_edicts` — game owns this allocation; server accesses it directly via pointer arithmetic using `edict_size` for stride.

## Control Flow Notes
This file is not executable — it is a pure interface header. At startup the server calls `GetGameApi` (via `dlopen`/`GetProcAddress`), passes a filled `game_import_t`, and stores the returned `game_export_t`. From then on: `SpawnEntities` is called per level load; `RunFrame` drives every tick; client callbacks fire on connection events; `WriteGame`/`WriteLevel` fire on exit or save.

## External Dependencies
- **Includes:** Implicitly depends on `q_shared.h` for `vec3_t`, `trace_t`, `entity_state_t`, `player_state_t`, `usercmd_t`, `pmove_t`, `multicast_t`, `cvar_t`, `qboolean`.
- **Defined elsewhere:** `entity_state_t`, `player_state_t`, `usercmd_t`, `pmove_t`, `multicast_t`, `cvar_t` — all in `qcommon/q_shared.h` / `qcommon/qcommon.h`. `GetGameApi` body lives in `game/g_main.c`.
