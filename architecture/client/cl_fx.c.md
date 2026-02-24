# client/cl_fx.c

## File Purpose
Handles all client-side visual and audio effects parsing and management, including light styles, dynamic lights (dlights), particles, muzzle flashes, and entity event responses. Acts as the bridge between server-sent effect messages and renderer/audio submission calls.

## Core Responsibilities
- Parse and dispatch player muzzle flash messages (`MZ_*`) and monster muzzle flash messages (`MZ2_*`)
- Manage the dynamic light pool: allocation, decay, and submission to the renderer
- Manage the particle free-list/active-list pool and per-frame simulation/submission
- Animate and submit light styles to the view system each frame
- Emit particles for trails, explosions, teleports, weapon effects, and environmental events
- Handle per-entity events (footsteps, teleports, item respawns, falls) via `CL_EntityEvent`
- Clear all effect state on level load via `CL_ClearEffects`

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `clightstyle_t` | struct | Stores a parsed light style: animated map string, current RGB value, and length |
| `cdlight_t` | struct (defined in `client.h`) | Dynamic light with origin, radius, color, key, die time, decay rate |
| `cparticle_t` | struct (defined in `client.h`) | Single particle with position, velocity, acceleration, color, alpha, and fade rate |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `cl_lightstyle` | `clightstyle_t[MAX_LIGHTSTYLES]` | global | All active light style entries |
| `lastofs` | `int` | global | Last light style animation tick offset; used to skip redundant updates |
| `cl_dlights` | `cdlight_t[MAX_DLIGHTS]` | global | Dynamic light pool |
| `avelocities` | `vec3_t[NUMVERTEXNORMALS]` | static | Random angular velocities for BFG/fly orbital particle effects |
| `active_particles` | `cparticle_t *` | global | Head of the active particle linked list |
| `free_particles` | `cparticle_t *` | global | Head of the free particle linked list |
| `particles` | `cparticle_t[MAX_PARTICLES]` | global | Raw particle storage pool |
| `cl_numparticles` | `int` | global | Total particle count (== `MAX_PARTICLES`) |

## Key Functions

### CL_ClearLightStyles
- **Signature:** `void CL_ClearLightStyles(void)`
- **Purpose:** Resets all light style data and the animation offset.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** Zeroes `cl_lightstyle[]`, sets `lastofs = -1`
- **Calls:** `memset`
- **Notes:** Called from `CL_ClearEffects` on level transitions.

### CL_RunLightStyles
- **Signature:** `void CL_RunLightStyles(void)`
- **Purpose:** Advances light style animation once per 100ms tick, updating each style's current RGB value from its map string.
- **Inputs:** None (reads `cl.time`)
- **Outputs/Return:** None
- **Side effects:** Writes `ls->value[0..2]` for all active styles
- **Calls:** None
- **Notes:** Early-out if `ofs == lastofs`; styles with `length == 0` default to white (1.0).

### CL_SetLightstyle
- **Signature:** `void CL_SetLightstyle(int i)`
- **Purpose:** Parses a config string light style into the normalized float map for style slot `i`.
- **Inputs:** `i` — light style index
- **Outputs/Return:** None
- **Side effects:** Writes `cl_lightstyle[i]`
- **Calls:** `strlen`, `Com_Error`
- **Notes:** Map values normalized from `'a'..'m'` to `[0..1]`.

### CL_AddLightStyles
- **Signature:** `void CL_AddLightStyles(void)`
- **Purpose:** Submits all light styles to the view/renderer each frame.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** Calls `V_AddLightStyle` for every slot
- **Calls:** `V_AddLightStyle`

### CL_AllocDlight
- **Signature:** `cdlight_t *CL_AllocDlight(int key)`
- **Purpose:** Allocates a dlight slot by key match, then by expiry, then by eviction of slot 0.
- **Inputs:** `key` — entity number or 0
- **Outputs/Return:** Pointer to zeroed `cdlight_t`
- **Side effects:** Writes into `cl_dlights[]`
- **Calls:** `memset`
- **Notes:** Key-based lookup allows an entity to own and update the same dlight every frame.

### CL_RunDLights
- **Signature:** `void CL_RunDLights(void)`
- **Purpose:** Decays dlight radii over time and expires lights past their die time.
- **Inputs:** None (reads `cl.time`, `cls.frametime`)
- **Outputs/Return:** None
- **Side effects:** Modifies `dl->radius` in `cl_dlights[]`
- **Notes:** Returns immediately on first expired light (possible early-exit bug when multiple lights expire simultaneously).

### CL_AddDLights
- **Signature:** `void CL_AddDLights(void)`
- **Purpose:** Submits all active dlights to the renderer via `V_AddLight`.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** For software renderer, converts negative-color tracker lights to inverted white
- **Calls:** `V_AddLight`
- **Notes:** Branches on `vidref_val == VIDREF_GL` to handle negative-light dlight workaround for software mode.

