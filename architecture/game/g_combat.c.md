# game/g_combat.c

## File Purpose
Implements the core damage, knockback, and death processing systems for the Quake 2 game logic. Handles direct damage application (`T_Damage`), radius/splash damage (`T_RadiusDamage`), armor and power armor absorption, kill accounting, and monster aggression responses to being attacked.

## Core Responsibilities
- Line-of-sight checks for damage eligibility (`CanDamage`)
- Full damage pipeline: godmode, invincibility, power armor, armor, net health reduction
- Knockback velocity application scaled by mass and attacker identity
- Kill event dispatch and score/stat tracking (`Killed`)
- Monster AI target switching in response to damage (`M_ReactToDamage`)
- Radius damage attenuation and entity enumeration (`T_RadiusDamage`)
- Temporary effect (blood/sparks) spawning at impact points

## Key Types / Data Structures
None defined here; all types are from `g_local.h`.

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `meansOfDeath` | `int` (extern) | global | Records the damage type (mod) for the current kill; read by death message logic elsewhere |

## Key Functions

### CanDamage
- **Signature:** `qboolean CanDamage(edict_t *targ, edict_t *inflictor)`
- **Purpose:** Tests whether inflictor has unobstructed LOS to target; used by explosions and melee before applying damage.
- **Inputs:** Target entity, inflictor entity.
- **Outputs/Return:** `true` if at least one trace reaches the target unblocked.
- **Side effects:** None.
- **Calls:** `gi.trace`, `VectorAdd`, `VectorScale`, `VectorCopy`
- **Notes:** MOVETYPE_PUSH (brush models) uses the bbox center; point entities get 5 probe points (center + ±15 on X/Y) to handle large targets partially behind geometry.

---

