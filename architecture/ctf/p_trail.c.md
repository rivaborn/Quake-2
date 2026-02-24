# ctf/p_trail.c

## File Purpose
Implements a circular buffer of recent player position markers used by AI monsters for pursuit logic. Each trail node is a lightweight `edict_t` storing a world position, timestamp, and facing angle.

## Core Responsibilities
- Allocate and initialize the fixed-size circular trail buffer at game start
- Record new player positions into the trail ring as the player moves
- Provide monster AI with trail node lookups: first visible/reachable node, next node ahead, and the most recent spot

## Key Types / Data Structures
None (uses existing `edict_t` and engine primitives).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `trail[TRAIL_LENGTH]` | `edict_t *[8]` | global | Circular buffer of trail marker entities |
| `trail_head` | `int` | global | Index of the next write slot in the ring |
| `trail_active` | `qboolean` | global | Guards all trail operations; false in deathmatch |

## Key Functions

### PlayerTrail_Init
- **Signature:** `void PlayerTrail_Init(void)`
- **Purpose:** Spawns 8 trail marker entities and resets the ring head; skips initialization in deathmatch mode.
- **Inputs:** None (reads `deathmatch->value`)
- **Outputs/Return:** None
- **Side effects:** Calls `G_Spawn()` 8 times; sets `trail_active = true`; writes `trail[]` and `trail_head`
- **Calls:** `G_Spawn`
- **Notes:** FIXME comment suggests coop mode was intended to also disable the trail but was never wired in.

### PlayerTrail_Add
- **Signature:** `void PlayerTrail_Add(vec3_t spot)`
- **Purpose:** Writes a new position into the current `trail_head` slot, records `level.time`, computes a yaw angle from the previous slot, then advances the head.
- **Inputs:** `spot` — world-space position to record
- **Outputs/Return:** None
- **Side effects:** Mutates `trail[trail_head]->s.origin`, `->timestamp`, `->s.angles[1]`; increments `trail_head` (wraps via `NEXT`)
- **Calls:** `VectorCopy`, `VectorSubtract`, `vectoyaw`
- **Notes:** Angle is relative to the previous entry; meaningless on the very first add before two points exist.

### PlayerTrail_New
- **Signature:** `void PlayerTrail_New(vec3_t spot)`
- **Purpose:** Reinitializes the entire trail then immediately adds the given spot — used when a fresh trail sequence should begin (e.g., player respawn).
- **Inputs:** `spot` — seed position
- **Outputs/Return:** None
- **Side effects:** Re-spawns all 8 trail entities via `PlayerTrail_Init`, then calls `PlayerTrail_Add`
- **Calls:** `PlayerTrail_Init`, `PlayerTrail_Add`

### PlayerTrail_PickFirst
- **Signature:** `edict_t *PlayerTrail_PickFirst(edict_t *self)`
- **Purpose:** Finds the oldest trail entry that is newer than the monster's `trail_time`, preferring one that is visible to the monster.
- **Inputs:** `self` — pursuing monster entity (reads `monsterinfo.trail_time`)
- **Outputs/Return:** Pointer to the chosen `trail[]` entry, or `NULL` if inactive
- **Side effects:** None
- **Calls:** `visible`
- **Notes:** Falls back to `PREV(marker)` if `marker` itself is not visible, then returns `marker` unconditionally as a last resort.

### PlayerTrail_PickNext
- **Signature:** `edict_t *PlayerTrail_PickNext(edict_t *self)`
- **Purpose:** Returns the next trail entry ahead of the monster's current `trail_time` without a visibility check.
- **Inputs:** `self` — pursuing monster entity
- **Outputs/Return:** Pointer to the chosen `trail[]` entry, or `NULL` if inactive
- **Side effects:** None
- **Calls:** None beyond index arithmetic

### PlayerTrail_LastSpot
- **Signature:** `edict_t *PlayerTrail_LastSpot(void)`
- **Purpose:** Returns the most recently written trail entry (`trail_head - 1`).
- **Inputs:** None
- **Outputs/Return:** `edict_t *` — last recorded position node
- **Side effects:** None
- **Calls:** None

## Control Flow Notes
- `PlayerTrail_Init` is called at level/game init (single-player only).
- `PlayerTrail_Add` is called each frame (or on significant movement) from player update code.
- Monster AI (`g_ai.c`) calls `PlayerTrail_PickFirst` / `PlayerTrail_PickNext` during pursuit state to select a navigation waypoint, and reads `trail_time` from `monsterinfo` to track progress along the trail.

## External Dependencies
- `g_local.h` — brings in `edict_t`, `level`, `monsterinfo`, `G_Spawn`, `visible`, `vectoyaw`, `VectorCopy`, `VectorSubtract`, `deathmatch`
- `G_Spawn` — defined in `g_utils.c`
- `visible` — defined in `g_ai.c`
- `vectoyaw` — defined in `g_utils.c` / `q_shared.c`
- `deathmatch` — cvar defined in `g_main.c`
