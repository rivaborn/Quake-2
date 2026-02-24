# client/adivtab.h
## File Purpose
A precomputed lookup table of integer division quotient/remainder pairs for all combinations of numerator in [-15...16] and denominator in [-15...16]. It exists to replace costly integer division operations with a direct table lookup in the software renderer's inner loops.

## Core Responsibilities
- Provide all 32×32 = 1024 precomputed `{quotient, remainder}` pairs for integer division across the signed range [-15, 16].
- Eliminate runtime division in performance-critical rendering code paths.
- Handle the division-by-zero case (denominator = 0) gracefully by storing `{0, 0}`.

## External Dependencies
- No includes of its own.
- Depends entirely on the enclosing file to declare the array type (typically a struct with two `int` fields, `quotient` and `remainder`, or equivalent) before `#include`-ing this file.
- Defined elsewhere: the struct/array type into which these initializers are inserted.

# client/anorms.h
## File Purpose
A raw data table of 162 pre-computed unit normal vectors distributed approximately uniformly across the surface of a sphere. These are the Quake/id Software "anorms" (alias normals) used to represent lighting normals for alias (MD2) models in a compact, quantized form.

## Core Responsibilities
- Provides the 162-entry icosphere normal lookup table used by alias model lighting calculations
- Encodes each 3D normal as a `{x, y, z}` float triple, all unit-length (magnitude ≈ 1.0)
- Allows the engine to store a normal index (1 byte) in model data rather than 12 bytes of floats
- Shared across client rendering code and potentially software/GL renderers that include this header

## External Dependencies
- No `#include` directives present
- No external symbols referenced
- Consumed by: any `.c` file that declares an array and then `#include`s this file (e.g., `float r_avertexnormals[NUMVERTEXNORMALS][3] = { #include "anorms.h" }`)


# client/asm_i386.h
## File Purpose
A header file providing symbolic byte-offset constants for several engine C structures, enabling x86 assembly routines to access struct fields by offset rather than by name. It serves as the contract between C struct layouts and hand-written assembly code.

## Core Responsibilities
- Define byte-offset macros for `plane_t`, `hull_t`, `dnode_t`, `sfxcache_t`, `channel_t`, and `portable_samplepair_t` structs
- Provide a `C()` macro to handle ELF vs. non-ELF symbol naming conventions (underscore prefix)
- Document and enforce the structural contract between C headers and assembly files
- Define the `TRANSPARENT_COLOR` constant shared with `d_iface.h`

## External Dependencies
- **Notable includes:** None — self-contained.
- **External symbols used but not defined here:**
  - `plane_t` — defined in `model.h` (and referenced in BSP/collision code)
  - `hull_t` — defined in `model.h`
  - `dnode_t` — defined in `bspfile.h`
  - `sfxcache_t` — defined in `sound.h`
  - `channel_t` — defined in `sound.h`
  - `portable_samplepair_t` — defined in `sound.h`
  - `TRANSPARENT_COLOR` — must match `d_iface.h`


# client/block16.h
## File Purpose
An x86 AT&T-syntax assembly fragment (included as a header) implementing a hand-unrolled, bilinear-style block-drawing inner loop for 16-bit color mode. It processes pairs of 8-bit palette indices per iteration, looking them up in a 16-bit color translation table, and writes the resulting 16-bit pixels to the output framebuffer.

## Core Responsibilities
- Fetch two source texel indices per span step from a texture/span source (`%esi` + stride `%ebx`)
- Advance a fixed-point U/V coordinate accumulator (`%edx` += `%ebp`) for sub-texel stepping
- Perform palette/color-table lookups converting 8-bit indices to 16-bit RGB values via a patchable address (`0x12345678`)
- Write two 16-bit pixels at a time to the destination buffer (`%edi`), advancing by 4 bytes per block
- Provide multiple entry points (`LEnter16_16`, `LEnter8_16`, `LEnter4_16`, `LEnter2_16`) for power-of-two span lengths (16, 8, 4, 2 pixels), enabling a Duff's-device-style unrolled loop

## External Dependencies
- **No includes** — this file is itself an included fragment.
- `0x12345678` lookup table address: patched at runtime by the surrounding rasterizer initialization code (defined elsewhere).
- Register state: fully set up by the calling span-draw routine (defined elsewhere).

# client/block8.h
## File Purpose
Inline x86 AT&T-syntax assembly fragment implementing a bilinear-scaled 8-bit texture block-copy loop body. It is `#include`d directly into a C or assembly file that provides the surrounding loop/function scaffold. Implements the inner loop of an 8-bit software renderer texture scaling routine using patchable lookup-table addresses.

