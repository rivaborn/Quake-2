# ctf/g_misc.c

## File Purpose
Implements miscellaneous map entity spawn functions and shared utility systems for the Quake 2 CTF game module. Covers gibs/debris effects, world geometry entities (areaportal, func_wall, func_explosive), navigational helpers (path_corner, point_combat), decorative/scripted entities, and teleporters. Extends base `g_misc.c` with CTF-specific hooks in `BecomeExplosion1` and `teleporter_touch`.

## Core Responsibilities
- Spawn and manage gib/debris physics entities on death
- Register and handle map brush entities (func_wall, func_object, func_explosive, misc_explobox)
- Provide AI navigation waypoints (path_corner, point_combat)
- Implement teleporter logic with CTF grapple reset integration
- Handle CTF flag/tech item preservation in `BecomeExplosion1`
- Spawn decorative/scripted scene entities (ships, banners, easter eggs, satellite dish)
- Implement a real-time/countdown `func_clock` driven by `target_string`

## Key Types / Data Structures
None (all types imported from `g_local.h`).

## Global / File-Static State

| Name | Type | Scope (global/static) | Purpose |
|---|---|---|---|
| `robotron` | `int[4]` | static | Model index cache for `viewthing` debug entity cycling |

## Key Functions

### VelocityForDamage
- Signature: `void VelocityForDamage(int damage, vec3_t v)`
- Purpose: Generates a random outward velocity for a gib, scaled by damage severity.
- Inputs: `damage` — magnitude; `v` — output vector.
- Outputs/Return: Populates `v` in place.
- Side effects: None.
- Calls: `crandom`, `random`, `VectorScale`.
- Notes: Z-component biased upward (200+); scale factor is 0.7 below 50 damage, 1.2 above.

### ThrowGib
- Signature: `void ThrowGib(edict_t *self, char *gibname, int damage, int type)`
- Purpose: Spawns a new gib entity with physics, randomized velocity, and auto-free timer.
- Inputs: `self` — source entity; `gibname` — model path; `damage` — used for velocity; `type` — `GIB_ORGANIC` or `GIB_METALLIC`.
- Outputs/Return: None.
- Side effects: Allocates entity via `G_Spawn`, registers model, links entity.
- Calls: `G_Spawn`, `VectorScale/Add/MA`, `gi.setmodel`, `VelocityForDamage`, `ClipGibVelocity`, `gi.linkentity`.
- Notes: Organic gibs use `MOVETYPE_TOSS` + touch callback; metallic use `MOVETYPE_BOUNCE`.

### ThrowHead / ThrowClientHead
- Both repurpose `self` (the dying entity) as a gib head rather than spawning new.
- `ThrowClientHead` randomly picks between two skull models and handles client animation state.

### ThrowDebris
- Signature: `void ThrowDebris(edict_t *self, char *modelname, float speed, vec3_t origin)`
- Purpose: Spawns a small bouncing debris chunk at a given world position.
- Inputs: `self` for velocity inheritance; `speed` scales random vector.
- Side effects: Spawns entity, links it; auto-frees in 5–10 seconds.
- Calls: `G_Spawn`, `gi.setmodel`, `VectorMA`, `gi.linkentity`.

### BecomeExplosion1
- Signature: `void BecomeExplosion1(edict_t *self)`
- Purpose: Converts an entity into a `TE_EXPLOSION1` temp effect then frees it — with CTF guard for flags and tech items.
- Side effects: May call `CTFResetFlag` or `CTFRespawnTech` (both free `self`); otherwise multicasts explosion event and frees entity.
- Calls: `CTFResetFlag`, `CTFTeamName`, `CTFRespawnTech`, `gi.WriteByte`, `gi.WritePosition`, `gi.multicast`, `G_FreeEdict`.
- Notes: CTF flag classname check contains a copy-paste bug — both flag resets print `CTF_TEAM1`'s name.

### teleporter_touch
- Signature: `void teleporter_touch(edict_t *self, edict_t *other, cplane_t *plane, csurface_t *surf)`
- Purpose: Teleports the touching player to the targeted destination entity; clears velocity and angles.
- Inputs: `self` — trigger volume; `other` — touching entity (must be a client).
- Side effects: Repositions `other`, sends `EV_PLAYER_TELEPORT` events, calls `CTFPlayerResetGrapple`, calls `KillBox`.
- Calls: `G_Find`, `CTFPlayerResetGrapple`, `gi.unlinkentity`, `KillBox`, `gi.linkentity`.
- Notes: Only operates on client entities; CTF-specific grapple reset added vs. base game.

### func_clock_think
- Signature: `void func_clock_think(edict_t *self)`
- Purpose: Per-second think that formats time (real clock or countdown) into a message string, then drives a `target_string` entity to update a `target_character` display.
- Side effects: Writes to `self->message` (TAG_LEVEL allocation), fires `G_UseTargets` on timeout.
- Calls: `G_Find`, `func_clock_format_countdown`, `localtime`, `Com_sprintf`, `G_UseTargets`.

### SP_func_explosive / func_explosive_explode
- Spawner sets health/die callbacks; `func_explosive_explode` does radius damage, spawns debris chunks (scaled by `mass`), fires targets, then calls `BecomeExplosion1`.

### SP_misc_teleporter
- Spawns two entities: visible disc model + invisible `SOLID_TRIGGER` volume that owns the touch logic.

## Control Flow Notes
All `SP_*` functions are called during map load (entity spawn pass). Think/touch/use callbacks fire during the game frame loop. Gib entities are self-contained with `nextthink`-based auto-cleanup. `func_clock_think` runs on a 1-second interval outside the normal `FRAMETIME` cadence.

## External Dependencies
- `g_local.h` — all game types, `gi` import table, entity fields
- `CTFResetFlag`, `CTFTeamName`, `CTFRespawnTech`, `CTFPlayerResetGrapple` — defined in `g_ctf.c`
- `train_use`, `func_train_find` — defined in `g_func.c` (extern declared inline)
- `T_Damage`, `T_RadiusDamage`, `KillBox`, `G_UseTargets`, `G_PickTarget`, `G_Find`, `G_Spawn`, `G_FreeEdict` — defined elsewhere in game module
- `M_walkmove`, `M_droptofloor` — monster movement, defined in `m_move.c`
- `sm_meat_index` — global model index, defined elsewhere
