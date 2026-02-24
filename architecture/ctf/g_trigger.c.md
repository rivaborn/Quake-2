# ctf/g_trigger.c

## File Purpose
Implements all trigger entity types for the Quake 2 CTF game module. Triggers are invisible volume-based or event-driven entities that activate game logic when touched or used by players, monsters, or other entities.

## Core Responsibilities
- Initialize trigger volumes with shared geometry/solid setup (`InitTrigger`)
- Handle multi-fire and single-fire trigger activation and cooldown
- Implement key-gated relay triggers with coop inventory synchronization
- Implement push, hurt, gravity, and monster-jump trigger volumes
- Implement counter triggers requiring N activations before firing
- Manage deferred entity removal via `G_FreeEdict` scheduled through `nextthink`

## Key Types / Data Structures
None (uses engine types from `g_local.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `windsound` | `int` | static (file-level) | Cached sound index for the wind/push sound, set at `trigger_push` spawn time |

## Key Functions

### InitTrigger
- **Signature:** `void InitTrigger(edict_t *self)`
- **Purpose:** Shared setup for touchable trigger volumes.
- **Inputs:** `self` — the trigger entity
- **Outputs/Return:** void
- **Side effects:** Sets `solid`, `movetype`, `svflags`; calls `gi.setmodel`
- **Calls:** `G_SetMovedir`, `VectorCompare`, `gi.setmodel`
- **Notes:** Does not call `gi.linkentity`; callers must link after.

### multi_trigger
- **Signature:** `void multi_trigger(edict_t *ent)`
- **Purpose:** Core activation logic for repeatable/once triggers; fires targets and schedules re-arm or self-removal.
- **Inputs:** `ent` — the trigger entity (must have `ent->activator` set)
- **Outputs/Return:** void
- **Side effects:** Calls `G_UseTargets`; sets `nextthink`/`think`; nulls `touch` and schedules `G_FreeEdict` for `wait == -1` triggers
- **Calls:** `G_UseTargets`, `G_FreeEdict`, `multi_wait`
- **Notes:** Guard on `ent->nextthink` prevents double-triggering within same frame.

### Touch_Multi
- **Signature:** `void Touch_Multi(edict_t *self, edict_t *other, cplane_t *plane, csurface_t *surf)`
- **Purpose:** Touch callback filtering by spawnflags (monsters/players) and directional facing before delegating to `multi_trigger`.
- **Inputs:** `self` — trigger; `other` — touching entity
- **Calls:** `AngleVectors`, `_DotProduct`, `multi_trigger`
- **Notes:** Spawnflag 1 = MONSTER, spawnflag 2 = NOT_PLAYER; directional check ignores activation if facing wrong way.

### trigger_key_use
- **Signature:** `void trigger_key_use(edict_t *self, edict_t *other, edict_t *activator)`
- **Purpose:** Fires targets only if activator holds the required key item; handles coop-wide key consumption including power cube bit tracking.
- **Side effects:** Modifies `activator->client->pers.inventory`; plays sounds via `gi.sound`/`gi.centerprintf`; sets `self->use = NULL` after firing (one-shot)
- **Calls:** `ITEM_INDEX`, `gi.centerprintf`, `gi.sound`, `gi.soundindex`, `G_UseTargets`
- **Notes:** `touch_debounce_time` rate-limits the "you need the key" message to once per 5 seconds.

### trigger_counter_use
- **Signature:** `void trigger_counter_use(edict_t *self, edict_t *other, edict_t *activator)`
- **Purpose:** Decrements internal counter each use; fires via `multi_trigger` only when count reaches zero.
- **Side effects:** Prints countdown messages unless `nomessage` spawnflag set; plays sound
- **Calls:** `gi.centerprintf`, `gi.sound`, `gi.soundindex`, `multi_trigger`

### trigger_push_touch
- **Signature:** `void trigger_push_touch(edict_t *self, edict_t *other, cplane_t *plane, csurface_t *surf)`
- **Purpose:** Applies velocity impulse to touching entities; suppresses fall damage for players via `oldvelocity`.
- **Side effects:** Modifies `other->velocity`, `other->client->oldvelocity`; plays wind sound with debounce; may free self if `PUSH_ONCE`
- **Calls:** `VectorScale`, `gi.sound`, `G_FreeEdict`

### hurt_touch
- **Signature:** `void hurt_touch(edict_t *self, edict_t *other, cplane_t *plane, csurface_t *surf)`
- **Purpose:** Applies damage each frame (or once per second with SLOW flag) to any damageable entity in volume.
- **Side effects:** Calls `T_Damage`; plays sound every 10 frames unless SILENT
- **Calls:** `T_Damage`, `gi.sound`
- **Notes:** `DAMAGE_NO_PROTECTION` flag bypasses all resistances when spawnflag 8 is set.

### trigger_gravity_touch / trigger_monsterjump_touch
- **Notes:** Trivial touch callbacks — former sets `other->gravity` from `self->gravity`; latter applies directional velocity to grounded non-flying monsters only.

## Control Flow Notes
All `SP_trigger_*` functions are spawn-time entry points called during map load by the entity spawner. Touch callbacks fire per-frame during physics collision detection. `Use` callbacks fire when targeted by other entities at runtime. `multi_trigger` bridges both into the unified target-firing pipeline.

## External Dependencies
- `g_local.h` — all game types, constants, and inline macros
- `G_UseTargets`, `G_SetMovedir`, `G_FreeEdict`, `T_Damage` — defined in other game files
- `gi.*` — engine import struct (sound, model, linking, printf)
- `level`, `game`, `g_edicts`, `st` — global game state defined elsewhere
- `ITEM_INDEX`, `FindItemByClassname` — item system defined elsewhere
