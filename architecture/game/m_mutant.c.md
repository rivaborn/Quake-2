# game/m_mutant.c

## File Purpose
Implements the Mutant monster AI for Quake 2, a fast melee/jump attacker. Defines all animation frame sequences, sound callbacks, combat logic (claw strikes and leaping attack), pain/death handling, and the spawn entry point.

## Core Responsibilities
- Precache and manage mutant-specific sound indices
- Define frame sequences for stand, idle, walk, run, melee attack, jump attack, pain, and death
- Implement melee hit detection (left/right claw strikes with randomized damage)
- Implement a physics-driven leap attack with touch callback for mid-air collision damage
- Handle pain response with skin switching at half health and nightmare-mode suppression
- Handle death with gibbing threshold and two randomized death animations
- Register all monster callbacks and spawn the entity via `SP_monster_mutant`

## Key Types / Data Structures
None (uses engine types from `g_local.h` and `m_mutant.h`).

| Name | Kind | Purpose |
|---|---|---|
| `mframe_t` | struct | Single animation frame: AI function, move distance, optional callback |
| `mmove_t` | struct | Animation sequence: start/end frame, frame array, terminal callback |
| `edict_t` | struct | Entity instance; mutant's state lives here |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `sound_swing` | `static int` | file-static | Cached sound index for swing/miss |
| `sound_hit` | `static int` | file-static | Cached index for left-claw hit |
| `sound_hit2` | `static int` | file-static | Cached index for right-claw hit |
| `sound_death` | `static int` | file-static | Cached index for death cry |
| `sound_idle` | `static int` | file-static | Cached index for idle vocalization |
| `sound_pain1/2` | `static int` | file-static | Cached pain sound indices |
| `sound_sight` | `static int` | file-static | Cached sight/alert sound; also reused on jump takeoff |
| `sound_search` | `static int` | file-static | Cached search sound |
| `sound_step1/2/3` | `static int` | file-static | Cached footstep sounds (randomly chosen) |
| `sound_thud` | `static int` | file-static | Cached landing impact sound |

## Key Functions

### mutant_hit_left / mutant_hit_right
- **Signature:** `void mutant_hit_left(edict_t *self)` / `void mutant_hit_right(edict_t *self)`
- **Purpose:** Execute a claw strike during melee animation frames; plays hit or swing sound based on contact.
- **Inputs:** `self` — the mutant entity
- **Outputs/Return:** void
- **Side effects:** Calls `fire_hit`; applies 10–14 damage, 100 knockback; plays sound on `CHAN_WEAPON`
- **Calls:** `fire_hit`, `gi.sound`, `VectorSet`
- **Notes:** Left claw aims toward `self->mins[0]`, right toward `self->maxs[0]`, both at height +8 and `MELEE_DISTANCE` forward.

### mutant_check_refire
- **Signature:** `void mutant_check_refire(edict_t *self)`
- **Purpose:** At the end of a melee combo, conditionally loops the attack back to frame 9 if enemy is alive and still in melee range (or nightmare difficulty with 50% chance).
- **Inputs:** `self`
- **Outputs/Return:** void
- **Side effects:** Sets `monsterinfo.nextframe`
- **Calls:** `range`
- **Notes:** Returns immediately if enemy is dead or freed.

### mutant_jump_touch
- **Signature:** `void mutant_jump_touch(edict_t *self, edict_t *other, cplane_t *plane, csurface_t *surf)`
- **Purpose:** Touch callback active during the leap; deals velocity-scaled damage on impact if speed > 400; transitions animation on landing.
- **Inputs:** `self`, `other` (entity struck), `plane`, `surf`
- **Outputs/Return:** void
- **Side effects:** Calls `T_Damage`; clears `self->touch`; sets `monsterinfo.nextframe`
- **Calls:** `VectorLength`, `T_Damage`, `VectorNormalize`, `VectorMA`, `M_CheckBottom`
- **Notes:** Damage = 40 + up to 10 random; uses `MOD_UNKNOWN`. Nulls `self->touch` on completion to prevent re-triggering.