### Killed
- **Signature:** `void Killed(edict_t *targ, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- **Purpose:** Finalises a kill: clamps health floor, updates kill counters, invokes the entity's `die` callback, and triggers monster death-use targets.
- **Inputs:** The dying entity, damage source, attacker, lethal damage amount, impact point.
- **Outputs/Return:** void.
- **Side effects:** Mutates `targ->health`, `targ->enemy`, `targ->owner`, `targ->touch`; increments `level.killed_monsters` and optionally `attacker->client->resp.score` (coop); calls `monster_death_use`, `targ->die`.
- **Calls:** `monster_death_use`, `targ->die`
- **Notes:** Medic self-kills set `targ->owner = attacker` to prevent self-resurrection. Static movers (doors, triggers) bypass monster logic and call `die` directly.

---

### SpawnDamage
- **Signature:** `void SpawnDamage(int type, vec3_t origin, vec3_t normal, int damage)`
- **Purpose:** Sends a `svc_temp_entity` network message for visual impact effects (blood, sparks, shield sparks, etc.).
- **Inputs:** Effect type constant, world position, surface normal, damage magnitude (clamped to 255).
- **Outputs/Return:** void.
- **Side effects:** Writes to the network message buffer; multicasts within PVS.
- **Calls:** `gi.WriteByte`, `gi.WritePosition`, `gi.WriteDir`, `gi.multicast`

---

### CheckPowerArmor *(static)*
- **Signature:** `static int CheckPowerArmor(edict_t *ent, vec3_t point, vec3_t normal, int damage, int dflags)`
- **Purpose:** Computes and applies power armor cell absorption for players and monsters.
- **Inputs:** Entity, impact point/normal, incoming damage, damage flags.
- **Outputs/Return:** Damage absorbed (integer).
- **Side effects:** Depletes `client->pers.inventory[cells_index]` or `monsterinfo.power_armor_power`; sets `ent->powerarmor_time`; calls `SpawnDamage`.
- **Calls:** `PowerArmorType`, `FindItem`, `ITEM_INDEX`, `AngleVectors`, `VectorSubtract`, `VectorNormalize`, `DotProduct`, `SpawnDamage`
- **Notes:** Screen armor only absorbs frontal hits (dot > 0.3); Shield armor absorbs from any direction at 2:1 cell cost.

---

### CheckArmor *(static)*
- **Signature:** `static int CheckArmor(edict_t *ent, vec3_t point, vec3_t normal, int damage, int te_sparks, int dflags)`
- **Purpose:** Computes and applies conventional armor absorption for players only.
- **Inputs:** Entity, impact data, damage, spark effect type, damage flags.
- **Outputs/Return:** Damage absorbed (integer).
- **Side effects:** Decrements `client->pers.inventory[armor_index]`; calls `SpawnDamage`.
- **Calls:** `ArmorIndex`, `GetItemByIndex`, `SpawnDamage`

---

### M_ReactToDamage
- **Signature:** `void M_ReactToDamage(edict_t *targ, edict_t *attacker)`
- **Purpose:** Updates a monster's `enemy` pointer in response to being hit, implementing aggro/target-switching rules.
- **Inputs:** Damaged monster, attacker entity.
- **Outputs/Return:** void.
- **Side effects:** Mutates `targ->enemy`, `targ->oldenemy`, `targ->monsterinfo.aiflags`; may call `FoundTarget`.
- **Calls:** `visible`, `FoundTarget`
- **Notes:** Good-guy monsters ignore friendly-fire; client attackers always take priority; same-locomotion-type monsters of different classes trigger mutual aggro; hardcoded exclusions for high-splash monsters (tank, supertank, makron, jorg).

---

### T_Damage
- **Signature:** `void T_Damage(edict_t *targ, edict_t *inflictor, edict_t *attacker, vec3_t dir, vec3_t point, vec3_t normal, int damage, int knockback, int dflags, int mod)`
- **Purpose:** Central damage dispatch: applies all mitigations in order (godmode → invincibility → power armor → armor), applies net health loss, triggers pain/death callbacks, and records per-frame client damage for screen effects.
- **Inputs:** Full damage context: entities, direction, point, normal, raw damage, knockback magnitude, flags, means-of-death.
- **Outputs/Return:** void; returns early if `targ->takedamage == 0` or team-damage blocked.
- **Side effects:** Mutates `targ->health`, `targ->velocity`, `targ->flags`; sets `meansOfDeath`; accumulates `client->damage_*` fields; calls `SpawnDamage`, `CheckPowerArmor`, `CheckArmor`, `Killed`, `M_ReactToDamage`, `targ->pain`.
- **Calls:** `OnSameTeam`, `CheckPowerArmor`, `CheckArmor`, `CheckTeamDamage`, `SpawnDamage`, `Killed`, `M_ReactToDamage`, `targ->pain`
- **Notes:** Easy skill halves damage to players; surprise bonus doubles damage to unalerted monsters; rocket-jump self-knockback uses 1600 scalar vs 500 for others; skill 3 extends monster pain debounce to 5 s.

---

### T_RadiusDamage
- **Signature:** `void T_RadiusDamage(edict_t *inflictor, edict_t *attacker, float damage, edict_t *ignore, float radius, int mod)`
- **Purpose:** Enumerates all damageable entities within radius, attenuates damage linearly with distance, and calls `T_Damage` for each.
- **Inputs:** Explosion origin entity, attacker, max damage, one entity to skip, radius, means-of-death.
- **Outputs/Return:** void.
- **Side effects:** Indirectly all side effects of `T_Damage`; uses `findradius` iterator.
- **Calls:** `findradius`, `CanDamage`, `VectorAdd`, `VectorMA`, `VectorSubtract`, `VectorLength`, `T_Damage`
- **Notes:** Attacker receives 50% of computed points; damage = `base − 0.5 × dist`; entities with 0 or negative points are skipped.

## Control Flow Notes
Called during the game frame from weapons, projectile `think`/`touch` functions, and environmental hazards. `T_Damage` is the single choke-point for all health modification; `T_RadiusDamage` is its splash wrapper. `Killed` is only reached from within `T_Damage`. No direct init or shutdown involvement.

## External Dependencies
- **Includes:** `g_local.h` (all engine/game types and macros)
- **Defined elsewhere:** `gi` (game import struct), `findradius`, `OnSameTeam`, `visible`, `FoundTarget`, `monster_death_use`, `PowerArmorType`, `ArmorIndex`, `GetItemByIndex`, `FindItem`, `ITEM_INDEX`, `level`, `skill`, `deathmatch`, `dmflags`, `coop`, `meansOfDeath`, `vec3_origin`
