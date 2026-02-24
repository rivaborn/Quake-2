# game/g_utils.c

## File Purpose
Miscellaneous utility functions for the Quake 2 game module. Provides entity search, spawning/freeing, target firing, vector math helpers, and trigger/solid overlap detection used throughout the game logic.

## Core Responsibilities
- Entity search by field string match and by spatial radius
- Entity spawning (slot allocation) and freeing (slot recycling)
- Target chain firing with optional delay, kill-targets, and centerprint messaging
- Vector/angle conversion utilities (temp vectors, yaw extraction, full angle decomposition)
- Movement direction resolution from special angle sentinels
- Trigger and solid overlap testing after entity movement
- Kill-box telefrag logic for teleportation

## Key Types / Data Structures
None (all types imported from `g_local.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `VEC_UP` | `vec3_t` | global | Sentinel angle value meaning "straight up" |
| `MOVEDIR_UP` | `vec3_t` | global | Resolved movement direction for VEC_UP |
| `VEC_DOWN` | `vec3_t` | global | Sentinel angle value meaning "straight down" |
| `MOVEDIR_DOWN` | `vec3_t` | global | Resolved movement direction for VEC_DOWN |

## Key Functions

### G_Find
- Signature: `edict_t *G_Find(edict_t *from, int fieldofs, char *match)`
- Purpose: Linear scan of the active edict list for the next entity whose string field at byte offset `fieldofs` case-insensitively matches `match`.
- Inputs: Starting edict (NULL = beginning), field byte offset via `FOFS()`, target string.
- Outputs/Return: Pointer to matching edict, or NULL.
- Side effects: None.
- Calls: `Q_stricmp`
- Notes: Iterator pattern — pass the last result back as `from` to continue scanning.

### findradius
- Signature: `edict_t *findradius(edict_t *from, vec3_t org, float rad)`
- Purpose: Iterator returning the next solid entity whose bounding-box center is within `rad` of `org`.
- Inputs: Starting edict, origin, radius.
- Outputs/Return: Next in-range edict, or NULL.
- Side effects: None.
- Calls: `VectorLength`
- Notes: Skips `SOLID_NOT` entities. Uses center-of-bounds, not raw origin.

### G_PickTarget
- Signature: `edict_t *G_PickTarget(char *targetname)`
- Purpose: Collects up to `MAXCHOICES` (8) entities matching `targetname` and returns one at random.
- Inputs: Target name string.
- Outputs/Return: Random matching edict, or NULL.
- Side effects: Debug print via `gi.dprintf` on NULL input or no match.
- Calls: `G_Find`, `rand`, `gi.dprintf`

### G_UseTargets
- Signature: `void G_UseTargets(edict_t *ent, edict_t *activator)`
- Purpose: Fires the full target chain for `ent`: optional delay spawn, centerprint message, killtarget removal, then calling `.use` on all matching targets.
- Inputs: Firing entity, activating entity.
- Outputs/Return: void.
- Side effects: May spawn a `DelayedUse` edict; frees killtarget entities; calls target `.use` callbacks; emits sound/centerprint to activator.
- Calls: `G_Spawn`, `G_Find`, `G_FreeEdict`, `gi.centerprintf`, `gi.sound`, `gi.soundindex`, `gi.dprintf`, `Q_stricmp`
- Notes: Guards against self-activation and re-entrance (checks `ent->inuse` after each free/use).

### G_Spawn
- Signature: `edict_t *G_Spawn(void)`
- Purpose: Allocates a free edict slot, preferring slots not recently freed (> 0.5 s), to avoid client-side interpolation artifacts.
- Inputs: None.
- Outputs/Return: Initialized edict pointer.
- Side effects: Increments `globals.num_edicts` if no free slot found; calls `gi.error` if hard limit reached; calls `G_InitEdict`.
- Calls: `G_InitEdict`, `gi.error`
- Notes: Skips the first `maxclients+1` slots (reserved for player edicts).

### G_FreeEdict
- Signature: `void G_FreeEdict(edict_t *ed)`
- Purpose: Unlinks and zeroes an edict, marking it free with a timestamp for reuse throttling.
- Inputs: Edict to free.
- Outputs/Return: void.
- Side effects: Calls `gi.unlinkentity`; zeroes memory; sets `freetime` and `inuse=false`.
- Calls: `gi.unlinkentity`, `memset`
- Notes: Silently refuses to free player/body-queue edicts (indices ≤ `maxclients + BODY_QUEUE_SIZE`).

### G_TouchTriggers
- Signature: `void G_TouchTriggers(edict_t *ent)`
- Purpose: Finds all trigger-area entities overlapping `ent`'s bounds and calls their `.touch` callbacks.
- Inputs: Moving entity.
- Outputs/Return: void.
- Side effects: Invokes arbitrary `.touch` callbacks; entities may be freed mid-loop.
- Calls: `gi.BoxEdicts`
- Notes: Dead clients/monsters are skipped entirely.

### KillBox
- Signature: `qboolean KillBox(edict_t *ent)`
- Purpose: Telefrag loop — damages (100000 HP, `MOD_TELEFRAG`) any entity occupying `ent`'s proposed position until the space is clear or an unkillable blocker remains.
- Inputs: Entity about to teleport/spawn.
- Outputs/Return: `true` if clear, `false` if blocked by an indestructible entity.
- Side effects: Calls `T_Damage` repeatedly; may free entities.
- Calls: `gi.trace`, `T_Damage`

## Control Flow Notes
- **Utility layer** — no direct frame or init hooks. Functions here are called by entity think/use/touch callbacks throughout `g_func.c`, `g_trigger.c`, `g_combat.c`, `p_client.c`, and others.
- `G_UseTargets` is the central nervous system of Quake 2's trigger chain; nearly every activatable entity routes through it.
- `G_Spawn`/`G_FreeEdict` are the sole entity lifecycle managers for game-side entities.

## External Dependencies
- `g_local.h` — pulls in all game types, `gi` (game import), `g_edicts`, `globals`, `level`, `game`, `maxclients`
- `T_Damage` — defined in `g_combat.c`
- `G_UseTargets` — forward-referenced by `Think_Delay` within the same file
- `AngleVectors`, `VectorLength`, `VectorCompare`, `VectorCopy`, `VectorClear`, `Com_sprintf`, `Q_stricmp` — defined in shared/common code
