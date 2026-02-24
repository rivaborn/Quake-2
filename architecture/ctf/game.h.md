# ctf/game.h

## File Purpose
Defines the ABI contract between the Quake 2 server engine and the CTF game DLL. It declares the `game_import_t` (engine callbacks into the DLL) and `game_export_t` (DLL entry points called by the engine) structs, along with the minimal shared entity/client types needed to communicate across the boundary.

## Core Responsibilities
- Define `GAME_API_VERSION` (3) to version-check the DLL interface
- Declare `SVF_*` server-visible entity flags (including CTF-extended `SVF_PROJECTILE`)
- Define `solid_t` enum for collision modes
- Provide stub `edict_s` / `gclient_s` definitions when `GAME_INCLUDE` is not defined
- Declare `game_import_t`: all engine services the game DLL may call
- Declare `game_export_t`: all game DLL entry points the engine calls
- Declare `GetGameApi`, the single DLL export symbol that bootstraps the interface

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `solid_t` | enum | Collision mode for an entity (none, trigger, bbox, BSP) |
| `link_t` | struct | Doubly-linked list node for spatial area linkage |
| `edict_s` | struct | Minimal server-visible entity (stub when `GAME_INCLUDE` not defined) |
| `gclient_s` | struct | Minimal server-visible client (player state + ping; stub) |
| `game_import_t` | struct (function-pointer table) | Engine services provided to the game DLL |
| `game_export_t` | struct (function-pointer table) | Game DLL entry points consumed by the engine |

## Global / File-Static State
None.

## Key Functions

### GetGameApi
- **Signature:** `game_export_t *GetGameApi(game_import_t *import);`
- **Purpose:** Single exported DLL symbol; called by the engine at load time to exchange interface tables.
- **Inputs:** `import` — pointer to the engine's populated `game_import_t` table.
- **Outputs/Return:** Pointer to the game DLL's `game_export_t` table.
- **Side effects:** Initializes DLL-side global `gi` (game import) pointer; defined in `ctf/g_main.c`.
- **Calls:** Not inferable from this file (declaration only).
- **Notes:** Must be the only symbol exported from the game DLL; versioned by `apiversion` field.

## Control Flow Notes
- **Init/Shutdown:** Engine calls `ge->Init()` once at game start, `ge->Shutdown()` on exit.
- **Per-level:** `ge->SpawnEntities()` on map load; `ge->WriteLevel()` / `ge->ReadLevel()` for save/load.
- **Per-frame:** Engine calls `ge->RunFrame()` each server tick; `ge->ClientThink()` per connected client per tick.
- **Client lifecycle:** `ClientConnect` → `ClientBegin` → `ClientUserinfoChanged` / `ClientCommand` (event-driven) → `ClientDisconnect`.
- The edict array (`ge->edicts`, `ge->edict_size`, `ge->num_edicts`, `ge->max_edicts`) is owned by the game DLL but read by the engine for network serialization.

## External Dependencies
- **Notable includes:** None explicit in this file; depends on consumer including `q_shared.h` first for `vec3_t`, `trace_t`, `entity_state_t`, `player_state_t`, `usercmd_t`, `pmove_t`, `multicast_t`, `cvar_t`, `qboolean`.
- **Defined elsewhere:** `entity_state_t`, `player_state_t`, `usercmd_t`, `pmove_t`, `multicast_t`, `cvar_t` — all from `q_shared.h` / `qcommon.h`; `GetGameApi` body in `ctf/g_main.c`.
- **CTF addition vs. base game:** `SVF_PROJECTILE` flag and its comment block are CTF-specific extensions not present in `game/game.h`.
