# ctf/g_func.c

## File Purpose
Implements all BSP-brush functional entities for the CTF game module: moving platforms, rotating brushes, buttons, doors (sliding, rotating, secret), water brushes, trains, conveyors, timers, elevators, and killboxes. This is a near-identical copy of the base `game/g_func.c` adapted for the CTF mod.

## Core Responsibilities
- Provides linear and accelerated movement primitives (`Move_Calc`, `Think_AccelMove`) used by all brush movers
- Provides angular movement primitives (`AngleMove_Calc`) for rotating entities
- Implements spawn functions (`SP_func_*`) for all brush-based functional entities
- Manages multi-stage movement state machines (STATE_TOP/BOTTOM/UP/DOWN) for doors and platforms
- Handles block/crush damage for entities obstructing movers
- Synchronizes team-linked door groups to complete movement simultaneously
- Spawns secondary trigger volumes (e.g., plat center trigger, door proximity trigger)

## Key Types / Data Structures
None declared locally; relies on types from `g_local.h`.

| Name | Kind | Purpose |
|---|---|---|
| `moveinfo_t` | struct (external) | Per-entity movement parameters: speed, accel, decel, distance, state, sounds, start/end origins/angles |
| `edict_t` | struct (external) | Game entity; movers use `.moveinfo`, `.velocity`, `.avelocity`, `.think`, `.nextthink` |

## Global / File-Static State
None.

## Key Functions

### Move_Calc
- **Signature:** `void Move_Calc(edict_t *ent, vec3_t dest, void(*func)(edict_t*))`
- **Purpose:** Initiates linear movement toward `dest`; selects constant-speed or accelerated path based on accel/decel settings.
- **Inputs:** Entity, destination point, completion callback.
- **Outputs/Return:** void
- **Side effects:** Sets `ent->velocity`, `ent->moveinfo.dir`, `ent->moveinfo.remaining_distance`, `ent->think`, `ent->nextthink`.
- **Calls:** `Move_Begin`, `Think_AccelMove` (deferred via think)
- **Notes:** Team-slave entities defer one frame to sync with team master.

### Think_AccelMove
- **Signature:** `void Think_AccelMove(edict_t *ent)`
- **Purpose:** Per-frame think for accelerated movers; updates `current_speed` via `plat_Accelerate`, advances position, triggers `Move_Final` when close enough.
- **Inputs:** Entity with valid `moveinfo`.
- **Outputs/Return:** void
- **Side effects:** Modifies `ent->velocity`, `ent->moveinfo.remaining_distance`, reschedules itself.
- **Calls:** `plat_CalcAcceleratedMove`, `plat_Accelerate`, `Move_Final`

### AngleMove_Calc
- **Signature:** `void AngleMove_Calc(edict_t *ent, void(*func)(edict_t*))`
- **Purpose:** Initiates angular movement; mirrors `Move_Calc` for rotation-based movers.
- **Inputs:** Entity, completion callback.
- **Side effects:** Sets `ent->avelocity`, `ent->think`, `ent->nextthink`.
- **Calls:** `AngleMove_Begin` (immediate or deferred)

### Think_SpawnDoorTrigger
- **Signature:** `void Think_SpawnDoorTrigger(edict_t *ent)`
- **Purpose:** Post-spawn think that creates an invisible `SOLID_TRIGGER` volume around the entire door team to auto-open on proximity.
- **Side effects:** Spawns a new `edict_t` trigger, calls `Think_CalcMoveSpeed`, may open area portals.
- **Calls:** `G_Spawn`, `gi.linkentity`, `door_use_areaportals`, `Think_CalcMoveSpeed`

### Think_CalcMoveSpeed
- **Signature:** `void Think_CalcMoveSpeed(edict_t *self)`
- **Purpose:** Normalizes speed/accel/decel across all team-linked door members so they finish movement simultaneously.
- **Inputs:** Team master entity.
- **Side effects:** Modifies `moveinfo.speed/accel/decel` on all `teamchain` members.

### SP_func_door
- **Signature:** `void SP_func_door(edict_t *ent)`
- **Purpose:** Spawns a sliding door; computes travel distance, configures sounds, sets up team, schedules trigger or speed-calc think.
- **Side effects:** `gi.setmodel`, `gi.soundindex`, `gi.linkentity`; schedules `Think_SpawnDoorTrigger` or `Think_CalcMoveSpeed`.
- **Notes:** Doubles speed in deathmatch. Non-teamed doors self-assign as team of one.

### SP_func_train
- **Signature:** `void SP_func_train(edict_t *self)`
- **Purpose:** Spawns a path-following train mover; defers target lookup one frame via `func_train_find`.
- **Side effects:** `gi.setmodel`, `gi.linkentity`, schedules `func_train_find`.

- **Notes on trivial helpers:** `Move_Done`, `Move_Final`, `Move_Begin`, `AngleMove_Done`, `AngleMove_Final`, `AngleMove_Begin` form a 3-stage constant-speed movement pipeline. `plat_CalcAcceleratedMove` and `plat_Accelerate` implement the quadratic acceleration model used by `Think_AccelMove`.

## Control Flow Notes
All `SP_func_*` functions are called during map load (entity spawn phase). Movement executes via the think/nextthink scheduler each server frame. State machines transition: `STATE_BOTTOM → STATE_UP → STATE_TOP → STATE_DOWN → STATE_BOTTOM`. Area portals are opened on door-go-up and closed on door-hit-bottom.

## External Dependencies
- **Includes:** `g_local.h` (entity definitions, game API, shared constants)
- **External symbols:** `gi` (game import struct — sound, setmodel, linkentity, etc.), `G_Spawn`, `G_Find`, `G_PickTarget`, `G_UseTargets`, `G_SetMovedir`, `T_Damage`, `BecomeExplosion1`, `KillBox`, `AddPointToBounds`, `level` (global level state), `deathmatch` (cvar), `FRAMETIME`, `vec3_origin`
