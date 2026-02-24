# ctf/g_combat.c

## File Purpose
Implements the core damage, death, and knockback system for the CTF (Capture the Flag) game module. It handles direct and radius damage application, armor/power-armor absorption, team damage checks, and CTF-specific modifications such as strength/resistance tech bonuses and team armor protection.

## Core Responsibilities
- Line-of-sight damage eligibility testing (`CanDamage`)
- Dispatching entity death logic (`Killed`)
- Applying damage with armor/power-armor absorption, knockback, godmode, and invincibility (`T_Damage`)
- Spawning visual hit effects (sparks, blood) via temp entities
- Radius/explosion falloff damage distribution (`T_RadiusDamage`)
- CTF-specific team damage blocking and flag-carrier hurt notifications
- Monster aggro/reaction logic on taking damage (`M_ReactToDamage`)

## Key Types / Data Structures
None unique to this file; uses types from `g_local.h`.

| Name | Kind | Purpose |
|---|---|---|
| `edict_t` | struct | Game entity (target, inflictor, attacker) |
| `gclient_t` | struct | Per-client state including inventory and CTF team |
| `trace_t` | struct | Result of a gi.trace LOS query |
| `gitem_t` / `gitem_armor_t` | struct | Item descriptor with armor protection coefficients |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `meansOfDeath` | `int` (extern) | global | Set per-damage-event to track kill attribution/mod flags |

## Key Functions

### CanDamage
- **Signature:** `qboolean CanDamage(edict_t *targ, edict_t *inflictor)`
- **Purpose:** Determines whether inflictor has an unobstructed path to target (used by explosions and melee).
- **Inputs:** Target entity, inflictor entity.
- **Outputs/Return:** `qtrue` if any of up to 5 trace probes (center + 4 corner offsets) reaches target unobstructed.
- **Side effects:** None.
- **Calls:** `gi.trace`, `VectorAdd`, `VectorScale`, `VectorCopy`
- **Notes:** BSP-mover entities (`MOVETYPE_PUSH`) use their AABB center instead of `s.origin` due to their origin being `0,0,0`.

### CheckPowerArmor *(static)*
- **Signature:** `static int CheckPowerArmor(edict_t *ent, vec3_t point, vec3_t normal, int damage, int dflags)`
- **Purpose:** Calculates and deducts damage absorbed by power armor (screen or shield type) for players and monsters.
- **Inputs:** Entity, hit point/normal, damage amount, damage flags.
- **Outputs/Return:** Amount of damage saved.
- **Side effects:** Drains cell inventory (player) or `monsterinfo.power_armor_power` (monster); sets `powerarmor_time`; calls `SpawnDamage`.
- **Notes:** CTF weakens power armor — shield type uses `damagePerCell = 1` and absorbs only 2/3 damage (vs standard). Screen type blocks damage only from the front (dot product > 0.3).

### CheckArmor *(static)*
- **Signature:** `static int CheckArmor(edict_t *ent, vec3_t point, vec3_t normal, int damage, int te_sparks, int dflags)`
- **Purpose:** Calculates and deducts damage absorbed by conventional armor for players only.
- **Inputs:** Entity, hit point/normal, damage, spark effect type, damage flags.
- **Outputs/Return:** Amount of damage saved.
- **Side effects:** Decrements `client->pers.inventory[index]`; calls `SpawnDamage`.

### M_ReactToDamage
- **Signature:** `void M_ReactToDamage(edict_t *targ, edict_t *attacker)`
- **Purpose:** Updates a monster's enemy target in response to being hit, handling good-guy exemptions and inter-monster aggro rules.
- **Side effects:** Mutates `targ->enemy`, `targ->oldenemy`; may call `FoundTarget`.
- **Notes:** Tank-type monsters are excluded from inter-monster retaliation to prevent splash aggro cascades.

### CheckTeamDamage
- **Signature:** `qboolean CheckTeamDamage(edict_t *targ, edict_t *attacker)`
- **Purpose:** Returns true if both entities are on the same CTF team (and not the same entity), suppressing damage.
- **Notes:** CTF-specific; the non-CTF branch is a commented FIXME stub.

### Killed
- **Signature:** `void Killed(edict_t *targ, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- **Purpose:** Handles death bookkeeping and dispatches the entity's `die` callback.
- **Side effects:** Clamps health to -999; increments `level.killed_monsters`; awards coop score; sets medic ownership; nulls monster touch; calls `monster_death_use` and `targ->die`.

### SpawnDamage
- **Signature:** `void SpawnDamage(int type, vec3_t origin, vec3_t normal, int damage)`
- **Purpose:** Sends a temp-entity effect (sparks, blood, shield sparks) to clients in PVS.
- **Side effects:** Network write via `gi.WriteByte`, `gi.WritePosition`, `gi.WriteDir`, `gi.multicast`.

### T_Damage
- **Signature:** `void T_Damage(edict_t *targ, edict_t *inflictor, edict_t *attacker, vec3_t dir, vec3_t point, vec3_t normal, int damage, int knockback, int dflags, int mod)`
- **Purpose:** Central damage application entry point; applies all modifiers before subtracting health.
- **Side effects:** Mutates `targ->health`, `targ->velocity`, `client->damage_*` accumulators; calls `Killed`, `targ->pain`, `CTFApplyStrength`, `CTFApplyResistance`, `CTFCheckHurtCarrier`, `SpawnDamage`, `CheckTeamDamage`.
- **Notes:** Damage is blocked entirely during `CTFMatchSetup()`. Easy skill halves damage vs non-deathmatch. CTF team armor protection (`DF_ARMOR_PROTECT`) skips both power and regular armor checks for teammates.

### T_RadiusDamage
- **Signature:** `void T_RadiusDamage(edict_t *inflictor, edict_t *attacker, float damage, edict_t *ignore, float radius, int mod)`
- **Purpose:** Applies falloff damage to all damageable entities within a sphere, gated by `CanDamage`.
- **Inputs:** Source entity, attacker, max damage, entity to skip, radius, means-of-death.
- **Side effects:** Calls `T_Damage` for each eligible entity; self-damage is halved.

## Control Flow Notes
This file is invoked during the game frame's combat resolution phase. `T_Damage` is the primary entry point called by weapon fire, projectile touch callbacks, and `T_RadiusDamage`. `Killed` triggers `die` callbacks which feed into respawn or level-exit logic. No init or shutdown involvement.

## External Dependencies
- `g_local.h` — all game types, constants, CVars
- `CTFApplyStrength`, `CTFApplyResistance`, `CTFCheckHurtCarrier`, `CTFMatchSetup` — defined in `g_ctf.c`
- `FoundTarget`, `monster_death_use` — defined in monster AI files
- `OnSameTeam`, `PowerArmorType`, `ArmorIndex`, `GetItemByIndex`, `FindItem`, `findradius`, `visible` — defined elsewhere in game module
- `gi.trace`, `gi.sound`, `gi.soundindex`, `gi.WriteByte`, `gi.WritePosition`, `gi.WriteDir`, `gi.multicast` — engine imports via `gi` interface
