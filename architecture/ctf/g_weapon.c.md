# ctf/g_weapon.c

## File Purpose
Implements all projectile and hitscan weapon firing functions for the CTF game module. Spawns and configures projectile entities (blaster bolts, grenades, rockets, BFG) and performs instant-hit trace-based attacks (bullets, shotgun pellets, railgun). This is a near-identical copy of `game/g_weapon.c` with a single CTF-specific modification in `bfg_think`.

## Core Responsibilities
- Spawn and initialize projectile entities with correct physics, models, sounds, and touch callbacks
- Perform hitscan traces for bullet/shotgun/rail attacks, applying spread and water deflection
- Handle melee/impact hit detection via bbox-range checks
- Trigger monster dodge AI when non-instant projectiles are fired
- Apply direct and radius damage on projectile impact or explosion
- Emit temp entity network messages for visual effects (explosions, trails, splashes, laser beams)
- CTF-specific: prevent BFG laser from targeting teammates

## Key Types / Data Structures
None declared in this file; uses types from `g_local.h`.

## Global / File-Static State
None.

## Key Functions

### check_dodge
- **Signature:** `static void check_dodge(edict_t *self, vec3_t start, vec3_t dir, int speed)`
- **Purpose:** Traces along a projectile's path; if a live monster is in the way, triggers its dodge callback with an estimated time-of-arrival.
- **Inputs:** Firing entity, projectile start position, direction, travel speed.
- **Outputs/Return:** void
- **Side effects:** Calls `tr.ent->monsterinfo.dodge()`; on skill 0, skips 75% of the time.
- **Calls:** `gi.trace`, `infront`, `VectorMA`, `VectorLength`, `VectorSubtract`
- **Notes:** Only fires up to 8192 units; ETA accounts for target's bounding box radius.

### fire_hit
- **Signature:** `qboolean fire_hit(edict_t *self, vec3_t aim, int damage, int kick)`
- **Purpose:** Melee/impact attack; checks range, traces for occlusion, deals damage and knockback to `self->enemy`.
- **Inputs:** Attacker, aim vector (x=range, y=right offset, z=up offset), damage, kick force.
- **Outputs/Return:** `qtrue` if a monster or client was hit, `qfalse` otherwise.
- **Side effects:** Calls `T_Damage`; modifies `self->enemy->velocity` and `groundentity`.
- **Calls:** `gi.trace`, `AngleVectors`, `T_Damage`, `VectorMA`, `VectorNormalize`

### fire_lead *(static)*
- **Signature:** `static void fire_lead(edict_t *self, vec3_t start, vec3_t aimdir, int damage, int kick, int te_impact, int hspread, int vspread, int mod)`
- **Purpose:** Core hitscan trace for bullet/pellet weapons; handles spread, water entry splash, bullet deflection in water, and bubble trail.
- **Side effects:** `T_Damage` on hit target; emits `TE_SPLASH`, `TE_BUBBLETRAIL`, and `te_impact` temp entities via `gi.multicast`.
- **Calls:** `gi.trace`, `gi.pointcontents`, `T_Damage`, `PlayerNoise`, `gi.WriteByte/WritePosition/WriteDir/multicast`

### fire_bullet / fire_shotgun
- **Signature:** `void fire_bullet(...)` / `void fire_shotgun(..., int count, ...)`
- **Purpose:** Thin wrappers over `fire_lead`; shotgun calls it `count` times with `TE_SHOTGUN` impact effect.
- **Notes:** No additional logic beyond loop and impact-type selection.

### fire_blaster / blaster_touch
- **Signature:** `void fire_blaster(edict_t *self, vec3_t start, vec3_t dir, int damage, int speed, int effect, qboolean hyper)`
- **Purpose:** Spawns a `MOVETYPE_FLYMISSILE` bolt entity; `hyper` flag selects `MOD_HYPERBLASTER` in the touch callback.
- **Side effects:** Allocates entity via `G_Spawn`; calls `check_dodge`; immediate touch if spawned inside geometry.
- **Calls:** `G_Spawn`, `gi.modelindex`, `gi.soundindex`, `gi.linkentity`, `check_dodge`, `gi.trace`, `blaster_touch`

### fire_grenade / fire_grenade2
- **Signature:** `void fire_grenade(edict_t *self, vec3_t start, vec3_t aimdir, int damage, int speed, float timer, float damage_radius)`
- **Purpose:** Spawns `MOVETYPE_BOUNCE` grenade; `fire_grenade2` handles hand grenade variant with `held` flag and immediate detonation when `timer <= 0`.
- **Side effects:** `G_Spawn`, `gi.linkentity`; `Grenade_Explode` triggered by `think` after `timer` seconds or on contact with damageable entity.

### Grenade_Explode *(static)*
- **Purpose:** Applies directed damage to `ent->enemy` then radius damage to all nearby entities; emits explosion temp entity (water-aware).
- **Calls:** `T_Damage`, `T_RadiusDamage`, `PlayerNoise`, `G_FreeEdict`

### fire_rocket / rocket_touch
- **Signature:** `void fire_rocket(edict_t *self, vec3_t start, vec3_t dir, int damage, int speed, float damage_radius, int radius_damage)`
- **Purpose:** Spawns rocket with `MOVETYPE_FLYMISSILE`; touch applies direct + radius damage, spawns debris in non-multiplayer.
- **Side effects:** `check_dodge` called; debris via `ThrowDebris` skipped in deathmatch/coop.
- **Calls:** `G_Spawn`, `check_dodge`, `gi.linkentity`, `T_Damage`, `T_RadiusDamage`

### fire_rail
- **Signature:** `void fire_rail(edict_t *self, vec3_t start, vec3_t aimdir, int damage, int kick)`
- **Purpose:** Piercing hitscan; re-traces through each hit monster/client until a solid wall is reached, damaging all entities along the path.
- **Side effects:** `T_Damage` on each penetrated entity; emits `TE_RAILTRAIL` (twice if passing through water).

### bfg_think / bfg_explode / bfg_touch / fire_bfg
- **Purpose:** Full BFG lifecycle — `fire_bfg` spawns the projectile; `bfg_think` fires laser beams each frame to nearby entities (skips CTF teammates); `bfg_touch` triggers on impact, switching to `bfg_explode`; `bfg_explode` radiates energy damage across 5 animation frames.
- **CTF delta:** `bfg_think` contains `//ZOID` guard: skips clients on the same `ctf_team` as the owner.
- **Calls:** `findradius`, `gi.trace`, `T_Damage`, `T_RadiusDamage`, `G_Spawn`, `G_FreeEdict`, `check_dodge`

## Control Flow Notes
Functions are called from player weapon logic (`p_weapon.c`) during the server game frame. Projectile entities re-enter the engine each frame via their `think`/`touch` callbacks, which are invoked by the physics subsystem (`g_phys.c`). No init or shutdown involvement.

## External Dependencies
- `g_local.h` — all game types, `gi` interface, entity flags, damage flags, MOD constants
- **Defined elsewhere:** `T_Damage`, `T_RadiusDamage`, `ThrowDebris`, `PlayerNoise`, `CanDamage`, `findradius`, `infront`, `G_Spawn`, `G_FreeEdict`, `skill`, `deathmatch`, `coop`, `ctf`, `level.time`, `FRAMETIME`
