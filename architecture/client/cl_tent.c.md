# client/cl_tent.c

## File Purpose
Manages client-side temporary entities (TEnts): transient visual and audio effects that do not exist as server entities. Handles parsing of TEnt network messages, allocating/updating explosion/beam/laser/sustain slots, and submitting renderable entities each frame.

## Core Responsibilities
- Parse `TE_*` temporary entity messages from the server and dispatch to particle/sound/model effects
- Maintain fixed-size pools for explosions, beams, player-linked beams, lasers, and sustained effects
- Animate and submit explosion entities to the renderer each frame via `CL_AddExplosions`
- Segment and submit beam entities (parasite, grapple, lightning, heatbeam) via `CL_AddBeams` / `CL_AddPlayerBeams`
- Submit active laser entities each frame via `CL_AddLasers`
- Tick sustained particle effects (steam, widow beam, nuke blast) via `CL_ProcessSustain`
- Register all TEnt sounds and models at map load time

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `exptype_t` | enum | Classifies explosion slot state/animation type (`ex_free`, `ex_explosion`, `ex_misc`, `ex_flash`, `ex_mflash`, `ex_poly`, `ex_poly2`) |
| `explosion_t` | struct | One pooled explosion slot: holds `entity_t`, frame count, light color/radius, start time, base frame |
| `beam_t` | struct | One pooled beam slot: source/dest entity IDs, model, end time, offset, start/end positions |
| `laser_t` | struct | One pooled laser slot: `entity_t` (RF_BEAM flag), end time |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `cl_explosions` | `explosion_t[32]` | global | Pool of active explosion effects |
| `cl_beams` | `beam_t[32]` | global | Pool of world-space beams |
| `cl_playerbeams` | `beam_t[32]` | global | Pool of player-locked beams (heatbeam) |
| `cl_lasers` | `laser_t[32]` | global | Pool of laser line effects |
| `cl_sustains` | `cl_sustain_t[MAX_SUSTAINS]` | global | Pool of sustained particle emitters (defined in client.h) |
| `cl_sfx_ric1..3`, `cl_sfx_lashit`, etc. | `sfx_s *` | global | Cached sound handles for impact/explosion effects |
| `cl_mod_explode`, `cl_mod_explo4`, `cl_mod_bfg_explo`, etc. | `model_s *` | global | Cached model handles for TEnt visuals |
| `splash_color[]` | `byte[7]` | static (file) | Color palette indices for splash particle types |

## Key Functions

### CL_RegisterTEntSounds
- **Signature:** `void CL_RegisterTEntSounds(void)`
- **Purpose:** Loads all sound assets used by temporary entities into the sound system cache.
- **Inputs:** None
- **Outputs/Return:** None; populates global `cl_sfx_*` pointers
- **Side effects:** Calls `S_RegisterSound`; also registers footstep and fall sounds (side-registered for precache)
- **Calls:** `S_RegisterSound`, `Com_sprintf`, `sprintf`
- **Notes:** Must be called once per map load before any TEnts fire.

### CL_RegisterTEntModels
- **Signature:** `void CL_RegisterTEntModels(void)`
- **Purpose:** Registers all model and pic assets used by TEnts with the renderer.
- **Inputs:** None
- **Outputs/Return:** None; populates global `cl_mod_*` pointers
- **Side effects:** Calls `re.RegisterModel`, `re.RegisterPic`
- **Calls:** `re.RegisterModel`, `re.RegisterPic`

### CL_ClearTEnts
- **Signature:** `void CL_ClearTEnts(void)`
- **Purpose:** Zeroes all TEnt pools on level change/map load.
- **Side effects:** `memset` on all five pools.

### CL_AllocExplosion
- **Signature:** `explosion_t *CL_AllocExplosion(void)`
- **Purpose:** Returns a free explosion slot, or evicts the oldest active one if the pool is full.
- **Inputs:** None (reads `cl.time`)
- **Outputs/Return:** Pointer to a zeroed `explosion_t`
- **Notes:** Never returns NULL; overflow silently recycles the oldest entry.

