# ctf/g_chase.c

## File Purpose
Implements the spectator chase-camera system for the CTF game module. It positions a spectating client's view behind a target player each frame and provides navigation functions to cycle through valid chase targets.

## Core Responsibilities
- Each frame, compute and set the chase camera's world position behind the target player
- Clamp the camera using solid-geometry traces to avoid clipping into walls, floors, and ceilings
- Freeze the spectator's movement and suppress client-side prediction
- Sync the spectator's view angles to the target's view angles
- Send a periodic HUD layout string showing the target's name
- Provide forward/backward iteration over connected, solid (alive) clients

## Key Types / Data Structures
None (uses types defined in `g_local.h`).

## Global / File-Static State
None declared in this file.

## Key Functions

### UpdateChaseCam
- **Signature:** `void UpdateChaseCam(edict_t *ent)`
- **Purpose:** Repositions the spectating entity's origin and view each frame to follow its `chase_target`.
- **Inputs:** `ent` — the spectating client entity.
- **Outputs/Return:** void; mutates `ent->s.origin`, `ent->client->ps`, `ent->client->v_angle`, `ent->viewheight`.
- **Side effects:** Calls `gi.trace` (up to 3 traces), `gi.linkentity`, and conditionally `gi.WriteByte`/`gi.WriteString`/`gi.unicast` to push a layout update to the spectator. Clears `chase_target` if target is no longer in use.
- **Calls:** `VectorCopy`, `VectorMA`, `VectorNormalize`, `AngleVectors`, `ANGLE2SHORT`, `gi.trace`, `gi.linkentity`, `gi.WriteByte`, `gi.WriteString`, `gi.unicast`, `sprintf`.
- **Notes:** Camera is placed 30 units behind the target along the target's forward vector. Pitch is clamped to 56° to prevent extreme downward sweeps. Three successive traces handle wall obstruction, ceiling pad (+6 Z), and floor pad (-6 Z). HUD string is refreshed every 32 frames or when `update_chase` is set.

### ChaseNext
- **Signature:** `void ChaseNext(edict_t *ent)`
- **Purpose:** Advances `chase_target` forward through the client slot array to the next valid, solid (alive) client.
- **Inputs:** `ent` — the spectating client.
- **Outputs/Return:** void; sets `ent->client->chase_target` and `ent->client->update_chase = true`.
- **Side effects:** Modifies client state; wraps around at `maxclients->value`.
- **Calls:** Array pointer arithmetic on `g_edicts`.
- **Notes:** Skips slots where `!e->inuse` or `e->solid == SOLID_NOT` (dead/spectating players). Loop terminates when it returns to the original target if no other valid target exists.

### ChasePrev
- **Signature:** `void ChasePrev(edict_t *ent)`
- **Purpose:** Same as `ChaseNext` but iterates in reverse order through client slots.
- **Inputs/Outputs/Side effects:** Identical in structure to `ChaseNext`.
- **Calls:** Array pointer arithmetic on `g_edicts`.
- **Notes:** Wraps from slot 1 back to `maxclients->value`.

## Control Flow Notes
`UpdateChaseCam` is called once per server frame for each spectating client (from the CTF player frame update path). `ChaseNext`/`ChasePrev` are called in response to player commands (e.g., `+attack`/`+use` while spectating).

## External Dependencies
- **Includes:** `g_local.h` (pulls in `game.h`, `q_shared.h`, entity/client definitions)
- **External symbols used:**
  - `g_edicts` — global entity array (defined in `g_main.c`)
  - `maxclients` — cvar pointer (defined in `g_main.c`)
  - `level` — `level_locals_t` (defined in `g_main.c`)
  - `gi` — `game_import_t` vtable (provided by the engine)
  - `vec3_origin`, `MASK_SOLID`, `PM_FREEZE`, `PMF_NO_PREDICTION`, `svc_layout` — defined in shared/engine headers
