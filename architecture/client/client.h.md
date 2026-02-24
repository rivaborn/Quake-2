# client/client.h

## File Purpose
Primary header for the Quake 2 client subsystem. Defines all major client-side data structures, global state, CVars, and function prototypes shared across client modules (input, parsing, prediction, effects, rendering, menus, demo recording).

## Core Responsibilities
- Defines the two central client state structs: `client_state_t` (per-connection) and `client_static_t` (persistent across connections)
- Declares all client-facing CVars for movement, rendering, audio, and networking
- Declares entity, particle, and dynamic light types used for client-side visual effects
- Provides prototypes for all inter-module client functions (cl_main, cl_input, cl_parse, cl_fx, cl_pred, cl_tent, cl_view, menus, demo)
- Defines enumerations for connection state, download type, and key destination
- Declares shared global arrays: `cl_entities`, `cl_dlights`, `cl_parse_entities`

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `frame_t` | struct | One server frame snapshot: player state, entity count, area bits, delta info |
| `centity_t` | struct | Client-side entity with baseline/current/prev states, lerp origin, trail data |
| `clientinfo_t` | struct | Player skin, icon, model, and weapon model info per client slot |
| `client_state_t` | struct | All per-connection client state; wiped on map change |
| `client_static_t` | struct | Persistent client state across connections: connection, download, demo recording |
| `connstate_t` | enum | Connection lifecycle: uninitialized → disconnected → connecting → connected → active |
| `dltype_t` | enum | Download asset category (model, sound, skin, single) |
| `keydest_t` | enum | Current keyboard routing target (game, console, message, menu) |
| `cdlight_t` | struct | Client dynamic light: origin, color, radius, decay, lifetime |
| `cparticle_t` | struct | Linked-list particle with position, velocity, acceleration, color, alpha |
| `cl_sustain_t` | struct | Persistent particle effect with a think callback (e.g., steam, widow beam) |
| `kbutton_t` | struct | Tracks key-down state for analog input buttons (two keys, msec timing) |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `cl` | `client_state_t` | global | Active per-connection client state |
| `cls` | `client_static_t` | global | Persistent client state across map/server changes |
| `cl_entities` | `centity_t[MAX_EDICTS]` | global | All client-side entity states |
| `cl_dlights` | `cdlight_t[MAX_DLIGHTS]` | global | Active dynamic lights |
| `cl_parse_entities` | `entity_state_t[MAX_PARSE_ENTITIES]` | global | Ring buffer of parsed entity states for delta decompression |
| `re` | `refexport_t` | global | Interface handle to the loaded renderer DLL |
| `net_from` | `netadr_t` | global | Source address of last received packet |
| `net_message` | `sizebuf_t` | global | Buffer holding the last received network message |
| `gun_frame` | `int` | global | Current debug/override gun animation frame |
| `gun_model` | `struct model_s *` | global | Debug/override gun model pointer |
| `cl_weaponmodels` | `char[][MAX_QPATH]` | global | Weapon model name list for vwep |
| `num_cl_weaponmodels` | `int` | global | Count of loaded weapon models |

## Key Functions
Declared here, defined across multiple `.c` files. No function bodies present in this header.

### Notable groups (summarized):
- **CL_Init / CL_Disconnect / CL_ClearState**: Lifecycle entry points for client startup, server disconnect, and state reset.
- **CL_SendCmd / CL_ReadPackets / CL_ParseServerMessage**: Per-frame network I/O pipeline.
- **CL_PredictMove / CL_CheckPredictionError**: Client-side movement prediction and error correction.
- **CL_AddEntities / CL_AddDLights / CL_AddTEnts / CL_AddParticles**: Per-frame scene population before renderer submission.
- **V_RenderView / V_AddEntity / V_AddLight / V_AddParticle**: Renderer-facing scene submission API.
- **CL_RunParticles / CL_RunDLights / CL_RunLightStyles**: Per-frame effect simulation.
- **M_Init / M_Draw / M_Keydown**: Menu subsystem lifecycle.
- **CL_Record_f / CL_Stop_f / CL_WriteDemoMessage**: Demo recording API.
- **CL_PrepRefresh / CL_RegisterSounds**: Level load asset precaching.

## Control Flow Notes
- `client_state_t cl` is fully wiped on each map change; `client_static_t cls` persists for the process lifetime.
- Per-frame flow: input (`CL_SendCmd`) → network read (`CL_ReadPackets`) → prediction (`CL_PredictMove`) → effect simulation (`CL_RunParticles`, `CL_RunDLights`) → scene build (`CL_AddEntities`, `CL_AddDLights`, etc.) → render submission (`V_RenderView`).
- `connstate_t` in `cls.state` gates which subsystems are active each frame.
- `keydest_t` in `cls.key_dest` routes keyboard events to game input, console, or menu.

## External Dependencies
- `ref.h`, `vid.h`, `screen.h`, `sound.h`, `input.h`, `keys.h`, `console.h`, `cdaudio.h` — all client subsystem headers
- `qcommon.h` (transitively via ref.h): `MAX_EDICTS`, `MAX_DLIGHTS`, `UPDATE_BACKUP`, `netchan_t`, `usercmd_t`, `entity_state_t`, `player_state_t`, `refdef_t`, `cvar_t`, `netadr_t`, `sizebuf_t`
- `refexport_t` — renderer DLL export table, defined in `ref.h`; actual DLL loaded at runtime
