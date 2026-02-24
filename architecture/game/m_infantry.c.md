# game/m_infantry.c

## File Purpose
Implements the Infantry monster — a standard human soldier enemy in Quake 2. It handles all behavioral states (stand, walk, run, attack, dodge, pain, death) and fires a machine gun or delivers melee punches depending on range.

## Core Responsibilities
- Define all animation frame sequences for Infantry states
- Implement machine gun fire and melee punch attacks
- Handle pain response with skin damage indicator
- Implement ducking/dodge behavior against incoming projectiles
- Handle three distinct death animations, one of which fires the machine gun during the death sequence
- Spawn and initialize the Infantry entity via `SP_monster_infantry`

## Key Types / Data Structures
| Name | Kind | Purpose |
|---|---|---|
| `mframe_t` | struct (extern) | Single animation frame: AI function, distance, optional callback |
| `mmove_t` | struct (extern) | Animation sequence: frame range, frame array, end callback |
| `vec3_t aimangles[]` | array | Per-frame muzzle angle offsets used during death-spray firing |

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `sound_pain1/2` | `int` | static | Cached sound indices for pain vocalizations |
| `sound_die1/2` | `int` | static | Cached sound indices for death vocalizations |
| `sound_gunshot` | `int` | static | Cached gunshot sound index |
| `sound_weapon_cock` | `int` | static | Cached weapon cock sound index |
| `sound_punch_swing/hit` | `int` | static | Cached melee swing and impact sound indices |
| `sound_sight/search/idle` | `int` | static | Cached behavioral sound indices |
| `aimangles[]` | `vec3_t` | static (file-scope) | Angle offsets for death-spray bullet directions |

## Key Functions

### SP_monster_infantry
- Signature: `void SP_monster_infantry(edict_t *self)`
- Purpose: Spawns and fully initializes an Infantry entity.
- Inputs: `self` — the entity being spawned
- Outputs/Return: void
- Side effects: Registers all sound indices; sets model, bbox, health, mass, callbacks; calls `walkmonster_start`
- Calls: `gi.soundindex`, `gi.modelindex`, `VectorSet`, `gi.linkentity`, `walkmonster_start`, `G_FreeEdict`
- Notes: Immediately frees self and returns in deathmatch mode; sets `gib_health = -40`, `health = 100`

### InfantryMachineGun
- Signature: `void InfantryMachineGun(edict_t *self)`
- Purpose: Fires one machine gun bullet; handles both normal attack (frame `FRAME_attak111`) and death-spray modes (death2 animation frames).
- Inputs: `self`
- Outputs/Return: void
- Side effects: Calls `monster_fire_bullet`; reads `self->s.frame` to select flash number and aim direction
- Calls: `AngleVectors`, `G_ProjectSource`, `VectorMA`, `VectorSubtract`, `VectorNormalize`, `monster_fire_bullet`
- Notes: During death2, uses `aimangles[]` offset subtracted from entity angles to simulate a spraying sweep; `flash_number` indexes into `monster_flash_offset[]`

### infantry_pain
- Signature: `void infantry_pain(edict_t *self, edict_t *other, float kick, int damage)`
- Purpose: Triggers a pain animation and sound; switches skin to damaged variant at half health.
- Inputs: `self`, `other` (attacker), `kick`, `damage`
- Outputs/Return: void
- Side effects: Mutates `self->s.skinnum`, `self->pain_debounce_time`, `self->monsterinfo.currentmove`; emits sound
- Notes: Debounced by 3 seconds; no pain animations on skill 3 (nightmare)

### infantry_die
- Signature: `void infantry_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- Purpose: Handles death, including gibbing and selecting one of three death animations.
- Inputs: Standard die callback parameters
- Outputs/Return: void
- Side effects: May call `ThrowGib`/`ThrowHead`; sets `deadflag`, `takedamage`; assigns death move sequence
- Notes: Gib threshold at `gib_health`; death2 sequence fires machine gun on frames 11–22 as a post-death spray

### infantry_dodge
- Signature: `void infantry_dodge(edict_t *self, edict_t *attacker, float eta)`
- Purpose: Probabilistically initiates a duck/dodge sequence against incoming projectiles.
- Inputs: `self`, `attacker`, `eta` (time to impact, unused)
- Notes: 75% chance to ignore; assigns `attacker` as enemy if not set

### infantry_attack
- Signature: `void infantry_attack(edict_t *self)`
- Purpose: Selects machine gun (`attack1`) or melee punch (`attack2`) based on range.
- Calls: `range`

### infantry_duck_down / infantry_duck_hold / infantry_duck_up
- Three frame callbacks managing the duck state: shrink bbox, hold frame until `pausetime`, restore bbox and `takedamage`.

### infantry_fire / infantry_cock_gun
- Frame callbacks for `attack1`: `infantry_cock_gun` plays a sound and sets a random `pausetime`; `infantry_fire` calls `InfantryMachineGun` and holds the frame until `pausetime` expires.

## Control Flow Notes
- Lifecycle: `SP_monster_infantry` → `walkmonster_start` → idle/stand loop → transitions driven by AI callbacks (`ai_stand`, `ai_walk`, `ai_run`, `ai_charge`)
- Each `mmove_t` ends with a callback (e.g., pain sequences return to `infantry_run`; death sequences call `infantry_dead`)
- `infantry_dead` finalizes bbox, enables `MOVETYPE_TOSS`, marks `SVF_DEADMONSTER`, calls `M_FlyCheck`

## External Dependencies
- `g_local.h` — core game types, macros (`VectorSet`, `VectorMA`, etc.), entity/monster definitions
- `m_infantry.h` — frame constants (`FRAME_*`), `MODEL_SCALE`, `MZ2_INFANTRY_MACHINEGUN_*`
- External symbols: `ai_stand`, `ai_walk`, `ai_run`, `ai_move`, `ai_charge`, `monster_fire_bullet`, `fire_hit`, `G_ProjectSource`, `monster_flash_offset[]`, `M_FlyCheck`, `ThrowGib`, `ThrowHead`, `walkmonster_start`, `range`, `gi` (game import struct)
