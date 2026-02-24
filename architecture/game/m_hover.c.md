# game/m_hover.c

## File Purpose
Implements the Hover monster — a flying robot enemy that attacks with blaster fire. Defines all animation frame sequences, AI behavior callbacks, pain/death handling, and the spawn function for the `monster_hover` entity.

## Core Responsibilities
- Define all animation frame tables (`mframe_t`) and move sequences (`mmove_t`) for stand, walk, run, attack, pain, death, and transition states
- Handle blaster fire logic with per-frame effect selection and enemy targeting
- Manage pain response with damage-threshold branching and skin swap at low health
- Handle death with gibbing check, corpse physics (toss + delayed explosion), and `hover_deadthink` fallback
- Implement reattack logic with visibility and probability gating
- Register sounds and initialize entity fields in the spawn function

## Key Types / Data Structures
None (uses engine types from `g_local.h` and `m_hover.h`).

| Name | Kind | Purpose |
|------|------|---------|
| `mframe_t` | struct (external) | Single animation frame: AI function, move distance, callback |
| `mmove_t` | struct (external) | Animation sequence: frame range, frame array, end callback |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `sound_pain1` | `int` | static | Cached sound index for pain sound 1 |
| `sound_pain2` | `int` | static | Cached sound index for pain sound 2 |
| `sound_death1` | `int` | static | Cached sound index for death sound 1 |
| `sound_death2` | `int` | static | Cached sound index for death sound 2 |
| `sound_sight` | `int` | static | Cached sound index for sight alert |
| `sound_search1` | `int` | static | Cached sound index for search sound 1 |
| `sound_search2` | `int` | static | Cached sound index for search sound 2 |

## Key Functions

### hover_fire_blaster
- **Signature:** `void hover_fire_blaster(edict_t *self)`
- **Purpose:** Fires a blaster bolt toward the enemy's eye level from the Hover's gun offset.
- **Inputs:** `self` — the Hover entity
- **Outputs/Return:** None
- **Side effects:** Spawns a projectile via `monster_fire_blaster`; applies `EF_HYPERBLASTER` effect on first attack frame only
- **Calls:** `AngleVectors`, `G_ProjectSource`, `VectorCopy`, `VectorSubtract`, `monster_fire_blaster`
- **Notes:** Uses `monster_flash_offset[MZ2_HOVER_BLASTER_1]` for muzzle positioning; targets `enemy->viewheight`

### hover_reattack
- **Signature:** `void hover_reattack(edict_t *self)`
- **Purpose:** Decides after each attack cycle whether to continue attacking or end the attack sequence.
- **Inputs:** `self` — the Hover entity
- **Outputs/Return:** None
- **Side effects:** Sets `currentmove` to `hover_move_attack1` or `hover_move_end_attack`
- **Calls:** `visible`, `random`
- **Notes:** Reattacks only if enemy is alive, visible, and random roll ≤ 0.6

### hover_pain
- **Signature:** `void hover_pain(edict_t *self, edict_t *other, float kick, int damage)`
- **Purpose:** Responds to damage with sound and pain animation; swaps skin at half health.
- **Inputs:** `self`, `other`, `kick`, `damage`
- **Outputs/Return:** None
- **Side effects:** Modifies `s.skinnum`, `pain_debounce_time`, `currentmove`; plays sound
- **Calls:** `gi.sound`, `random`
- **Notes:** Debounced to 3 seconds; suppressed entirely on skill level 3 (nightmare)

### hover_deadthink
- **Signature:** `void hover_deadthink(edict_t *self)`
- **Purpose:** Delays the final explosion until the corpse touches the ground or a 15-second timeout expires.
- **Inputs:** `self` — the dead Hover entity
- **Outputs/Return:** None
- **Side effects:** Reschedules `nextthink` or calls `BecomeExplosion1`
- **Calls:** `BecomeExplosion1`
- **Notes:** Uses `self->timestamp` set in `hover_dead` as the fallback deadline

### hover_dead
- **Signature:** `void hover_dead(edict_t *self)`
- **Purpose:** Transitions the corpse to physics-driven toss mode and arms the deadthink timer.
- **Inputs:** `self`
- **Outputs/Return:** None
- **Side effects:** Resizes bbox, sets `MOVETYPE_TOSS`, assigns `hover_deadthink`, calls `gi.linkentity`
- **Calls:** `VectorSet`, `gi.linkentity`

### hover_die
- **Signature:** `void hover_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- **Purpose:** Handles death: gib check triggers instant disintegration; otherwise plays death animation.
- **Inputs:** Standard die callback parameters
- **Outputs/Return:** None
- **Side effects:** May spawn gibs via `ThrowGib`/`ThrowHead`, plays sound, sets `deadflag`, sets `currentmove`
- **Calls:** `gi.sound`, `gi.soundindex`, `ThrowGib`, `ThrowHead`, `random`
- **Notes:** Gib threshold is `-100`; guards against double-death with `DEAD_DEAD` check

### SP_monster_hover
- **Signature:** `void SP_monster_hover(edict_t *self)`
- **Purpose:** Spawn function; initializes all entity fields, caches sounds, and starts fly-monster AI.
- **Inputs:** `self` — freshly spawned entity
- **Outputs/Return:** None
- **Side effects:** Frees entity in deathmatch; sets model, bbox, health, callbacks, links entity, calls `flymonster_start`
- **Calls:** `G_FreeEdict`, `gi.soundindex`, `gi.modelindex`, `VectorSet`, `gi.linkentity`, `flymonster_start`
- **Notes:** Dodge callback is commented out; idle sound assigned to `self->s.sound` for continuous ambient loop

## Control Flow Notes
Integrated into the standard monster lifecycle: `SP_monster_hover` → `flymonster_start` registers the entity with the AI system. Per-frame updates drive animation via `currentmove`; attack sequencing flows `hover_start_attack` → `hover_attack` → `hover_move_attack1` (with `hover_reattack` looping or exiting) → `hover_move_end_attack` → `hover_run`. Death routes through `hover_die` → `hover_dead` → `hover_deadthink` → `BecomeExplosion1`.

## External Dependencies
- `g_local.h` — core game types, AI functions (`ai_stand`, `ai_run`, `ai_walk`, `ai_move`, `ai_charge`), entity fields
- `m_hover.h` — `FRAME_*` constants, `MODEL_SCALE`
- External symbols: `visible`, `flymonster_start`, `BecomeExplosion1`, `ThrowGib`, `ThrowHead`, `G_ProjectSource`, `monster_fire_blaster`, `monster_flash_offset`, `AngleVectors`, `gi` (game import struct)
