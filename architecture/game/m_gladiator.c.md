# game/m_gladiator.c

## File Purpose
Implements the Gladiator monster AI for Quake 2, a heavy melee/ranged hybrid enemy that attacks with a cleaver and a railgun. Defines all animation frame sequences, behavioral state callbacks, and the spawn function for `monster_gladiator`.

## Core Responsibilities
- Define frame sequences for stand, walk, run, melee attack, gun attack, pain, and death animations
- Implement cleaver melee attack with hit/miss sound feedback
- Implement railgun attack that pre-targets the enemy's position before firing
- Handle pain response with skin swap at half health and air-pain variant
- Handle death with gib threshold check and corpse physics finalization
- Register all sounds and initialize entity properties at spawn time

## Key Types / Data Structures
None (uses engine types from `g_local.h` and `m_gladiator.h`).

| Name | Kind | Purpose |
|---|---|---|
| `mframe_t` | struct | Single animation frame: AI function pointer, distance, and optional callback |
| `mmove_t` | struct | Animation sequence: frame range, frame array, end-of-sequence callback |
| `edict_t` | struct | Entity instance carrying monster state, physics, and callback pointers |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `sound_pain1` | `static int` | static | Sound index for pain variant 1 |
| `sound_pain2` | `static int` | static | Sound index for pain variant 2 |
| `sound_die` | `static int` | static | Sound index for death |
| `sound_gun` | `static int` | static | Sound index for railgun charge |
| `sound_cleaver_swing` | `static int` | static | Sound index for cleaver swing |
| `sound_cleaver_hit` | `static int` | static | Sound index for cleaver hit |
| `sound_cleaver_miss` | `static int` | static | Sound index for cleaver miss |
| `sound_idle` | `static int` | static | Sound index for idle vocalization |
| `sound_search` | `static int` | static | Sound index for search vocalization |
| `sound_sight` | `static int` | static | Sound index for sight vocalization |

## Key Functions

### GaldiatorMelee
- **Signature:** `void GaldiatorMelee(edict_t *self)`
- **Purpose:** Executes one cleaver strike; plays hit or miss sound based on result.
- **Inputs:** `self` — the Gladiator entity
- **Outputs/Return:** void
- **Side effects:** Calls `fire_hit` which applies damage to target; plays sound on `CHAN_AUTO`
- **Calls:** `VectorSet`, `fire_hit`, `gi.sound`
- **Notes:** Aim vector uses `MELEE_DISTANCE` with a slight downward offset (`-4`). Damage is 20–24 (rand % 5). Called twice per melee sequence (frames 7 and 14).

### GladiatorGun
- **Signature:** `void GladiatorGun(edict_t *self)`
- **Purpose:** Fires a railgun shot toward the pre-saved target position (`self->pos1`).
- **Inputs:** `self` — the Gladiator entity
- **Outputs/Return:** void
- **Side effects:** Spawns a railgun projectile via `monster_fire_railgun`; 50 damage, 100 knockback
- **Calls:** `AngleVectors`, `G_ProjectSource`, `VectorSubtract`, `VectorNormalize`, `monster_fire_railgun`
- **Notes:** Target position is captured at attack decision time in `gladiator_attack`, not at fire time — prevents trivial dodging.

### gladiator_attack
- **Signature:** `void gladiator_attack(edict_t *self)`
- **Purpose:** Decides whether to use the railgun; skips if enemy is within melee safe zone.
- **Inputs:** `self` — the Gladiator entity
- **Outputs/Return:** void
- **Side effects:** Plays railgun charge sound; copies enemy origin into `self->pos1`; sets current move to gun attack sequence
- **Calls:** `VectorSubtract`, `VectorLength`, `gi.sound`, `VectorCopy`
- **Notes:** Safe zone is `MELEE_DISTANCE + 32`. Enemy viewheight is added to `pos1[2]` to aim at torso level.

### gladiator_pain
- **Signature:** `void gladiator_pain(edict_t *self, edict_t *other, float kick, int damage)`
- **Purpose:** Handles pain response including skin change, debounce, skill gating, and airborne variant.
- **Inputs:** `self`, `other` (attacker), `kick`, `damage`
- **Outputs/Return:** void
- **Side effects:** Modifies `self->s.skinnum`, `self->pain_debounce_time`, `self->monsterinfo.currentmove`; plays sound
- **Calls:** `gi.sound`, `random`
- **Notes:** Skin switches to index 1 (damaged skin) permanently below half health. Nightmare skill (`3`) skips pain animation entirely. Air pain (`gladiator_move_pain_air`) triggered when `velocity[2] > 100`.

### gladiator_die
- **Signature:** `void gladiator_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- **Purpose:** Handles death: gib explosion or standard death animation.
- **Inputs:** Standard die callback parameters
- **Outputs/Return:** void
- **Side effects:** Calls `ThrowGib`/`ThrowHead` for gibs; sets `deadflag`; sets death move sequence; plays death sound
- **Calls:** `gi.sound`, `gi.soundindex`, `ThrowGib`, `ThrowHead`
- **Notes:** Gib threshold is `-175`. Gib sequence: 2 bones + 4 meat chunks + 1 head. Guards against double-death with `DEAD_DEAD` check.

### SP_monster_gladiator
- **Signature:** `void SP_monster_gladiator(edict_t *self)`
- **Purpose:** Spawns and fully initializes a Gladiator entity.
- **Inputs:** `self` — pre-allocated entity from map spawn
- **Outputs/Return:** void
- **Side effects:** Registers sounds and model; sets physics, health, mass, bounding box; assigns all AI callbacks; calls `walkmonster_start`
- **Calls:** `gi.soundindex`, `gi.modelindex`, `VectorSet`, `gi.linkentity`, `walkmonster_start`, `G_FreeEdict`
- **Notes:** Immediately frees entity in deathmatch mode. Health = 400, mass = 400, gib health = -175.

## Control Flow Notes
`SP_monster_gladiator` is the map-spawn entry point, invoked during level load. Per-frame AI is driven by `walkmonster_start` which runs the `monsterinfo.currentmove` frame sequence each server tick. Melee is triggered by the engine calling `monsterinfo.melee`; ranged attack by `monsterinfo.attack`. Pain and die callbacks are invoked by the damage system in `g_combat.c`.

## External Dependencies
- **Includes:** `g_local.h`, `m_gladiator.h`
- **Defined elsewhere:** `ai_stand`, `ai_walk`, `ai_run`, `ai_charge`, `ai_move`, `fire_hit`, `monster_fire_railgun`, `G_ProjectSource`, `monster_flash_offset`, `walkmonster_start`, `ThrowGib`, `ThrowHead`, `MELEE_DISTANCE`, `MODEL_SCALE`, `MZ2_GLADIATOR_RAILGUN_1`, frame constants (`FRAME_stand1` etc.), `gi` (game import struct), `level`, `skill`, `deathmatch`