## Core Responsibilities
- Fetch two source texels per iteration from a texture source pointer (`%esi`) with a row-stride offset (`%ebx`)
- Perform sub-texel interpolation by using the high byte of a fixed-point accumulator (`%dh`) as a table index
- Look up final 8-bit palette-mapped pixel values via patchable base addresses (`0x12345678` placeholders, `LBPatch*`)
- Write two pixels per iteration to the destination buffer (`%edi`), advancing it by 2 bytes
- Provide multiple entry points (`LEnter16_8`, `LEnter8_8`, `LEnter4_8`, `LEnter2_8`) for loop unrolling at different counts (16, 8, 4, 2 pixels)

## External Dependencies
- No `#include` directives (raw assembly fragment).
- Depends on caller-established register conventions (`%esi`, `%ebx`, `%edx`, `%ebp`, `%edi`).
- `LBPatch0`–`LBPatch15`: self-modification targets — addresses written by surrounding C/asm code (defined elsewhere).
- Designed for x86 (IA-32) with AT&T syntax; GAS assembler or inline `asm` context assumed.

# client/cdaudio.h
## File Purpose
Public interface header for the CD audio subsystem. Declares the six lifecycle and control functions that the engine calls to manage CD music playback.

## Core Responsibilities
- Expose CD audio initialization and shutdown entry points
- Declare playback control functions (play, stop, update)
- Provide an activation toggle for focus/minimize handling

## External Dependencies
- `qboolean` — defined in `qcommon/qcommon.h` or `game/q_shared.h`; no includes are present in this header, so the including translation unit must provide it.

# client/cl_cin.c
## File Purpose
Implements Quake 2's cinematic playback system, supporting both animated `.cin` video files (Huffman-compressed, with raw PCM audio) and static `.pcx` images displayed fullscreen. It manages frame decoding, audio synchronization, palette activation, and lifecycle (play/stop/finish).

## Core Responsibilities
- Load and decode PCX images for static cinematic screens
- Parse `.cin` binary video files (width/height/audio metadata + Huffman table)
- Build per-context order-1 Huffman decoding trees from the file's 64k count table
- Decompress individual video frames via `Huff1Decompress`
- Synchronize video frame advancement to real time (14 fps)
- Feed raw PCM audio samples to the sound system per frame
- Manage palette switching via the renderer interface
- Signal the server to advance to the next map/cinematic when playback ends

## External Dependencies
- **Includes:** `client.h` (pulls in `cl`, `cls`, `viddef`, `re`, message/network types)
- **Defined elsewhere:** `FS_LoadFile`, `FS_FreeFile`, `FS_Read`, `FS_FOpenFile`, `Z_Malloc`, `Z_Free`, `S_RawSamples`, `CDAudio_Stop`, `CL_Snd_Restart_f`, `MSG_WriteByte`, `SZ_Print`, `re.CinematicSetPalette`, `re.DrawStretchRaw`, `SCR_BeginLoadingPlaque`, `SCR_EndLoadingPlaque`, `Sys_Milliseconds`, `Cvar_VariableValue`, `Cvar_SetValue`, `Com_Error`, `Com_Printf`, `Com_sprintf`

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

# client/cl_input.c
## File Purpose
Translates raw keyboard, mouse, and controller input into a `usercmd_t` movement command each frame, then transmits that command to the server. It manages the full lifecycle from key-press/release tracking through angle adjustment, button encoding, and delta-compressed network transmission.

## Core Responsibilities
- Track continuous key-button press/release state with dual-key overlap support (`kbutton_t`)
- Register all `+`/`-` console commands for movement, look, attack, use, etc.
- Compute per-frame movement fractions via `CL_KeyState` (time-weighted, not binary)
- Adjust view angles from keyboard look inputs (`CL_AdjustAngles`)
- Assemble a complete `usercmd_t` per frame (`CL_CreateCmd`)
- Encode buttons, angles, impulse, and ambient light level into the command (`CL_FinishMove`)
- Send three delta-compressed commands per packet for redundancy (`CL_SendCmd`)

## External Dependencies
- **Includes:** `client.h` (pulls in `kbutton_t`, `usercmd_t`, `cl`, `cls`, cvars, etc.)
- **Defined elsewhere:** `sys_frame_time` (platform layer), `IN_Move` (platform input: mouse/joystick), `Netchan_Transmit`, `MSG_Write*`, `COM_BlockSequenceCRCByte`, `SCR_FinishCinematic`, `CL_FixUpGender`, `anykeydown`, `cl_lightlevel`, `curtime`

# client/cl_inv.c
## File Purpose
Handles the client-side inventory UI: parsing inventory data from the server and rendering the inventory overlay screen during gameplay.

## Core Responsibilities
- Parse incoming inventory item counts from network messages into `cl.inventory[]`
- Render the inventory screen with item names, counts, and key bindings
- Scroll the inventory list to keep the selected item centered
- Highlight the currently selected item with a blinking cursor
- Look up key bindings for each inventory item's `use <item>` command

