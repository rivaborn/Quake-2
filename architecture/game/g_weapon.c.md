# game/g_weapon.c

## File Purpose
Implements all projectile and hitscan weapon firing logic for the Quake 2 game DLL. Covers bullet/pellet spread, blaster bolts, grenades, rockets, railgun, and the BFG, including their spawned entity lifecycle and impact/explosion callbacks.

## Core Responsibilities
- Hitscan weapons: bullet and shotgun pellet tracing with spread, water deflection, and splash effects
- Melee impact: range-checked hit detection with knockback for monsters/players
- Projectile spawning: blaster, grenade (standard and hand), rocket, BFG entities with movement, touch, and think callbacks
- Monster dodge triggering for non-instant projectiles
- Radius and direct damage dispatch via `T_Damage` / `T_RadiusDamage`
- Temp-entity multicast for visual/audio effects (gun puffs, explosions, rail trail, bubble trails)
- BFG-specific per-frame laser sweep logic during flight

## Key Types / Data Structures
None — operates entirely on `edict_t`, `trace_t`, `cplane_t`, `csurface_t` defined in `g_local.h`.

## Global / File-Static State
None.

## Key Functions

### check_dodge
- Signature: `static void check_dodge(edict_t *self, vec3_t start, vec3_t dir, int speed)`
- Purpose: Traces the projectile path and notifies any monster in its way to dodge.
- Inputs: Firing entity, projectile origin, direction, speed.
- Outputs/Return: None.
- Side effects: Calls `tr.ent->monsterinfo.dodge`; suppressed 75% of the time on skill 0.
- Calls: `gi.trace`, `infront`, `monsterinfo.dodge`
- Notes: Called only for non-instant weapons (blaster, rocket, BFG). ETA calculated from distance minus bbox radius divided by speed.

### fire_hit
- Signature: `qboolean fire_hit(edict_t *self, vec3_t aim, int damage, int kick)`
- Purpose: Melee/impact weapon hit — range-checks enemy, traces to confirm line-of-sight, applies damage and custom knockback.
- Inputs: Attacker, aim vector (x=range, y=lateral offset, z=vertical offset), damage, kick.
- Outputs/Return: `true` if a monster or client was hit.
- Side effects: Calls `T_Damage`; directly modifies `enemy->velocity` and clears `groundentity` on upward kick.
- Calls: `gi.trace`, `AngleVectors`, `T_Damage`
- Notes: Redirects hit to `self->enemy` if trace hits any client/monster — ensures the intended target always receives damage.

### fire_lead *(static)*
- Signature: `static void fire_lead(edict_t *self, vec3_t start, vec3_t aimdir, int damage, int kick, int te_impact, int hspread, int vspread, int mod)`
- Purpose: Core hitscan routine; handles spread randomization, water entry/refraction, impact temp-entities, and bubble trails.
- Inputs: Firing entity, muzzle start, direction, damage, kick, impact TE type, horizontal/vertical spread, damage mod.
- Outputs/Return: None.
- Side effects: `T_Damage` on hit entities; multiple `gi.WriteByte`/`gi.multicast` calls for visual effects; `PlayerNoise` if client fired.
- Calls: `gi.trace`, `gi.pointcontents`, `vectoangles`, `AngleVectors`, `T_Damage`, `PlayerNoise`, `gi.multicast`
- Notes: First trace validates muzzle isn't inside geometry; water changes bullet direction and spawns `TE_BUBBLETRAIL`.

### fire_bullet / fire_shotgun
- Thin wrappers over `fire_lead`. `fire_shotgun` loops `count` times with `TE_SHOTGUN` impact type.

### fire_blaster / blaster_touch
- Signature: `void fire_blaster(edict_t *self, vec3_t start, vec3_t dir, int damage, int speed, int effect, qboolean hyper)`
- Purpose: Spawns a `MOVETYPE_FLYMISSILE` bolt entity; `blaster_touch` is its collision callback.
- Side effects: Allocates edict via `G_Spawn`; sets 2-second self-destruct think; calls `check_dodge`; immediate detonation if spawned inside geometry.
- Calls: `G_Spawn`, `gi.modelindex`, `gi.soundindex`, `gi.linkentity`, `check_dodge`, `gi.trace`, `blaster_touch`, `T_Damage`, `G_FreeEdict`
- Notes: `SVF_DEADMONSTER` flag prevents client prediction clipping against bolt.

### fire_grenade / fire_grenade2 / Grenade_Touch / Grenade_Explode
- `fire_grenade` spawns `MOVETYPE_BOUNCE` grenade; `fire_grenade2` handles hand grenade variant (held flag, `spawnflags 1/3`).
- `Grenade_Explode`: applies direct damage to `ent->enemy` then radius damage; emits appropriate water/ground TE; frees entity.
- `Grenade_Touch`: on non-damageable surface plays bounce sound; on damageable target sets `ent->enemy` and calls `Grenade_Explode`.

### fire_rocket / rocket_touch
- Spawns `MOVETYPE_FLYMISSILE` rocket with 8-second timeout; `rocket_touch` applies direct hit + radius damage, spawns debris in SP, emits `TE_ROCKET_EXPLOSION`.
- Calls `check_dodge` after spawn.

### fire_rail
- Signature: `void fire_rail(edict_t *self, vec3_t start, vec3_t aimdir, int damage, int kick)`
- Purpose: Penetrating hitscan — iterates traces through all monsters/clients in a line.
- Side effects: Multiple `T_Damage` calls; sends `TE_RAILTRAIL`; emits second trail multicast if water passed through.
- Notes: Uses advancing `ignore` pointer to chain through penetrated entities; stops at first non-monster/client.

### bfg_think / bfg_touch / bfg_explode / fire_bfg
- `fire_bfg`: spawns BFG projectile; overrides initial think with `bfg_think` running every `FRAMETIME`.
- `bfg_think`: each frame fires laser rays to all entities within 256 units; damages non-immune targets along line-of-sight.
- `bfg_touch`: on impact applies 200 direct + 100 radius damage, transitions entity to explosion sprite, schedules `bfg_explode`.
- `bfg_explode`: frame 0 does radius energy damage falloff to all entities within `dmg_radius`; runs 5 frames then frees.

## Control Flow Notes
This file is purely called on-demand: player weapon code and monster attack functions invoke the `fire_*` entry points during their per-frame attack think. Spawned projectile entities re-enter the engine's entity update loop via `nextthink`/`think` and `touch` callbacks set here. No init or shutdown involvement.

## External Dependencies
- `g_local.h` (all engine/game types)
- `T_Damage`, `T_RadiusDamage`, `ThrowDebris`, `CanDamage`, `findradius` — combat/utility, defined in `g_combat.c` / `g_utils.c`
- `PlayerNoise` — defined in `p_weapon.c`
- `G_Spawn`, `G_FreeEdict` — entity management, `g_utils.c`
- `gi` game import table: `gi.trace`, `gi.pointcontents`, `gi.modelindex`, `gi.soundindex`, `gi.linkentity`, `gi.sound`, `gi.WriteByte`, `gi.WritePosition`, `gi.WriteDir`, `gi.multicast`
- `skill`, `deathmatch`, `coop` — cvars, defined elsewhere
- `level.time`, `FRAMETIME` — globals from `g_main.c` / `g_local.h`
