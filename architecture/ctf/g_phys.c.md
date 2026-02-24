# ctf/g_phys.c

## File Purpose
Implements all server-side entity physics for the CTF game module, dispatching per-frame movement simulation based on each entity's `movetype`. This is a near-identical copy of the base game's `game/g_phys.c`, adapted for the CTF mod.

## Core Responsibilities
- Dispatch per-entity physics each frame via `G_RunEntity`
- Simulate pushmove (doors, platforms) with rollback on blocked moves
- Simulate toss/bounce/fly projectile and item movement
- Simulate stepping movement for monsters with friction and gravity
- Clip and reflect velocities against collision planes
- Run entity think functions at appropriate times
- Fire touch callbacks on collision impact

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `pushed_t` | struct | Saves an entity's pre-push origin/angles/deltayaw for rollback |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `pushed[MAX_EDICTS]` | `pushed_t[]` | global | Stack of saved positions for pushmove rollback |
| `pushed_p` | `pushed_t *` | global | Current top-of-stack pointer into `pushed[]` |
| `obstacle` | `edict_t *` | global | Entity that blocked the most recent push; passed to `blocked` callback |

## Key Functions

### G_RunEntity
- Signature: `void G_RunEntity(edict_t *ent)`
- Purpose: Per-frame physics dispatcher; routes entity to correct physics routine based on `movetype`.
- Inputs: Entity to simulate.
- Outputs/Return: None.
- Side effects: Calls `ent->prethink`, then one of the `SV_Physics_*` functions.
- Calls: `ent->prethink`, `SV_Physics_Pusher`, `SV_Physics_None`, `SV_Physics_Noclip`, `SV_Physics_Step`, `SV_Physics_Toss`, `gi.error`.
- Notes: Default case is a fatal error; all valid movetypes must be handled.

### SV_Physics_Pusher
- Signature: `void SV_Physics_Pusher(edict_t *ent)`
- Purpose: Moves BSP brush entities (doors, plats); pushes or blocks riders; rolls back entire team on failure.
- Inputs: Pusher entity (team captain).
- Outputs/Return: None.
- Side effects: Modifies origins/angles of pusher and all entities it contacts; calls `blocked` callback; calls `SV_RunThink` on success.
- Calls: `SV_Push`, `SV_RunThink`, `part->blocked`, `gi.error`.
- Notes: Skips `FL_TEAMSLAVE` entities—only the team captain drives the loop. Increments `nextthink` on all team members if move fails.

### SV_Push
- Signature: `qboolean SV_Push(edict_t *pusher, vec3_t move, vec3_t amove)`
- Purpose: Attempts to move pusher and all contacted/riding entities; rolls back all on any blockage.
- Inputs: Pusher entity, linear delta, angular delta.
- Outputs/Return: `true` if move succeeded, `false` if blocked.
- Side effects: Writes to `pushed[]` stack; modifies entity origins/angles; calls `G_TouchTriggers` on success.
- Calls: `SV_TestEntityPosition`, `gi.linkentity`, `G_TouchTriggers`, `AngleVectors`.
- Notes: Clamps move to 1/8-unit grid for client-side prediction accuracy. Rotational displacement of riders computed via forward/right/up projection.

### SV_Physics_Toss
- Signature: `void SV_Physics_Toss(edict_t *ent)`
- Purpose: Simulates toss, bounce, and fly movetypes; handles gravity, water transitions, ground detection.
- Inputs: Entity.
- Outputs/Return: None.
- Side effects: Updates origin, velocity, groundentity, watertype/waterlevel; plays water entry/exit sound; propagates position to teamslaves.
- Calls: `SV_RunThink`, `SV_CheckVelocity`, `SV_AddGravity`, `SV_PushEntity`, `ClipVelocity`, `gi.pointcontents`, `gi.positioned_sound`, `gi.soundindex`, `gi.linkentity`.

### SV_Physics_Step
- Signature: `void SV_Physics_Step(edict_t *ent)`
- Purpose: Monster stepping physics—ground check, gravity, friction, fly/swim vertical damping, then `SV_FlyMove`.
- Inputs: Entity (monster or step-mover).
- Outputs/Return: None.
- Side effects: Updates velocity, angles, groundentity; plays landing sound; calls `G_TouchTriggers`.
- Calls: `M_CheckGround`, `M_CheckBottom`, `SV_CheckVelocity`, `SV_AddRotationalFriction`, `SV_AddGravity`, `SV_FlyMove`, `gi.linkentity`, `G_TouchTriggers`, `gi.sound`, `gi.soundindex`, `SV_RunThink`.

### SV_FlyMove
- Signature: `int SV_FlyMove(edict_t *ent, float time, int mask)`
- Purpose: Core slide-move: iterates up to 4 bumps, clips velocity against encountered planes, detects floor/wall/dead-stop.
- Inputs: Entity, time step, collision mask.
- Outputs/Return: Bitmask — 1=floor hit, 2=wall/step hit, 4+3=dead stop.
- Side effects: Updates `ent->s.origin`, `ent->velocity`, `ent->groundentity`; calls `SV_Impact`.
- Calls: `gi.trace`, `SV_Impact`, `ClipVelocity`, `CrossProduct`, `DotProduct`, `VectorScale`.
- Notes: Crease handling (two planes): projects velocity along cross-product direction. Stops dead if resulting velocity opposes original to prevent oscillation.

### SV_PushEntity
- Signature: `trace_t SV_PushEntity(edict_t *ent, vec3_t push)`
- Purpose: Moves entity by `push` delta, links it, fires impact; retries if impacted entity was removed.
- Inputs: Entity, displacement vector.
- Outputs/Return: Collision trace.
- Side effects: Updates `ent->s.origin`; calls `gi.linkentity`, `SV_Impact`, `G_TouchTriggers`.
- Notes: `goto retry` loop handles the case where the blocking entity is removed by impact and the push should reattempt.

### Notes
- `SV_RunThink`: fires `ent->think` if `nextthink` is due; resets `nextthink` to 0 afterward.
- `SV_TestEntityPosition`: zero-length trace to detect if entity is currently embedded in solid; returns `g_edicts` (world) on startsolid.
- `SV_CheckVelocity`: clamps each velocity component to `±sv_maxvelocity`.
- `ClipVelocity`: reflects velocity off a plane with configurable overbounce; zeroes components below `STOP_EPSILON`.
- `SV_AddGravity`, `SV_AddRotationalFriction`: simple per-frame integrators.

## Control Flow Notes
`G_RunEntity` is called once per entity per server frame (from the game's `RunFrame`). It calls `prethink` first, then branches to a physics routine, which in turn calls `SV_RunThink`. Pusher physics run think only on success; step/toss physics always run think.

## External Dependencies
- `g_local.h` — entity definitions, game imports (`gi`), cvars (`sv_gravity`, `sv_maxvelocity`), constants (`FRAMETIME`, `MAX_EDICTS`, movetypes, masks)
- `gi.trace`, `gi.linkentity`, `gi.sound`, `gi.positioned_sound`, `gi.soundindex`, `gi.pointcontents`, `gi.error` — engine imports
- `M_CheckGround`, `M_CheckBottom` — defined in `m_move.c`
- `G_TouchTriggers` — defined in `g_utils.c`
- `AngleVectors`, `CrossProduct`, `DotProduct`, `VectorMA`, `VectorScale` — math utilities from `q_shared`