## External Dependencies
- **Includes:** `client.h` (pulls in `cl_parse`, `keys`, renderer refs, etc.)
- **External symbols used but not defined here:**
  - `cl` — global client state (`client_state_t`)
  - `cls` — global client static state (`client_static_t`), used for `realtime`
  - `net_message` — global incoming network message buffer
  - `viddef` — global video dimensions
  - `keybindings[]` — global key-to-command binding table
  - `re` — global renderer export struct (`refexport_t`)
  - `MSG_ReadShort`, `Com_sprintf`, `Q_stricmp`, `Key_KeynumToString`, `SCR_DirtyScreen` — defined elsewhere in engine

# client/cl_main.c
## File Purpose
The central client-side module for Quake 2, implementing the client main loop, connection lifecycle management, demo recording, cvar/command registration, and per-frame orchestration of all client subsystems.

## Core Responsibilities
- Manages the full client connection state machine (disconnected → connecting → connected → active)
- Drives the per-frame client tick: input, network, prediction, rendering, audio, effects
- Handles demo recording and playback setup
- Implements the precache/autodownload pipeline for assets before entering a server
- Registers all client-facing cvars and console commands at startup
- Enforces anti-cheat cvar resets in multiplayer
- Writes `config.cfg` on shutdown

## External Dependencies
- **Includes:** `client.h` (pulls in all client/shared headers)
- **Defined elsewhere:** `net_message`, `net_from`, `curtime`, `host_speeds`, `log_stats`, `log_stats_file`, `dedicated`, `userinfo_modified`, `allow_download*` cvars; `CL_ParseServerMessage`, `CL_PrepRefresh`, `CL_RegisterSounds`, `CL_CheckOrDownloadFile`, `CL_Download_f`, `CL_SendCmd`, `CL_PredictMovement`, `CL_ParseClientinfo`, `CM_LoadMap`, `numtexinfo`, `map_surfaces[]` (from `qcommon/cmodel.c`); all renderer entry points via `re` refexport struct.

# client/cl_newfx.c
## File Purpose
Implements an extended set of client-side particle and dynamic light effects for Quake 2, supplementing `cl_fx.c`. Contains visual effects introduced for newer weapons and enemies (CTF, Widow, Tracker, Heatbeam, etc.), operating entirely on the client particle/light systems.

## Core Responsibilities
- Spawn and configure `cparticle_t` entries from the free-list for trails, explosions, shells, and ambient effects
- Allocate `cdlight_t` dynamic lights for flashlight and colored flash effects
- Provide sustain-callback effects (`cl_sustain_t`) that re-fire on a timer (steam, widow beam, nuke blast)
- Implement the Heatbeam visual (compile-time switchable between CORKSCREW, RINGS, and SPRAY variants; RINGS active)
- Provide utility `vectoangles2` for converting a direction vector to Euler angles (client-local copy)

## External Dependencies
- `client.h` — `cparticle_t`, `cdlight_t`, `centity_t`, `cl_sustain_t`, `cl`, `vidref_val`, `PARTICLE_GRAVITY`, `INSTANT_PARTICLE`, `MAX_PARTICLES`, `VIDREF_GL`, `VIDREF_SOFT`
- `CL_AllocDlight` — defined in `cl_fx.c`
- `MakeNormalVectors` — defined in `cl_fx.c` (extern declared)
- `AngleVectors`, `VectorNormalize`, `VectorMA`, `DotProduct` — math utilities in `qcommon`
- `frand`, `crand` — random helpers defined elsewhere in client code

# client/cl_parse.c
## File Purpose
Parses and dispatches all server-to-client network messages received each frame. It handles the full lifecycle of server communication: connection handshaking, configuration, entity baselines, sound events, downloads, and per-frame game state updates.

## Core Responsibilities
- Dispatch incoming `svc_*` server messages via a central parse loop
- Manage in-progress file downloads (start, resume, block-by-block receive, rename on completion)
- Parse server connection data and initialize client state on connect
- Load and register player model/skin/weapon assets from configstrings
- Parse and apply configstrings (lights, models, sounds, images, player skins)
- Parse sound start packets with optional volume, attenuation, offset, and positional data
- Write demo data after frame parsing is complete

## External Dependencies
- **Includes:** `client.h` (pulls in all client state, `cls`, `cl`, `net_message`, cvar refs)
- **Defined elsewhere:** `net_message`, `cl`, `cls`, `con`, `re` (renderer export), `S_StartSound`, `S_BeginRegistration`, `S_EndRegistration`, `S_RegisterSound`, `CDAudio_Play`, `CM_InlineModel`, `FS_LoadFile`, `FS_Gamedir`, `FS_CreatePath`, `CL_ParseFrame`, `CL_ParseTEnt`, `CL_ParseMuzzleFlash`, `CL_ParseMuzzleFlash2`, `CL_ParseInventory`, `CL_ParseEntityBits`, `CL_ParseDelta`, `CL_RequestNextDownload`, `CL_WriteDemoMessage`, `CL_AddNetgraph`, `CL_SetLightstyle`, `CL_RegisterTEntSounds`, `SCR_PlayCinematic`, `SCR_CenterPrint`, `cl_shownet`, `cl_noskins`, `cl_vwep`, `cl_weaponmodels`, `num_cl_weaponmodels`

