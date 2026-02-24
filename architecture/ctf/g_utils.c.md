# ctf/g_utils.c

## File Purpose
Miscellaneous utility functions for the CTF game module, providing entity search, spawning, freeing, targeting, spatial queries, and math/string helpers used throughout the game logic layer.

## Core Responsibilities
- Entity search by field string match (`G_Find`) and by spatial radius (`findradius`)
- Target chain firing and killtarget processing (`G_UseTargets`)
- Entity allocation (`G_Spawn`) and deallocation (`G_FreeEdict`)
- Trigger and solid touch dispatch (`G_TouchTriggers`, `G_TouchSolids`)
- Telefrag kill-box clearing (`KillBox`)
- Vector/angle math helpers and string utilities

## Key Types / Data Structures
None (uses types from `g_local.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|------|-------|-------|---------|
| `VEC_UP` | `vec3_t` | global | Sentinel angle value indicating "up" direction |
| `MOVEDIR_UP` | `vec3_t` | global | Canonical up movedir result |
| `VEC_DOWN` | `vec3_t` | global | Sentinel angle value indicating "down" direction |
| `MOVEDIR_DOWN` | `vec3_t` | global | Canonical down movedir result |

Static rotation buffers inside `tv()` and `vtos()` (8-slot ring buffers) are file-local.

## Key Functions

### G_Find
- **Signature:** `edict_t *G_Find(edict_t *from, int fieldofs, char *match)`
- **Purpose:** Iterates active edicts starting after `from`, returning the next whose string field at `fieldofs` matches `match` case-insensitively.
- **Inputs:** Starting edict (NULL = beginning), byte offset into `edict_t`, target string.
- **Outputs/Return:** Matching `edict_t*` or NULL.
- **Side effects:** None.
- **Calls:** `Q_stricmp`
- **Notes:** Used as an iterator; caller loops until NULL. Foundation for targeting and `G_PickTarget`.

### findradius
- **Signature:** `edict_t *findradius(edict_t *from, vec3_t org, float rad)`
- **Purpose:** Iterates active, non-`SOLID_NOT` edicts returning the next whose center is within `rad` of `org`.
- **Inputs:** Starting edict, origin, radius.
- **Outputs/Return:** Next edict within radius or NULL.
- **Side effects:** None.
- **Calls:** `VectorLength`
- **Notes:** Uses entity center `(mins+maxs)*0.5`; also used as an iterator.

### G_PickTarget
- **Signature:** `edict_t *G_PickTarget(char *targetname)`
- **Purpose:** Collects up to `MAXCHOICES` (8) entities matching `targetname`, returns one at random.
- **Inputs:** Target name string.
- **Outputs/Return:** Random matching `edict_t*` or NULL.
- **Side effects:** Prints debug via `gi.dprintf` on failure.
- **Calls:** `G_Find`, `rand`, `gi.dprintf`

### G_UseTargets
- **Signature:** `void G_UseTargets(edict_t *ent, edict_t *activator)`
- **Purpose:** Fires the target chain for `ent`: optionally defers via a `DelayedUse` entity, prints message, kills `killtarget` entities, then calls `.use` on all `target` entities.
- **Inputs:** Triggering entity, activating entity.
- **Outputs/Return:** void
- **Side effects:** May spawn a `DelayedUse` edict, free killtarget edicts, call arbitrary `.use` callbacks, emit sound/centerprint to activator.
- **Calls:** `G_Spawn`, `G_Find`, `G_FreeEdict`, `gi.centerprintf`, `gi.sound`, `gi.soundindex`, `gi.dprintf`, `Q_stricmp`
- **Notes:** Guards `ent->inuse` after each freeation/use call to detect self-removal mid-chain.

### G_Spawn
- **Signature:** `edict_t *G_Spawn(void)`
- **Purpose:** Finds a free edict slot (skipping client/body-queue slots), preferring slots not freed within the last 0.5 s; expands `num_edicts` if needed.
- **Inputs:** None.
- **Outputs/Return:** Initialized `edict_t*`.
- **Side effects:** Modifies `globals.num_edicts`; calls `gi.error` on exhaustion.
- **Calls:** `G_InitEdict`, `gi.error`

### G_FreeEdict
- **Signature:** `void G_FreeEdict(edict_t *ed)`
- **Purpose:** Unlinks entity from the world, zeroes its memory, and marks it freed with a timestamp.
- **Inputs:** Entity to free.
- **Side effects:** Calls `gi.unlinkentity`; silently ignores attempts to free client/body-queue slots.
- **Calls:** `gi.unlinkentity`, `memset`

### G_TouchTriggers
- **Signature:** `void G_TouchTriggers(edict_t *ent)`
- **Purpose:** Finds all trigger-area edicts overlapping `ent`'s bbox and fires their `.touch` callbacks.
- **Side effects:** Calls arbitrary `.touch` handlers; skips dead clients/monsters.
- **Calls:** `gi.BoxEdicts`

### KillBox
- **Signature:** `qboolean KillBox(edict_t *ent)`
- **Purpose:** Repeatedly traces at `ent->s.origin` and telefrag-damages any blocking entity until the space is clear.
- **Outputs/Return:** `true` if clear, `false` if an unkillable solid remains.
- **Calls:** `gi.trace`, `T_Damage`
- **Notes:** Caller must unlink `ent` before calling.

## Control Flow Notes
- Called throughout the game frame: entity targeting chains fire during `G_UseTargets` callbacks; `G_TouchTriggers` is called after entity movement; `KillBox` is invoked during teleportation. `G_Spawn`/`G_FreeEdict` are called on entity creation/destruction at any point.

## External Dependencies
- **Includes:** `g_local.h` (all game types, `gi` interface, macros)
- **Defined elsewhere:** `g_edicts`, `globals`, `game`, `level`, `maxclients` (game globals); `T_Damage` (g_combat.c); `Q_stricmp`, `Com_sprintf`, `AngleVectors`, `VectorLength`, `VectorCompare`, `VectorCopy`, `VectorClear` (shared/math); `gi.*` (engine server interface)
