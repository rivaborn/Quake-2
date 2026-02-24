# game/g_monster.c

## File Purpose
Provides the shared monster infrastructure for the Quake 2 game module, including weapon-fire wrappers, per-frame animation/AI ticking, environmental interaction (water/lava/slime), and the initialization pipeline for walk/fly/swim monster types.

## Core Responsibilities
- Wrap projectile/hitscan fire functions with muzzle-flash network broadcasts for monster use
- Drive per-frame animation state machine (`M_MoveFrame`) through `mmove_t` sequences
- Tick monster logic each server frame (`monster_think`): move, ground-check, categorize position, apply world effects, set visual effects
- Handle monster activation via `monster_use` and triggered spawning
- Fire death targets via `monster_death_use`
- Initialize monsters through a three-stage pipeline: `monster_start` → `*_start_go` → `monster_start_go`

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `mmove_t` | struct (defined elsewhere) | Describes an animation sequence: first/last frame, per-frame AI+think callbacks, end callback |
| `edict_t` | struct (defined elsewhere) | Entity, the universal game object |
| `monsterinfo_t` | struct (defined elsewhere) | Per-monster state: `currentmove`, `aiflags`, `attack_finished`, `scale`, `linkcount`, etc. |
| `trace_t` | struct (defined elsewhere) | Result of a spatial trace used for ground detection |

## Global / File-Static State

None. (All state lives on `edict_t` fields or the shared `level` and `g_edicts` globals defined elsewhere.)

## Key Functions

### monster_fire_bullet / _shotgun / _blaster / _grenade / _rocket / _railgun / _bfg
- **Signature:** Various; all take `edict_t *self`, origin, direction, damage params, `int flashtype`
- **Purpose:** Delegate to corresponding `fire_*` projectile functions then broadcast `svc_muzzleflash2` to PVS
- **Inputs:** Firing entity, world-space start + direction, weapon parameters, flash effect index
- **Outputs/Return:** void
- **Side effects:** Writes network message bytes; spawns projectile entities via `fire_*` calls
- **Calls:** `fire_bullet/shotgun/blaster/grenade/rocket/rail/bfg`, `gi.WriteByte`, `gi.WriteShort`, `gi.multicast`
- **Notes:** Grenade and rocket splash radii are hardcoded (`damage+40`, `damage+20`); no skill-based spread variation despite the FIXME comment

### M_MoveFrame
- **Signature:** `void M_MoveFrame(edict_t *self)`
- **Purpose:** Advance the monster's animation one frame, invoke per-frame AI and think callbacks, handle frame override/hold, and trigger the sequence end callback
- **Inputs:** Monster entity with valid `monsterinfo.currentmove`
- **Outputs/Return:** void
- **Side effects:** Mutates `self->s.frame`, `self->nextthink`, `self->monsterinfo.nextframe/aiflags`; calls `aifunc` (may move entity) and `thinkfunc`; `endfunc` may set new `currentmove`
- **Calls:** `move->endfunc`, `move->frame[].aifunc`, `move->frame[].thinkfunc`
- **Notes:** After `endfunc`, re-fetches `currentmove` because it is likely replaced; returns early if `SVF_DEADMONSTER` is set after `endfunc`

### monster_think
- **Signature:** `void monster_think(edict_t *self)`
- **Purpose:** Main per-frame think callback; orchestrates the full monster update
- **Inputs:** Monster entity
- **Outputs/Return:** void
- **Side effects:** Calls `M_MoveFrame`, conditionally `M_CheckGround`, `M_CatagorizePosition`, `M_WorldEffects`, `M_SetEffects`
- **Calls:** `M_MoveFrame`, `M_CheckGround`, `M_CatagorizePosition`, `M_WorldEffects`, `M_SetEffects`

### M_CheckGround
- **Signature:** `void M_CheckGround(edict_t *ent)`
- **Purpose:** Determine whether the monster is standing on solid ground; snap origin down if slightly above
- **Inputs:** Entity; skips FL_SWIM/FL_FLY entities and upward-moving ones (velocity[2] > 100)
- **Outputs/Return:** void; sets `ent->groundentity`
- **Side effects:** May snap `ent->s.origin` down, zero `velocity[2]`, update `groundentity`/`groundentity_linkcount`
- **Calls:** `gi.trace`

