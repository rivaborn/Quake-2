# qcommon/pmove.c

## File Purpose
Implements the player movement simulation (`Pmove`) shared between client and server to ensure deterministic, reproducible physics. Handles walking, running, swimming, flying, ducking, jumping, ladder climbing, and water jumping on top of a collision/trace abstraction.

## Core Responsibilities
- Convert quantized network-precision state to full-float working values and back
- Apply friction, acceleration, and gravity per movement context (ground, air, water, fly)
- Perform step-and-slide collision response against world geometry
- Detect and set ground entity, water level, and water type each frame
- Handle special movement states: ducking, jumping, water jumping, ladder, teleport freeze
- Accumulate touched entities for game-logic callbacks
- Snap final position/velocity back to 1/8-unit network quantization with jitter search

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `pml_t` | struct | Per-frame local working state: full-precision origin/velocity, basis vectors, frametime, ground info, ladder flag |
| `pmove_t` | struct (defined in qcommon.h) | Public move state passed in by caller; holds quantized origin/velocity, pm_type/flags, cmd, touch list, trace/pointcontents callbacks |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `pm` | `pmove_t *` | global | Pointer to current pmove input/output structure |
| `pml` | `pml_t` | global | Current frame's working locals; zeroed at start of each `Pmove` call |
| `pm_stopspeed` | `float` | global | Minimum speed threshold before full stop (100) |
| `pm_maxspeed` | `float` | global | Maximum player speed (300) |
| `pm_duckspeed` | `float` | global | Max speed while ducked (100) |
| `pm_accelerate` | `float` | global | Ground/fly acceleration rate (10) |
| `pm_airaccelerate` | `float` | global | Air acceleration rate (0 = disabled by default) |
| `pm_wateraccelerate` | `float` | global | Water acceleration rate (10) |
| `pm_friction` | `float` | global | Ground friction coefficient (6) |
| `pm_waterfriction` | `float` | global | Water friction coefficient (1) |
| `pm_waterspeed` | `float` | global | Current velocity scale in water (400) |

## Key Functions

### Pmove
- Signature: `void Pmove(pmove_t *pmove)`
- Purpose: Top-level entry point; orchestrates full player movement tick
- Inputs: `pmove` — caller-populated move structure with state, cmd, trace callbacks
- Outputs/Return: Modifies `pmove` in place (origin, velocity, flags, viewangles, touch list, water/ground info)
- Side effects: Sets globals `pm` and `pml`; calls `pm->trace` and `pm->pointcontents` callbacks
- Calls: `PM_ClampAngles`, `PM_CheckDuck`, `PM_InitialSnapPosition`, `PM_CatagorizePosition`, `PM_DeadMove`, `PM_CheckSpecialMovement`, `PM_CheckJump`, `PM_Friction`, `PM_WaterMove`, `PM_AirMove`, `PM_FlyMove`, `PM_StepSlideMove`, `PM_SnapPosition`
- Notes: Must be called identically on client and server for prediction correctness; zeroes `pml` every call

### PM_StepSlideMove_
- Signature: `void PM_StepSlideMove_(void)`
- Purpose: Core slide-along-planes collision loop; moves player up to 4 bumps per frame
- Inputs: Reads/writes `pml.origin`, `pml.velocity`; calls `pm->trace`
- Outputs/Return: Modifies `pml.origin` and `pml.velocity` in place
- Side effects: Appends to `pm->touchents`; zeroes velocity on over-constrained cases
- Calls: `pm->trace`, `PM_ClipVelocity`, `CrossProduct`, `DotProduct`, `VectorScale`
- Notes: Contains commented-out alternative velocity rubbing path (`#if 0`); restores `primal_velocity` if `pm->s.pm_time` is set

### PM_StepSlideMove
- Signature: `void PM_StepSlideMove(void)`
- Purpose: Wraps `PM_StepSlideMove_` with step-up logic; tries sliding at current level then 18 units higher and picks whichever traveled farther horizontally
- Inputs: `pml.origin`, `pml.velocity`
- Outputs/Return: Updates `pml.origin`, `pml.velocity`
- Side effects: Calls `pm->trace` twice for step probing
- Notes: Falls back to flat-slide result if stepped surface is too steep (`< MIN_STEP_NORMAL = 0.7`)

