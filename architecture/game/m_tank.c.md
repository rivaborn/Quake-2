# game/m_tank.c

## File Purpose
Implements the Tank and Tank Commander monsters for Quake 2. Defines all animation sequences, AI callbacks, attack behaviors (blaster, rocket, machinegun, melee strike), pain responses, and death handling for both variants, which share the same logic but differ in health and skin.

## Core Responsibilities
- Define all `mframe_t`/`mmove_t` animation sequences for stand, walk, run, pain, attack, and death states
- Implement three ranged attack modes: blaster burst, rocket salvo, and machinegun sweep
- Implement a melee strike attack used against dead/downed enemies
- Handle skill-level-dependent pain suppression and attack re-fire logic
- Spawn and initialize both `monster_tank` and `monster_tank_commander` entities
- Manage death: gib threshold dismemberment vs. normal death animation

## Key Types / Data Structures
None (uses engine types from `g_local.h` and `m_tank.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `sound_thud` | `int` | static | Cached sound index for death thud |
| `sound_pain` | `int` | static | Cached sound index for pain vocalisation |
| `sound_idle` | `int` | static | Cached sound index for idle vocalisation |
| `sound_die` | `int` | static | Cached sound index for death vocalisation |
| `sound_step` | `int` | static | Cached sound index for footstep |
| `sound_sight` | `int` | static | Cached sound index for sight alert |
| `sound_windup` | `int` | static | Cached sound index for strike wind-up |
| `sound_strike` | `int` | static | Cached sound index for melee strike impact |

## Key Functions

### SP_monster_tank
- Signature: `void SP_monster_tank(edict_t *self)`
- Purpose: Spawn entry point for both `monster_tank` and `monster_tank_commander`; sets geometry, health, mass, callbacks, and starts the walk-monster AI loop.
- Inputs: `self` — the entity being spawned
- Outputs/Return: void
- Side effects: Precaches model and all sound assets; sets entity fields; calls `walkmonster_start()`; conditionally sets `health=1000`/`skinnum=2` for commander variant
- Calls: `gi.modelindex`, `gi.soundindex`, `gi.linkentity`, `walkmonster_start`, `G_FreeEdict`, `strcmp`
- Notes: Removed in deathmatch. Commander differentiated purely by `classname` string comparison.

### tank_attack
- Signature: `void tank_attack(edict_t *self)`
- Purpose: Selects the attack mode based on range to enemy and a random roll; also triggers melee strike if enemy is already dead.
- Inputs: `self` — the Tank entity
- Outputs/Return: void
- Side effects: Sets `self->monsterinfo.currentmove`; sets `pain_debounce_time` when entering rocket sequence
- Calls: `VectorSubtract`, `VectorLength`, `random`
- Notes: Rocket attack only available at range > 250; melee strike (`tank_move_attack_strike`) selected exclusively when `enemy->health < 0`.

### TankBlaster
- Signature: `void TankBlaster(edict_t *self)`
- Purpose: Fires a blaster bolt at the enemy during the blast attack animation; flash number derived from current frame.
- Inputs: `self` — the Tank entity
- Outputs/Return: void
- Side effects: Spawns a blaster projectile via `monster_fire_blaster`
- Calls: `AngleVectors`, `G_ProjectSource`, `VectorCopy`, `VectorSubtract`, `monster_fire_blaster`
- Notes: Called on frames 110, 113, 116 (three shots per sequence).

### TankRocket
- Signature: `void TankRocket(edict_t *self)`
- Purpose: Fires a rocket at the enemy during the rocket attack animation.
- Inputs: `self` — the Tank entity
- Outputs/Return: void
- Side effects: Spawns a rocket projectile via `monster_fire_rocket`
- Calls: `AngleVectors`, `G_ProjectSource`, `VectorCopy`, `VectorSubtract`, `VectorNormalize`, `monster_fire_rocket`
- Notes: Called on frames 324, 327, 330 (three rockets per salvo).

### TankMachineGun
- Signature: `void TankMachineGun(edict_t *self)`
- Purpose: Fires a single machinegun bullet per frame during the chain attack; sweeps horizontally by offsetting yaw ±8° per frame relative to `FRAME_attak411`/`FRAME_attak419`.
- Inputs: `self` — the Tank entity
- Outputs/Return: void
- Side effects: Spawns a bullet via `monster_fire_bullet`
- Calls: `AngleVectors`, `G_ProjectSource`, `VectorCopy`, `VectorSubtract`, `vectoangles`, `monster_fire_bullet`
- Notes: Flash number computed from `MZ2_TANK_MACHINEGUN_1 + (frame - FRAME_attak406)`.

### tank_pain
- Signature: `void tank_pain(edict_t *self, edict_t *other, float kick, int damage)`
- Purpose: Handles pain response; selects pain animation by damage threshold; suppresses pain on hard/nightmare if currently in attack sequences.
- Inputs: `self`, `other` (attacker), `kick`, `damage`
- Outputs/Return: void
- Side effects: Sets `skinnum |= 1` when below half health; sets `pain_debounce_time`; sets `currentmove`
- Calls: `gi.sound`, `random`
- Notes: No pain animations in nightmare (`skill == 3`). Damage ≤10 always ignored.

### tank_run
- Signature: `void tank_run(edict_t *self)`
- Purpose: Selects run or start-run animation; sets `AI_BRUTAL` flag when chasing a player.
- Inputs: `self`
- Outputs/Return: void
- Side effects: Modifies `monsterinfo.aiflags` and `currentmove`
- Calls: None directly
- Notes: Falls back to `tank_move_stand` if `AI_STAND_GROUND` is active.

### tank_die
- Signature: `void tank_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- Purpose: Handles death; gibs the entity if below `gib_health`, otherwise starts the death animation.
- Inputs: Standard die callback parameters
- Outputs/Return: void
- Side effects: Throws gibs or sets `currentmove = &tank_move_death`; sets `deadflag = DEAD_DEAD`
- Calls: `gi.sound`, `gi.soundindex`, `ThrowGib`, `ThrowHead`, `gi.linkentity`
- Notes: Mix of organic and metallic gibs. Chest gib count `/* 4 */` is commented out to 1.

### tank_refire_rocket / tank_reattack_blaster
- Both are end-of-sequence callbacks that conditionally loop the fire animation on skill ≥ 2 with probability checks (0.4 and 0.6 respectively), otherwise transitioning to the post-attack cooldown sequence.

## Control Flow Notes
`SP_monster_tank` is called during map entity spawn. It calls `walkmonster_start()` which integrates the Tank into the per-frame monster think loop. Each frame, the AI dispatches through `monsterinfo.currentmove` frame tables, calling per-frame functions (`TankBlaster`, etc.) and transitioning states via end callbacks. `tank_attack` is the entry point for all combat decisions each time the AI decides to attack.

## External Dependencies
- `g_local.h` — entity types, AI functions (`ai_stand`, `ai_walk`, `ai_run`, `ai_charge`, `ai_move`), game imports (`gi`), utility macros
- `m_tank.h` — frame constants (`FRAME_*`), `MODEL_SCALE`
- Defined elsewhere: `monster_fire_blaster`, `monster_fire_rocket`, `monster_fire_bullet`, `monster_flash_offset`, `G_ProjectSource`, `AngleVectors`, `VectorNormalize`, `vectoangles`, `ThrowGib`, `ThrowHead`, `walkmonster_start`, `visible`, `skill`, `level`, `deathmatch`
