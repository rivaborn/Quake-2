# ctf/g_monster.c

## File Purpose
Provides the shared monster infrastructure for the CTF game module, including monster weapon firing wrappers, per-frame think logic, world interaction (water/lava/slime damage), and monster spawn/initialization routines.

## Core Responsibilities
- Wrap projectile fire functions with muzzle flash network messages for all monster weapon types
- Drive per-frame animation via `M_MoveFrame`, advancing through `mmove_t` sequences and dispatching AI/think callbacks
- Categorize monster position (water level, ground contact) each frame
- Apply environmental damage (drowning, lava, slime) and entry/exit sounds
- Handle monster spawn variants: walk, fly, swim, and triggered spawn
- Resolve target/combattarget linkage at spawn time
- Fire death targets and drop items on monster death

## Key Types / Data Structures
None defined here (all types from `g_local.h`).

## Global / File-Static State
None.

## Key Functions

### monster_fire_bullet / _shotgun / _blaster / _grenade / _rocket / _railgun / _bfg
- **Signature:** Various; all take `edict_t *self`, origin/direction vectors, damage, and a `flashtype`
- **Purpose:** Delegate to the corresponding `fire_*` function, then broadcast a `svc_muzzleflash2` network event to all PVS clients
- **Inputs:** Firing entity, projectile origin, direction, damage params, flash type constant
- **Outputs/Return:** void
- **Side effects:** Writes to network message buffer via `gi.WriteByte/WriteShort`, calls `gi.multicast`
- **Calls:** `fire_bullet`, `fire_shotgun`, `fire_blaster`, `fire_grenade`, `fire_rocket`, `fire_rail`, `fire_bfg`, `gi.WriteByte`, `gi.WriteShort`, `gi.multicast`
- **Notes:** Grenade splash damage hardcoded as `damage+40`; rocket as `damage+20`. Splash radius not exposed to callers.

### M_MoveFrame
- **Signature:** `void M_MoveFrame(edict_t *self)`
- **Purpose:** Advance the monster's animation frame within its current `mmove_t`, invoke per-frame `aifunc` and `thinkfunc`, and handle sequence end via `endfunc`
- **Inputs:** Monster entity
- **Outputs/Return:** void
- **Side effects:** Mutates `self->s.frame`, `self->nextthink`, `self->monsterinfo.nextframe/aiflags`; may trigger state transitions via callbacks
- **Calls:** `move->endfunc`, `move->frame[index].aifunc`, `move->frame[index].thinkfunc`
- **Notes:** Checks `AI_HOLD_FRAME` to suppress movement distance; early-returns if monster dies inside `endfunc`.

### monster_think
- **Signature:** `void monster_think(edict_t *self)`
- **Purpose:** Per-frame think callback; orchestrates frame advance, ground check, position categorization, world effects, and visual effects
- **Calls:** `M_MoveFrame`, `M_CheckGround`, `M_CatagorizePosition`, `M_WorldEffects`, `M_SetEffects`

### M_CheckGround
- **Signature:** `void M_CheckGround(edict_t *ent)`
- **Purpose:** Traces 0.25 units down to determine if entity is on solid ground; snaps origin to surface
- **Side effects:** May mutate `ent->s.origin`, `ent->groundentity`, `ent->velocity[2]`
- **Notes:** Skips FL_SWIM/FL_FLY entities; rejects slopes with `normal[2] < 0.7`.

### M_WorldEffects
- **Signature:** `void M_WorldEffects(edict_t *ent)`
- **Purpose:** Applies drowning/suffocation damage, lava/slime damage, water entry/exit sounds, and sets `FL_INWATER`
- **Side effects:** Calls `T_Damage`, `gi.sound`; mutates `ent->air_finished`, `ent->damage_debounce_time`, `ent->flags`

### monster_start
- **Signature:** `qboolean monster_start(edict_t *self)`
- **Purpose:** Common initialization for all monster types; sets flags, registers think, increments `level.total_monsters`
- **Outputs/Return:** `false` if deathmatch (entity freed); `true` otherwise
- **Side effects:** Calls `G_FreeEdict` in deathmatch; mutates numerous entity fields; sets default `checkattack` to `M_CheckAttack`

### monster_start_go
- **Signature:** `void monster_start_go(edict_t *self)`
- **Purpose:** Post-spawn setup: resolves `target`/`combattarget`, picks initial patrol path or stand idle, sets `monster_think` as the recurring think
- **Calls:** `G_Find`, `G_PickTarget`, `vectoyaw`, `self->monsterinfo.walk`, `self->monsterinfo.stand`

### monster_death_use
- **Signature:** `void monster_death_use(edict_t *self)`
- **Purpose:** On death: drops carried item, redirects target to `deathtarget` if set, fires targets with enemy as activator
- **Calls:** `Drop_Item`, `G_UseTargets`

### monster_triggered_spawn / _spawn_use / _triggered_start
- **Purpose:** Implement deferred triggered spawning — entity hides (SOLID_NOT, SVF_NOCLIENT) until activated, then spawns with a one-frame delay to avoid telefragging
- **Notes:** `monster_triggered_spawn_use` sets a `FRAMETIME` delay before calling `monster_triggered_spawn`.

## Control Flow Notes
- `walkmonster_start` / `flymonster_start` / `swimmonster_start` are the entry points called by individual monster spawn functions. Each sets the appropriate locomotion flag and schedules `*_start_go` via `self->think`.
- `*_start_go` calls `monster_start_go`, which sets `monster_think` as the recurring frame think.
- Each game frame: `monster_think` → `M_MoveFrame` → per-frame AI/think callbacks → ground/water checks → effects.

## External Dependencies
- **Includes:** `g_local.h`
- **Defined elsewhere:** `fire_bullet`, `fire_shotgun`, `fire_blaster`, `fire_grenade`, `fire_rocket`, `fire_rail`, `fire_bfg`; `T_Damage`, `Drop_Item`, `G_UseTargets`, `G_Find`, `G_PickTarget`, `KillBox`, `FoundTarget`, `M_CheckAttack`, `M_walkmove`; `gi` (game import struct); `g_edicts`, `level`, `world`, `st`
