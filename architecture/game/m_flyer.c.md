# game/m_flyer.c

## File Purpose
Implements the Flyer enemy — a small flying robot that attacks with blaster fire (ranged) and blade slashes (melee). Defines all animation sequences, AI state transitions, combat logic, pain/death responses, and the spawn function for `monster_flyer`.

## Core Responsibilities
- Define all animation frame sequences (stand, walk, run, start/stop, roll/bank, pain, attack, melee)
- Implement ranged blaster attack firing left/right cannons alternately
- Implement melee blade-slash attack with loop/check/end state machine
- Handle pain response with skin swap at half health and three randomized pain animations
- Handle death via explosion
- Register sounds and initialize entity fields in the spawn function
- Fix a known map bug in `jail5.bsp` at spawn time

## Key Types / Data Structures
None (uses engine-shared `mframe_t`, `mmove_t`, `edict_t` from `g_local.h`).

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `nextmove` | `static int` | file-static | Deferred move target used by start/stop transition animations |
| `sound_sight` | `static int` | file-static | Sound index for sight alert |
| `sound_idle` | `static int` | file-static | Sound index for idle search |
| `sound_pain1` | `static int` | file-static | Sound index for pain variant 1 |
| `sound_pain2` | `static int` | file-static | Sound index for pain variant 2 |
| `sound_slash` | `static int` | file-static | Sound index for blade slash |
| `sound_sproing` | `static int` | file-static | Sound index for blade deployment |
| `sound_die` | `static int` | file-static | Sound index for death |

## Key Functions

### flyer_fire
- **Signature:** `void flyer_fire(edict_t *self, int flash_number)`
- **Purpose:** Fires a blaster bolt from either the left or right cannon toward the enemy's eye height.
- **Inputs:** `self` — the flyer entity; `flash_number` — muzzle flash index (`MZ2_FLYER_BLASTER_1` or `_2`)
- **Outputs/Return:** void
- **Side effects:** Calls `monster_fire_blaster`; sets `EF_HYPERBLASTER` effect on specific attack frames
- **Calls:** `AngleVectors`, `G_ProjectSource`, `VectorCopy`, `VectorSubtract`, `monster_fire_blaster`
- **Notes:** Effect flag is applied only on frames `FRAME_attak204`, `207`, `210`.

### flyer_check_melee
- **Signature:** `void flyer_check_melee(edict_t *self)`
- **Purpose:** At end of each melee loop iteration, decides whether to continue looping or end melee based on range and 80% random chance.
- **Inputs:** `self`
- **Outputs/Return:** void
- **Side effects:** Sets `currentmove` to `loop_melee` or `end_melee`
- **Calls:** `range`, `random`
- **Notes:** Called as the end callback of `flyer_move_loop_melee`.

### flyer_pain
- **Signature:** `void flyer_pain(edict_t *self, edict_t *other, float kick, int damage)`
- **Purpose:** Handles pain response — debounced, skipped on Nightmare, randomly selects one of three pain animations.
- **Inputs:** `self`, `other` (attacker), `kick`, `damage`
- **Outputs/Return:** void
- **Side effects:** May swap skin to index 1 below half health; sets `currentmove`; plays pain sound
- **Calls:** `gi.sound`
- **Notes:** Debounce interval is 3 seconds; `n==2` reuses `sound_pain1`.

### flyer_die
- **Signature:** `void flyer_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- **Purpose:** Plays death sound and destroys the entity as an explosion.
- **Side effects:** Plays sound; calls `BecomeExplosion1` (removes entity, spawns gibs/explosion)
- **Calls:** `gi.sound`, `BecomeExplosion1`

### SP_monster_flyer
- **Signature:** `void SP_monster_flyer(edict_t *self)`
- **Purpose:** Spawn entry point — initializes all fields, registers sounds and model, applies jail5 map bug fix, and starts flying monster AI.
- **Inputs:** `self` — freshly allocated entity
- **Side effects:** Registers 8 sound indices, sets model/bbox/health/mass, assigns all AI callbacks, calls `flymonster_start`
- **Calls:** `G_FreeEdict`, `Q_stricmp`, `gi.soundindex`, `gi.modelindex`, `VectorSet`, `gi.linkentity`, `flymonster_start`
- **Notes:** Early-outs in deathmatch. `flymonster_start` (defined elsewhere) handles flying-specific monster initialization.

### Notes on minor functions
- `flyer_sight`, `flyer_idle`, `flyer_pop_blades` — single sound playback callbacks wired into frame tables or `monsterinfo`.
- `flyer_fireleft` / `flyer_fireright` — thin wrappers calling `flyer_fire` with the appropriate flash index; used as per-frame callbacks.
- `flyer_slash_left` / `flyer_slash_right` — call `fire_hit` with `MELEE_DISTANCE` aimed at the entity's min/max X extent; deal 5 damage.
- `flyer_run`, `flyer_walk`, `flyer_stand`, `flyer_start`, `flyer_stop`, `flyer_attack`, `flyer_melee`, `flyer_loop_melee`, `flyer_setstart`, `flyer_nextmove` — state-setter functions assigning `currentmove`; `flyer_nextmove` dispatches on the file-static `nextmove` variable.

## Control Flow Notes
- **Spawn:** `SP_monster_flyer` → `flymonster_start` → initial `currentmove = flyer_move_stand`
- **Per-frame:** Engine advances `currentmove` frames, calling per-frame AI functions (`ai_stand`, `ai_run`, `ai_charge`, `ai_move`) and optional callbacks
- **Combat:** Ranged attack goes directly to `flyer_move_attack2`; melee enters `flyer_move_start_melee` → loops via `flyer_move_loop_melee` → exits via `flyer_move_end_melee` → back to `flyer_run`
- **Pain/Death:** Interrupt current move; pain returns to `flyer_run` via `mmove_t` end callback; death calls `BecomeExplosion1`
- The `nextmove`/`flyer_start`/`flyer_stop` mechanism for deferred transitions appears partially stubbed (commented-out code in `flyer_melee`)

## External Dependencies
- `g_local.h` — core game types, AI functions (`ai_stand`, `ai_run`, `ai_charge`, `ai_move`, `ai_walk`), combat helpers
- `m_flyer.h` — frame constants (`FRAME_*`), `MODEL_SCALE`, `ACTION_*` defines
- **Defined elsewhere:** `visible`, `range`, `fire_hit`, `monster_fire_blaster`, `BecomeExplosion1`, `G_ProjectSource`, `monster_flash_offset`, `flymonster_start`, `gi` (game import struct)