# client/cl_pred.c
## File Purpose
Implements client-side movement prediction for Quake 2, allowing the client to simulate player physics locally without waiting for server confirmation. Also handles prediction error correction and collision detection against client-visible entities.

## Core Responsibilities
- Run `Pmove` on unacknowledged user commands to predict player position
- Compare predicted origins against server-confirmed state to detect and smooth prediction errors
- Provide trace and point-contents callbacks to `Pmove` that clip against both world geometry and solid client entities
- Decode packed solid bounding boxes from entity state for client-side collision
- Detect and record stair-step events for view smoothing

## External Dependencies
- **Includes:** `client.h`
- **External symbols:** `Pmove`, `CM_BoxTrace`, `CM_HeadnodeForBox`, `CM_TransformedBoxTrace`, `CM_PointContents`, `CM_TransformedPointContents`, `cl`, `cls`, `cl_parse_entities`, `cl_predict`, `cl_showmiss`, `cl_paused`, `pm_airaccelerate`, `CMD_BACKUP`, `MAX_PARSE_ENTITIES`, `SHORT2ANGLE`, `CS_AIRACCEL`

# client/cl_scrn.c
## File Purpose
Master screen compositor for the Quake 2 client. Orchestrates every per-frame 2D overlay (HUD, console, center print, loading plaque, debug graphs) and drives the renderer's frame begin/end cycle. Acts as the top-level coordinator between all client subsystems that produce visible output.

## Core Responsibilities
- Initialize and manage screen-related cvars and console commands
- Drive `SCR_UpdateScreen`, the single entry point for all rendering each frame
- Animate the drop-down console (`SCR_RunConsole`)
- Render the HUD via a server-supplied layout string (`SCR_ExecuteLayoutString`)
- Maintain the dirty-rectangle system for background tile clearing
- Display center-print messages, pause overlay, loading plaque, and network/debug graphs
- Handle stereoscopic rendering (dual-frame separation pass)

## External Dependencies
- **Notable includes:** `client.h` (pulls in all client/common headers)
- **Defined elsewhere:** `re` (refexport_t — renderer API struct), `cls` (client_static_t), `cl` (client_state_t), `viddef`, `con`, `cl_paused`, `cl_stereo`, `cl_stereo_separation`, `crosshair`, `developer`; `V_RenderView`, `CL_DrawInventory`, `M_Draw`, `Con_DrawConsole`, `Con_DrawNotify`, `Con_CheckResize`, `Con_ClearNotify`, `S_StopAllSounds`, `CDAudio_Stop`, `SCR_DrawCinematic`, `DrawString`, `DrawAltString`, `Sys_Milliseconds`, `COM_Parse`, `Com_Error`, `Com_Printf`, `Cvar_*`, `Cmd_*`

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

## External Dependencies
- `client.h` — pulls in `entity_t`, `client_state_t cl`, `cl_sustain_t`, `net_message`, `frame_t`, `player_state_t`
- `MSG_Read*` — defined in `qcommon/net_chan.c` / `common.c`
- `S_RegisterSound`, `S_StartSound` — sound system
- `re.RegisterModel`, `re.RegisterPic`, `V_AddEntity`, `V_AddLight` — renderer interface
- `CL_ParticleEffect`, `CL_RailTrail`, `CL_BubbleTrail`, `CL_Heatbeam`, `CL_ParticleSteamEffect2`, `CL_Widowbeamout`, `CL_Nukeblast`, `CL_TeleportParticles`, etc. — defined in `cl_fx.c` / `cl_newfx.c`
- `hand` cvar — defined elsewhere, used for handedness in `CL_AddPlayerBeams`

# client/cl_view.c
## File Purpose
Manages the client-side view rendering pipeline, assembling the render scene (entities, particles, dynamic lights, light styles) into a `refdef` structure each frame and dispatching it to the renderer. Also handles level precaching/registration and development/debugging view tools.

## Core Responsibilities
- Maintain and clear per-frame render lists (entities, particles, dynamic lights, light styles)
- Expose `V_Add*` helpers for other client subsystems to populate those lists
- Assemble `cl.refdef` and invoke `re.RenderFrame` each frame via `V_RenderView`
- Precache all level assets (models, images, skins, sky) in `CL_PrepRefresh`
- Compute vertical FOV from horizontal FOV and viewport dimensions
- Provide developer test modes (test particles, entities, lights, blend)
- Register debug console commands (`gun_next`, `gun_prev`, `gun_model`, `viewpos`)

