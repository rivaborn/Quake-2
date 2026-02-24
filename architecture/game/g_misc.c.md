# game/g_misc.c

## File Purpose
Implements the spawn and logic functions for miscellaneous game entities in Quake 2's server-side game DLL. Covers area portals, gibs, debris, decorative objects, scripted world props (teleporters, clocks, path nodes, explosive barrels), and various `misc_*`/`func_*` entity types used by map designers.

## Core Responsibilities
- Spawning and managing gib/debris physics entities thrown on death
- Handling area portal open/close state
- Implementing path corner and combat point navigation nodes for monsters
- Providing func_wall, func_object, and func_explosive brush entities
- Implementing misc_explobox (exploding barrel) with delayed detonation
- Managing decorative/scripted entities (banners, ships, teleporters, clocks, easter eggs)
- Providing teleporter trigger and destination spawners

## Key Types / Data Structures
None (all types imported via `g_local.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `sm_meat_index` | `int` (extern) | global | Model index for small meat gib; referenced in `gib_touch` for frame-advance logic |

## Key Functions

### VelocityForDamage
- **Signature:** `void VelocityForDamage(int damage, vec3_t v)`
- **Purpose:** Generates a randomized launch velocity for gibs scaled by damage amount.
- **Inputs:** `damage` – severity; `v` – output vector.
- **Outputs/Return:** Fills `v` with velocity.
- **Side effects:** None.
- **Calls:** `crandom`, `random`, `VectorScale`.
- **Notes:** Z component always positive (upward bias). Scale factor 0.7 below 50 damage, 1.2 above.

### ThrowGib
- **Signature:** `void ThrowGib(edict_t *self, char *gibname, int damage, int type)`
- **Purpose:** Spawns a new gib entity originating from `self`'s bounding box with randomized velocity.
- **Inputs:** Source entity, model path, damage (for velocity), `GIB_ORGANIC` or `GIB_METAL`.
- **Outputs/Return:** None.
- **Side effects:** Allocates entity via `G_Spawn`; calls `gi.linkentity`.
- **Calls:** `G_Spawn`, `gi.setmodel`, `VelocityForDamage`, `ClipGibVelocity`, `gi.linkentity`.
- **Notes:** Organic gibs use `MOVETYPE_TOSS` + touch callback; metal use `MOVETYPE_BOUNCE`. Auto-freed after 10–20 s.

### ThrowHead
- **Signature:** `void ThrowHead(edict_t *self, char *gibname, int damage, int type)`
- **Purpose:** Converts the dying entity itself into a flying head gib (reuses the entity slot).
- **Side effects:** Modifies `self` in place, calls `gi.setmodel`, `gi.linkentity`.
- **Notes:** Clears monster flags, model2, sound. Yaw-only angular velocity.

### ThrowClientHead
- **Signature:** `void ThrowClientHead(edict_t *self, int damage)`
- **Purpose:** Throws a player head gib on client death; randomly selects head2 or skull model.
- **Side effects:** Modifies `self`, sets `anim_priority`/`anim_end` on live clients.
- **Calls:** `VelocityForDamage`, `gi.setmodel`, `gi.linkentity`.

### ThrowDebris
- **Signature:** `void ThrowDebris(edict_t *self, char *modelname, float speed, vec3_t origin)`
- **Purpose:** Spawns a bouncing debris chunk at a specific origin with speed-scaled random velocity.
- **Side effects:** `G_Spawn`, `gi.linkentity`. Auto-freed after 5–10 s.
- **Calls:** `G_Spawn`, `gi.setmodel`, `gi.linkentity`.

### barrel_explode
- **Signature:** `void barrel_explode(edict_t *self)`
- **Purpose:** Executes full barrel detonation: radius damage, throws many debris chunks, calls `BecomeExplosion1/2`.
- **Side effects:** `T_RadiusDamage`, multiple `ThrowDebris` calls, frees entity.
- **Notes:** Distinguishes `BecomeExplosion2` (grounded) vs `BecomeExplosion1` (airborne).

### path_corner_touch
- **Signature:** `void path_corner_touch(edict_t *self, edict_t *other, cplane_t *plane, csurface_t *surf)`
- **Purpose:** Advances a monster along its waypoint path; handles optional teleport corners and pause waits.
- **Calls:** `G_UseTargets`, `G_PickTarget`, `vectoyaw`.
- **Notes:** Only acts if `other->movetarget == self`. TELEPORT spawnflag moves monster instantly.

### teleporter_touch
- **Signature:** `void teleporter_touch(edict_t *self, edict_t *other, cplane_t *plane, csurface_t *surf)`
- **Purpose:** Teleports a player client to the targeted `misc_teleporter_dest`, clearing velocity and setting angles.
- **Side effects:** Repositions entity, sets pmove flags, fires `EV_PLAYER_TELEPORT`, calls `KillBox`, `gi.linkentity`.
- **Calls:** `G_Find`, `gi.unlinkentity`, `KillBox`, `gi.linkentity`.

### func_clock_think
- **Signature:** `void func_clock_think(edict_t *self)`
- **Purpose:** Per-second think function: formats countdown/countup/real-time clock string, pushes to linked `target_string`, fires `pathtarget` on completion.
- **Calls:** `G_Find`, `func_clock_format_countdown`, `G_UseTargets`, `localtime`, `time`.

- **Notes (trivial helpers):** `BecomeExplosion1/2` broadcast a temp-entity explosion event then free the entity. `ClipGibVelocity` clamps gib velocity components. `gib_think/gib_touch/gib_die` manage gib lifecycle. `light_use` toggles configstring light style.

## Control Flow Notes
All `SP_*` functions are called during level spawn (map load) by the entity spawn dispatcher. Think/touch/use callbacks fire during the server frame loop. Gibs and debris are entirely frame-driven via `nextthink`. The file has no init or shutdown hook of its own.

## External Dependencies
- **Includes:** `g_local.h` (pulls in all game types, `edict_t`, `gi`, `level`, constants)
- **Defined elsewhere:** `G_Spawn`, `G_FreeEdict`, `G_UseTargets`, `G_PickTarget`, `G_Find`, `KillBox`, `T_Damage`, `T_RadiusDamage`, `M_walkmove`, `M_droptofloor`, `train_use`, `func_train_find`, `sm_meat_index`, `vectoangles`, `vectoyaw`, `AngleVectors`, `Com_sprintf`
