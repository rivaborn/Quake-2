# game/m_soldier.c

## File Purpose
Implements the Soldier enemy monster in three variants (Light/Blaster, Shotgun, and Super Shotgun/Machinegun), sharing a common skeleton of animation frames, AI callbacks, and weapon-fire logic distinguished entirely by `s.skinnum`.

## Core Responsibilities
- Define all animation frame sequences (stand, walk, run, pain, attack, duck, death) as `mframe_t`/`mmove_t` tables
- Dispatch weapon fire (blaster, shotgun, or bullet) based on `s.skinnum` in `soldier_fire`
- Handle pain response with debounce, skin switching to wounded appearance, and skill-gated animation suppression
- Implement dodge behavior: skill-scaled probability of duck vs. counter-attack
- Handle death with gib detection, head-shot recognition, and randomized death animations (6 variants)
- Register sound assets and wire AI callbacks during spawn via `SP_monster_soldier_x` and three variant spawn functions

## Key Types / Data Structures
None (uses engine types from `g_local.h` and `m_soldier.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `sound_idle` | `int` | static | Cached sound index for idle vocalisation |
| `sound_sight1/2` | `int` | static | Cached indices for two sight alert sounds |
| `sound_pain_light/pain/pain_ss` | `int` | static | Per-variant pain sounds |
| `sound_death_light/death/death_ss` | `int` | static | Per-variant death sounds |
| `sound_cock` | `int` | static | Weapon cock sound |
| `blaster_flash[]` | `int[8]` | static | Muzzle flash indices for blaster variant |
| `shotgun_flash[]` | `int[8]` | static | Muzzle flash indices for shotgun variant |
| `machinegun_flash[]` | `int[8]` | static | Muzzle flash indices for machinegun variant |

## Key Functions

### soldier_fire
- Signature: `void soldier_fire(edict_t *self, int flash_number)`
- Purpose: Central fire dispatcher; selects weapon type and muzzle offset from `s.skinnum`, computes aim with randomised spread, fires the appropriate projectile.
- Inputs: `self` — firing soldier; `flash_number` — index into flash offset arrays (0–7)
- Outputs/Return: void
- Side effects: Calls `monster_fire_blaster`, `monster_fire_shotgun`, or `monster_fire_bullet`; sets `AI_HOLD_FRAME` and `pausetime` for machinegun burst timing
- Calls: `AngleVectors`, `G_ProjectSource`, `VectorCopy/Subtract/MA/Normalize`, `vectoangles`, `crandom`, `monster_fire_blaster`, `monster_fire_shotgun`, `monster_fire_bullet`
- Notes: `flash_number` 5 and 6 fire directly forward (used in death-sequence shots); machinegun variant uses `AI_HOLD_FRAME` to maintain burst until `pausetime` expires.

### soldier_pain
- Signature: `void soldier_pain(edict_t *self, edict_t *other, float kick, int damage)`
- Purpose: Responds to damage: switches skin to wounded (odd skinnum), debounces repeat pain, selects pain animation based on skill and random roll.
- Inputs: `self`, `other` (unused), `kick` (unused), `damage` (unused)
- Outputs/Return: void
- Side effects: Modifies `s.skinnum`, `pain_debounce_time`, `monsterinfo.currentmove`
- Calls: `gi.sound`, `random`
- Notes: Skill 3 (Nightmare) suppresses all pain animations after debounce. Vertical velocity > 100 forces `pain4` (knockback stagger).

### soldier_dodge
- Signature: `void soldier_dodge(edict_t *self, edict_t *attacker, float eta)`
- Purpose: Skill-scaled evasion: lower skill biases toward passive duck; higher skill biases toward counter-attack3 (duck-and-shoot).
- Inputs: `self`, `attacker`, `eta` — time until incoming projectile arrives
- Outputs/Return: void
- Side effects: Sets `self->enemy`, `monsterinfo.pausetime`, `monsterinfo.currentmove`
- Calls: `random`
- Notes: 75% chance (r > 0.25) to ignore dodge entirely regardless of skill.

### soldier_die
- Signature: `void soldier_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- Purpose: Handles death: gib below threshold, otherwise pick death animation. Head-shot detection forces `death3`.
- Inputs: Standard die callback params; `point` — damage impact location
- Outputs/Return: void
- Side effects: May call `ThrowGib`/`ThrowHead`, sets `deadflag`, `takedamage`, `s.skinnum`, `currentmove`
- Calls: `gi.sound`, `ThrowGib`, `ThrowHead`, `fabs`, `rand`
- Notes: `death1` contains frames that fire `soldier_fire6/7` (dying shots). Death animation 3 is head-shot-specific and not reachable via the random `n` roll.

### SP_monster_soldier_x
- Signature: `void SP_monster_soldier_x(edict_t *self)`
- Purpose: Shared base initialisation for all three soldier variants: model, bounds, sounds, AI callbacks, then kicks off `walkmonster_start`.
- Inputs: `self` — newly spawned entity
- Outputs/Return: void
- Side effects: Registers model/sound assets, sets entity fields, calls `walkmonster_start`
- Calls: `gi.modelindex`, `gi.soundindex`, `gi.linkentity`, `walkmonster_start`
- Notes: Variant-specific skin, health, gib threshold, and per-variant sounds are applied by the calling `SP_monster_soldier_*` after this returns.

### soldier_stand / soldier_walk / soldier_run
- `soldier_stand`: randomly alternates between `stand1` (idle) and `stand3` (weapon-cock), biased 80% toward `stand1` unless already in `stand3`.
- `soldier_walk`: 50/50 between two walk cycles.
- `soldier_run`: transitions through `start_run` before entering the full `run` loop; falls back to `stand1` if `AI_STAND_GROUND`.

## Control Flow Notes
Lifecycle follows standard Quake 2 monster pattern: `SP_monster_soldier_*` → `SP_monster_soldier_x` → `walkmonster_start` → per-frame AI tick drives `currentmove`. Animation callbacks (`soldier_fire*`, `soldier_duck_down/up`, `soldier_cock`) fire mid-sequence at designated frames. Pain and death interrupt `currentmove` immediately. Dodge is invoked externally by the engine when a projectile is detected inbound.

## External Dependencies
- Notable includes: `g_local.h`, `m_soldier.h` (frame constants, `MODEL_SCALE`)
- External symbols used but not defined here: `ai_stand`, `ai_walk`, `ai_run`, `ai_charge`, `ai_move`, `walkmonster_start`, `monster_fire_blaster`, `monster_fire_shotgun`, `monster_fire_bullet`, `G_ProjectSource`, `monster_flash_offset`, `AngleVectors`, `vectoangles`, `ThrowGib`, `ThrowHead`, `range`, `skill`, `level`, `deathmatch`, `G_FreeEdict`, `gi` (game import struct)