### M_CatagorizePosition
- **Signature:** `void M_CatagorizePosition(edict_t *ent)`
- **Purpose:** Determine `waterlevel` (0–3) and `watertype` by sampling content flags at feet, waist, and head
- **Calls:** `gi.pointcontents` (twice or three times)

### M_WorldEffects
- **Signature:** `void M_WorldEffects(edict_t *ent)`
- **Purpose:** Apply drowning/suffocation damage, lava/slime damage, and water-entry/exit sounds
- **Side effects:** Calls `T_Damage`, `gi.sound`; sets `FL_INWATER`; updates `air_finished`, `damage_debounce_time`, `pain_debounce_time`

### M_SetEffects
- **Signature:** `void M_SetEffects(edict_t *ent)`
- **Purpose:** Sync `s.effects` / `s.renderfx` to power-armor state and resurrection AI flag
- **Side effects:** Mutates render fields on the entity

### monster_start
- **Signature:** `qboolean monster_start(edict_t *self)`
- **Purpose:** Common first-stage initialization for all monsters; rejected in deathmatch
- **Outputs/Return:** `true` on success, `false` (and frees entity) in deathmatch
- **Side effects:** Increments `level.total_monsters`; sets damage, clip mask, flags, skin, schedules first think; resolves drop item

### monster_start_go
- **Signature:** `void monster_start_go(edict_t *self)`
- **Purpose:** Second-stage init: resolves `target`/`combattarget`, sets initial walk/stand state, assigns `monster_think` as the ongoing think
- **Calls:** `G_Find`, `G_PickTarget`, `G_UseTargets`, `vectoyaw`, monster's `stand`/`walk` callbacks

### monster_death_use
- **Signature:** `void monster_death_use(edict_t *self)`
- **Purpose:** On death, drop carried item, redirect `target` to `deathtarget`, fire targets with enemy as activator
- **Calls:** `Drop_Item`, `G_UseTargets`

### monster_use
- **Signature:** `void monster_use(edict_t *self, edict_t *other, edict_t *activator)`
- **Purpose:** Use-callback to make a monster hostile toward its activator
- **Notes:** Guards against already-having-an-enemy, dead monsters, `FL_NOTARGET` activators, and non-client/non-good-guy activators

### monster_triggered_spawn / _spawn_use / _start
- **Purpose:** Implement deferred trigger-spawned monsters: start invisible/non-solid (`monster_triggered_start`), activate on use (`monster_triggered_spawn_use`), materialize one frame later (`monster_triggered_spawn`)

### walkmonster_start / flymonster_start / swimmonster_start
- **Purpose:** Type-specific entry points; set `FL_FLY`/`FL_SWIM`, call `monster_start`, schedule the appropriate `*_start_go`
- **Notes:** `walkmonster_start_go` drops to floor and validates walk-in-solid on level load; fly/swim variants skip floor-drop

## Control Flow Notes
- **Spawn:** Map loader calls `walkmonster_start` (or fly/swim variant) → `monster_start` (validates, increments counter) → deferred `*_start_go` (floor placement, pathing) → `monster_start_go` (target resolution, assigns `monster_think`)
- **Frame update:** `monster_think` is called every `FRAMETIME` by the server think scheduler; it drives animation, ground state, environment, and visual effects
- **Death:** Individual monster death functions call `monster_death_use` before transitioning to death animations

## External Dependencies
- **Includes:** `g_local.h` (all game types, macros, prototypes)
- **Defined elsewhere:** `fire_bullet/shotgun/blaster/grenade/rocket/rail/bfg`, `T_Damage`, `Drop_Item`, `G_UseTargets`, `G_Find`, `G_PickTarget`, `KillBox`, `FoundTarget`, `M_CheckAttack`, `M_walkmove`, `vectoyaw`, `gi` (game import struct), `level`, `g_edicts`, `world`, `deathmatch`, `st`
