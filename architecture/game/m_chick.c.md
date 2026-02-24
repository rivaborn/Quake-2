# game/m_chick.c

## File Purpose
Implements the "Chick" monster (internally called "bitch" per model path), a mid-tier enemy that combines rocket launcher ranged attacks with melee slash attacks. Defines all animation sequences, AI callbacks, combat logic, and the spawn entry point for this monster type.

## Core Responsibilities
- Register and cache all sound assets for the Chick monster on spawn
- Define frame-by-frame animation sequences (stand, walk, run, pain, death, attack, dodge)
- Implement ranged rocket attack with looping re-fire logic based on range/visibility
- Implement melee slash attack with looping re-slash logic at close range
- Handle pain response scaled to damage magnitude (3 pain animations)
- Handle death via gibbing threshold or one of two death animations
- Implement dodge behavior (ducking) to evade incoming projectiles

## Key Types / Data Structures
None (uses engine-defined `mframe_t`, `mmove_t`, `edict_t` from `g_local.h`/`m_chick.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `sound_missile_prelaunch` | `static int` | static | Sound index for rocket arm-up sound |
| `sound_missile_launch` | `static int` | static | Sound index for rocket fire sound |
| `sound_melee_swing` | `static int` | static | Sound index for melee swing |
| `sound_melee_hit` | `static int` | static | Sound index for melee hit |
| `sound_missile_reload` | `static int` | static | Sound index for rocket reload |
| `sound_death1/2` | `static int` | static | Death vocalization indices |
| `sound_fall_down` | `static int` | static | Fall sound (loaded but unused in code) |
| `sound_idle1/2` | `static int` | static | Idle vocalization indices |
| `sound_pain1/2/3` | `static int` | static | Pain vocalization indices |
| `sound_sight` | `static int` | static | Sight alert sound index |
| `sound_search` | `static int` | static | Search sound (loaded but unused in code) |

## Key Functions

### SP_monster_chick
- **Signature:** `void SP_monster_chick(edict_t *self)`
- **Purpose:** Spawn entry point; initializes all monster state, loads sounds and model, sets callbacks.
- **Inputs:** `self` — the entity being spawned
- **Outputs/Return:** void
- **Side effects:** Populates all `static int` sound globals; sets entity fields; calls `gi.linkentity`, `walkmonster_start`
- **Calls:** `gi.soundindex`, `gi.modelindex`, `gi.linkentity`, `walkmonster_start`, `G_FreeEdict`
- **Notes:** Immediately frees entity and returns in deathmatch mode. `sound_fall_down` and `sound_search` are registered but never triggered.

### ChickRocket
- **Signature:** `void ChickRocket(edict_t *self)`
- **Purpose:** Fires a rocket toward the enemy's head height from the correct muzzle flash offset.
- **Inputs:** `self` — the Chick entity
- **Outputs/Return:** void
- **Side effects:** Spawns a rocket projectile into the world
- **Calls:** `AngleVectors`, `G_ProjectSource`, `VectorCopy`, `VectorSubtract`, `VectorNormalize`, `monster_fire_rocket`
- **Notes:** Uses `MZ2_CHICK_ROCKET_1` flash offset; targets `enemy->viewheight` for accuracy.

### ChickSlash
- **Signature:** `void ChickSlash(edict_t *self)`
- **Purpose:** Executes a melee hit in front of the monster.
- **Inputs:** `self` — the Chick entity
- **Outputs/Return:** void
- **Side effects:** Plays swing sound; deals 10–15 damage with 100 knockback
- **Calls:** `gi.sound`, `fire_hit`
- **Notes:** Aim vector targets `MELEE_DISTANCE` forward at `mins[0]` horizontal offset, height 10.

### chick_rerocket
- **Signature:** `void chick_rerocket(edict_t *self)`
- **Purpose:** Decides whether to fire another rocket or transition to the end-attack sequence.
- **Inputs:** `self`
- **Outputs/Return:** void
- **Side effects:** Sets `currentmove`
- **Calls:** `range`, `visible`, `random`
- **Notes:** Re-fires if enemy alive, not in melee range, visible, and random ≤ 0.6; otherwise ends attack.

### chick_reslash
- **Signature:** `void chick_reslash(edict_t *self)`
- **Purpose:** Decides whether to slash again or end the melee sequence.
- **Inputs:** `self`
- **Outputs/Return:** void
- **Side effects:** Sets `currentmove`
- **Calls:** `range`, `random`
- **Notes:** Re-slashes if enemy alive, at melee range, and random ≤ 0.9.

### chick_pain
- **Signature:** `void chick_pain(edict_t *self, edict_t *other, float kick, int damage)`
- **Purpose:** Responds to damage with appropriate pain animation and sound; updates skin at half health.
- **Inputs:** `self`, attacker `other`, `kick`, `damage`
- **Side effects:** May alter `s.skinnum`, `pain_debounce_time`, `currentmove`
- **Notes:** Nightmare skill (3) skips animation entirely. Damage thresholds: ≤10→pain1, ≤25→pain2, else pain3.

### chick_die
- **Signature:** `void chick_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- **Purpose:** Handles death — either gibbing or one of two death animations.
- **Calls:** `ThrowGib`, `ThrowHead`, `gi.sound`
- **Notes:** Gib threshold is `gib_health` (−70). Randomly picks death1 or death2 animation.

### chick_dodge
- **Signature:** `void chick_dodge(edict_t *self, edict_t *attacker, float eta)`
- **Purpose:** 25% chance to initiate a duck sequence when a projectile is incoming.
- **Notes:** Sets enemy if not already set; uses a 7-frame duck animation with hold logic.

### chick_duck_down / chick_duck_hold / chick_duck_up
- Frame callbacks managing the duck state: shrink hitbox, hold until `pausetime`, restore hitbox and set `DAMAGE_AIM`.

## Control Flow Notes
- **Init:** `SP_monster_chick` → `walkmonster_start` enters the AI think loop.
- **Idle:** Cycles `chick_move_stand`; last frame calls `chick_fidget` (30% chance to switch to `chick_move_fidget` with a moan).
- **Combat:** Engine calls `monsterinfo.attack` → `chick_attack` (rocket) or `monsterinfo.melee` → `chick_melee` (slash). Each loops via `chick_rerocket`/`chick_reslash` until conditions fail.
- **Shutdown:** `chick_dead` disables thinking and switches to `MOVETYPE_TOSS` for physics-driven corpse.

## External Dependencies
- **Includes:** `g_local.h`, `m_chick.h`
- **Defined elsewhere:** `ai_stand`, `ai_run`, `ai_walk`, `ai_move`, `ai_charge`, `fire_hit`, `monster_fire_rocket`, `walkmonster_start`, `ThrowGib`, `ThrowHead`, `G_ProjectSource`, `range`, `visible`, `monster_flash_offset`, `skill`, `level`, `deathmatch`, `gi` (game import struct), all `FRAME_*` constants, `MODEL_SCALE`
