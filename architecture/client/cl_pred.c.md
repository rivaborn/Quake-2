# client/cl_pred.c

## File Purpose
Implements client-side movement prediction for Quake 2, allowing the client to simulate player physics locally without waiting for server confirmation. Also handles prediction error correction and collision detection against client-visible entities.

## Core Responsibilities
- Run `Pmove` on unacknowledged user commands to predict player position
- Compare predicted origins against server-confirmed state to detect and smooth prediction errors
- Provide trace and point-contents callbacks to `Pmove` that clip against both world geometry and solid client entities
- Decode packed solid bounding boxes from entity state for client-side collision
- Detect and record stair-step events for view smoothing

## Key Types / Data Structures
| Name | Kind | Purpose |
|---|---|---|
| `pmove_t` | struct (external) | Full pmove state passed to `Pmove`; holds player state, callbacks, and current cmd |
| `trace_t` | struct (external) | Result of a collision trace; fraction, normal, startsolid, allsolid, ent |
| `usercmd_t` | struct (external) | A single client input command stored in `cl.cmds[]` ring buffer |
| `entity_state_t` | struct (external) | Per-entity snapshot state including encoded `solid` field, origin, angles |
| `cmodel_t` | struct (external) | Collision model; carries `headnode` for CM trace routines |

## Global / File-Static State
None.

## Key Functions

### CL_CheckPredictionError
- **Signature:** `void CL_CheckPredictionError(void)`
- **Purpose:** Compares the server-confirmed origin for the last acknowledged frame against what the client predicted, storing the delta for interpolation-based error correction.
- **Inputs:** `cl.frame.playerstate.pmove.origin`, `cl.predicted_origins[]`, `cls.netchan.incoming_acknowledged`
- **Outputs/Return:** Writes `cl.prediction_error[]`; may clear it on teleport (delta > 80 units).
- **Side effects:** Writes `cl.predicted_origins[frame]` with server-corrected value; prints to console if `cl_showmiss` is set.
- **Calls:** `VectorSubtract`, `VectorClear`, `VectorCopy`, `Com_Printf`
- **Notes:** Delta is in 1/8-unit fixed-point; threshold of 640 fixed units == 80 world units triggers teleport reset.

### CL_ClipMoveToEntities
- **Signature:** `void CL_ClipMoveToEntities(vec3_t start, vec3_t mins, vec3_t maxs, vec3_t end, trace_t *tr)`
- **Purpose:** Clips a movement trace against all solid entities in the current frame snapshot, merging results into an existing world-trace.
- **Inputs:** Ray endpoints/extents; existing `tr` from world trace.
- **Outputs/Return:** Modifies `*tr` in-place with closest hit or startsolid flags.
- **Side effects:** None beyond `*tr`.
- **Calls:** `CM_HeadnodeForBox`, `CM_TransformedBoxTrace`
- **Notes:** `solid == 31` signals a brush model entity; other values encode a bbox as `x | zd<<5 | zu<<10`. Skips the local player entity (`ent->number == cl.playernum+1`). Early-exit if `tr->allsolid`.

### CL_PMTrace
- **Signature:** `trace_t CL_PMTrace(vec3_t start, vec3_t mins, vec3_t maxs, vec3_t end)`
- **Purpose:** `Pmove` trace callback; traces against world then all solid entities.
- **Inputs:** Ray endpoints and box extents.
- **Outputs/Return:** Combined `trace_t`.
- **Side effects:** None.
- **Calls:** `CM_BoxTrace`, `CL_ClipMoveToEntities`
- **Notes:** Sets `t.ent = (edict_s*)1` as a sentinel when the world is hit.

### CL_PMpointcontents
- **Signature:** `int CL_PMpointcontents(vec3_t point)`
- **Purpose:** `Pmove` pointcontents callback; ORs world contents with contents from all bmodel entities.
- **Inputs:** World-space point.
- **Outputs/Return:** Combined content flags.
- **Side effects:** None.
- **Calls:** `CM_PointContents`, `CM_TransformedPointContents`
- **Notes:** Only checks `solid == 31` (bmodel) entities; box entities have no volume content.

### CL_PredictMovement
- **Signature:** `void CL_PredictMovement(void)`
- **Purpose:** Replays all unacknowledged user commands through `Pmove` to produce `cl.predicted_origin` and `cl.predicted_angles` for the current frame.
- **Inputs:** `cls.netchan` sequence numbers, `cl.cmds[]`, `cl.frame.playerstate.pmove`.
- **Outputs/Return:** Writes `cl.predicted_origin[3]`, `cl.predicted_angles[3]`, `cl.predicted_step`, `cl.predicted_step_time`.
- **Side effects:** Populates `cl.predicted_origins[]` ring buffer for every replayed frame.
- **Calls:** `Pmove`, `CL_PMTrace` (via callback), `CL_PMpointcontents` (via callback), `CM_...` (indirect), `Com_Printf`, `atof`
- **Notes:** Stair-step detection range is 63–160 fixed units (~8–20 world units) on-ground only. If prediction is disabled (`cl_predict` == 0 or `PMF_NO_PREDICTION`), only angles are set from delta_angles. Freezes if cmd ring is fully lapped (`current - ack >= CMD_BACKUP`).

## Control Flow Notes
Called each client frame from the view/render pipeline. `CL_CheckPredictionError` runs after a new server frame is parsed to record error. `CL_PredictMovement` runs every rendered frame to produce smooth predicted positions between server frames.

## External Dependencies
- **Includes:** `client.h`
- **External symbols:** `Pmove`, `CM_BoxTrace`, `CM_HeadnodeForBox`, `CM_TransformedBoxTrace`, `CM_PointContents`, `CM_TransformedPointContents`, `cl`, `cls`, `cl_parse_entities`, `cl_predict`, `cl_showmiss`, `cl_paused`, `pm_airaccelerate`, `CMD_BACKUP`, `MAX_PARSE_ENTITIES`, `SHORT2ANGLE`, `CS_AIRACCEL`