## External Dependencies
- `client.h` — pulls in `client_state_t cl`, `client_static_t cls`, screen/viewport globals, `re` renderer interface
- `re.*` — renderer DLL interface (`RenderFrame`, `RegisterModel`, `RegisterPic`, `BeginRegistration`, `EndRegistration`, `SetSky`, `DrawPic`) — defined in renderer DLL
- `CL_AddEntities`, `CL_ParseClientinfo`, `CL_LoadClientinfo`, `CL_RegisterTEntModels` — defined in `cl_ents.c` / `cl_parse.c`
- `CM_InlineModel` — defined in `qcommon/cmodel.c`
- `SCR_*`, `Con_ClearNotify`, `CDAudio_Play`, `Sys_Milliseconds`, `Sys_SendKeyEvents` — defined elsewhere in client/common layer

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

## External Dependencies
- `ref.h`, `vid.h`, `screen.h`, `sound.h`, `input.h`, `keys.h`, `console.h`, `cdaudio.h` — all client subsystem headers
- `qcommon.h` (transitively via ref.h): `MAX_EDICTS`, `MAX_DLIGHTS`, `UPDATE_BACKUP`, `netchan_t`, `usercmd_t`, `entity_state_t`, `player_state_t`, `refdef_t`, `cvar_t`, `netadr_t`, `sizebuf_t`
- `refexport_t` — renderer DLL export table, defined in `ref.h`; actual DLL loaded at runtime

# client/console.c
## File Purpose
Implements the Quake 2 in-game console: text buffer management, output printing, input line rendering, notify overlay, and the full console draw pass. All engine text output routes through `Con_Print` so it is captured and displayed here.

## Core Responsibilities
- Maintain a circular text buffer (`con.text`) with line-wrap and resize logic
- Print engine/game text with carriage-return and color-mask handling
- Draw the full drop-down console (background, scrollback, version string, download bar, input line)
- Draw the transient notify overlay (last N lines shown briefly over the game view)
- Register and handle console commands: `toggleconsole`, `clear`, `condump`, `messagemode`, etc.
- Manage console state transitions (key destination, pause on singleplayer open)

## External Dependencies
- `client.h` — pulls in `console.h`, `cl_*.h`, `ref.h`, `qcommon.h`
- `re` (refexport_t) — `DrawChar`, `DrawStretchPic` defined in active renderer DLL
- `cls` (client_static_t), `cl` (client_state_t), `viddef` — defined in `cl_main.c` / `vid_*.c`
- `chat_buffer`, `chat_team`, `chat_bufferlen` — defined in `keys.c`
- `key_lines`, `edit_line`, `key_linepos` — defined in `keys.c`
- `SCR_EndLoadingPlaque`, `SCR_AddDirtyPoint` — defined in `cl_scrn.c`
- `M_ForceMenuOff` — defined in `menu.c`
- `Com_ServerState`, `Cbuf_AddText`, `Cvar_*`, `Cmd_*`, `FS_*` — defined in `qcommon/`

# client/console.h
## File Purpose
Declares the console subsystem interface for Quake 2's in-game developer/chat console. Defines the console buffer structure and exposes rendering, printing, and lifecycle functions implemented in `client/console.c`.

## Core Responsibilities
- Define the fixed-size circular text buffer (`console_t`) for console output
- Expose initialization and resize hooks for the console subsystem
- Declare rendering entry points for the full console overlay and transient notify lines
- Declare print functions for general and centered console text output
- Expose console toggle and clear commands

## External Dependencies
- `qcommon.h` / `client.h` — `qboolean`, `cls.realtime`
- `Con_DrawCharacter` depends on the active renderer for glyph drawing
- `CON_TEXTSIZE` (32768) defines a fixed ring buffer; no dynamic allocation

# client/input.h
## File Purpose
Declares the public interface for external (non-keyboard) input devices such as mice and joysticks. Acts as a platform-abstraction boundary, allowing the client to drive input polling without coupling to platform-specific implementation details.

## Core Responsibilities
- Expose lifecycle hooks (`IN_Init`, `IN_Shutdown`) for input device setup and teardown
- Provide a per-frame polling hook (`IN_Frame`) for device state updates
- Allow devices to inject console commands (`IN_Commands`)
- Contribute device-derived movement deltas to the user command (`IN_Move`)
- Allow the client to notify input devices of focus/activation changes (`IN_Activate`)

## External Dependencies
- `usercmd_t` — defined in `qcommon/qcommon.h` or `game/q_shared.h`; not defined here.
- `qboolean` — engine-wide boolean typedef; defined elsewhere.
- Platform implementations live in `win32/in_win.c`, `linux/in_linux.c`, etc.

# client/keys.c
## File Purpose
Implements the client-side keyboard input system, managing key bindings, console line editing, chat message input, and routing of key events to the appropriate subsystem (console, menu, game, or message).

## Core Responsibilities
- Maintain and serialize key-to-command bindings (`keybindings[]`)
- Route key events to console, menu, chat, or game based on `cls.key_dest`
- Provide interactive console line editing with history (32-line ring buffer)
- Handle tab-completion for commands and cvars in the console
- Track modifier key state (`shift_down`, `keydown[]`) and autorepeat filtering
- Map key numbers to/from string names for config file serialization
- Register `bind`/`unbind`/`unbindall`/`bindlist` console commands

