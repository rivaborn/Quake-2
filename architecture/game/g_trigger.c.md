# game/g_trigger.c

## File Purpose
Implements all trigger entity types for the Quake 2 game module. Triggers are invisible volume-based or event-driven entities that fire targets, apply forces, deal damage, or alter physics when activated by players, monsters, or other entities.

## Core Responsibilities
- Initialize trigger volumes (solid, movetype, model linkage)
- Handle multi-fire and single-fire trigger logic with configurable wait/delay
- Implement key-gated relay triggers with coop inventory management
- Provide push/hurt/gravity/monsterjump environmental trigger volumes
- Support counter-based sequencing before target firing
- Manage TRIGGERED spawnflag (dormant until enabled by another event)

## Key Types / Data Structures
None (uses engine types from `g_local.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `windsound` | `int` | static (file) | Cached sound index for wind/push sound (`misc/windfly.wav`) |

## Key Functions

### InitTrigger
- **Signature:** `void InitTrigger(edict_t *self)`
- **Purpose:** Common setup for volume-based triggers.
- **Inputs:** `self` — the trigger entity
- **Outputs/Return:** void
- **Side effects:** Sets `solid`, `movetype`, `svflags`; calls `gi.setmodel`
- **Calls:** `G_SetMovedir`, `gi.setmodel`
- **Notes:** Does not call `gi.linkentity`; callers are responsible for linking.

### multi_trigger
- **Signature:** `void multi_trigger(edict_t *ent)`
- **Purpose:** Core firing logic for repeatable triggers; guards against double-activation via `nextthink`.
- **Inputs:** `ent` — the trigger entity; `ent->activator` must be pre-set
- **Outputs/Return:** void
- **Side effects:** Fires targets via `G_UseTargets`; schedules `multi_wait` or `G_FreeEdict` via `nextthink`
- **Calls:** `G_UseTargets`, `G_FreeEdict`
- **Notes:** `wait == -1` means fire once then free. Removal is deferred to avoid corrupting touch iteration.

### Touch_Multi
- **Signature:** `void Touch_Multi(edict_t *self, edict_t *other, cplane_t *plane, csurface_t *surf)`
- **Purpose:** Touch callback filtering by entity type (client/monster) and directional angle.
- **Inputs:** Toucher `other`, spawnflags control monster/player exclusion
- **Side effects:** Sets `self->activator`, calls `multi_trigger`
- **Calls:** `AngleVectors`, `_DotProduct`, `multi_trigger`
- **Notes:** Directional triggers reject approach from wrong angles using dot product against `movedir`.

### trigger_key_use
- **Signature:** `void trigger_key_use(edict_t *self, edict_t *other, edict_t *activator)`
- **Purpose:** Key-gated relay; consumes inventory item then fires targets.
- **Inputs:** `self->item` specifies required key; checks `activator->client->pers.inventory`
- **Side effects:** Decrements/zeroes inventory across all coop players for `key_power_cube` (bit-tracked) or standard keys; plays sounds; calls `G_UseTargets`; nulls `self->use` (one-shot)
- **Calls:** `ITEM_INDEX`, `gi.centerprintf`, `gi.sound`, `gi.soundindex`, `G_UseTargets`
- **Notes:** Coop power cube removal uses bitmask tracking across all players; debounce prevents repeated "need key" messages within 5 seconds.

### trigger_counter_use
- **Signature:** `void trigger_counter_use(edict_t *self, edict_t *other, edict_t *activator)`
- **Purpose:** Counts down from `self->count`; fires targets only when count reaches zero.
- **Side effects:** Decrements count; prints progress messages unless `nomessage` flag set; calls `multi_trigger` at zero
- **Calls:** `gi.centerprintf`, `gi.sound`, `gi.soundindex`, `multi_trigger`

### trigger_push_touch
- **Signature:** `void trigger_push_touch(edict_t *self, edict_t *other, cplane_t *plane, csurface_t *surf)`
- **Purpose:** Applies velocity impulse along `movedir` to grenades and living entities.
- **Side effects:** Overwrites `other->velocity`; copies to `other->client->oldvelocity` to suppress fall damage; plays wind sound with debounce; frees self if `PUSH_ONCE`
- **Calls:** `VectorScale`, `VectorCopy`, `gi.sound`, `G_FreeEdict`

### hurt_touch
- **Signature:** `void hurt_touch(edict_t *self, edict_t *other, cplane_t *plane, csurface_t *surf)`
- **Purpose:** Deals damage each frame or once per second (`SLOW` flag) to any entity with `takedamage`.
- **Side effects:** Calls `T_Damage`; plays damage sound every 10 frames unless `SILENT`
- **Calls:** `T_Damage`, `gi.sound`
- **Notes:** `NO_PROTECTION` flag passes `DAMAGE_NO_PROTECTION` to bypass armor/powerups.

### trigger_monsterjump_touch
- **Signature:** `void trigger_monsterjump_touch(edict_t *self, edict_t *other, cplane_t *plane, csurface_t *surf)`
- **Purpose:** Launches grounded non-flying, non-dead monsters in the trigger's angled direction.
- **Side effects:** Sets `other->velocity` XY immediately; sets Z and clears `groundentity` only if grounded
- **Notes:** XY applied even airborne to clear lips/edges; Z applied only when grounded to ensure proper jump.

## Control Flow Notes
All `SP_*` functions are called at map load (spawn phase) by the entity spawning system. Touch callbacks fire during the server's per-frame physics/area collision step. `Use` callbacks are invoked by `G_UseTargets` chains from other entities. `trigger_always` fires immediately at spawn after a mandatory 0.2s minimum delay to ensure target entities exist.

## External Dependencies
- **Includes:** `g_local.h` (pulls in all game types, `edict_t`, `gi`, level state)
- **Defined elsewhere:** `G_UseTargets`, `G_SetMovedir`, `G_FreeEdict`, `T_Damage`, `FindItemByClassname`, `ITEM_INDEX`, `AngleVectors`, `VectorCompare`, `VectorScale`, `VectorCopy`, `VectorMA`, `vtos`, `g_edicts`, `game`, `level`, `st`, `coop`, `FRAMETIME`
