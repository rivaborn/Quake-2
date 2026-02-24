# game/m_float.c

## File Purpose
Implements the Floater enemy (a hovering robotic sphere) for Quake 2's single-player game. It defines all animation sequences, AI behavior callbacks, combat logic, and the spawn function used to instantiate the monster in a level.

## Core Responsibilities
- Define all animation frame tables (`mframe_t` arrays) and move sequences (`mmove_t`) for stand, walk, run, attack, pain, and death states
- Handle three distinct attack modes: blaster fire, claw melee (wham), and energy zap
- Manage pain response with skin-swap at half health and debounce timing
- Handle death by triggering an explosion rather than a ragdoll collapse
- Register all sound assets at spawn time
- Wire up `monsterinfo` function pointers and initialize entity physics/collision properties

## Key Types / Data Structures
None defined in this file; uses engine/game types from `g_local.h` and `m_float.h`.

| Name | Kind | Purpose |
|---|---|---|
| `mframe_t` | struct (external) | Single animation frame: AI function, move distance, optional callback |
| `mmove_t` | struct (external) | Animation sequence: start/end frame, frame array, completion callback |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `sound_attack2` | `static int` | file-static | Cached sound index for energy zap attack |
| `sound_attack3` | `static int` | file-static | Cached sound index for claw/wham attack |
| `sound_death1` | `static int` | file-static | Cached sound index for death |
| `sound_idle` | `static int` | file-static | Cached sound index for idle vocalisation |
| `sound_pain1` | `static int` | file-static | Cached sound index for pain variant 1 |
| `sound_pain2` | `static int` | file-static | Cached sound index for pain variant 2 |
| `sound_sight` | `static int` | file-static | Cached sound index for sight alert |

## Key Functions

### SP_monster_floater
- **Signature:** `void SP_monster_floater(edict_t *self)`
- **Purpose:** Spawns and fully initialises a Floater entity in the world.
- **Inputs:** `self` — the pre-allocated entity from the map spawn system.
- **Outputs/Return:** void; mutates `self` in place.
- **Side effects:** Calls `gi.soundindex`/`gi.modelindex` to precache assets; calls `gi.linkentity` and `flymonster_start` to register entity in the world.
- **Calls:** `G_FreeEdict`, `gi.soundindex`, `gi.modelindex`, `gi.linkentity`, `random`, `flymonster_start`
- **Notes:** No-ops in deathmatch. Randomly selects stand1 or stand2 as initial animation.

### floater_fire_blaster
- **Signature:** `void floater_fire_blaster(edict_t *self)`
- **Purpose:** Fires a blaster projectile toward the enemy's eye position; applies `EF_HYPERBLASTER` visual effect on specific frames.
- **Inputs:** `self` — the Floater entity.
- **Outputs/Return:** void.
- **Side effects:** Spawns a projectile via `monster_fire_blaster`.
- **Calls:** `AngleVectors`, `G_ProjectSource`, `VectorCopy`, `VectorSubtract`, `monster_fire_blaster`
- **Notes:** Effect flag is conditional on `FRAME_attak104` or `FRAME_attak107`.

### floater_wham
- **Signature:** `void floater_wham(edict_t *self)`
- **Purpose:** Executes a close-range claw strike dealing 5–10 damage with knockback.
- **Inputs:** `self` — the Floater entity.
- **Outputs/Return:** void.
- **Side effects:** Plays `sound_attack3`; calls `fire_hit` which applies damage.
- **Calls:** `gi.sound`, `fire_hit`

### floater_zap
- **Signature:** `void floater_zap(edict_t *self)`
- **Purpose:** Fires an energy zap directly at the enemy using a network-broadcast spark effect and applying 5–10 energy damage.
- **Inputs:** `self` — the Floater entity.
- **Outputs/Return:** void.
- **Side effects:** Writes `TE_SPLASH` temp-entity message via `gi.WriteByte/WritePosition/WriteDir/multicast`; calls `T_Damage`.
- **Calls:** `VectorSubtract`, `AngleVectors`, `VectorSet`, `G_ProjectSource`, `gi.sound`, `gi.WriteByte`, `gi.WritePosition`, `gi.WriteDir`, `gi.multicast`, `T_Damage`
- **Notes:** Contains two `//FIXME` comments noting the zap origin/flash is hardcoded rather than using `monster_flash_offset`.

### floater_pain
- **Signature:** `void floater_pain(edict_t *self, edict_t *other, float kick, int damage)`
- **Purpose:** Handles damage reaction: swaps to damaged skin at half health, selects a random pain animation, respects debounce and nightmare-mode skip.
- **Inputs:** `self`, `other` (unused), `kick`, `damage`.
- **Side effects:** Modifies `self->s.skinnum`, `self->pain_debounce_time`, `self->monsterinfo.currentmove`.
- **Calls:** `gi.sound`

### floater_die
- **Signature:** `void floater_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- **Purpose:** Triggers an explosion death effect instead of a death animation.
- **Side effects:** Plays death sound; calls `BecomeExplosion1` which removes the entity and spawns gibs/explosion.
- **Calls:** `gi.sound`, `BecomeExplosion1`

### floater_dead
- **Signature:** `void floater_dead(edict_t *self)`
- **Purpose:** End-of-death-sequence callback; resizes bounding box and marks entity as dead.
- **Notes:** In practice unreachable since `floater_die` calls `BecomeExplosion1`; likely legacy.

## Control Flow Notes
- `SP_monster_floater` is the map-spawn entry point; it calls `flymonster_start` which wires the entity into the frame-update loop.
- Each game frame, `monsterinfo.currentmove` drives per-frame AI calls (`ai_stand`, `ai_walk`, `ai_run`, `ai_charge`) and fires frame callbacks (`floater_fire_blaster`, `floater_wham`, `floater_zap`).
- `floater_run` is used as the completion callback for all attack and pain sequences, returning the monster to active pursuit.
- `floater_stand` randomly alternates between two 52-frame idle sequences.

## External Dependencies
- **Includes:** `g_local.h` (game entity types, AI functions, damage), `m_float.h` (frame number constants, `MODEL_SCALE`)
- **Defined elsewhere:** `ai_stand`, `ai_walk`, `ai_run`, `ai_charge`, `ai_move`, `monster_fire_blaster`, `fire_hit`, `T_Damage`, `BecomeExplosion1`, `flymonster_start`, `G_ProjectSource`, `monster_flash_offset`, `gi` (game import struct), `level`, `skill`, `deathmatch`