## External Dependencies
- **Includes:** `client.h` (pulls in all client state: `cls`, `cl`, `con`)
- **Defined elsewhere:** `Cmd_CompleteCommand`, `Cvar_CompleteVariable`, `Cbuf_AddText`, `Com_sprintf`, `Com_Printf`, `Com_Error`, `Con_ToggleConsole_f`, `M_Keydown`, `M_Menu_Main_f`, `SCR_UpdateScreen`, `Sys_SendKeyEvents`, `Sys_GetClipboardData`, `Z_Malloc`, `Z_Free`; key constants `K_*` from `keys.h`

# client/keys.h
## File Purpose
Defines the virtual keycode constants used throughout the Quake 2 input system, along with the key binding state variables and the public API for the keyboard subsystem. It serves as the shared interface between platform-specific input backends and the client input/UI layers.

## Core Responsibilities
- Define numeric key constants (`K_*`) for all supported input sources: keyboard, mouse, joystick, aux buttons, and mouse wheel
- Expose global key binding and state arrays (`keybindings`, `key_repeats`)
- Expose chat buffer state for console/UI access
- Declare the public API for key event processing, initialization, binding management, and state reset

## External Dependencies
- No `#include` directives present in this header.
- `qboolean`, `FILE` — assumed available via `qcommon.h` / standard headers included by translation units that include this header.
- All declared symbols are **defined in `client/keys.c`**.

# client/menu.c
## File Purpose
Implements the entire in-game menu system for Quake 2, including the main menu, all submenus (game, multiplayer, options, keys, video, load/save, server browser, player config, DM options, credits, etc.). It manages a layered menu stack with draw/key function dispatch, and registers all menu console commands.

## Core Responsibilities
- Maintain a depth-limited menu stack (`m_layers[]`) with push/pop semantics
- Dispatch per-frame draw and per-keypress key callbacks to the active menu
- Provide shared UI primitives: character drawing, text printing, cursor animation, text boxes
- Initialize and configure each submenu's `menuframework_s` and its items on demand
- Apply cvar reads/writes when menu items change (audio, input, gameplay settings)
- Scan the filesystem for player models/skins and map lists at menu open time
- Register all `menu_*` console commands during engine init

## External Dependencies
- **Includes:** `client.h`, `client/qmenu.h`, `<ctype.h>`, `<io.h>` (Win32)
- **External symbols (defined elsewhere):**
  - `re` — renderer export table (`DrawPic`, `DrawChar`, `DrawGetPicSize`, `DrawFill`, `DrawFadeScreen`, `RegisterPic`, `RegisterModel`, `RegisterSkin`, `RenderFrame`, `EndFrame`)
  - `viddef` — video dimensions
  - `cls`, `cl` — client state structs
  - `keybindings[]`, `Key_SetBinding`, `Key_KeynumToString`, `Key_ClearStates`
  - `Cvar_*`, `Cbuf_*`, `Cmd_AddCommand`, `Com_*`, `FS_*`, `S_StartLocalSound`
  - `Menu_*`, `Field_Key` — from `qmenu.c`
  - `VID_MenuInit`, `VID_MenuDraw`, `VID_MenuKey` — from platform video module
  - `CL_Snd_Restart_f`, `CL_PingServers_f`, `CL_Quit_f`
  - `Developer_searchpath` — defined elsewhere (game/filesystem layer)
  - `CalcFov` — renderer utility

# client/qmenu.c
## File Purpose
Implements the generic menu widget system for the Quake 2 client UI. Provides reusable menu item types (actions, fields, sliders, spin controls, lists, separators) with unified draw, input, and cursor management logic.

## Core Responsibilities
- Draw all menu widget types by dispatching on `menucommon_s.type`
- Handle keyboard input for text field widgets (`Field_Key`)
- Manage cursor movement and selection across menu items
- Render status bar text at the bottom of the screen
- Provide string drawing utilities (left-to-right, right-to-left, normal/dark variants)
- Compute menu slot totals for layout purposes
- Vertically center menus on screen

## External Dependencies
- `client.h`, `qmenu.h` — type definitions and constants
- `re` (`refexport_t`) — `DrawChar`, `DrawFill` render calls
- `viddef` (`viddef_t`) — screen width/height for layout
- `Sys_Milliseconds()` — cursor blink timing
- `Sys_GetClipboardData()` — clipboard paste support
- `keydown[]` — modifier key state for Ctrl/Shift detection (defined in `keys.c`)

# client/qmenu.h
## File Purpose
Defines the data structures and function interface for Quake 2's in-game menu system. Provides a widget-based UI framework supporting sliders, lists, action buttons, text fields, spin controls, and separators.

## Core Responsibilities
- Define menu item type constants (`MTYPE_*`)
- Define key code constants used exclusively by the menu system
- Define item flag constants (`QMF_*`)
- Declare structs for the menu framework container and each widget type
- Declare the public API for menu management and rendering

