# client/cl_ents.c

## File Purpose
Handles client-side entity frame parsing, delta decompression, and rendering submission. Each frame, it reconstructs the full entity list from server-sent deltas, interpolates positions/angles between frames, and emits renderable entities with appropriate visual effects and particle trails to the refresh subsystem.

## Core Responsibilities
- Parse `svc_packetentities` delta streams from the network message buffer
- Maintain the `cl_entities` array with current/previous state for interpolation
- Parse per-frame player state (`svc_playerinfo`) including pmove, viewangles, and HUD stats
- Build `cl.refdef` view parameters (origin, angles, FOV, blend) each render frame
- Submit interpolated world entities to the renderer via `V_AddEntity`
- Spawn particle trails, dynamic lights, and effect particles per entity effects flags
- Fire one-shot entity events (teleport, etc.) and handle `EF_TELEPORTER` continuously
- Resolve sexed (player-model-relative) weapon model paths for custom player skins

## Key Types / Data Structures
| Name | Kind | Purpose |
|------|------|---------|
| `frame_t` | struct (external) | One server frame: validity, serverframe number, playerstate, entity list slice |
| `entity_state_t` | struct (external) | Network-serialized per-entity state (origin, angles, model indices, effects, etc.) |
| `centity_t` | struct (external) | Client-side entity: current + prev states, lerp_origin, trailcount, serverframe |
| `player_state_t` | struct (external) | Player-specific state: pmove, viewangles, gunindex/frame, blend, stats, FOV |
| `entity_t` | struct (external) | Renderer-facing entity descriptor passed to `V_AddEntity` |
| `clientinfo_t` | struct (external) | Per-client skin/model/weapon model cache |

## Global / File-Static State
| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `vidref_val` | `int` | global | Video renderer type (GL vs software) used to invert tracker light signs |
| `bitcounts[32]` | `int[32]` | file-static (comment says profiling) | Counts per-bit frequency of entity update flags for protocol profiling |

## Key Functions

### CL_ParseEntityBits
- **Signature:** `int CL_ParseEntityBits(unsigned *bits)`
- **Purpose:** Reads 1–4 bytes from `net_message` to reconstruct the full entity update bitmask and entity number.
- **Inputs:** Pointer to receive the combined bitmask.
- **Outputs/Return:** Entity number; `*bits` set to combined update flags.
- **Side effects:** Advances `net_message.readcount`; increments `bitcounts[]`.
- **Calls:** `MSG_ReadByte`, `MSG_ReadShort`
- **Notes:** Handles 8/16-bit entity numbers via `U_NUMBER16`; supports up to 32-bit bitmask via `U_MOREBITS1–3`.

### CL_ParseDelta
- **Signature:** `void CL_ParseDelta(entity_state_t *from, entity_state_t *to, int number, int bits)`
- **Purpose:** Applies a network delta to an entity state, reading only the fields flagged in `bits`.
- **Inputs:** Baseline/previous state, destination state, entity number, bitmask.
- **Outputs/Return:** Populates `*to` in place.
- **Side effects:** Advances `net_message.readcount`.
- **Calls:** `MSG_ReadByte`, `MSG_ReadShort`, `MSG_ReadLong`, `MSG_ReadCoord`, `MSG_ReadAngle`, `MSG_ReadPos`
- **Notes:** Combined `U_SKIN8|U_SKIN16` encodes a full 32-bit laser color; `U_EVENT` is cleared to 0 when absent (one-shot semantics).

### CL_DeltaEntity
- **Signature:** `void CL_DeltaEntity(frame_t *frame, int newnum, entity_state_t *old, int bits)`
- **Purpose:** Parses one entity delta, stores state into `cl_parse_entities`, and manages lerp initialization for new/teleporting entities.
- **Inputs:** Target frame, entity number, old state, update bitmask.
- **Side effects:** Writes to `cl_parse_entities[cl.parse_entities]`, increments `cl.parse_entities` and `frame->num_entities`; updates `cl_entities[newnum].prev/current/serverframe/lerp_origin/trailcount`.
- **Calls:** `CL_ParseDelta`, `VectorCopy`
- **Notes:** Forces `serverframe = -99` on model change, >512-unit teleport, or teleport events to suppress lerp artifacts.

### CL_ParsePacketEntities
- **Signature:** `void CL_ParsePacketEntities(frame_t *oldframe, frame_t *newframe)`
- **Purpose:** Drives the full entity list reconstruction: merges unchanged old entities, applies deltas, removes departed entities, and baselines new ones.
- **Side effects:** Calls `CL_DeltaEntity` repeatedly; reads `net_message` via `CL_ParseEntityBits`.
- **Calls:** `CL_ParseEntityBits`, `CL_DeltaEntity`, `Com_Error`, `Com_Printf`
- **Notes:** Terminates on `newnum == 0`; uses sentinel `oldnum = 99999` when old list is exhausted.

### CL_ParsePlayerstate
- **Signature:** `void CL_ParsePlayerstate(frame_t *oldframe, frame_t *newframe)`
- **Purpose:** Delta-decompresses the player state (pmove, view, gun, blend, stats) into `newframe->playerstate`.
- **Side effects:** Advances `net_message.readcount`; forces `PM_FREEZE` on `cl.attractloop` (demo playback).
- **Calls:** `MSG_ReadShort`, `MSG_ReadByte`, `MSG_ReadChar`, `MSG_ReadAngle16`, `MSG_ReadLong`

