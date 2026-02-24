# game/m_boss32.c

## File Purpose
Implements the Makron, the final boss of Quake 2. Defines all animation sequences, attack logic, pain/death responses, and the spawn/precache entry points for `monster_makron`, including a secondary torso entity spawned on death.

## Core Responsibilities
- Define all Makron animation frame sets (stand, walk, run, pain, death, sight, attacks)
- Implement three attack modes: BFG, Hyperblaster burst, and Railgun
- Handle pain response with damage-threshold branching and nightmare-mode suppression
- Handle death: gibs at critical damage, or play full 95-frame death sequence with torso ejection
- Provide a custom `Makron_CheckAttack` that performs LOS tracing before committing to attack
- Spawn a decorative torso entity (`makron_torso`) that loops independently after death
- Support `MakronToss`/`MakronSpawn` for programmatic ejection from Jorg (boss31)

## Key Types / Data Structures
None unique to this file; uses engine-standard types.

| Name | Kind | Purpose |
|---|---|---|
| `mframe_t` | struct (defined elsewhere) | Single animation frame: AI function, distance, callback |
| `mmove_t` | struct (defined elsewhere) | Animation sequence: frame range, frame array, end callback |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `sound_pain4/5/6` | `static int` | static | Cached sound indices for three pain tiers |
| `sound_death` | `static int` | static | Cached death sound index |
| `sound_step_left/right` | `static int` | static | Footstep sounds |
| `sound_attack_bfg` | `static int` | static | BFG fire sound |
| `sound_brainsplorch` | `static int` | static | Brain splatter sound during death animation |
| `sound_prerailgun` | `static int` | static | Railgun charge-up sound |
| `sound_popup` | `static int` | static | Pop-up sound during pain6 animation |
| `sound_taunt1/2/3` | `static int` | static | Random taunt voice lines |
| `sound_hit` | `static int` | static | Impact sound |

## Key Functions

### SP_monster_makron
- Signature: `void SP_monster_makron (edict_t *self)`
- Purpose: Entity spawn point; initializes all Makron fields, hooks callbacks, starts AI.
- Inputs: `self` — the entity being spawned
- Outputs/Return: void
- Side effects: Calls `MakronPrecache`, sets `self->health = 3000`, `gib_health = -2000`, `mass = 500`, links entity, calls `walkmonster_start`.
- Calls: `MakronPrecache`, `gi.modelindex`, `gi.linkentity`, `walkmonster_start`, `G_FreeEdict` (deathmatch path)
- Notes: Immediately enters `makron_move_sight` rather than stand; no melee or dodge callbacks.

### MakronPrecache
- Signature: `void MakronPrecache (void)`
- Purpose: Registers all sounds and the torso model with the game server.
- Inputs: None
- Outputs/Return: void
- Side effects: Populates all 14 `static int sound_*` globals via `gi.soundindex`; calls `gi.modelindex` for the torso.
- Calls: `gi.soundindex`, `gi.modelindex`

### makron_die
- Signature: `void makron_die (edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- Purpose: Death handler; branches to gibbing or full death animation; spawns the torso entity.
- Inputs: Standard die callback parameters.
- Outputs/Return: void
- Side effects: May call `ThrowGib`/`ThrowHead`; spawns `tempent` via `G_Spawn` and calls `makron_torso`; sets `deadflag`, `takedamage`; starts `makron_move_death2`.
- Calls: `gi.sound`, `ThrowGib`, `ThrowHead`, `G_Spawn`, `makron_torso`
- Notes: Torso origin is offset by `–84` on Y axis before spawning.

### makron_dead
- Signature: `void makron_dead (edict_t *self)`
- Purpose: End-of-death-animation callback; sets final bounding box and physics state.
- Inputs: `self`
- Outputs/Return: void
- Side effects: Enlarges bbox to `(±60, ±60, 0–72)`, sets `MOVETYPE_TOSS`, adds `SVF_DEADMONSTER`, clears `nextthink`.
- Calls: `gi.linkentity`

### Makron_CheckAttack
- Signature: `qboolean Makron_CheckAttack (edict_t *self)`
- Purpose: Custom attack gating — traces LOS, determines range, and sets `attack_state` with range-weighted probability.
- Inputs: `self`
- Outputs/Return: `qboolean` — true if an attack should be initiated
- Side effects: Writes `self->ideal_yaw`, `self->monsterinfo.attack_state`, `self->monsterinfo.attack_finished`.
- Calls: `gi.trace`, `infront`, `range`, `vectoyaw`, `random`
- Notes: Returns false immediately if trace hits something other than the enemy; blocks far-range attacks entirely.

### MakronRailgun / MakronSaveloc
- Signature: `void MakronRailgun(edict_t*)` / `void MakronSaveloc(edict_t*)`
- Purpose: `MakronSaveloc` snapshots enemy position into `self->pos1` during wind-up; `MakronRailgun` fires at that saved location, compensating for enemy movement.
- Side effects: `MakronSaveloc` writes `self->pos1`; `MakronRailgun` calls `monster_fire_railgun`.
- Notes: FIXME comment acknowledges incorrect Z firing origin.

### MakronHyperblaster
- Signature: `void MakronHyperblaster (edict_t *self)`
- Purpose: Fires one blaster bolt per frame during `attack4`; sweeps yaw ±10° per frame around the enemy angle.
- Side effects: Calls `monster_fire_blaster`.
- Notes: FIXME comment — firing angles are acknowledged as incorrect.

### makronBFG
- Signature: `void makronBFG (edict_t *self)`
- Purpose: Fires a single BFG projectile toward the enemy's eye height.
- Side effects: `gi.sound`, `monster_fire_bfg`.

### MakronToss / MakronSpawn
- Purpose: `MakronToss` defers a `MakronSpawn` think by 0.8 s via a temporary entity; `MakronSpawn` calls `SP_monster_makron` then launches the Makron toward the nearest player with velocity `(dir*400, Z=200)`.
- Notes: Entry point called by Jorg (`m_boss31.c`) at end of its death sequence.

### makron_torso / makron_torso_think
- Purpose: Spawns a non-solid looping torso model (frames 346–364) as a visual remnant after death.
- Notes: Loops frame range indefinitely; plays `makron/spine.wav` as ambient entity sound.

## Control Flow Notes
Spawned via map entity (`SP_monster_makron`) or programmatically via `MakronToss` → `MakronSpawn`. On spawn, enters sight animation then transitions to `walkmonster_start`. Per-frame AI uses standard `ai_run`/`ai_stand`/`ai_charge`/`ai_move` with `Makron_CheckAttack` gating attacks. Death triggers either gibbing or a 95-frame sequence ending in `makron_dead`.

## External Dependencies
- `g_local.h`, `m_boss32.h` (frame constants, `MODEL_SCALE`, `MZ2_MAKRON_*` flash offsets)
- `visible`, `infront`, `range`, `vectoyaw`, `vectoangles` — defined in `g_utils.c`
- `monster_fire_bfg`, `monster_fire_railgun`, `monster_fire_blaster` — `g_monster.c` or `g_weapon.c`
- `G_ProjectSource`, `G_Spawn`, `G_FreeEdict`, `ThrowGib`, `ThrowHead`, `walkmonster_start` — defined elsewhere in game module
- `gi` (game import struct), `level`, `skill` — engine-provided globals
