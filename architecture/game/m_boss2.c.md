# game/m_boss2.c

## File Purpose
Implements the Boss2 monster ("Hover Boss"), a large flying boss enemy that attacks with dual miniguns and quad-rocket salvos. It manages all animation states, attack logic, pain/death responses, and spawn initialization for this entity.

## Core Responsibilities
- Define animation frame sequences (stand, fidget, walk, run, attack phases, pain, death)
- Fire dual simultaneous bullets (left/right hardpoints) or 4-rocket salvos at the enemy
- Select attack type (machinegun vs rocket) based on range and probability
- Handle pain reactions with damage-threshold branching and skin swap at half health
- Implement a custom `CheckAttack` override with LOS tracing and high per-range attack probabilities
- Manage death sequence culminating in `BossExplode` and dead-state bounding box resize
- Spawn initialization: set stats, bind callbacks, invoke `flymonster_start`

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `mframe_t` | struct (external) | Single animation frame: AI function, distance, optional callback |
| `mmove_t` | struct (external) | Animation sequence: frame range, frame array, end callback |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `sound_pain1` | `static int` | static | Cached sound index for pain variant 1 |
| `sound_pain2` | `static int` | static | Cached sound index for pain variant 2 |
| `sound_pain3` | `static int` | static | Cached sound index for pain variant 3 |
| `sound_death` | `static int` | static | Cached sound index for death |
| `sound_search1` | `static int` | static | Cached sound index for idle search vocalization |

## Key Functions

### Boss2Rocket
- **Signature:** `void Boss2Rocket (edict_t *self)`
- **Purpose:** Fires 4 rockets simultaneously from 4 distinct hardpoints toward the enemy's view height.
- **Inputs:** `self` — the boss entity with a valid `self->enemy`
- **Outputs/Return:** void
- **Side effects:** Spawns 4 rocket projectiles via `monster_fire_rocket`; each deals 50 damage at speed 500
- **Calls:** `AngleVectors`, `G_ProjectSource`, `VectorCopy`, `VectorSubtract`, `VectorNormalize`, `monster_fire_rocket`
- **Notes:** Flash offsets `MZ2_BOSS2_ROCKET_1..4` used; each rocket independently targets enemy viewheight position

### boss2_firebullet_right / boss2_firebullet_left
- **Signature:** `void boss2_firebullet_right/left (edict_t *self)`
- **Purpose:** Fire a single bullet from the right or left gun hardpoint with lead-compensation (`VectorMA` with `-0.2` velocity factor).
- **Side effects:** Calls `monster_fire_bullet` (6 dmg, spread 4)
- **Notes:** Both called together by `Boss2MachineGun` each frame tick; effectively doubles bullet output

### Boss2MachineGun
- **Signature:** `void Boss2MachineGun (edict_t *self)`
- **Purpose:** Per-frame MG attack callback; fires both left and right guns simultaneously.
- **Notes:** Original single-gun implementation is commented out in favor of the dual-gun approach

### boss2_attack
- **Signature:** `void boss2_attack (edict_t *self)`
- **Purpose:** Chooses between machinegun pre-sequence and rocket attack based on range.
- **Inputs:** `self->enemy` distance computed via `VectorSubtract/VectorLength`
- **Side effects:** Sets `self->monsterinfo.currentmove`
- **Notes:** ≤125 units → always MG; otherwise 60% MG / 40% rocket

### boss2_reattack_mg
- **Signature:** `void boss2_reattack_mg (edict_t *self)`
- **Purpose:** End-of-MG-loop decision: 70% chance to continue MG if enemy is in front, else transitions to post-MG cooldown.
- **Calls:** `infront`

### boss2_pain
- **Signature:** `void boss2_pain (edict_t *self, edict_t *other, float kick, int damage)`
- **Purpose:** Handles pain reaction with 3-second debounce; swaps skin at half health; plays one of three pain sounds based on damage threshold.
- **Side effects:** May set `self->s.skinnum = 1`; sets `currentmove` to light or heavy pain sequence

### Boss2_CheckAttack
- **Signature:** `qboolean Boss2_CheckAttack (edict_t *self)`
- **Purpose:** Custom attack eligibility check; performs LOS trace and uses elevated 80% attack probability for melee/near/mid range.
- **Calls:** `gi.trace`, `infront`, `range`, `vectoyaw`, `random`
- **Notes:** Overrides default `M_CheckAttack`; returns false on blocked LOS or `RANGE_FAR`

### boss2_die
- **Signature:** `void boss2_die (edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- **Purpose:** Initiates death sequence: plays death sound, disables damage, starts death animation ending in `BossExplode` + `boss2_dead`.
- **Notes:** Gibbing code is present but `#if 0`-disabled

### SP_monster_boss2
- **Signature:** `void SP_monster_boss2 (edict_t *self)`
- **Purpose:** Entity spawn function; no-ops in deathmatch, precaches sounds, sets bounding box, stats (2000 HP, 1000 mass), laser immunity, registers all callbacks, calls `flymonster_start`.
- **Side effects:** Allocates sound/model indices; links entity; sets `currentmove` to stand

## Control Flow Notes
- **Init:** `SP_monster_boss2` → `flymonster_start` registers entity in the world.
- **Frame update:** `monsterinfo.currentmove` drives per-frame AI and fire callbacks through the engine's monster think loop.
- **Attack:** `Boss2_CheckAttack` → `boss2_attack` → pre-MG or rocket sequence → `boss2_reattack_mg` loops or exits.
- **Death:** `boss2_die` → `boss2_move_death` (49 frames) → `BossExplode` on frame 49 → `boss2_dead` sets final dead-state bbox.

## External Dependencies
- `g_local.h` — core game types, entity structure, helper macros
- `m_boss2.h` — `FRAME_*` constants, `MODEL_SCALE`, `MZ2_BOSS2_*` flash indices
- **Defined elsewhere:** `BossExplode`, `infront`, `flymonster_start`, `monster_fire_rocket`, `monster_fire_bullet`, `G_ProjectSource`, `monster_flash_offset`, `ai_stand`, `ai_walk`, `ai_run`, `ai_charge`, `ai_move`, `range`, `vectoyaw`
