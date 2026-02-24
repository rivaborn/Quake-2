# game/g_turret.c

## File Purpose
Implements the multi-part controllable turret entity system, consisting of a rotating base, a pitching/yawing breach (gun head), and an AI-driven infantry driver entity that autonomously targets and fires the turret.

## Core Responsibilities
- Define spawn functions for `turret_breach`, `turret_base`, and `turret_driver` entities
- Manage per-frame angle interpolation of the breach toward a target orientation
- Clamp breach pitch/yaw to configured min/max limits
- Synchronize yaw angular velocity across all team members
- Position-correct the driver entity to ride the breach as it rotates
- Handle driver AI: enemy detection, line-of-sight tracking, and fire signaling
- Handle driver death: detach from team chain and level the gun

## Key Types / Data Structures
None (uses engine types exclusively).

## Global / File-Static State
None.

## Key Functions

### AnglesNormalize
- **Signature:** `void AnglesNormalize(vec3_t vec)`
- **Purpose:** Wraps pitch and yaw components into [0, 360).
- **Inputs:** Mutable angle vector.
- **Outputs/Return:** Modifies `vec` in place.
- **Side effects:** None.
- **Calls:** None.
- **Notes:** Only normalizes indices 0 and 1; roll (index 2) is untouched.

### SnapToEights
- **Signature:** `float SnapToEights(float x)`
- **Purpose:** Quantizes a float to the nearest 0.125 grid, matching Quake's fixed-point coordinate precision.
- **Inputs:** Float coordinate value.
- **Outputs/Return:** Quantized float.
- **Side effects:** None.
- **Notes:** Used when computing driver target positions to avoid floating-point drift.

### turret_blocked
- **Signature:** `void turret_blocked(edict_t *self, edict_t *other)`
- **Purpose:** Crush callback; damages any damageable entity blocking turret movement.
- **Inputs:** `self` — the blocked turret part; `other` — the blocking entity.
- **Outputs/Return:** None.
- **Side effects:** Calls `T_Damage`; attacker resolved as `teammaster->owner` if present, else `teammaster`.
- **Calls:** `T_Damage`

### turret_breach_fire
- **Signature:** `void turret_breach_fire(edict_t *self)`
- **Purpose:** Fires a rocket from the turret muzzle position (stored in `move_origin`).
- **Inputs:** `self` — the breach entity.
- **Outputs/Return:** None.
- **Side effects:** Spawns a rocket projectile; plays weapon sound at muzzle.
- **Calls:** `AngleVectors`, `VectorMA`, `fire_rocket`, `gi.positioned_sound`, `gi.soundindex`
- **Notes:** Damage is 100–150; speed scales with `skill->value`.

### turret_breach_think
- **Signature:** `void turret_breach_think(edict_t *self)`
- **Purpose:** Per-frame think: interpolates current angles toward `move_angles`, clamps to limits, drives `avelocity`, and corrects driver position/velocity.
- **Inputs:** `self` — the breach entity.
- **Outputs/Return:** None.
- **Side effects:** Writes `avelocity` on `self` and all team members; writes `velocity` and `avelocity` on `self->owner` (the driver); may call `turret_breach_fire` via spawnflag `65536`.
- **Calls:** `AnglesNormalize`, `VectorSubtract`, `VectorScale`, `SnapToEights`, `cos`, `sin`, `tan`, `turret_breach_fire`
- **Notes:** Driver position is computed in polar coords relative to breach origin; spawnflag `65536` is the fire signal set by the driver AI and cleared after firing.

### turret_breach_finish_init
- **Signature:** `void turret_breach_finish_init(edict_t *self)`
- **Purpose:** Deferred init; resolves the muzzle tip target entity and stores the offset in `move_origin`, then transitions to the think loop.
- **Inputs:** `self` — the breach entity.
- **Side effects:** Frees the target info_notnull entity via `G_FreeEdict`.
- **Calls:** `G_PickTarget`, `VectorSubtract`, `G_FreeEdict`

### SP_turret_breach
- **Signature:** `void SP_turret_breach(edict_t *self)`
- **Purpose:** Spawn entry point; sets physics, reads pitch/yaw limit fields from `st`, and schedules `turret_breach_finish_init`.
- **Calls:** `gi.setmodel`, `gi.linkentity`
- **Notes:** `pos1`/`pos2` store [pitch_max, yaw_min] and [pitch_min, yaw_max] respectively (sign-flipped from map values).

### SP_turret_base
- **Signature:** `void SP_turret_base(edict_t *self)`
- **Purpose:** Minimal spawn for the yaw-only base; sets BSP solid/push physics and blocked callback.
- **Notes:** No think function; purely moves as a team slave following the breach's yaw avelocity.

### turret_driver_die
- **Signature:** `void turret_driver_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- **Purpose:** Death handler; levels the gun, removes the driver from the team chain, and delegates to `infantry_die`.
- **Side effects:** Mutates team chain linked list; clears `owner` on breach and teammaster.
- **Calls:** `infantry_die`

### turret_driver_think
- **Signature:** `void turret_driver_think(edict_t *self)`
- **Purpose:** Per-frame AI; finds/tracks enemy, aims breach via `move_angles`, and signals fire using spawnflag `65536` after reaction delay.
- **Calls:** `FindTarget`, `visible`, `vectoangles`, `VectorSubtract`, `VectorCopy`
- **Notes:** Reaction time is `(3 - skill) * 1.0` seconds; fire rate is reaction_time + 1.0 seconds.

### turret_driver_link
- **Signature:** `void turret_driver_link(edict_t *self)`
- **Purpose:** Deferred link; resolves the targeted breach, computes polar offset for driver positioning, and appends driver to the team chain as a slave.
- **Calls:** `G_PickTarget`, `VectorLength`, `VectorSubtract`, `vectoangles`, `AnglesNormalize`

### SP_turret_driver
- **Signature:** `void SP_turret_driver(edict_t *self)`
- **Purpose:** Spawn entry point for the AI driver; disabled in deathmatch. Configures infantry-like monster properties and schedules `turret_driver_link`.
- **Side effects:** Increments `level.total_monsters`; frees self in deathmatch.
- **Calls:** `gi.modelindex`, `gi.linkentity`, `FindItemByClassname`

## Control Flow Notes
- **Init:** `SP_turret_breach` → (next frame) `turret_breach_finish_init` → begins `turret_breach_think` loop. `SP_turret_driver` → (next frame) `turret_driver_link` → begins `turret_driver_think` loop.
- **Per frame:** Driver think sets `target_ent->move_angles`; breach think reads them, interpolates `s.angles`, propagates yaw avelocity to the base team, and repositions the driver. Fire is signaled via spawnflag rather than a direct call.
- **Shutdown:** Driver death severs all ownership and team linkage; no explicit turret shutdown path.

## External Dependencies
- `g_local.h` — all game types, macros (`FRAMETIME`, `MOD_CRUSH`, AI flags), and engine interface (`gi`)
- **Defined elsewhere:** `T_Damage`, `fire_rocket`, `G_PickTarget`, `G_FreeEdict`, `FindTarget`, `visible`, `vectoangles`, `AngleVectors`, `VectorMA/Scale/Subtract/Copy/Length/Set`, `vtos`, `infantry_die`, `infantry_stand`, `monster_use`, `FindItemByClassname`, `skill`, `level`, `deathmatch`