### PM_CatagorizePosition
- Signature: `void PM_CatagorizePosition(void)`
- Purpose: Determines ground entity, ground plane/surface/contents, and water level (1–3)
- Inputs: `pml.origin`, `pm->mins/maxs`
- Outputs/Return: Sets `pm->groundentity`, `pml.groundplane/surface/contents`, `pm->waterlevel`, `pm->watertype`, pm_flags
- Side effects: Clears waterjump flags on ground contact; sets `PMF_TIME_LAND` on hard landing; appends to `pm->touchents`
- Calls: `pm->trace`, `pm->pointcontents`
- Notes: Velocity threshold for airborne is 180 (not ground-checked if moving up faster)

### PM_AirMove
- Signature: `void PM_AirMove(void)`
- Purpose: Handles ground walking, in-air movement, and ladder movement (all non-water)
- Inputs: `pm->cmd`, `pml.forward/right`, ground/ladder state
- Outputs/Return: Modifies `pml.velocity`; delegates to `PM_StepSlideMove`
- Side effects: Applies gravity when airborne or on ladder without vertical wish
- Calls: `PM_AddCurrents`, `PM_Accelerate`, `PM_AirAccelerate`, `PM_StepSlideMove`, `VectorNormalize`

### PM_FlyMove
- Signature: `void PM_FlyMove(qboolean doclip)`
- Purpose: Noclip/spectator 6-DOF flight; applies friction, acceleration, optional clipping
- Inputs: `doclip` flag, `pm->cmd`, `pml.forward/right`
- Outputs/Return: Modifies `pml.origin`, `pml.velocity`
- Side effects: Forces `pm->viewheight = 22`; calls `pm->trace` if `doclip`

### PM_SnapPosition
- Signature: `void PM_SnapPosition(void)`
- Purpose: Quantizes float origin/velocity to 1/8-unit shorts; jitters up to 8 combinations to find a non-solid landing spot
- Inputs: `pml.origin`, `pml.velocity`
- Outputs/Return: Writes `pm->s.origin`, `pm->s.velocity`
- Side effects: Falls back to `pml.previous_origin` if all jitter positions are solid
- Calls: `PM_GoodPosition`

### PM_CheckJump
- Signature: `void PM_CheckJump(void)`
- Purpose: Applies jump impulse (270 ups) or swim impulse based on water type; enforces hold/land timing
- Notes: Water jump velocities vary by liquid: water=100, slime=80, other=50

### PM_CheckSpecialMovement
- Signature: `void PM_CheckSpecialMovement(void)`
- Purpose: Detects ladder contact and water-jump opportunity; initiates water-jump velocity if valid
- Notes: Skipped entirely if `pm->s.pm_time` is nonzero

### PM_ClipVelocity
- Signature: `void PM_ClipVelocity(vec3_t in, vec3_t normal, vec3_t out, float overbounce)`
- Purpose: Projects velocity away from a surface plane with optional bounce factor; zeroes near-zero components

## Control Flow Notes
`Pmove` is the single exported entry point called once per command frame by both the server (`sv_user.c`) and client prediction code. Execution order within a frame: clamp angles → check duck → categorize position → dead/special checks → timing countdown → dispatch to fly/waterjump/water/air move → re-categorize → snap position.

## External Dependencies
- Notable includes: `qcommon.h` (pulls in `pmove_t`, `csurface_t`, `cplane_t`, math macros, content flags)
- External symbols used but not defined here: `vec3_origin`, `AngleVectors`, `VectorNormalize`, `VectorLength`, `DotProduct`, `CrossProduct`, `VectorMA`, `SHORT2ANGLE`, `MASK_WATER`, `MASK_CURRENT`, `CONTENTS_*`, `SURF_SLICK`, `PMF_*` flags, `PM_DEAD/SPECTATOR/GIB/FREEZE` enum values, `MAXTOUCH`, `Com_DPrintf`, `memset`