### CL_ParseFrame
- **Signature:** `void CL_ParseFrame(void)`
- **Purpose:** Top-level frame parser: reads server/delta frame numbers, validates delta, reads areabits, dispatches `CL_ParsePlayerstate` and `CL_ParsePacketEntities`, then activates the client if first valid frame.
- **Side effects:** Updates `cl.frame`, `cl.frames[]`, `cls.state → ca_active`, `cl.time`, `cl.sound_prepped`; calls `SCR_EndLoadingPlaque`, `CL_FireEntityEvents`, `CL_CheckPredictionError`.
- **Calls:** `MSG_ReadLong`, `MSG_ReadByte`, `MSG_ReadData`, `CL_ParsePlayerstate`, `CL_ParsePacketEntities`, `CL_FireEntityEvents`, `CL_CheckPredictionError`, `SCR_EndLoadingPlaque`, `Com_Error`, `Com_Printf`

### CL_AddPacketEntities
- **Signature:** `void CL_AddPacketEntities(frame_t *frame)`
- **Purpose:** Iterates the current frame's entity list; interpolates origins/angles; resolves models/skins; emits `entity_t` structs and effect particles/lights to the renderer.
- **Side effects:** Calls `V_AddEntity`, `V_AddLight`; spawns trails via `CL_RocketTrail`, `CL_BlasterTrail`, `CL_DiminishingTrail`, etc.; updates `cent->lerp_origin`.
- **Calls:** `V_AddEntity`, `V_AddLight`, `AngleVectors`, `VectorMA`, `LerpAngle`, `anglemod`, `re.RegisterSkin`, `re.RegisterModel`, and numerous `CL_*Trail`/`CL_*Particles` functions.
- **Notes:** `modelindex == 255` signals custom player skin; `modelindex2 == 255` signals custom weapon. `RF_USE_DISGUISE` swaps to disguise skin by model path prefix comparison.

### CL_CalcViewValues
- **Signature:** `void CL_CalcViewValues(void)`
- **Purpose:** Builds `cl.refdef` (vieworg, viewangles, FOV, blend) by interpolating between previous and current player states; uses predicted origin/angles when prediction is active.
- **Side effects:** Writes `cl.refdef.*`, `cl.v_forward/right/up`; calls `CL_AddViewWeapon`.
- **Calls:** `AngleVectors`, `LerpAngle`, `CL_AddViewWeapon`
- **Notes:** Detects teleport by >256-unit pmove origin jump and suppresses interpolation. Stair-step smoothing applied over 100 ms window.

### CL_AddEntities
- **Signature:** `void CL_AddEntities(void)`
- **Purpose:** Per-render-frame entry point: clamps `cl.lerpfrac`, then dispatches view, entity, temp-entity, particle, light, and lightstyle submissions.
- **Side effects:** Clamps `cl.time`; calls `CL_CalcViewValues`, `CL_AddPacketEntities`, `CL_AddTEnts`, `CL_AddParticles`, `CL_AddDLights`, `CL_AddLightStyles`.

### CL_FireEntityEvents
- **Signature:** `void CL_FireEntityEvents(frame_t *frame)`
- **Purpose:** Iterates all entities in a frame, dispatching one-shot events via `CL_EntityEvent` and continuous `EF_TELEPORTER` particle effects.
- **Calls:** `CL_EntityEvent`, `CL_TeleporterParticles`

### Notes
- `S_RegisterSexedModel`: resolves a model path relative to a player's configured model directory, falling back through weapon.md2 → male model → male/weapon.md2.
- `CL_AddViewWeapon`: emits the view weapon entity; respects `cl_gun` cvar and FOV > 90 suppression.
- `CL_GetEntitySoundOrigin`: returns `lerp_origin` for sound spatialization; bmodel accuracy noted as a FIXME.
- The projectile parsing block (`CL_ParseProjectiles`, `CL_AddProjectiles`, `CL_ClearProjectiles`) is entirely `#if 0`-disabled.

## Control Flow Notes
- **Per network message:** `CL_ParseFrame` is called from `cl_parse.c` on `svc_frame`; it populates `cl.frame` and `cl.frames[]`.
- **Per render frame:** `CL_AddEntities` is called from `cl_view.c:CL_ViewRender`; it computes `lerpfrac`, calls `CL_CalcViewValues` then `CL_AddPacketEntities`, then effect/particle subsystems.
- This file bridges the network layer (raw delta messages) and the renderer (entity_t submissions), sitting entirely within the client frame update path.

## External Dependencies
- **Includes:** `client.h` (pulls in all client state, cvars, renderer interface `re`, entity arrays)
- **Defined elsewhere:**
  - `cl`, `cls`, `cl_entities[]`, `cl_parse_entities[]` — global client state
  - `net_message` — incoming network message buffer
  - `re` — renderer export table (`RegisterModel`, `RegisterSkin`)
  - `V_AddEntity`, `V_AddLight` — view/renderer submission (`cl_view.c`)
  - `CL_AddTEnts`, `CL_AddParticles`, `CL_AddDLights`, `CL_AddLightStyles` — effect subsystems
  - `CL_*Trail`, `CL_*Particles`, `CL_EntityEvent` — effect generators (`cl_fx.c`, `cl_newfx.c`, `cl_tent.c`)
  - `CL_CheckPredictionError` — prediction subsystem (`cl_pred.c`)
  - `MSG_Read*` — network message decoding (`qcommon/net_chan.c` / `qcommon/common.c`)
  - `gun_model`, `gun_frame`, `cl_mod_powerscreen` — development/special model overrides