## External Dependencies
- Relies on `qboolean` being defined prior to inclusion (typically from `q_shared.h` / `qcommon.h`).
- All function bodies defined in `client/qmenu.c`.
- Rendering calls within implementations depend on `client/ref.h` draw primitives — not visible here.

# client/ref.h
## File Purpose
Defines the ABI contract between the Quake 2 engine client and dynamically loaded renderer (refresh) modules. It declares all shared data structures passed to the renderer and the two-sided function-pointer tables that form the renderer plugin interface.

## Core Responsibilities
- Define scene-object types (`entity_t`, `dlight_t`, `particle_t`, `lightstyle_t`, `refdef_t`) passed per-frame to the renderer
- Declare `refexport_t`: the function table the renderer DLL exposes to the engine
- Declare `refimport_t`: the function table the engine exposes to the renderer DLL
- Define the single exported linker symbol type `GetRefAPI_t` used to bootstrap the renderer
- Provide palette index constants for player powersuit shell effects
- Set capacity limits for scene objects (`MAX_DLIGHTS`, `MAX_ENTITIES`, etc.)

## External Dependencies
- `../qcommon/qcommon.h` — pulls in `vec3_t`, `byte`, `qboolean`, `cvar_t`, and shared constants
- `model_s`, `image_s` — opaque forward-declared types; defined inside each renderer module, not visible to the client
- All `refexport_t` implementations reside in `ref_gl/` or `ref_soft/` renderer modules (defined elsewhere)
- All `refimport_t` implementations reside in the engine client/common layer (defined elsewhere)

# client/screen.h
## File Purpose
Public interface header for the Quake 2 screen/HUD subsystem. It declares all externally-visible screen management functions and shared global state that other client subsystems depend on.

## Core Responsibilities
- Declare screen lifecycle functions (init, update)
- Expose console sizing and positioning state
- Declare HUD/viewport geometry globals
- Expose crosshair state
- Declare dirty-region tracking API
- Declare the cinematic playback API (attributed to `scr_cin.c`)

## External Dependencies
- `cvar_t` — defined in `qcommon/qcommon.h`
- `vrect_t` — defined in shared/renderer headers
- `MAX_QPATH` — defined in `game/q_shared.h`
- `qboolean` — defined in `game/q_shared.h`
- All function implementations defined in `client/cl_scrn.c` and `client/cl_cin.c`

# client/snd_dma.c
## File Purpose
Main control layer for the Quake 2 streaming sound output system. It manages sound registration, channel allocation, spatialization, playsound queuing, and drives the DMA mixing pipeline each frame.

## Core Responsibilities
- Initialize and shut down the sound system via the platform DMA backend (`SNDDMA_*`)
- Manage the `sfx_t` registry (load, alias, register, expire sounds by sequence)
- Allocate and schedule `playsound_t` events in a time-sorted pending queue
- Pick and configure `channel_t` slots for active playback
- Spatialize channels (stereo pan + distance attenuation) each frame
- Generate looped autosounds from entity state each frame
- Feed raw PCM samples for cinematic/voice streaming (`s_rawsamples`)
- Drive the mixing loop by computing `endtime` and calling `S_PaintChannels`

## External Dependencies
- `client.h` — `cl`, `cls`, `cl_entities`, `cl_parse_entities`, `cl_paused`
- `snd_loc.h` — `channel_t`, `playsound_t`, `sfx_t`, `sfxcache_t`, `dma_t`, `MAX_CHANNELS`, `MAX_RAW_SAMPLES`, `ATTN_STATIC`
- `SNDDMA_Init/Shutdown/BeginPainting/Submit/GetDMAPos` — platform DMA backend (defined in `snd_win.c` / `snd_linux.c`)
- `S_PaintChannels` — defined in `snd_mix.c`
- `S_LoadSound`, `S_InitScaletable` — defined in `snd_mem.c`
- `CL_GetEntitySoundOrigin` — defined in `cl_ents.c`
- `Z_Malloc`, `Z_Free`, `Com_PageInMemory`, `FS_FOpenFile`, `FS_FCloseFile` — engine common

# client/snd_loc.h
## File Purpose
Private header for the Quake 2 software sound system. Defines internal data structures, shared state (extern declarations), and internal function prototypes used across `snd_dma.c`, `snd_mem.c`, `snd_mix.c`, and platform-specific DMA backends.

## Core Responsibilities
- Define the core sound data structures (`sfx_t`, `sfxcache_t`, `channel_t`, `dma_t`, `playsound_t`, `wavinfo_t`)
- Declare the DMA abstraction layer (SNDDMA_* functions) that platform backends must implement
- Expose shared globals (channels, listener state, DMA handle, cvars) to all sound subsystem translation units
- Declare internal utility functions used across sound subsystem files

## External Dependencies
- `qcommon/qcommon.h` (implied) — `vec3_t`, `vec_t`, `qboolean`, `byte`, `MAX_QPATH`, `cvar_t`
- Platform DMA backends — implement all `SNDDMA_*` functions
- ASM mixer routines — depend on exact layout of `portable_samplepair_t` and `channel_t`

