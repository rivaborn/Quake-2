# ctf/m_move.c

## File Purpose
Implements ground-based and flying/swimming monster movement for the CTF game module. Handles step-up movement, bottom-check validation, yaw rotation, and goal-directed chase navigation for AI entities.

## Core Responsibilities
- Validate that a monster has solid ground beneath it (`M_CheckBottom`)
- Perform a single movement step with slope/stair adjustment (`SV_movestep`)
- Rotate a monster incrementally toward its ideal yaw (`M_ChangeYaw`)
- Execute a directional step and confirm facing alignment (`SV_StepDirection`)
- Choose a new chase direction toward an enemy with fallback directions (`SV_NewChaseDir`)
- Drive per-frame monster goal movement (`M_MoveToGoal`, `M_walkmove`)

## Key Types / Data Structures
None (uses types from `g_local.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|------|-------|--------|---------|
| `c_yes` | `int` | global | Debug counter: fast-path bottom-check successes |
| `c_no` | `int` | global | Debug counter: full bottom-check executions |

## Key Functions

### M_CheckBottom
- **Signature:** `qboolean M_CheckBottom(edict_t *ent)`
- **Purpose:** Determines if the entity has solid ground under all four bottom corners, preventing monsters from walking off edges.
- **Inputs:** `ent` — the monster entity
- **Outputs/Return:** `true` if grounded; `false` if dangling over an edge
- **Side effects:** Increments `c_yes` or `c_no`; issues traces via `gi.trace`/`gi.pointcontents`
- **Calls:** `gi.pointcontents`, `gi.trace`
- **Notes:** Fast path exits early if all four corners are in `CONTENTS_SOLID`. Full check traces the midpoint and all corners downward up to `2*STEPSIZE` (36 units); rejects if any corner deviates more than `STEPSIZE` from mid.

### SV_movestep
- **Signature:** `qboolean SV_movestep(edict_t *ent, vec3_t move, qboolean relink)`
- **Purpose:** Attempts one movement step, handling stair-climbing, water entry/exit rules, and partial-ground edge cases.
- **Inputs:** `ent` — moving entity; `move` — delta vector; `relink` — whether to relink into the world after success
- **Outputs/Return:** `true` if move succeeded; `false` otherwise
- **Side effects:** Modifies `ent->s.origin`, `ent->groundentity`, `ent->groundentity_linkcount`, `ent->flags`; calls `gi.linkentity`, `G_TouchTriggers`
- **Calls:** `gi.trace`, `gi.pointcontents`, `gi.linkentity`, `G_TouchTriggers`, `M_CheckBottom`
- **Notes:** Flying/swimming monsters use a two-pass vertical-tracking loop. Ground monsters are pushed up by `STEPSIZE` (18) then traced down. `AI_NOSTEP` flag reduces step height to 1. Water avoidance is enforced per `FL_FLY`/`FL_SWIM` flags.

### M_ChangeYaw
- **Signature:** `void M_ChangeYaw(edict_t *ent)`
- **Purpose:** Incrementally rotates the entity's yaw toward `ideal_yaw` at `yaw_speed` degrees per call.
- **Inputs:** `ent->s.angles[YAW]`, `ent->ideal_yaw`, `ent->yaw_speed`
- **Outputs/Return:** None; modifies `ent->s.angles[YAW]`
- **Side effects:** Writes entity yaw angle
- **Calls:** `anglemod`
- **Notes:** Handles wraparound correctly by clamping the delta to ±180.

### SV_StepDirection
- **Signature:** `qboolean SV_StepDirection(edict_t *ent, float yaw, float dist)`
- **Purpose:** Turns the monster toward `yaw` and attempts a step; cancels the position if the entity has not rotated within 45° of target.
- **Inputs:** `ent`, `yaw` (degrees), `dist` (units)
- **Outputs/Return:** `true` if step taken; `false` otherwise
- **Side effects:** Modifies `ent->ideal_yaw`, `ent->s.origin`; calls `gi.linkentity`, `G_TouchTriggers`
- **Calls:** `M_ChangeYaw`, `SV_movestep`, `gi.linkentity`, `G_TouchTriggers`

### SV_NewChaseDir
- **Signature:** `void SV_NewChaseDir(edict_t *actor, edict_t *enemy, float dist)`
- **Purpose:** Computes a new 45°-quantized movement direction toward `enemy`, trying diagonal then cardinal then random fallbacks.
- **Inputs:** `actor`, `enemy`, `dist`
- **Outputs/Return:** None; modifies `actor->ideal_yaw`/position via `SV_StepDirection`
- **Side effects:** May set `FL_PARTIALGROUND` via `SV_FixCheckBottom`
- **Calls:** `anglemod`, `SV_StepDirection`, `M_CheckBottom`, `SV_FixCheckBottom`
- **Notes:** Excludes turnaround direction to prevent ping-pong. Uses `rand()` to vary fallback sweep order.

### M_MoveToGoal
- **Signature:** `void M_MoveToGoal(edict_t *ent, float dist)`
- **Purpose:** Per-frame movement driver: skips if airborne (non-flying), returns early if already close enough to enemy, otherwise steps or picks new chase direction.
- **Calls:** `SV_CloseEnough`, `SV_StepDirection`, `SV_NewChaseDir`

### M_walkmove
- **Signature:** `qboolean M_walkmove(edict_t *ent, float yaw, float dist)`
- **Purpose:** Script-facing helper to move a monster by yaw+distance; guards against airborne non-flyers.
- **Calls:** `SV_movestep`

- **Notes:** `SV_CloseEnough` and `SV_FixCheckBottom` are trivial helpers (AABB proximity test and flag setter, respectively).

## Control Flow Notes
Called from monster AI action functions (e.g., `ai_walk`, `ai_run`) during the per-frame entity think cycle. `M_MoveToGoal` and `M_walkmove` are the primary entry points driven by monster think callbacks. This file has no init or shutdown involvement.

## External Dependencies
- `g_local.h` — entity types, flags (`FL_FLY`, `FL_SWIM`, `FL_PARTIALGROUND`, `AI_NOSTEP`), masks (`MASK_MONSTERSOLID`, `MASK_WATER`)
- `gi.trace`, `gi.pointcontents`, `gi.linkentity` — server game import interface (defined elsewhere in engine)
- `G_TouchTriggers` — defined elsewhere in CTF game module
- `anglemod`, `VectorAdd`, `VectorCopy` — math utilities (defined elsewhere)