### mutant_jump_takeoff
- **Signature:** `void mutant_jump_takeoff(edict_t *self)`
- **Purpose:** Launches the mutant into its leap: sets forward velocity (600), upward velocity (250), clears ground entity, sets `AI_DUCKED`, arms touch callback.
- **Side effects:** Modifies `self->velocity`, `self->groundentity`, `monsterinfo.aiflags`, `monsterinfo.attack_finished`, `self->touch`
- **Calls:** `gi.sound`, `AngleVectors`, `VectorScale`

### mutant_check_landing
- **Signature:** `void mutant_check_landing(edict_t *self)`
- **Purpose:** Per-frame callback during jump arc; detects landing via `groundentity`, plays thud, clears `AI_DUCKED`; or extends air time if timeout not reached.
- **Side effects:** Plays `sound_thud`; clears `AI_DUCKED`; modifies `monsterinfo.nextframe` and `attack_finished`
- **Calls:** `gi.sound`

### mutant_checkattack
- **Signature:** `qboolean mutant_checkattack(edict_t *self)`
- **Purpose:** Top-level attack decision: prefers melee if in range, otherwise evaluates jump eligibility.
- **Outputs/Return:** `true` if an attack was chosen
- **Side effects:** Sets `monsterinfo.attack_state` to `AS_MELEE` or `AS_MISSILE`
- **Calls:** `mutant_check_melee`, `mutant_check_jump`

### mutant_check_jump
- **Signature:** `qboolean mutant_check_jump(edict_t *self)`
- **Purpose:** Validates jump conditions: vertical alignment within 25–75% of enemy height, horizontal distance 100–open (90% rejection chance beyond 100 units).
- **Calls:** `VectorLength`
- **Notes:** Distance check has a quirk — both `< 100` and `> 100` branches are checked, making exactly 100 units also reject with 90% probability.

### mutant_pain
- **Signature:** `void mutant_pain(edict_t *self, edict_t *other, float kick, int damage)`
- **Purpose:** Applies pain animation; switches to damaged skin at half health; suppressed in nightmare mode and during debounce window.
- **Side effects:** Sets `self->s.skinnum`; sets `pain_debounce_time`; sets `currentmove`
- **Calls:** `gi.sound`, `random`

### mutant_die
- **Signature:** `void mutant_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- **Purpose:** Handles death: gibbing below `gib_health`, or plays death sound and selects one of two death animations.
- **Side effects:** Calls `ThrowGib`, `ThrowHead`; sets `deadflag`, `takedamage`, `skinnum`, `currentmove`
- **Calls:** `gi.sound`, `ThrowGib`, `ThrowHead`, `random`

### SP_monster_mutant
- **Signature:** `void SP_monster_mutant(edict_t *self)`
- **Purpose:** Spawn entry point; precaches all sounds, sets bbox/model/stats, assigns all monster callbacks, and starts walk-monster logic.
- **Side effects:** Precaches 13 sounds; sets entity fields; calls `walkmonster_start`
- **Calls:** `gi.soundindex`, `gi.modelindex`, `gi.linkentity`, `walkmonster_start`, `G_FreeEdict` (in deathmatch)
- **Notes:** Immediately frees the entity in deathmatch mode (mutant is singleplayer only). `MODEL_SCALE` is defined in `m_mutant.h`.

## Control Flow Notes
- `SP_monster_mutant` is the map-spawn entry point, called during level load.
- Per-frame AI is driven by the `monsterinfo.currentmove` animation table; AI functions (`ai_stand`, `ai_walk`, `ai_run`, `ai_charge`) are called each frame per `mframe_t`.
- Attack decision occurs via `mutant_checkattack` (registered as `monsterinfo.checkattack`), called by the monster AI think loop.
- Jump attack uses a physics touch callback (`mutant_jump_touch`) active only during the airborne phase, self-clearing on landing.

## External Dependencies
- **Includes:** `g_local.h` (entity/game types, AI functions), `m_mutant.h` (frame constants, `MODEL_SCALE`)
- **Defined elsewhere:** `fire_hit`, `T_Damage`, `ThrowGib`, `ThrowHead`, `M_FlyCheck`, `M_CheckBottom`, `walkmonster_start`, `range`, `ai_stand`, `ai_walk`, `ai_run`, `ai_charge`, `ai_move`, `gi` (game import interface), `level`, `skill`, `deathmatch`