# client/snd_mem.c
## File Purpose
Handles loading and caching of sound samples from disk. Parses WAV files into engine-usable `sfxcache_t` structures and resamples audio data to match the output device's sample rate.

## Core Responsibilities
- Load WAV files from the virtual filesystem into memory
- Parse RIFF/WAV chunk structure to extract audio metadata and PCM data
- Resample audio from source rate to DMA output rate
- Allocate and populate `sfxcache_t` cache entries on `sfx_t` objects
- Detect and reject stereo samples (engine requires mono)
- Parse optional loop points from WAV `cue ` chunks

## External Dependencies
- **Includes:** `client.h`, `snd_loc.h`
- **Defined elsewhere:** `dma` (`dma_t` output device state, `snd_dma.c`), `s_loadas8bit` (cvar, `snd_dma.c`), `Z_Malloc`, `FS_LoadFile`, `FS_FreeFile`, `Com_sprintf`, `Com_DPrintf`, `Com_Printf`, `Com_Error`, `LittleShort`; `sfx_t`, `sfxcache_t`, `wavinfo_t` from `snd_loc.h`.

# client/snd_mix.c
## File Purpose
Implements the portable sound mixing layer for Quake 2's audio system. It paints active sound channels into an intermediate paintbuffer, then transfers that buffer to the DMA output buffer in the appropriate hardware format.

## Core Responsibilities
- Maintain and fill `paintbuffer` with mixed stereo sample pairs each frame
- Mix 8-bit and 16-bit sound channels into the paintbuffer with per-channel volume scaling
- Handle streaming raw audio (e.g., cinematics) via `s_rawsamples`
- Transfer the paintbuffer to the DMA output buffer, converting to the hardware's bit depth and channel count
- Issue pending `playsound_t` events at the correct time during mixing
- Precompute a volume scale lookup table for fast 8-bit channel mixing

## External Dependencies
- `client.h`, `snd_loc.h` — type definitions (`channel_t`, `sfxcache_t`, `portable_samplepair_t`, `dma`, `playsound_t`)
- **Defined elsewhere:** `paintedtime`, `channels`, `MAX_CHANNELS`, `s_pendingplays`, `s_rawend`, `s_rawsamples`, `MAX_RAW_SAMPLES`, `dma`, `s_volume`, `s_testsound`, `S_IssuePlaysound`, `S_LoadSound`
- Platform assembly override: `linux/snd_mixa.s` provides `S_WriteLinearBlastStereo16` and `S_PaintChannelFrom8` for Linux x86

# client/sound.h
## File Purpose
Public interface header for the Quake 2 client sound system. Declares all sound lifecycle, playback, registration, and spatial update functions consumed by the client and other engine subsystems.

## Core Responsibilities
- Declare the sound system init/shutdown entry points
- Expose spatial and local sound playback functions
- Declare raw PCM sample streaming support
- Provide the sound asset registration API
- Declare the listener (camera) position update function
- Declare the reverse callback for dynamic entity spatialization

## External Dependencies
- `vec3_t`, `qboolean`, `byte` — defined in `qcommon/q_shared.h`
- `struct sfx_s` — defined in `client/snd_loc.h`
- `CL_GetEntitySoundOrigin` — implemented in client code, not in this header

# client/vid.h
## File Purpose
Defines the public interface for the video driver subsystem. It declares shared data types for video geometry and global video state, and exposes the lifecycle and menu functions that the engine uses to manage the display system.

## Core Responsibilities
- Define the `vrect_t` rectangle type used across rendering subsystems
- Define `viddef_t` to carry global display dimensions
- Declare the `viddef` global that all subsystems read for current resolution
- Expose video lifecycle entry points (`Init`, `Shutdown`, `CheckChanges`)
- Expose video options menu entry points used by the in-game menu system

## External Dependencies
- No includes in this header beyond implicit engine conventions.
- `viddef` is **defined elsewhere** (platform-specific video module, e.g., `win32/vid_dll.c` or `linux/vid_so.c`).
- `vrect_t` is consumed by rendering and HUD code across the codebase.

# client/x86.c
## File Purpose
Implements x86-specific CPU cycle-counting profiling utilities using the RDTSC instruction (opcode `0F 31h`). Provides a histogram-based timing mechanism to measure and record execution durations in CPU cycles, compiled only when targeting x86 (`id386`).

## Core Responsibilities
- Initialize a cycle-count histogram with bias calibration
- Start a cycle timer using RDTSC
- Stop the timer and bin the elapsed cycle count into a histogram array
- Expose the histogram buffer for external consumers

## External Dependencies
- `<stdlib.h>` — included but not directly used here
- `"client.h"` — pulls in `Z_Malloc` and the `id386` platform define
- `Z_Malloc` — defined in the engine zone memory allocator (not in this file)

