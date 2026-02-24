# game/g_func.c

## File Purpose
Implements all brush-function entities (`func_*`) that involve movement, rotation, or triggered behavior in Quake 2. This includes platforms, doors, rotating brushes, trains, conveyors, buttons, secret doors, timers, and killboxes.

## Core Responsibilities
- Provide linear and angular movement primitives (velocity stepping, acceleration/deceleration) used by all moving entities
- Spawn and configure `func_plat`, `func_door`, `func_door_rotating`, `func_door_secret`, `func_rotating`, `func_train`, `func_water`, `func_button`, `func_conveyor`, `func_timer`, `func_killbox`, and `trigger_elevator`
- Manage state machines (STATE_TOP/BOTTOM/UP/DOWN) for all moving entities
- Handle blocked/touch/use/kill callbacks for each entity type
- Synchronize team-linked door/plat movement so all members complete travel at the same time
- Integrate with area portals on door open/close

## Key Types / Data Structures

None defined here; relies on types from `g_local.h`.

| Name | Kind | Purpose |
|------|------|---------|
| `moveinfo_t` | struct (external) | Per-entity movement parameters: speed, accel, decel, distance, state, sounds, endpoints |
| `edict_t` | struct (external) | Entity with all game fields including `moveinfo`, `think`, `touch`, `use`, `blocked` |

## Global / File-Static State

None.

## Key Functions

### Move_Calc
- **Signature:** `void Move_Calc(edict_t *ent, vec3_t dest, void(*func)(edict_t*))`
- **Purpose:** Initiates linear movement toward `dest`; dispatches to constant-speed or accelerative path.
- **Inputs:** Entity, destination point, completion callback.
- **Outputs/Return:** void
- **Side effects:** Sets `ent->velocity`, `ent->moveinfo.dir`, `ent->moveinfo.remaining_distance`, schedules think.
- **Calls:** `VectorSubtract`, `VectorNormalize`, `Move_Begin`, `Think_AccelMove`
- **Notes:** Team-slave entities defer one frame so the team master leads.

### Think_AccelMove
- **Signature:** `void Think_AccelMove(edict_t *ent)`
- **Purpose:** Per-frame think for accelerated movement; updates current_speed via `plat_CalcAcceleratedMove` / `plat_Accelerate`, transitions to `Move_Final` when close enough.
- **Side effects:** Modifies `ent->moveinfo.remaining_distance`, `ent->velocity`; reschedules self.

### AngleMove_Calc / AngleMove_Begin / AngleMove_Final / AngleMove_Done
- Parallel set for angular (rotational) movement using `avelocity` instead of `velocity`. Used by `func_door_rotating`.

### Think_SpawnDoorTrigger
- **Signature:** `void Think_SpawnDoorTrigger(edict_t *ent)`
- **Purpose:** Spawns a proximity trigger encompassing all team members and calls `Think_CalcMoveSpeed`.
- **Side effects:** `G_Spawn`s a new trigger entity; calls `door_use_areaportals` if `START_OPEN`.

### Think_CalcMoveSpeed
- **Signature:** `void Think_CalcMoveSpeed(edict_t *self)`
- **Purpose:** Normalizes speed/accel/decel across all door team members so they all finish moving simultaneously.
- **Calls:** Iterates `teamchain`.

### SP_func_plat / SP_func_door / SP_func_door_rotating / SP_func_door_secret / SP_func_rotating / SP_func_train / SP_func_water / SP_func_button / SP_func_conveyor / SP_func_timer / SP_func_killbox / SP_trigger_elevator
- **Purpose:** Spawn functions called by the entity system at level load. Each initializes solid type, move parameters, sound indices, pos1/pos2 endpoints, callbacks (`use`, `blocked`, `touch`, `think`), and links the entity.
- **Notes:** These are the engine-facing entry points registered in the spawn table.

### door_blocked / plat_blocked / train_blocked / door_secret_blocked
- Shared pattern: instantly kill non-monster/non-client blockers; deal `self->dmg` crush damage to monsters/players; reverse movement direction.

### door_use_areaportals
- **Signature:** `void door_use_areaportals(edict_t *self, qboolean open)`
- **Purpose:** Finds all `func_areaportal` entities matching `self->target` and opens/closes them via `gi.SetAreaPortalState`.

## Control Flow Notes
- **Init:** All `SP_func_*` functions fire during level spawn. Doors schedule either `Think_SpawnDoorTrigger` or `Think_CalcMoveSpeed` one frame later to allow targets to spawn first.
- **Frame:** Moving entities drive themselves via the `think`/`nextthink` scheduler. `Think_AccelMove` reschedules itself every `FRAMETIME` until `Move_Final` is reached.
- **Shutdown:** No explicit shutdown; entity lifecycle managed by the game's GC (`G_FreeEdict`).

## External Dependencies
- `g_local.h` — all game types, macros (`FRAMETIME`, `FL_TEAMSLAVE`, state constants), `gi` interface
- **Defined elsewhere:** `T_Damage`, `BecomeExplosion1`, `KillBox`, `G_UseTargets`, `G_Find`, `G_PickTarget`, `G_Spawn`, `G_SetMovedir`, `AddPointToBounds`, `crandom`, `vtos`; `gi.sound`, `gi.soundindex`, `gi.setmodel`, `gi.linkentity`, `gi.centerprintf`, `gi.SetAreaPortalState`, `gi.dprintf`
