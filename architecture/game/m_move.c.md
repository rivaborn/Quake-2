# game/m_move.c

## File Purpose
Implements ground-based and aerial monster movement logic for Quake 2, including step-up stair climbing, directional pathfinding toward a goal entity, yaw rotation, and bottom-edge validation to prevent monsters from walking off ledges.

## Core Responsibilities
- Validate that a monster has solid ground beneath its corners (`M_CheckBottom`)
- Execute a single movement step for walking, swimming, and flying monsters (`SV_movestep`)
- Rotate a monster toward its ideal yaw incrementally per frame (`M_ChangeYaw`)
- Attempt a step in a specific direction, committing only if facing close enough to that direction (`SV_StepDirection`)
- Select a new chase direction when the direct path to the enemy is blocked (`SV_NewChaseDir`)
- Drive monsters toward their `goalentity` each AI frame (`M_MoveToGoal`)
- Provide a yaw-to-vector walk step helper (`M_walkmove`)

## Key Types / Data Structures
None (uses types from `g_local.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `c_yes` | `int` | global | Debug counter: fast-path bottom checks that passed |
| `c_no` | `int` | global | Debug counter: bottom checks that fell through to full trace |

## Key Functions

### M_CheckBottom
- **Signature:** `qboolean M_CheckBottom(edict_t *ent)`
- **Purpose:** Determines whether any bottom corner of the entity is hanging over a non-stair edge; returns false if the monster would fall.
- **Inputs:** `ent` — the monster entity.
- **Outputs/Return:** `qtrue` if all corners are adequately supported, `qfalse` otherwise.
- **Side effects:** Increments `c_yes` or `c_no`; issues up to 5 `gi.trace` / `gi.pointcontents` calls.
- **Calls:** `gi.pointcontents`, `gi.trace`, `VectorAdd`.
- **Notes:** Fast path checks four corner points via `pointcontents`; falls to full trace only if any corner is not solid. Stair tolerance is `STEPSIZE` (18 units).

### SV_movestep
- **Signature:** `qboolean SV_movestep(edict_t *ent, vec3_t move, qboolean relink)`
- **Purpose:** Attempts to move the monster by `move` delta, handling step-up climbing, water boundary enforcement, and partial-ground recovery.
- **Inputs:** `ent` — monster; `move` — world-space delta; `relink` — whether to relink and touch triggers on success.
- **Outputs/Return:** `qtrue` if the move completed.
- **Side effects:** Mutates `ent->s.origin`, `ent->groundentity`, `ent->groundentity_linkcount`, `ent->flags`; calls `gi.linkentity` / `G_TouchTriggers` when `relink` is set.
- **Calls:** `gi.trace`, `gi.pointcontents`, `gi.linkentity`, `G_TouchTriggers`, `M_CheckBottom`, `VectorCopy`, `VectorAdd`.
- **Notes:** Fly/swim monsters use a two-pass vertical-adjustment loop toward `goalentity`. Walk monsters are pushed up `STEPSIZE` then traced downward to find the floor. `AI_NOSTEP` flag reduces stepsize to 1 unit.

### M_ChangeYaw
- **Signature:** `void M_ChangeYaw(edict_t *ent)`
- **Purpose:** Rotates entity's yaw toward `ideal_yaw` by at most `yaw_speed` degrees per call.
- **Inputs:** `ent->s.angles[YAW]`, `ent->ideal_yaw`, `ent->yaw_speed`.
- **Outputs/Return:** Void; mutates `ent->s.angles[YAW]`.
- **Side effects:** None beyond angle mutation.
- **Calls:** `anglemod`.

### SV_StepDirection
- **Signature:** `qboolean SV_StepDirection(edict_t *ent, float yaw, float dist)`
- **Purpose:** Sets ideal yaw, rotates toward it, converts yaw to a move vector, and commits the step only if the monster is facing within 45° of the target direction.
- **Inputs:** `yaw` — desired heading in degrees; `dist` — move distance.
- **Outputs/Return:** `qtrue` if the step succeeded and orientation was acceptable.
- **Side effects:** Mutates `ent->s.origin`, `ent->ideal_yaw`, `ent->s.angles[YAW]`; always calls `gi.linkentity` and `G_TouchTriggers`.
- **Calls:** `M_ChangeYaw`, `SV_movestep`, `gi.linkentity`, `G_TouchTriggers`, `VectorCopy`.

### SV_NewChaseDir
- **Signature:** `void SV_NewChaseDir(edict_t *actor, edict_t *enemy, float dist)`
- **Purpose:** Computes a new 45°-quantized movement direction for an actor chasing an enemy, trying diagonal, axis-aligned, old, random sweep, and finally turnaround directions in order.
- **Inputs:** `actor`, `enemy`, `dist`.
- **Outputs/Return:** Void; updates `actor->ideal_yaw` on failure.
- **Side effects:** Calls `SV_StepDirection` repeatedly; may set `FL_PARTIALGROUND` via `SV_FixCheckBottom`.
- **Calls:** `anglemod`, `SV_StepDirection`, `M_CheckBottom`, `SV_FixCheckBottom`, `rand`.
- **Notes:** Uses `DI_NODIR (-1)` sentinel. Random coin-flip determines sweep direction (CW vs CCW).

### M_MoveToGoal
- **Signature:** `void M_MoveToGoal(edict_t *ent, float dist)`
- **Purpose:** Per-AI-frame entry point: moves monster toward `goalentity`; bails early if airborne (non-flyer) or already close enough to enemy.
- **Inputs:** `ent`, `dist` — desired step size.
- **Side effects:** Calls `SV_StepDirection` or `SV_NewChaseDir`; 1-in-4 chance of forcing a direction recalculation.
- **Calls:** `SV_CloseEnough`, `SV_StepDirection`, `SV_NewChaseDir`.

### M_walkmove
- **Signature:** `qboolean M_walkmove(edict_t *ent, float yaw, float dist)`
- **Purpose:** Public API for monster scripts to request a walk step at a given yaw and distance.
- **Calls:** `SV_movestep`.

## Control Flow Notes
Called during the game AI frame. Monster think functions call `M_MoveToGoal` or `M_walkmove`. `SV_movestep` is the core primitive; all higher-level functions reduce to it. Init and shutdown involvement: none.

## External Dependencies
- `g_local.h` — entity definitions, `gi` game import interface, `FL_*` flags, `AI_NOSTEP`, `MASK_MONSTERSOLID`, `MASK_WATER`
- **Defined elsewhere:** `gi.trace`, `gi.pointcontents`, `gi.linkentity`, `G_TouchTriggers`, `anglemod`, `VectorAdd`, `VectorCopy`, `M_PI`
