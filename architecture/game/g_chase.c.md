# game/g_chase.c

## File Purpose
Implements the spectator chase-camera system for Quake 2's game module. Allows spectating players to follow active (non-spectator) players in third-person, with camera positioning, collision avoidance, and dead-player view handling.

## Core Responsibilities
- Compute and update the chase camera position behind the target player each frame
- Perform geometry traces to avoid clipping the camera through walls and floors/ceilings
- Cycle forward/backward through chaseable (non-spectator) players
- Find an initial valid chase target when a spectator enters chase mode
- Mirror target player's view angles to the spectating client's player state
- Handle edge cases: target disconnected, target became spectator, target dead

## Key Types / Data Structures
None (uses types defined in `g_local.h`).

## Global / File-Static State
None.

## Key Functions

### UpdateChaseCam
- **Signature:** `void UpdateChaseCam(edict_t *ent)`
- **Purpose:** Repositions the spectator entity's origin and view angles to follow its `chase_target` each frame. Handles target validity, dead-target view, and traces to prevent camera clipping.
- **Inputs:** `ent` — the spectating client entity.
- **Outputs/Return:** void; modifies `ent->s.origin`, `ent->client->ps`, `ent->client->v_angle`, `ent->viewheight`.
- **Side effects:** Calls `gi.trace` (up to 3 times) and `gi.linkentity`. May call `ChaseNext` to replace an invalid target. Clears `chase_target` and `PMF_NO_PREDICTION` if no valid target is found.
- **Calls:** `ChaseNext`, `AngleVectors`, `VectorNormalize`, `VectorMA`, `VectorCopy`, `gi.trace`, `gi.linkentity`, `ANGLE2SHORT`.
- **Notes:** Pitches the camera to max 56° to avoid flipping. Offsets camera 30 units behind the target along forward vector. Adds 16-unit vertical offset when target is airborne. Two sequential floor/ceiling traces pad the goal position by ±6 units. Dead targets force a fixed tilt/roll view using `killer_yaw`.

### ChaseNext
- **Signature:** `void ChaseNext(edict_t *ent)`
- **Purpose:** Advances the spectator's chase target forward through the client slot array, skipping spectators and unused slots.
- **Inputs:** `ent` — the spectating client entity.
- **Outputs/Return:** void; sets `ent->client->chase_target` and `update_chase = true`.
- **Side effects:** Wraps around `maxclients` boundary. Terminates when it has cycled back to the original target (no valid non-spectator found).
- **Calls:** None beyond pointer arithmetic on `g_edicts`.
- **Notes:** If no valid target exists the loop exits pointing back at the original target unchanged.

### ChasePrev
- **Signature:** `void ChasePrev(edict_t *ent)`
- **Purpose:** Same as `ChaseNext` but iterates backward through client slots.
- **Inputs/Outputs:** Mirror of `ChaseNext`.
- **Notes:** Wraps from slot 1 down to `maxclients`.

### GetChaseTarget
- **Signature:** `void GetChaseTarget(edict_t *ent)`
- **Purpose:** Scans all client slots to assign the first valid non-spectator as the initial chase target, then calls `UpdateChaseCam`.
- **Inputs:** `ent` — the spectating client requesting chase mode.
- **Outputs/Return:** void; sets `chase_target` and calls `UpdateChaseCam`, or prints a center message if no valid player exists.
- **Side effects:** Calls `gi.centerprintf` when no chaseable player is found.
- **Calls:** `UpdateChaseCam`, `gi.centerprintf`.

## Control Flow Notes
`GetChaseTarget` is called once when a spectator enters chase mode. `UpdateChaseCam` is called every server frame (from player think logic) to keep the camera current. `ChaseNext`/`ChasePrev` are called in response to player input commands.

## External Dependencies
- `g_local.h` — entity definitions, `gclient_t`, `gi` interface, `g_edicts`, `maxclients`
- `gi.trace`, `gi.linkentity`, `gi.centerprintf` — engine callbacks (defined elsewhere)
- `AngleVectors`, `VectorMA`, `VectorNormalize`, `VectorCopy`, `ANGLE2SHORT` — math utilities (defined elsewhere)
- `PMF_NO_PREDICTION`, `PM_DEAD`, `PM_FREEZE`, `MASK_SOLID` — engine constants (defined elsewhere)