### CL_ParseMuzzleFlash
- **Signature:** `void CL_ParseMuzzleFlash(void)`
- **Purpose:** Reads player muzzle flash packet, allocates a dlight at the weapon barrel, and plays the corresponding weapon sound.
- **Inputs:** Network message (`net_message`)
- **Outputs/Return:** None
- **Side effects:** Allocates dlight, calls `S_StartSound`, may call `CL_LogoutEffect`
- **Calls:** `MSG_ReadShort`, `MSG_ReadByte`, `CL_AllocDlight`, `AngleVectors`, `VectorMA`, `VectorCopy`, `S_StartSound`, `S_RegisterSound`, `CL_LogoutEffect`, `Com_Error`, `Com_sprintf`
- **Notes:** Handles `MZ_SILENCED` flag; covers all player weapons plus login/logout/respawn special effects.

### CL_ParseMuzzleFlash2
- **Signature:** `void CL_ParseMuzzleFlash2(void)`
- **Purpose:** Reads monster muzzle flash packet, computes barrel origin from `monster_flash_offset` table, allocates dlight, and plays attack sounds.
- **Inputs:** Network message (`net_message`)
- **Outputs/Return:** None
- **Side effects:** Allocates dlight, calls `S_StartSound`, may call `CL_ParticleEffect` / `CL_SmokeAndFlash`
- **Calls:** `MSG_ReadShort`, `MSG_ReadByte`, `AngleVectors`, `CL_AllocDlight`, `S_StartSound`, `S_RegisterSound`, `CL_ParticleEffect`, `CL_SmokeAndFlash`, `Com_Error`, `Com_sprintf`
- **Notes:** Covers all monster types; `monster_flash_offset` is defined elsewhere.

### CL_ClearParticles
- **Signature:** `void CL_ClearParticles(void)`
- **Purpose:** Re-initializes the particle free-list, linking all slots together.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** Writes `free_particles`, `active_particles`, and all `particles[].next`

### CL_AddParticles
- **Signature:** `void CL_AddParticles(void)`
- **Purpose:** Per-frame simulation and renderer submission of all active particles. Fades out expired particles and returns them to the free list.
- **Inputs:** None (reads `cl.time`)
- **Outputs/Return:** None
- **Side effects:** Rebuilds `active_particles` list, calls `V_AddParticle`, returns dead particles to `free_particles`
- **Calls:** `V_AddParticle`
- **Notes:** Supports `INSTANT_PARTICLE` alphavel sentinel for heat beam single-frame particles; integrates position with velocity and acceleration.

### CL_EntityEvent
- **Signature:** `void CL_EntityEvent(entity_state_t *ent)`
- **Purpose:** Dispatches client-side sound and particle effects for entity-embedded events (footsteps, teleports, item respawns, fall damage).
- **Inputs:** `ent` — entity state containing `event` and `origin`
- **Outputs/Return:** None
- **Side effects:** Calls `S_StartSound`, particle emitters
- **Calls:** `S_StartSound`, `S_RegisterSound`, `CL_ItemRespawnParticles`, `CL_TeleportParticles`

- **Notes (trail/emitter helpers):** `CL_BlasterTrail`, `CL_RailTrail`, `CL_RocketTrail`, `CL_DiminishingTrail`, `CL_QuadTrail`, `CL_FlagTrail`, `CL_BubbleTrail`, `CL_IonripperTrail` all follow the same pattern: walk a step-vector from `start` to `end`, allocating particles at each step from the free list.

## Control Flow Notes
- **Init:** `CL_ClearEffects` → `CL_ClearParticles` + `CL_ClearDlights` + `CL_ClearLightStyles`, called on level load.
- **Per-frame update:** `CL_RunLightStyles` and `CL_RunDLights` advance animation state; `CL_AddLightStyles`, `CL_AddDLights`, and `CL_AddParticles` submit to the renderer during scene building (`cl_view.c`).
- **Network parse:** `CL_ParseMuzzleFlash` and `CL_ParseMuzzleFlash2` called from the server message parser (`cl_parse.c`) when `svc_muzzleflash` / `svc_muzzleflash2` messages arrive.

## External Dependencies
- **Notable includes:** `client.h` (pulls in all client types, `cl`, `cls`, `cl_entities`, `net_message`)
- **External symbols used but not defined here:**
  - `V_AddLight`, `V_AddLightStyle`, `V_AddParticle` — renderer submission (defined in `cl_view.c` / ref layer)
  - `S_StartSound`, `S_RegisterSound` — audio system
  - `MSG_ReadShort`, `MSG_ReadByte` — network message parsing
  - `monster_flash_offset` — monster barrel offset table (defined in `m_flash.c`)
  - `bytedirs`, `NUMVERTEXNORMALS` — normal table (shared header)
  - `cl_footsteps`, `cl_sfx_footsteps` — cvar and sfx array (defined in `cl_main.c`)
  - `CL_SmokeAndFlash` — defined in `cl_newfx.c`
  - `vidref_val` — renderer backend identifier (defined elsewhere)
  - `AngleVectors`, `VectorMA`, `VectorNormalize`, `CrossProduct`, `MakeNormalVectors` — math utilities
