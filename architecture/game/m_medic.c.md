# game/m_medic.c

## File Purpose
Implements the Medic monster, a unique enemy that can both fight players with a blaster/hyperblaster and resurrect dead allied monsters via a cable-hook attack. It is one of the few monsters with active ally-restoration behavior built into its AI.

## Core Responsibilities
- Search for and target dead monsters within a 1024-unit radius for resurrection
- Execute three distinct attack modes: blaster, hyperblaster, and cable-hook healing
- Manage the `AI_MEDIC` flag to switch between combat and resurrection behavior
- Revive dead monsters via `ED_CallSpawn`, re-linking them to fight players
- Handle pain, death, gibbing, and dodging animations
- Register all sounds and set up entity fields in the spawn function

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `mframe_t` | struct (extern) | Single animation frame: AI func, move dist, callback |
| `mmove_t` | struct (extern) | Animation sequence: start frame, end frame, frame array, end callback |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `sound_idle1` | `int` | static | Precached sound index for idle audio |
| `sound_pain1/2` | `int` | static | Precached pain sounds |
| `sound_die` | `int` | static | Precached death sound |
| `sound_sight` | `int` | static | Precached sight sound |
| `sound_search` | `int` | static | Precached search sound |
| `sound_hook_launch/hit/heal/retract` | `int` | static | Precached cable hook sound stages |
| `medic_cable_offsets` | `vec3_t[10]` | static | Per-frame muzzle offsets for cable beam origin |

## Key Functions

### medic_FindDeadMonster
- Signature: `edict_t *medic_FindDeadMonster(edict_t *self)`
- Purpose: Scans within 1024 units for dead, unowned, non-good-guy monsters with no pending `nextthink`, preferring the highest `max_health` candidate.
- Inputs: `self` — the medic entity
- Outputs/Return: Best candidate dead monster, or `NULL`
- Side effects: None
- Calls: `findradius`, `visible`
- Notes: Skips entities with `owner` set (already claimed by another medic) and those still thinking (mid-death animation).

### medic_cable_attack
- Signature: `void medic_cable_attack(edict_t *self)`
- Purpose: Per-frame handler for the healing cable; validates range/pitch/LOS, triggers hit/heal/resurrect sounds at specific frames, and at `FRAME_attack50` calls `ED_CallSpawn` to fully re-initialize the dead monster.
- Inputs: `self` — medic entity; `self->enemy` — target dead monster
- Outputs/Return: void
- Side effects: Mutates `self->enemy` fields (spawnflags, aiflags, targets, owner). Fires `TE_MEDIC_CABLE_ATTACK` temp entity via `gi.multicast`. Calls `FoundTarget` on the revived monster. Plays hook sounds.
- Calls: `AngleVectors`, `G_ProjectSource`, `VectorSubtract`, `VectorLength`, `vectoangles`, `gi.trace`, `gi.sound`, `ED_CallSpawn`, `FoundTarget`, `gi.WriteByte`, `gi.WriteShort`, `gi.WritePosition`, `gi.multicast`
- Notes: Distance cap is 256 units; pitch cap is ±45°. Resurrection only fires on `FRAME_attack50` — earlier frames just draw the beam and play audio.

### medic_attack
- Signature: `void medic_attack(edict_t *self)`
- Purpose: Selects cable-hook move if in medic mode (`AI_MEDIC`), else blaster move.
- Inputs: `self`
- Outputs/Return: void
- Side effects: Sets `self->monsterinfo.currentmove`
- Calls: None (sets move pointers)

### medic_checkattack
- Signature: `qboolean medic_checkattack(edict_t *self)`
- Purpose: Overrides default attack check — immediately attacks if in medic mode; otherwise defers to `M_CheckAttack`.
- Inputs: `self`
- Outputs/Return: `true` if attacking, else result of `M_CheckAttack`
- Side effects: May set currentmove via `medic_attack`
- Calls: `medic_attack`, `M_CheckAttack`

### medic_die
- Signature: `void medic_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- Purpose: Handles death — releases any claimed patient (`enemy->owner = NULL`), gibs if below threshold, otherwise starts death animation.
- Inputs: Standard die callback parameters
- Outputs/Return: void
- Side effects: Frees patient ownership, triggers gibs or death move, plays death/gib sounds
- Calls: `gi.sound`, `gi.soundindex`, `ThrowGib`, `ThrowHead`

### SP_monster_medic
- Signature: `void SP_monster_medic(edict_t *self)`
- Purpose: Spawns the medic entity — loads sounds, sets model/bbox/stats, wires all AI callbacks, starts walk-monster logic.
- Inputs: `self` — pre-allocated entity
- Outputs/Return: void
- Side effects: Calls `gi.soundindex`, `gi.modelindex`, `gi.linkentity`, `walkmonster_start`; frees entity in deathmatch.
- Calls: `G_FreeEdict`, `gi.soundindex`, `gi.modelindex`, `gi.linkentity`, `walkmonster_start`

### Notes
- `medic_idle`, `medic_search`, `medic_run` all opportunistically call `medic_FindDeadMonster` and set `AI_MEDIC` + `FoundTarget` if a patient is found.
- `medic_duck_down/hold/up` manage a crouch dodge sequence controlling `AI_DUCKED`, `AI_HOLD_FRAME`, hitbox height, and `takedamage`.
- `medic_continue` is an in-animation callback that re-enters hyperblaster loop with 95% probability if enemy is still visible.

## Control Flow Notes
- Init: `SP_monster_medic` → `walkmonster_start` → begins in `medic_move_stand`, polling `medic_idle` on frame 1.
- Frame loop: Standard stand/walk/run transitions; `medic_run` and `medic_idle` continually scan for dead monsters.
- Attack: `medic_checkattack` short-circuits to cable attack when `AI_MEDIC` is set; otherwise fires blaster sequences.
- Resurrection completes at `FRAME_attack50` inside `medic_cable_attack`; `self->enemy->owner` is set then cleared to prevent re-claiming.
- Shutdown: `medic_die` releases patient ownership before death sequence; `medic_dead` finalizes bbox and marks `SVF_DEADMONSTER`.

## External Dependencies
- Includes: `g_local.h`, `m_medic.h`
- External symbols: `visible`, `findradius`, `FoundTarget`, `M_CheckAttack`, `ED_CallSpawn`, `walkmonster_start`, `ThrowGib`, `ThrowHead`, `G_FreeEdict`, `monster_fire_blaster`, `G_ProjectSource`, `monster_flash_offset`, `g_edicts`, `level`, `skill`, `deathmatch`, `gi` (game import struct), all `ai_*` and animation frame constants from `m_medic.h`
