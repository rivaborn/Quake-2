# game/m_brain.c

## File Purpose
Implements the "Brain" monster for Quake 2 — a melee-focused creature with a power armor screen defense and a secondary tentacle chest attack. Covers all behavioral states: stand, idle, walk, run, pain, dodge, melee, and death.

## Core Responsibilities
- Preloads all sound assets at spawn time via `gi.soundindex`
- Defines animation frame sequences (`mframe_t` arrays) for every monster state
- Implements two melee attack sequences: dual arm swings and a tentacle chest attack
- Manages power armor screen toggling during tentacle attack cycles
- Handles pain responses with three randomized animation variants
- Implements a dodge/duck behavior triggered probabilistically on incoming fire
- Handles gibbing and two death animations on entity death

## Key Types / Data Structures
None (uses engine types from `g_local.h` and `m_brain.h`).

| Name | Kind | Purpose |
|---|---|---|
| `mframe_t` | struct (defined elsewhere) | Per-frame AI function pointer + movement delta |
| `mmove_t` | struct (defined elsewhere) | Animation sequence: first/last frame, frame array, end callback |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `sound_chest_open` | `static int` | file-static | Sound index for chest opening |
| `sound_tentacles_extend` | `static int` | file-static | Sound index for tentacle extend |
| `sound_tentacles_retract` | `static int` | file-static | Sound index for tentacle retract |
| `sound_death` | `static int` | file-static | Sound index for death |
| `sound_idle1/2/3` | `static int` | file-static | Sound indices for idle vocalizations |
| `sound_pain1/2` | `static int` | file-static | Sound indices for pain reactions |
| `sound_sight` | `static int` | file-static | Sound index for sighting player |
| `sound_search` | `static int` | file-static | Sound index for searching |
| `sound_melee1/2/3` | `static int` | file-static | Sound indices for melee swing/hit |

## Key Functions

### SP_monster_brain
- **Signature:** `void SP_monster_brain(edict_t *self)`
- **Purpose:** Entity spawn function; initializes all Brain monster state.
- **Inputs:** `self` — the entity being spawned
- **Outputs/Return:** void
- **Side effects:** Loads 14 sound indices into file-static vars; sets `self` fields (model, bbox, health, mass, callbacks); calls `walkmonster_start`
- **Calls:** `gi.soundindex`, `gi.modelindex`, `VectorSet`, `gi.linkentity`, `walkmonster_start`, `G_FreeEdict`
- **Notes:** No-ops in deathmatch by freeing the entity immediately. Sets initial `power_armor_type = POWER_ARMOR_SCREEN` with 100 power.

### brain_melee
- **Signature:** `void brain_melee(edict_t *self)`
- **Purpose:** Randomly selects between the arm-swing attack (attack1) or tentacle chest attack (attack2).
- **Inputs:** `self`
- **Outputs/Return:** void
- **Side effects:** Sets `currentmove`
- **Calls:** `random`
- **Notes:** 50/50 split between sequences.

### brain_tentacle_attack
- **Signature:** `void brain_tentacle_attack(edict_t *self)`
- **Purpose:** Fires the tentacle hit; on success at skill > 0, sets a spawnflag to trigger follow-up arm attack.
- **Inputs:** `self`
- **Outputs/Return:** void
- **Side effects:** Calls `fire_hit`; conditionally sets `spawnflags |= 65536`; plays retract sound
- **Calls:** `fire_hit`, `gi.sound`
- **Notes:** Uses magic number `65536` as an internal state flag (not a standard spawn flag).

### brain_chest_open / brain_chest_closed
- **Signature:** `void brain_chest_open(edict_t *self)` / `void brain_chest_closed(edict_t *self)`
- **Purpose:** Toggle the power armor screen off during tentacle exposure, then restore it; optionally chains to attack1 if the tentacle hit landed.
- **Side effects:** Mutates `power_armor_type`, `spawnflags`, `currentmove`
- **Calls:** `gi.sound`

### brain_dodge
- **Signature:** `void brain_dodge(edict_t *self, edict_t *attacker, float eta)`
- **Purpose:** 25% chance to initiate a duck animation when targeted by a projectile.
- **Side effects:** Sets `enemy`, `pausetime`, `currentmove`
- **Notes:** `eta` is the projectile time-to-impact; duck hold duration = `eta + 0.5`.

### brain_duck_down / brain_duck_hold / brain_duck_up
- **Purpose:** Per-frame callbacks that shrink the bbox on duck, hold via `AI_HOLD_FRAME` until `pausetime`, then restore.
- **Side effects:** Mutates `maxs[2]`, `takedamage`, `aiflags`; calls `gi.linkentity`

### brain_pain
- **Signature:** `void brain_pain(edict_t *self, edict_t *other, float kick, int damage)`
- **Purpose:** Selects one of three pain animations; switches skin to damaged variant below half health.
- **Notes:** Debounced to 3 seconds. Skipped entirely on skill 3 (nightmare).

### brain_die
- **Signature:** `void brain_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- **Purpose:** Handles death: gib explosion below `gib_health`, otherwise plays death animation.
- **Calls:** `ThrowGib`, `ThrowHead`, `gi.sound`, `random`

### brain_dead
- **Signature:** `void brain_dead(edict_t *self)`
- **Purpose:** End-of-death-animation callback; collapses bbox and marks as dead monster.
- **Side effects:** Sets `mins`, `maxs`, `movetype`, `svflags`, `nextthink`; calls `gi.linkentity`

## Control Flow Notes
`SP_monster_brain` is the map-entity entry point. `walkmonster_start` drives the think loop. Each frame the AI calls into the active `currentmove` sequence; frame callbacks transition state. `brain_run` is the universal post-sequence fallback (referenced as end callback in all pain/attack/duck sequences). Power armor screen is active during run/stand; disabled only during the tentacle window.

## External Dependencies
- **Includes:** `g_local.h`, `m_brain.h`
- **Defined elsewhere:** `ai_stand`, `ai_walk`, `ai_run`, `ai_charge`, `ai_move`, `fire_hit`, `ThrowGib`, `ThrowHead`, `walkmonster_start`, `G_FreeEdict`, `gi` (game import struct), `level`, `skill`, `FRAME_*` constants (from `m_brain.h`), `MELEE_DISTANCE`, `MODEL_SCALE`
