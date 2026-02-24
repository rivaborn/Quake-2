# game/p_trail.c

## File Purpose
Implements a circular buffer of recent player positions used by AI monsters to track and pursue the player. Each trail node stores a world-space origin, a timestamp, and a yaw angle pointing toward the next node.

## Core Responsibilities
- Allocate and initialize trail node entities at map load
- Append new player positions to the circular buffer each frame/event
- Provide monster AI queries to find the oldest unseen or most recent visible trail node
- Support pursuit logic by exposing the last recorded player spot

## Key Types / Data Structures
None (uses existing `edict_t` fields repurposed as trail nodes).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `trail[TRAIL_LENGTH]` | `edict_t *[8]` | global | Circular array of trail node entities |
| `trail_head` | `int` | global | Index of the next write slot in the circular buffer |
| `trail_active` | `qboolean` | global | Guards all trail operations; false in deathmatch |

## Key Functions

### PlayerTrail_Init
- **Signature:** `void PlayerTrail_Init(void)`
- **Purpose:** Allocates 8 trail entities via `G_Spawn()`, resets `trail_head` to 0, sets `trail_active = true`. Skips entirely in deathmatch.
- **Inputs:** None (reads `deathmatch->cvar`)
- **Outputs/Return:** void
- **Side effects:** Spawns 8 persistent entities into the game world; sets globals `trail_head` and `trail_active`
- **Calls:** `G_Spawn`
- **Notes:** FIXME comment indicates coop mode was intended to also disable the trail but was never wired up.

### PlayerTrail_Add
- **Signature:** `void PlayerTrail_Add(vec3_t spot)`
- **Purpose:** Writes a new player position into the current `trail_head` slot: copies origin, records `level.time` as timestamp, computes yaw from previous node, then advances `trail_head`.
- **Inputs:** `spot` — world-space player position
- **Outputs/Return:** void
- **Side effects:** Mutates `trail[trail_head]->s.origin`, `.timestamp`, `.s.angles[1]`; advances `trail_head`
- **Calls:** `VectorCopy`, `VectorSubtract`, `vectoyaw`, `NEXT` macro
- **Notes:** Overwrites the oldest entry when the buffer wraps (circular overwrite, no guard).

### PlayerTrail_New
- **Signature:** `void PlayerTrail_New(vec3_t spot)`
- **Purpose:** Re-initializes the trail (re-spawning all nodes) then immediately adds the given spot. Used when a fresh trail is needed (e.g., player respawn or new level segment).
- **Inputs:** `spot` — starting player position
- **Outputs/Return:** void
- **Side effects:** All side effects of `PlayerTrail_Init` + `PlayerTrail_Add`; leaks previously spawned trail entities if called repeatedly.
- **Calls:** `PlayerTrail_Init`, `PlayerTrail_Add`
- **Notes:** Calling this repeatedly without cleanup will leak the previously allocated trail entities.

### PlayerTrail_PickFirst
- **Signature:** `edict_t *PlayerTrail_PickFirst(edict_t *self)`
- **Purpose:** Finds the oldest trail node whose timestamp is newer than `self->monsterinfo.trail_time`, preferring a visible node. Used by monsters to pick a pursuit waypoint when they first acquire the trail.
- **Inputs:** `self` — the querying monster entity
- **Outputs/Return:** A trail `edict_t *` node, or `NULL` if trail inactive
- **Side effects:** None
- **Calls:** `visible`, `NEXT`, `PREV` macros
- **Notes:** Checks `trail[marker]` then `trail[PREV(marker)]` for visibility; falls back to `trail[marker]` if neither is visible.

### PlayerTrail_PickNext
- **Signature:** `edict_t *PlayerTrail_PickNext(edict_t *self)`
- **Purpose:** Same traversal logic as `PickFirst` but returns the raw `trail[marker]` without visibility checks. Used by monsters already on the trail to advance to the next waypoint.
- **Inputs:** `self` — the querying monster entity
- **Outputs/Return:** A trail `edict_t *` node, or `NULL` if trail inactive
- **Side effects:** None
- **Calls:** `NEXT` macro
- **Notes:** No visibility fallback; simpler than `PickFirst`.

### PlayerTrail_LastSpot
- **Signature:** `edict_t *PlayerTrail_LastSpot(void)`
- **Purpose:** Returns the most recently written trail node (`trail_head - 1`), representing the last known player position.
- **Inputs:** None
- **Outputs/Return:** `edict_t *` — most recent trail node
- **Side effects:** None
- **Calls:** `PREV` macro

## Control Flow Notes
- `PlayerTrail_Init` is called during map/game initialization (single-player only).
- `PlayerTrail_Add` is called from player movement/think code each time the player moves significantly.
- `PlayerTrail_PickFirst` / `PickNext` / `LastSpot` are called from monster AI (`g_ai.c`) during pursuit states each frame.

## External Dependencies
- `g_local.h` — pulls in all game types, `edict_t`, `level`, `deathmatch` cvar, `G_Spawn`, `vectoyaw`, `VectorCopy`, `VectorSubtract`, `visible`
- `G_Spawn` — defined in `g_utils.c`
- `visible` — defined in `g_ai.c`
- `vectoyaw` — defined in `g_utils.c` or `q_shared.c`
- `level.time`, `deathmatch` — engine/game globals defined elsewhere
