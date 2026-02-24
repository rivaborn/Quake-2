# game/m_flipper.c

## File Purpose
Implements the Flipper monster (an aquatic creature resembling a shark/dolphin) for Quake 2. It defines all animation sequences, AI callbacks, and the spawn function for `monster_flipper`.

## Core Responsibilities
- Register and cache all Flipper sound assets at spawn time
- Define animation frame sequences for stand, walk, run, attack, pain, and death states
- Implement melee bite attack using `fire_hit`
- Handle pain response with skin damage indicator and debounce logic
- Handle death with gibbing threshold and 56-frame death animation
- Register the entity via `swimmonster_start` as a swimming monster

## Key Types / Data Structures
| Name | Kind | Purpose |
|---|---|---|
| `mframe_t` | struct (external) | Single animation frame: AI function, distance, optional callback |
| `mmove_t` | struct (external) | Animation sequence: start frame, end frame, frame array, completion callback |

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `sound_chomp` | `static int` | static | Cached index for bite/attack sound |
| `sound_attack` | `static int` | static | Cached index for secondary attack sound (registered but unused in logic) |
| `sound_pain1` | `static int` | static | Cached index for pain sound variant 1 |
| `sound_pain2` | `static int` | static | Cached index for pain sound variant 2 |
| `sound_death` | `static int` | static | Cached index for death sound |
| `sound_idle` | `static int` | static | Cached index for idle sound (registered but unused in logic) |
| `sound_search` | `static int` | static | Cached index for search sound (registered but unused in logic) |
| `sound_sight` | `static int` | static | Cached index for sight/alert sound |

## Key Functions

### SP_monster_flipper
- **Signature:** `void SP_monster_flipper (edict_t *self)`
- **Purpose:** Spawns and initializes a Flipper entity; sets up all physics, model, health, and AI callbacks.
- **Inputs:** `self` — the entity being spawned
- **Outputs/Return:** void
- **Side effects:** Preloads 8 sounds via `gi.soundindex`; sets model, bbox, health, mass; calls `gi.linkentity`; calls `swimmonster_start`
- **Calls:** `G_FreeEdict`, `gi.soundindex`, `gi.modelindex`, `VectorSet`, `gi.linkentity`, `swimmonster_start`
- **Notes:** Immediately frees entity in deathmatch mode. `sound_attack`, `sound_idle`, and `sound_search` are registered but never triggered by any callback in this file.

### flipper_pain
- **Signature:** `void flipper_pain (edict_t *self, edict_t *other, float kick, int damage)`
- **Purpose:** Handles pain reaction: switches skin at half health, debounces, picks random pain animation.
- **Inputs:** `self`, `other` (attacker), `kick`, `damage`
- **Outputs/Return:** void
- **Side effects:** Mutates `self->s.skinnum`, `self->pain_debounce_time`, `self->monsterinfo.currentmove`; plays sound
- **Calls:** `gi.sound`, sets `currentmove` to `flipper_move_pain1` or `flipper_move_pain2`
- **Notes:** Nightmare skill (`skill->value == 3`) suppresses pain animations entirely. Both pain moves chain back to `flipper_run` on completion.

### flipper_die
- **Signature:** `void flipper_die (edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- **Purpose:** Handles death: gibs at threshold or plays 56-frame death animation.
- **Inputs:** Standard die callback parameters
- **Outputs/Return:** void
- **Side effects:** Spawns gib entities via `ThrowGib`/`ThrowHead`; plays sounds; sets `deadflag`, `takedamage`, `currentmove`
- **Calls:** `gi.sound`, `gi.soundindex`, `ThrowGib`, `ThrowHead`
- **Notes:** Gib check uses `gib_health` (-30). Double-death guard via `DEAD_DEAD` check.

### flipper_bite
- **Signature:** `void flipper_bite (edict_t *self)`
- **Purpose:** Executes a melee hit for 5 damage at `MELEE_DISTANCE` along the forward axis.
- **Inputs:** `self`
- **Outputs/Return:** void
- **Side effects:** May damage target entity via `fire_hit`
- **Calls:** `VectorSet`, `fire_hit`
- **Notes:** Called twice within the 20-frame attack sequence (frames 14 and 19).

### flipper_dead
- **Signature:** `void flipper_dead (edict_t *self)`
- **Purpose:** Finalizes death state — collapses bbox, sets physics to TOSS, marks as dead monster.
- **Inputs:** `self`
- **Outputs/Return:** void
- **Side effects:** Mutates bbox, `movetype`, `svflags`, `nextthink`; calls `gi.linkentity`

## Control Flow Notes
- **Init:** `SP_monster_flipper` → `swimmonster_start` (registers monster with game loop)
- **Frame:** AI callbacks (`ai_stand`, `ai_walk`, `ai_run`, `ai_charge`, `ai_move`) drive per-frame movement; `monsterinfo.currentmove` is the active state machine pointer
- **Run transition:** `flipper_run` → `flipper_move_run_start` (6 frames) → auto-chains to `flipper_move_run_loop` (24-frame loop)
- **Attack:** `flipper_melee` sets `flipper_move_attack`; `flipper_bite` fires on frames 14 and 19; sequence returns to `flipper_run`
- **Death:** `flipper_die` → `flipper_move_death` (56 frames) → `flipper_dead` callback

## External Dependencies
- `g_local.h` — core game types, entity structure, AI functions (`ai_stand`, `ai_walk`, `ai_run`, `ai_charge`, `ai_move`), `fire_hit`, `ThrowGib`, `ThrowHead`, `swimmonster_start`
- `m_flipper.h` — frame index constants (`FRAME_flp*`), `MODEL_SCALE`
- **Defined elsewhere:** `gi` (game import struct), `level`, `skill`, `deathmatch`, `MELEE_DISTANCE`, `VectorSet`, `G_FreeEdict`