### CL_ParseTEnt
- **Signature:** `void CL_ParseTEnt(void)`
- **Purpose:** Central dispatcher: reads the `TE_*` type byte from `net_message`, then reads type-specific data and triggers the appropriate particle, sound, explosion, beam, or laser effect.
- **Inputs:** Reads from global `net_message`
- **Outputs/Return:** None
- **Side effects:** Allocates from effect pools; calls `S_StartSound`, `V_AddEntity` indirectly via helpers; calls `CL_ParticleEffect`, `CL_RailTrail`, beam parsers, etc.
- **Calls:** `MSG_ReadByte/Short/Pos/Dir/Long`, `CL_AllocExplosion`, `CL_ParseBeam`, `CL_ParseBeam2`, `CL_ParsePlayerBeam`, `CL_ParseLightning`, `CL_ParseLaser`, `CL_ParseSteam`, `CL_ParseWidow`, `CL_ParseNuke`, `S_StartSound`, all `CL_*Particles*` variants
- **Notes:** Falls through to `Com_Error(ERR_DROP)` on unknown type.

### CL_AddBeams
- **Signature:** `void CL_AddBeams(void)`
- **Purpose:** Each frame, iterates `cl_beams`; computes yaw/pitch from start→end, then subdivides the beam into model-length segments and calls `V_AddEntity` for each.
- **Side effects:** Calls `V_AddEntity` (renderer submission); updates `b->start` for player-origin beams.
- **Notes:** Lightning model uses 35-unit segments and handles the short-beam flip case.

### CL_AddPlayerBeams
- **Signature:** `void CL_AddPlayerBeams(void)`
- **Purpose:** Same segmentation logic as `CL_AddBeams` but for `cl_playerbeams`; handles heatbeam gun-offset interpolation from player state and calls `CL_Heatbeam` for first-person particle effect.
- **Side effects:** Reads `cl.frame.playerstate`, `cl.frames[]`, `cl.v_right/forward/up`; calls `V_AddEntity`, `CL_Heatbeam`, `CL_MonsterPlasma_Shell`.

### CL_AddExplosions
- **Signature:** `void CL_AddExplosions(void)`
- **Purpose:** Each frame, advances explosion animation frames, sets alpha/skinnum by type, emits dynamic light via `V_AddLight`, and submits entity via `V_AddEntity`.
- **Side effects:** Frees expired slots (`ex_free`), calls `V_AddLight`, `V_AddEntity`.

### CL_AddTEnts
- **Signature:** `void CL_AddTEnts(void)`
- **Purpose:** Per-frame entry point that calls all four add functions and `CL_ProcessSustain`.
- **Calls:** `CL_AddBeams`, `CL_AddPlayerBeams`, `CL_AddExplosions`, `CL_AddLasers`, `CL_ProcessSustain`

## Control Flow Notes
- **Init:** `CL_RegisterTEntSounds` and `CL_RegisterTEntModels` called at map load; `CL_ClearTEnts` called on level clear.
- **Per network message:** `CL_ParseTEnt` called from the packet parse loop when a `svc_temp_entity` message is received.
- **Per frame:** `CL_AddTEnts` called from the client view update path to submit all live TEnts to the renderer for the current frame.

## External Dependencies
- `client.h` — pulls in `entity_t`, `client_state_t cl`, `cl_sustain_t`, `net_message`, `frame_t`, `player_state_t`
- `MSG_Read*` — defined in `qcommon/net_chan.c` / `common.c`
- `S_RegisterSound`, `S_StartSound` — sound system
- `re.RegisterModel`, `re.RegisterPic`, `V_AddEntity`, `V_AddLight` — renderer interface
- `CL_ParticleEffect`, `CL_RailTrail`, `CL_BubbleTrail`, `CL_Heatbeam`, `CL_ParticleSteamEffect2`, `CL_Widowbeamout`, `CL_Nukeblast`, `CL_TeleportParticles`, etc. — defined in `cl_fx.c` / `cl_newfx.c`
- `hand` cvar — defined elsewhere, used for handedness in `CL_AddPlayerBeams`
