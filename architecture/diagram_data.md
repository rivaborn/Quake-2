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

# ctf/g_ai.c
## File Purpose
Implements monster AI locomotion, target acquisition, and attack decision logic for the CTF game module. It provides the core per-frame AI state machine entry points (`ai_stand`, `ai_walk`, `ai_run`, `ai_charge`, etc.) and the target-finding/enemy-tracking subsystem used by all monsters.

## Core Responsibilities
- Cycling `level.sight_client` each frame so monsters check players fairly in multiplayer
- Providing movement primitives (`ai_move`, `ai_stand`, `ai_walk`, `ai_charge`, `ai_turn`, `ai_run`) called by monster animation frames
- Spatial queries: range classification, line-of-sight (`visible`), facing check (`infront`)
- Target acquisition (`FindTarget`) via sight, sound, and area-connectivity checks
- Alerting the level when a target is found (`FoundTarget`, `HuntTarget`)
- Attack decision (`M_CheckAttack`, `ai_checkattack`) including melee, missile, and sliding strafing
- Lost-sight pursuit using player trail waypoints (`ai_run`)

## External Dependencies
- `g_local.h` — all engine/game types, constants (`MELEE_DISTANCE`, `RANGE_*`, `AI_*`, `AS_*`)
- `M_walkmove`, `M_MoveToGoal`, `M_ChangeYaw` — monster movement (defined in `m_move.c`)
- `AttackFinished`, `G_PickTarget`, `G_Spawn`, `G_FreeEdict`, `G_ProjectSource` — game utilities (defined elsewhere)
- `PlayerTrail_PickFirst`, `PlayerTrail_PickNext` — trail system (defined in `p_trail.c`)
- `gi.trace`, `gi.inPHS`, `gi.AreasConnected`, `gi.dprintf` — engine imports via `gi` game interface
- `level`, `g_edicts`, `game`, `coop`, `skill` — global game state (defined in `g_main.c` / `g_local.h`)

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

## External Dependencies
- **Includes:** `g_local.h` (pulls in `game.h`, `q_shared.h`, entity/client definitions)
- **External symbols used:**
  - `g_edicts` — global entity array (defined in `g_main.c`)
  - `maxclients` — cvar pointer (defined in `g_main.c`)
  - `level` — `level_locals_t` (defined in `g_main.c`)
  - `gi` — `game_import_t` vtable (provided by the engine)
  - `vec3_origin`, `MASK_SOLID`, `PM_FREEZE`, `PMF_NO_PREDICTION`, `svc_layout` — defined in shared/engine headers

# ctf/g_cmds.c
## File Purpose
Handles all client-issued game commands for the CTF (Capture the Flag) mod, routing text commands to their corresponding handler functions. It extends the base Quake 2 command set with CTF-specific commands such as team selection, voting, ghosting, and admin controls.

## Core Responsibilities
- Parse and dispatch client commands via `ClientCommand`
- Implement cheat commands (give, god, notarget, noclip) gated behind `sv_cheats`
- Manage inventory navigation, use, and drop
- Implement player chat (`say`, `say_team`) with flood protection
- Provide weapon cycling and player animation (wave) commands
- Support CTF-specific player menu navigation (PMenu) and chase-cam redirection
- Determine team membership from userinfo skin/model strings

## External Dependencies
- **Includes:** `g_local.h`, `m_player.h`
- **Defined elsewhere:** `PMenu_Next/Prev/Close/Select`, `CTFOpenJoinMenu`, `CTFSay_Team`, `CTFTeam_f`, `CTFID_f`, `CTFVoteYes/No`, `CTFReady/NotReady`, `CTFGhost`, `CTFAdmin`, `CTFStats`, `CTFWarp`, `CTFBoot`, `CTFPlayerList`, `CTFObserver`, `CTFWhat_Tech`, `ChaseNext/ChasePrev`, `Add_Ammo`, `SpawnItem`, `Touch_Item`, `player_die`, `FindItem`, `G_Spawn`, `G_FreeEdict`, `itemlist`, `game`, `g_edicts`, `meansOfDeath`, `dmflags`, `sv_cheats`, `deathmatch`, `dedicated`, `ctf`, `flood_msgs`, `flood_persecond`, `flood_waitdelay`, `maxclients`

# ctf/g_combat.c
## File Purpose
Implements the core damage, death, and knockback system for the CTF (Capture the Flag) game module. It handles direct and radius damage application, armor/power-armor absorption, team damage checks, and CTF-specific modifications such as strength/resistance tech bonuses and team armor protection.

## Core Responsibilities
- Line-of-sight damage eligibility testing (`CanDamage`)
- Dispatching entity death logic (`Killed`)
- Applying damage with armor/power-armor absorption, knockback, godmode, and invincibility (`T_Damage`)
- Spawning visual hit effects (sparks, blood) via temp entities
- Radius/explosion falloff damage distribution (`T_RadiusDamage`)
- CTF-specific team damage blocking and flag-carrier hurt notifications
- Monster aggro/reaction logic on taking damage (`M_ReactToDamage`)

## External Dependencies
- `g_local.h` — all game types, constants, CVars
- `CTFApplyStrength`, `CTFApplyResistance`, `CTFCheckHurtCarrier`, `CTFMatchSetup` — defined in `g_ctf.c`
- `FoundTarget`, `monster_death_use` — defined in monster AI files
- `OnSameTeam`, `PowerArmorType`, `ArmorIndex`, `GetItemByIndex`, `FindItem`, `findradius`, `visible` — defined elsewhere in game module
- `gi.trace`, `gi.sound`, `gi.soundindex`, `gi.WriteByte`, `gi.WritePosition`, `gi.WriteDir`, `gi.multicast` — engine imports via `gi` interface

# ctf/g_ctf.c
## File Purpose
Core implementation of the ThreeWave Capture the Flag (CTF) game mode for Quake 2. Handles all CTF-specific gameplay logic including flag mechanics, team assignment, the grappling hook weapon, tech powerups, match/election systems, and the in-game admin/join menus.

## Core Responsibilities
- Flag pickup, capture, drop, and auto-return logic
- Team assignment, skin assignment, and spawn point selection
- Grappling hook weapon simulation (fire, pull, cable draw, reset)
- Tech powerup spawning, pickup, drop, and effect application
- Match lifecycle management (SETUP → PREGAME → GAME → POST)
- Election/voting system for admin, map changes, and match requests
- CTF HUD stat population (`SetCTFStats`) and scoreboard formatting
- Ghost code system for reconnection score restoration
- In-game player menus (join, admin, settings, credits)

## External Dependencies
- Notable includes: `g_local.h`, `m_player.h`
- External symbols used but not defined here:
  - `g_edicts`, `globals`, `game`, `level` — engine/game globals
  - `gi` — game import interface (all engine I/O)
  - `G_Find`, `G_Spawn`, `G_FreeEdict`, `Drop_Item`, `Touch_Item` — entity utilities
  - `PutClientInServer`, `respawn`, `player_die` — player lifecycle
  - `Weapon_Generic`, `P_ProjectSource`, `PlayerNoise` — weapon framework
  - `T_Damage`, `CheckTeamDamage`, `KillBox` — combat
  - `EndDMLevel`, `DoRespawn` — level transition
  - `PMenu_Open/Close/Update/UpdateEntry` — in-game menu system
  - `CheckFlood`, `ArmorIndex`, `PowerArmorType`, `GetItemByIndex` — utility
  - `SelectRandomDeathmatchSpawnPoint`, `SelectFarthestDeathmatchSpawnPoint`, `PlayersRangeFromSpot` — spawn selection
  - `capturelimit`, `dmflags`, `maxclients`, `instantweap` — cvars defined elsewhere

# ctf/g_ctf.h
## File Purpose
Public interface header for the Quake 2 CTF (Capture The Flag) game module. Declares all shared types, constants, and function prototypes used across the CTF game logic, exposing the full CTF subsystem API to other translation units.

## Core Responsibilities
- Define HUD stat slot indices for CTF-specific UI elements
- Declare team, grapple state, and ghost record types
- Define all CTF gameplay tuning constants (bonuses, timeouts, radii, speeds)
- Expose function prototypes for flag logic, grapple weapon, tech items, match/voting system, and chase cam

## External Dependencies
- Notable includes: Implicitly depends on `g_local.h` (defines `edict_t`, `gclient_t`, `gitem_t`, `cvar_t`, `qboolean`)
- External symbols used but not defined here: `edict_t`, `gclient_t`, `gitem_t`, `cvar_t`, `CS_MAXCLIENTS`, `qboolean`, all function bodies

# ctf/g_func.c
## File Purpose
Implements all BSP-brush functional entities for the CTF game module: moving platforms, rotating brushes, buttons, doors (sliding, rotating, secret), water brushes, trains, conveyors, timers, elevators, and killboxes. This is a near-identical copy of the base `game/g_func.c` adapted for the CTF mod.

## Core Responsibilities
- Provides linear and accelerated movement primitives (`Move_Calc`, `Think_AccelMove`) used by all brush movers
- Provides angular movement primitives (`AngleMove_Calc`) for rotating entities
- Implements spawn functions (`SP_func_*`) for all brush-based functional entities
- Manages multi-stage movement state machines (STATE_TOP/BOTTOM/UP/DOWN) for doors and platforms
- Handles block/crush damage for entities obstructing movers
- Synchronizes team-linked door groups to complete movement simultaneously
- Spawns secondary trigger volumes (e.g., plat center trigger, door proximity trigger)

## External Dependencies
- **Includes:** `g_local.h` (entity definitions, game API, shared constants)
- **External symbols:** `gi` (game import struct — sound, setmodel, linkentity, etc.), `G_Spawn`, `G_Find`, `G_PickTarget`, `G_UseTargets`, `G_SetMovedir`, `T_Damage`, `BecomeExplosion1`, `KillBox`, `AddPointToBounds`, `level` (global level state), `deathmatch` (cvar), `FRAMETIME`, `vec3_origin`

# ctf/g_items.c
## File Purpose
Implements the complete item system for the CTF game module, covering pickup, use, drop, respawn, and world-placement logic for all item categories: armor, weapons, ammo, powerups, keys, health, CTF flags, and CTF tech items. It also defines the master `itemlist[]` table that enumerates every item in the game.

## Core Responsibilities
- Define and expose the global `itemlist[]` item registry for all game items
- Handle pickup callbacks for each item category (armor, ammo, health, powerup, key, power armor)
- Handle use callbacks for timed powerups (Quad, Breather, Envirosuit, Invulnerability, Silencer, Power Armor)
- Handle drop logic for ammo, general items, and power armor
- Manage item respawning via `SetRespawn`/`DoRespawn`
- Spawn items into the world via `SpawnItem`/`droptofloor`, including CTF flag routing
- Precache all assets (models, sounds, images) required by each item via `PrecacheItem`
- Provide item lookup utilities (`GetItemByIndex`, `FindItem`, `FindItemByClassname`)

## External Dependencies
- **Includes:** `g_local.h` (pulls in `game.h`, `q_shared.h`, entity/game definitions)
- **Defined elsewhere:**
  - `itemlist` referenced by `game.num_items` and `ITEM_INDEX` macro (defined in `game.h`)
  - `CTFMatchSetup`, `CTFHasRegeneration`, `CTFPickup_Flag`, `CTFDrop_Flag`, `CTFPickup_Tech`, `CTFDrop_Tech`, `CTFFlagSetup`, `CTFWeapon_Grapple` — CTF logic in `g_ctf.c`
  - `gi` game import struct (engine interface)
  - `deathmatch`, `coop`, `skill`, `dmflags`, `ctf` — cvars
  - `level`, `game` — global game/level state
  - `G_Spawn`, `G_FreeEdict`, `G_UseTargets`, `G_ProjectSource`, `ValidateSelectedItem` — entity utilities

# ctf/g_local.h
## File Purpose
Central local header for the CTF (Capture the Flag) game module, defining all game-side types, structures, constants, and function prototypes. It is the CTF variant of the base game's `game/g_local.h`, extended with CTF-specific fields (grapple, CTF team state, tech timers, menus) and includes `g_ctf.h` at the bottom.

## Core Responsibilities
- Defines the full `edict_s` and `gclient_s` structures (gated by `GAME_INCLUDE`)
- Declares all game-module globals (`game`, `level`, `gi`, `g_edicts`, cvars)
- Provides all cross-file function prototypes for the game DLL subsystems
- Enumerates constants for damage, movement, AI, items, weapons, armor, and MOD codes
- Extends base `client_respawn_t` and `gclient_s` with CTF-specific fields
- Defines field offset macros (`FOFS`, `STOFS`, etc.) used by the save/load system

## External Dependencies

- `q_shared.h` — math types, `vec3_t`, `qboolean`, string utilities
- `game.h` — `game_import_t`, `game_export_t`, `entity_state_t`, `player_state_t`, `pmove_state_t`, short `gclient_t`/`edict_t` stubs (overridden by `GAME_INCLUDE`)
- `p_menu.h` — CTF in-game menu types (`pmenuhnd_t`)
- `g_ctf.h` — CTF-specific declarations (included at bottom to avoid circular deps)
- `link_t`, `cplane_t`, `csurface_t`, `solid_t` — defined in `q_shared.h` / `qcommon.h`

# ctf/g_main.c
## File Purpose
Entry point and frame driver for the CTF game DLL. Registers all game API callbacks with the engine via `GetGameAPI`, and advances the game world one frame at a time through `G_RunFrame`. It is the CTF variant counterpart to `game/g_main.c`.

## Core Responsibilities
- Export the game DLL interface (`GetGameAPI`) to the engine
- Drive the per-frame entity update loop (`G_RunFrame`)
- Enforce deathmatch end conditions (timelimit, fraglimit, CTF-specific rules)
- Handle level transitions and intermission exit (`EndDMLevel`, `ExitLevel`)
- Declare and register all global CVars used by the game module
- Provide stub implementations of `Sys_Error` and `Com_Printf` for shared code linkage

## External Dependencies
- **Includes:** `g_local.h` (pulls in all CTF game types, `qcommon.h`, etc.)
- **Defined elsewhere:** `SpawnEntities`, `ClientThink`, `ClientConnect`, `ClientUserinfoChanged`, `ClientDisconnect`, `ClientBegin`, `ClientCommand`, `G_RunEntity`, `WriteGame`, `ReadGame`, `WriteLevel`, `ReadLevel`, `InitGame`, `ClientBeginServerFrame`, `ClientEndServerFrame`, `BeginIntermission`, `AI_SetSightClient`, `M_CheckGround`, `G_Find`, `G_Spawn`, `CTFCheckRules`, `CTFInMatch`, `CTFNextMap`, `ServerCommand`

# ctf/g_misc.c
## File Purpose
Implements miscellaneous map entity spawn functions and shared utility systems for the Quake 2 CTF game module. Covers gibs/debris effects, world geometry entities (areaportal, func_wall, func_explosive), navigational helpers (path_corner, point_combat), decorative/scripted entities, and teleporters. Extends base `g_misc.c` with CTF-specific hooks in `BecomeExplosion1` and `teleporter_touch`.

## Core Responsibilities
- Spawn and manage gib/debris physics entities on death
- Register and handle map brush entities (func_wall, func_object, func_explosive, misc_explobox)
- Provide AI navigation waypoints (path_corner, point_combat)
- Implement teleporter logic with CTF grapple reset integration
- Handle CTF flag/tech item preservation in `BecomeExplosion1`
- Spawn decorative/scripted scene entities (ships, banners, easter eggs, satellite dish)
- Implement a real-time/countdown `func_clock` driven by `target_string`

## External Dependencies
- `g_local.h` — all game types, `gi` import table, entity fields
- `CTFResetFlag`, `CTFTeamName`, `CTFRespawnTech`, `CTFPlayerResetGrapple` — defined in `g_ctf.c`
- `train_use`, `func_train_find` — defined in `g_func.c` (extern declared inline)
- `T_Damage`, `T_RadiusDamage`, `KillBox`, `G_UseTargets`, `G_PickTarget`, `G_Find`, `G_Spawn`, `G_FreeEdict` — defined elsewhere in game module
- `M_walkmove`, `M_droptofloor` — monster movement, defined in `m_move.c`
- `sm_meat_index` — global model index, defined elsewhere

# ctf/g_monster.c
## File Purpose
Provides the shared monster infrastructure for the CTF game module, including monster weapon firing wrappers, per-frame think logic, world interaction (water/lava/slime damage), and monster spawn/initialization routines.

## Core Responsibilities
- Wrap projectile fire functions with muzzle flash network messages for all monster weapon types
- Drive per-frame animation via `M_MoveFrame`, advancing through `mmove_t` sequences and dispatching AI/think callbacks
- Categorize monster position (water level, ground contact) each frame
- Apply environmental damage (drowning, lava, slime) and entry/exit sounds
- Handle monster spawn variants: walk, fly, swim, and triggered spawn
- Resolve target/combattarget linkage at spawn time
- Fire death targets and drop items on monster death

## External Dependencies
- **Includes:** `g_local.h`
- **Defined elsewhere:** `fire_bullet`, `fire_shotgun`, `fire_blaster`, `fire_grenade`, `fire_rocket`, `fire_rail`, `fire_bfg`; `T_Damage`, `Drop_Item`, `G_UseTargets`, `G_Find`, `G_PickTarget`, `KillBox`, `FoundTarget`, `M_CheckAttack`, `M_walkmove`; `gi` (game import struct); `g_edicts`, `level`, `world`, `st`

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

## External Dependencies
- `g_local.h` — entity definitions, game imports (`gi`), cvars (`sv_gravity`, `sv_maxvelocity`), constants (`FRAMETIME`, `MAX_EDICTS`, movetypes, masks)
- `gi.trace`, `gi.linkentity`, `gi.sound`, `gi.positioned_sound`, `gi.soundindex`, `gi.pointcontents`, `gi.error` — engine imports
- `M_CheckGround`, `M_CheckBottom` — defined in `m_move.c`
- `G_TouchTriggers` — defined in `g_utils.c`
- `AngleVectors`, `CrossProduct`, `DotProduct`, `VectorMA`, `VectorScale` — math utilities from `q_shared`

# ctf/g_save.c
## File Purpose
Implements the CTF game module's save/load system, handling serialization of game state, level state, entities, and clients to binary files. It also contains `InitGame`, the entry point called when the game DLL is first loaded.

## Core Responsibilities
- Register entity field descriptors for spawn-time parsing (`fields[]`) and savegame pointer fixup (`savefields[]`, `levelfields[]`, `clientfields[]`)
- Initialize all game CVars, entity/client pools, and CTF subsystem on game start
- Serialize/deserialize the game-global state (`WriteGame`/`ReadGame`) including all client structs
- Serialize/deserialize per-level state (`WriteLevel`/`ReadLevel`) including all live edicts and `level_locals_t`
- Perform pointer swizzling: convert pointers to integer indices before write, restore them after read

## External Dependencies
- `g_local.h` — `edict_t`, `gclient_t`, `level_locals_t`, `game`, `level`, `g_edicts`, `globals`, `itemlist`, field macros (`FOFS`, `STOFS`, `LLOFS`, `CLOFS`)
- `gi` interface — `gi.cvar`, `gi.TagMalloc`, `gi.FreeTags`, `gi.linkentity`, `gi.error`, `gi.dprintf`
- `SaveClientData`, `InitItems`, `CTFInit` — defined elsewhere in the CTF game module
- `maxclients`, `deathmatch`, `coop`, `maxentities` — CVars, registered here and used globally

# ctf/g_spawn.c
## File Purpose
CTF-variant entity spawning and map initialization module. It parses the textual entity definitions from a BSP map, dispatches each entity to its registered spawn function, and performs full level setup for the CTF game mode.

## Core Responsibilities
- Maintains a named dispatch table (`spawns[]`) mapping classname strings to spawn functions
- Resolves each parsed entity to either an item spawn or a named spawn function via `ED_CallSpawn`
- Parses raw entity string data (key/value pairs) into `edict_t` fields via `ED_ParseEdict` / `ED_ParseField`
- Filters entities by skill level and deathmatch flags during map load
- Chains team-slave entities together via `G_FindTeams`
- Initializes world-level configstrings (sky, gravity, CD track, statusbar, light styles) in `SP_worldspawn`
- CTF-specific: registers CTF team spawn points, banners, teleporters, and calls `CTFSpawn()` post-load
- Monsters and certain misc entities are compiled out (`#if 0`) for the CTF variant

## External Dependencies
- **Includes:** `g_local.h` (all game types, `fields[]`, `st`, `g_edicts`, `level`, `game`, cvars)
- **Defined elsewhere:** `itemlist`, `SpawnItem`, `G_Spawn`, `G_FreeEdict`, `SaveClientData`, `PlayerTrail_Init`, `CTFSpawn`, `CTF`-specific spawn functions (`SP_info_player_team1/2`, `SP_misc_ctf_banner`, `SP_trigger_teleport`, etc.), `ctf_statusbar`, `COM_Parse`, all `SP_*` functions listed as forward declarations, `gi` (game import), `sm_meat_index`

# ctf/g_svcmds.c
## File Purpose
Implements the CTF game module's server-side command dispatch. It handles the `sv` console command by routing subcommands to registered handler functions.

## Core Responsibilities
- Receive and dispatch server commands issued via the `sv` console command
- Provide a test command (`sv test`) for diagnostic purposes
- Report unknown subcommands back to the server console

## External Dependencies
- **Includes:** `g_local.h` (pulls in all CTF game types, `game_import_t gi`, and shared utilities)
- **External symbols used:**
  - `gi.argv` — engine function to retrieve console command arguments
  - `gi.cprintf` — engine function for console output
  - `Q_stricmp` — case-insensitive string comparison (defined in `q_shared.c`)

# ctf/g_target.c
## File Purpose
Defines all `target_*` entity types for the CTF game module. Each entity responds to trigger/use events by performing a discrete world effect such as playing sounds, changing levels, firing lasers, spawning entities, or causing earthquakes.

## Core Responsibilities
- Register spawn functions (`SP_target_*`) and use callbacks (`use_target_*`) for each target entity class
- Send temp-entity network messages (splashes, explosions, laser sparks) to clients via multicast
- Manage level progression: secret/goal tracking, level changes, cross-level trigger state
- Drive per-frame thinking entities (laser, lightramp, earthquake) via `nextthink`/`think`
- Apply radius damage or direct damage on certain target activations
- Modify global `game` and `level` state (help messages, server flags, secret/goal counts)

## External Dependencies
- `g_local.h` — all engine/game types, constants, macros
- `G_UseTargets`, `G_FreeEdict`, `G_Spawn`, `G_SetMovedir`, `G_Find`, `KillBox` — entity utilities (defined in `g_utils.c`)
- `T_Damage`, `T_RadiusDamage` — damage system (`g_combat.c`)
- `BeginIntermission` — level transition (`p_hud.c` / `g_main.c`)
- `fire_blaster` — projectile code (`p_weapon.c`)
- `ED_CallSpawn` — entity spawner dispatcher (declared extern, defined in `g_spawn.c`)
- `gi.*` — engine game import API (server interface)
- `level`, `game`, `g_edicts`, `globals` — global state defined in `g_main.c`

# ctf/g_trigger.c
## File Purpose
Implements all trigger entity types for the Quake 2 CTF game module. Triggers are invisible volume-based or event-driven entities that activate game logic when touched or used by players, monsters, or other entities.

## Core Responsibilities
- Initialize trigger volumes with shared geometry/solid setup (`InitTrigger`)
- Handle multi-fire and single-fire trigger activation and cooldown
- Implement key-gated relay triggers with coop inventory synchronization
- Implement push, hurt, gravity, and monster-jump trigger volumes
- Implement counter triggers requiring N activations before firing
- Manage deferred entity removal via `G_FreeEdict` scheduled through `nextthink`

## External Dependencies
- `g_local.h` — all game types, constants, and inline macros
- `G_UseTargets`, `G_SetMovedir`, `G_FreeEdict`, `T_Damage` — defined in other game files
- `gi.*` — engine import struct (sound, model, linking, printf)
- `level`, `game`, `g_edicts`, `st` — global game state defined elsewhere
- `ITEM_INDEX`, `FindItemByClassname` — item system defined elsewhere

# ctf/g_utils.c
## File Purpose
Miscellaneous utility functions for the CTF game module, providing entity search, spawning, freeing, targeting, spatial queries, and math/string helpers used throughout the game logic layer.

## Core Responsibilities
- Entity search by field string match (`G_Find`) and by spatial radius (`findradius`)
- Target chain firing and killtarget processing (`G_UseTargets`)
- Entity allocation (`G_Spawn`) and deallocation (`G_FreeEdict`)
- Trigger and solid touch dispatch (`G_TouchTriggers`, `G_TouchSolids`)
- Telefrag kill-box clearing (`KillBox`)
- Vector/angle math helpers and string utilities

## External Dependencies
- **Includes:** `g_local.h` (all game types, `gi` interface, macros)
- **Defined elsewhere:** `g_edicts`, `globals`, `game`, `level`, `maxclients` (game globals); `T_Damage` (g_combat.c); `Q_stricmp`, `Com_sprintf`, `AngleVectors`, `VectorLength`, `VectorCompare`, `VectorCopy`, `VectorClear` (shared/math); `gi.*` (engine server interface)

# ctf/g_weapon.c
## File Purpose
Implements all projectile and hitscan weapon firing functions for the CTF game module. Spawns and configures projectile entities (blaster bolts, grenades, rockets, BFG) and performs instant-hit trace-based attacks (bullets, shotgun pellets, railgun). This is a near-identical copy of `game/g_weapon.c` with a single CTF-specific modification in `bfg_think`.

## Core Responsibilities
- Spawn and initialize projectile entities with correct physics, models, sounds, and touch callbacks
- Perform hitscan traces for bullet/shotgun/rail attacks, applying spread and water deflection
- Handle melee/impact hit detection via bbox-range checks
- Trigger monster dodge AI when non-instant projectiles are fired
- Apply direct and radius damage on projectile impact or explosion
- Emit temp entity network messages for visual effects (explosions, trails, splashes, laser beams)
- CTF-specific: prevent BFG laser from targeting teammates

## External Dependencies
- `g_local.h` — all game types, `gi` interface, entity flags, damage flags, MOD constants
- **Defined elsewhere:** `T_Damage`, `T_RadiusDamage`, `ThrowDebris`, `PlayerNoise`, `CanDamage`, `findradius`, `infront`, `G_Spawn`, `G_FreeEdict`, `skill`, `deathmatch`, `coop`, `ctf`, `level.time`, `FRAMETIME`

# ctf/game.h
## File Purpose
Defines the ABI contract between the Quake 2 server engine and the CTF game DLL. It declares the `game_import_t` (engine callbacks into the DLL) and `game_export_t` (DLL entry points called by the engine) structs, along with the minimal shared entity/client types needed to communicate across the boundary.

## Core Responsibilities
- Define `GAME_API_VERSION` (3) to version-check the DLL interface
- Declare `SVF_*` server-visible entity flags (including CTF-extended `SVF_PROJECTILE`)
- Define `solid_t` enum for collision modes
- Provide stub `edict_s` / `gclient_s` definitions when `GAME_INCLUDE` is not defined
- Declare `game_import_t`: all engine services the game DLL may call
- Declare `game_export_t`: all game DLL entry points the engine calls
- Declare `GetGameApi`, the single DLL export symbol that bootstraps the interface

## External Dependencies
- **Notable includes:** None explicit in this file; depends on consumer including `q_shared.h` first for `vec3_t`, `trace_t`, `entity_state_t`, `player_state_t`, `usercmd_t`, `pmove_t`, `multicast_t`, `cvar_t`, `qboolean`.
- **Defined elsewhere:** `entity_state_t`, `player_state_t`, `usercmd_t`, `pmove_t`, `multicast_t`, `cvar_t` — all from `q_shared.h` / `qcommon.h`; `GetGameApi` body in `ctf/g_main.c`.
- **CTF addition vs. base game:** `SVF_PROJECTILE` flag and its comment block are CTF-specific extensions not present in `game/game.h`.

# ctf/m_move.c
## File Purpose
Implements ground-based and flying/swimming monster movement for the CTF game module. Handles step-up movement, bottom-check validation, yaw rotation, and goal-directed chase navigation for AI entities.

## Core Responsibilities
- Validate that a monster has solid ground beneath it (`M_CheckBottom`)
- Perform a single movement step with slope/stair adjustment (`SV_movestep`)
- Rotate a monster incrementally toward its ideal yaw (`M_ChangeYaw`)
- Execute a directional step and confirm facing alignment (`SV_StepDirection`)
- Choose a new chase direction toward an enemy with fallback directions (`SV_NewChaseDir`)
- Drive per-frame monster goal movement (`M_MoveToGoal`, `M_walkmove`)

## External Dependencies
- `g_local.h` — entity types, flags (`FL_FLY`, `FL_SWIM`, `FL_PARTIALGROUND`, `AI_NOSTEP`), masks (`MASK_MONSTERSOLID`, `MASK_WATER`)
- `gi.trace`, `gi.pointcontents`, `gi.linkentity` — server game import interface (defined elsewhere in engine)
- `G_TouchTriggers` — defined elsewhere in CTF game module
- `anglemod`, `VectorAdd`, `VectorCopy` — math utilities (defined elsewhere)

# ctf/m_player.h
## File Purpose
Auto-generated header defining all animation frame index constants for the CTF player model. It maps symbolic frame names to sequential integer indices used by the animation system to reference frames within the player's `.md2` model file.

## Core Responsibilities
- Enumerate all player animation frames as preprocessor constants
- Define frame ranges for: idle stand, run, attack, pain, jump, gestures (flip, salute, taunt, wave, point), crouch states, and death sequences
- Provide `MODEL_SCALE` for world-space scaling of the player model

## External Dependencies
- No includes.
- Consumed by: `ctf/p_view.c`, `ctf/p_client.c`, `ctf/p_weapon.c` (defined elsewhere).
- `MODEL_SCALE` may be read by model loading or collision code (defined elsewhere).

# ctf/p_client.c
## File Purpose
Implements the CTF-variant player client lifecycle for Quake 2, covering connection, spawning, death, respawning, per-frame input processing, and disconnection. It is the CTF-modified fork of `game/p_client.c`, adding grapple, flag, tech, and team-assignment hooks throughout.

## Core Responsibilities
- Manage player connection/disconnection and userinfo parsing
- Select and validate spawn points (deathmatch, coop, CTF, single-player)
- Initialize and reset persistent and per-respawn client state
- Handle player death: obituaries, gibbing, animation, weapon toss, CTF flag/tech drops
- Drive per-client-frame physics via `gi.Pmove`, touch resolution, and weapon firing
- Drive per-server-frame logic: weapon animation ticks and dead-player respawn gating
- Maintain a body queue for corpse entities after respawn

## External Dependencies
- **Includes:** `g_local.h`, `m_player.h` (frame constants)
- **Defined elsewhere:** `CTFStartClient`, `CTFFragBonuses`, `CTFPlayerResetGrapple`, `CTFDeadDropFlag`, `CTFDeadDropTech`, `CTFGrapplePull`, `CTFApplyRegeneration`, `CTFAssignTeam`, `CTFAssignSkin`, `CTFMatchOn`, `SelectCTFSpawnPoint`, `UpdateChaseCam`, `PMenu_Do_Update`, `Think_Weapon`, `ChangeWeapon`, `Drop_Item`, `ThrowGib`, `ThrowClientHead`, `PlayerTrail_Add`, `G_Find`, `G_Spawn`, `G_FreeEdict`, `G_InitEdict`, `KillBox`, `ClientEndServerFrame`, `MoveClientToIntermission`, `gi.*` (engine import table)

# ctf/p_hud.c
## File Purpose
Implements the CTF variant HUD system, including intermission sequencing, deathmatch scoreboard rendering, help computer display, and per-frame player stat updates sent to the client. It is largely identical to `game/p_hud.c` but with CTF-specific hooks injected at key points.

## Core Responsibilities
- Teleport clients to intermission camera positions and freeze them
- Trigger and coordinate the intermission/end-of-level sequence
- Build and unicast the deathmatch scoreboard layout string
- Render the in-game help computer overlay
- Populate `player_state_t.stats[]` each frame for HUD rendering (health, ammo, armor, timers, frags, layouts)
- Delegate scoreboard and score calculation to CTF-specific functions when `ctf->value` is set

## External Dependencies
- `g_local.h` — all game types, CVars (`deathmatch`, `coop`, `ctf`, `skill`), `level`, `game`, `g_edicts`, `itemlist`
- `CTFCalcScores`, `CTFScoreboardMessage`, `SetCTFStats`, `PMenu_Close` — defined in `g_ctf.c` / `p_menu.c`
- `PowerArmorType`, `ArmorIndex`, `FindItem`, `GetItemByIndex` — defined in `g_items.c`
- `G_Find`, `respawn` — defined in `g_utils.c` / `p_client.c`
- `gi` (game import struct) — provided by the engine at game init

# ctf/p_menu.c
## File Purpose
Implements a per-client in-game HUD menu system for the CTF game module. Menus are rendered via the layout string mechanism (svc_layout) and displayed over the inventory screen. Each client maintains its own dynamically allocated menu state.

## Core Responsibilities
- Allocate and initialize per-client menu handles with deep-copied entries
- Serialize menu entries into a layout string and send via unicast
- Rate-limit menu redraws (dirty flag + 1-second threshold)
- Navigate menu cursor forward/backward, skipping non-selectable entries
- Invoke the selected entry's callback function
- Free all menu resources on close

## External Dependencies
- `g_local.h` — pulls in all game types, `gi` import table, `level`, entity/client structs
- `gi.unicast`, `gi.WriteByte`, `gi.WriteString`, `gi.dprintf` — engine import table (defined in engine)
- `pmenu_t`, `pmenuhnd_t`, `SelectFunc_t` — declared in `ctf/p_menu.h`
- `svc_layout` — engine protocol constant (defined in `qcommon/qcommon.h` or equivalent)
- `level.time` — global game state (defined in `g_local.h`)

# ctf/p_menu.h
## File Purpose
Declares the in-game player menu system used by the CTF (Capture the Flag) mod. It defines the data structures and public API for presenting a navigable, text-based HUD menu to individual players during gameplay.

## Core Responsibilities
- Define alignment constants for menu entry text positioning
- Declare the `pmenu_t` structure representing a single menu entry (text, alignment, callback)
- Declare the `pmenuhnd_t` handle tracking an open menu instance and its cursor state
- Expose the full lifecycle API: open, close, update, navigate, and select menu entries

## External Dependencies
- `edict_t` — defined in `ctf/g_local.h` / `game.h`; the core game entity type
- `SelectFunc_t` depends on `edict_t` being declared prior to this header's inclusion

# ctf/p_trail.c
## File Purpose
Implements a circular buffer of recent player position markers used by AI monsters for pursuit logic. Each trail node is a lightweight `edict_t` storing a world position, timestamp, and facing angle.

## Core Responsibilities
- Allocate and initialize the fixed-size circular trail buffer at game start
- Record new player positions into the trail ring as the player moves
- Provide monster AI with trail node lookups: first visible/reachable node, next node ahead, and the most recent spot

## External Dependencies
- `g_local.h` — brings in `edict_t`, `level`, `monsterinfo`, `G_Spawn`, `visible`, `vectoyaw`, `VectorCopy`, `VectorSubtract`, `deathmatch`
- `G_Spawn` — defined in `g_utils.c`
- `visible` — defined in `g_ai.c`
- `vectoyaw` — defined in `g_utils.c` / `q_shared.c`
- `deathmatch` — cvar defined in `g_main.c`

# ctf/p_view.c
## File Purpose
Handles per-frame player view computation for the CTF game module, including view angles, bob, roll, blend effects, falling damage, world environmental effects, and client-side state finalization at end of server frame.

## Core Responsibilities
- Compute view angle kick from damage, fall impact, velocity, and bob
- Compute gun offset and angles from bob and view delta
- Calculate full-screen color blend from environment, powerups, and damage
- Apply environmental hazard damage (drowning, lava, slime)
- Detect and apply falling damage (with CTF grapple immunity)
- Drive player animation state machine (stand/walk/duck/jump/pain/death)
- Finalize per-client `player_state_t` fields at end of server frame
- Propagate stats to chase-cam followers (CTF-specific)

## External Dependencies
- `g_local.h` — `edict_t`, `gclient_t`, all game cvars and constants
- `m_player.h` — player animation frame constants (`FRAME_*`, `ANIM_*`)
- External symbols: `sv_rollangle`, `sv_rollspeed`, `run_pitch`, `run_roll`, `bob_pitch`, `bob_roll`, `bob_up`, `gun_x/y/z`, `deathmatch`, `dmflags`, `maxclients` (cvars); `T_Damage`, `PlayerNoise`, `PowerArmorType`, `CTFEffects`, `G_SetStats`, `DeathmatchScoreboardMessage`, `PMenu_Do_Update` (game functions); `gi` (engine import struct); `world`, `g_edicts`, `level`, `game` (global state).

# ctf/p_weapon.c
## File Purpose
Implements all player weapon logic for the CTF (Capture the Flag) game module, including weapon pickup, switching, firing, animation state management, and noise generation for AI targeting. This is the CTF variant of the standard `game/p_weapon.c`, augmented with CTF-specific haste and strength power-up hooks.

## Core Responsibilities
- Manage weapon state machine (ACTIVATING → READY → FIRING → DROPPING → ChangeWeapon)
- Project weapon fire origin accounting for player handedness (left/center/right)
- Generate `PlayerNoise` entities for monster AI awareness
- Handle weapon pickup, drop, and ammo-conditional switching
- Implement per-weapon fire callbacks (grenade, rocket, blaster, shotguns, machinegun, chaingun, railgun, BFG)
- Apply CTF power-ups: quad damage (`is_quad`), silencer (`is_silenced`), haste (double tick via `CTFApplyHaste`), strength sound (`CTFApplyStrengthSound`)

## External Dependencies
- **Includes:** `g_local.h`, `m_player.h`
- **Defined elsewhere:** `G_ProjectSource`, `G_Spawn`, `gi.*` (engine game import), `fire_grenade`, `fire_grenade2`, `fire_rocket`, `fire_blaster`, `fire_bullet`, `fire_shotgun`, `fire_rail`, `fire_bfg`, `FindItem`, `Add_Ammo`, `Drop_Item`, `SetRespawn`, `CTFApplyHaste`, `CTFApplyHasteSound`, `CTFApplyStrengthSound`, `instantweap` (cvar), `dmflags`, `coop`, `g_select_empty`, `level`, `g_edicts`

# ctf/q_shared.c
## File Purpose
Shared utility library for the CTF game module, providing math, string, byte-order, and info-string primitives used across client, server, and game code. This is a near-identical copy of `game/q_shared.c` scoped to the CTF mod.

## Core Responsibilities
- 3D vector and matrix math (normalize, cross product, rotation, bounds)
- Angle/rotation utilities (AngleVectors, LerpAngle, anglemod)
- AABB plane-side classification (BoxOnPlaneSide, with x86 asm fast path)
- Byte-order detection and endian-swap initialization
- String utilities (case-insensitive compare, sprintf wrapper, token parser)
- File path manipulation (strip extension, file base, default extension)
- Info-string key/value encoding and parsing

## External Dependencies
- Notable includes: `q_shared.h` (all type and macro definitions)
- `Com_Printf` — defined elsewhere (engine common layer); used for error/warning output in string utilities
- `sin`, `cos`, `sqrt`, `fabs`, `vsprintf`, `strcasecmp`/`_stricmp` — C runtime
- `VectorNormalize`, `DotProduct` — macros or functions declared in `q_shared.h`
- `R_ConcatRotations` — defined in this same file (self-call)
- `ProjectPointOnPlane`, `PerpendicularVector` — also defined in this file

# ctf/q_shared.h
## File Purpose
The universal shared header for the CTF game module, included first by all translation units. It defines the engine-game protocol contract: fundamental types, math primitives, collision structures, network-communicated entity/player state, and all enumerated constants for effects, events, and game configuration.

## Core Responsibilities
- Define portable primitive types (`byte`, `qboolean`) and platform detection macros (`id386`, `idaxp`)
- Declare the math library: vector types, macros, and function prototypes
- Define collision detection structures (`cplane_t`, `cmodel_t`, `trace_t`, `pmove_t`)
- Declare the network protocol types: `entity_state_t`, `player_state_t`, `pmove_state_t`, `usercmd_t`
- Enumerate all effect flags (`EF_*`), render flags (`RF_*`), temp events (`TE_*`), muzzle flashes (`MZ_*`, `MZ2_*`)
- Define config string layout (`CS_*`) and deathmatch flags (`DF_*`)
- Declare system/utility interfaces: cvars, info strings, hunk allocator, byte-order functions

## External Dependencies
- **Standard library**: `<assert.h>`, `<math.h>`, `<stdio.h>`, `<stdarg.h>`, `<string.h>`, `<stdlib.h>`, `<time.h>`
- **Defined elsewhere**:
  - `vec3_origin` — `ctf/q_shared.c`
  - `monster_flash_offset` — `game/m_flash.c` (or CTF equivalent)
  - `curtime` — platform `sys_*.c`
  - `vidref_val` — renderer/video init code
  - All declared math, string, system, and byte-order functions — `ctf/q_shared.c` and platform layers
  - `struct edict_s` — forward-declared only; defined in `ctf/g_local.h`

# game/g_ai.c
## File Purpose
Implements the core AI behavior system for Quake 2 monsters, providing movement primitives, target detection/acquisition, attack decision-making, and enemy pursuit logic. It bridges per-frame monster state machine calls with the engine's movement and trace systems.

## Core Responsibilities
- Cycle the global sight client each frame (`AI_SetSightClient`)
- Provide movement primitives used by monster animation frames (`ai_move`, `ai_stand`, `ai_walk`, `ai_charge`, `ai_turn`, `ai_run`)
- Detect and acquire targets via sight, sound, and proximity (`FindTarget`, `FoundTarget`, `HuntTarget`)
- Evaluate attack feasibility and select attack mode (`M_CheckAttack`, `ai_checkattack`)
- Execute attack approach behaviors: close for melee, align for missile, strafe sideways (`ai_run_melee`, `ai_run_missile`, `ai_run_slide`)
- Implement lost-sight pursuit using player trail waypoints (`ai_run`)

## External Dependencies
- **Includes:** `g_local.h` (all game types, entity fields, `monsterinfo_t`, AI flags, range constants)
- **Defined elsewhere:** `M_walkmove`, `M_MoveToGoal`, `M_ChangeYaw` (`game/m_move.c`); `G_Spawn`, `G_FreeEdict`, `G_PickTarget`, `G_ProjectSource`, `AttackFinished` (various `g_*.c`); `PlayerTrail_PickFirst`, `PlayerTrail_PickNext` (`game/p_trail.c`); `gi.trace`, `gi.inPHS`, `gi.AreasConnected`, `gi.dprintf` (engine import struct); `g_edicts`, `level`, `game`, `coop`, `skill` (game globals)

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

## External Dependencies
- `g_local.h` — entity definitions, `gclient_t`, `gi` interface, `g_edicts`, `maxclients`
- `gi.trace`, `gi.linkentity`, `gi.centerprintf` — engine callbacks (defined elsewhere)
- `AngleVectors`, `VectorMA`, `VectorNormalize`, `VectorCopy`, `ANGLE2SHORT` — math utilities (defined elsewhere)
- `PMF_NO_PREDICTION`, `PM_DEAD`, `PM_FREEZE`, `MASK_SOLID` — engine constants (defined elsewhere)

# game/g_cmds.c
## File Purpose
Implements all client-issued game commands (chat, inventory, cheats, wave, kill, etc.) dispatched through the central `ClientCommand` entry point. Bridges player input from the network layer to game-state mutations and UI feedback.

## Core Responsibilities
- Dispatch client commands via `ClientCommand` to appropriate handlers
- Implement cheat commands: `give`, `god`, `notarget`, `noclip`
- Handle inventory navigation, use, and drop
- Handle weapon cycling (next/prev/last)
- Implement chat (`say`/`say_team`) with flood protection
- Provide player listing utilities (`players`, `playerlist`)
- Determine team membership for team-based deathmatch modes

## External Dependencies
- **Includes:** `g_local.h`, `m_player.h`
- **Defined elsewhere:** `gi` (game import struct), `itemlist`, `g_edicts`, `game`, `level`, `meansOfDeath`, `dmflags`, `sv_cheats`, `deathmatch`, `maxclients`, `dedicated`, `flood_msgs`, `flood_persecond`, `flood_waitdelay`, `FindItem`, `Add_Ammo`, `SpawnItem`, `Touch_Item`, `G_Spawn`, `G_FreeEdict`, `player_die`, `ChaseNext`, `ChasePrev`, `Cmd_Score_f`, `Cmd_Help_f`, all `FRAME_*` constants from `m_player.h`.

# game/g_combat.c
## File Purpose
Implements the core damage, knockback, and death processing systems for the Quake 2 game logic. Handles direct damage application (`T_Damage`), radius/splash damage (`T_RadiusDamage`), armor and power armor absorption, kill accounting, and monster aggression responses to being attacked.

## Core Responsibilities
- Line-of-sight checks for damage eligibility (`CanDamage`)
- Full damage pipeline: godmode, invincibility, power armor, armor, net health reduction
- Knockback velocity application scaled by mass and attacker identity
- Kill event dispatch and score/stat tracking (`Killed`)
- Monster AI target switching in response to damage (`M_ReactToDamage`)
- Radius damage attenuation and entity enumeration (`T_RadiusDamage`)
- Temporary effect (blood/sparks) spawning at impact points

## External Dependencies
- **Includes:** `g_local.h` (all engine/game types and macros)
- **Defined elsewhere:** `gi` (game import struct), `findradius`, `OnSameTeam`, `visible`, `FoundTarget`, `monster_death_use`, `PowerArmorType`, `ArmorIndex`, `GetItemByIndex`, `FindItem`, `ITEM_INDEX`, `level`, `skill`, `deathmatch`, `dmflags`, `coop`, `meansOfDeath`, `vec3_origin`

# game/g_func.c
## File Purpose
Implements all brush-function entities (`func_*`) that involve movement, rotation, or triggered behavior in Quake 2. This includes platforms, doors, rotating brushes, trains, conveyors, buttons, secret doors, timers, and killboxes.

## Core Responsibilities
- Provide linear and angular movement primitives (velocity stepping, acceleration/deceleration) used by all moving entities
- Spawn and configure `func_plat`, `func_door`, `func_door_rotating`, `func_door_secret`, `func_rotating`, `func_train`, `func_water`, `func_button`, `func_conveyor`, `func_timer`, `func_killbox`, and `trigger_elevator`
- Manage state machines (STATE_TOP/BOTTOM/UP/DOWN) for all moving entities
- Handle blocked/touch/use/kill callbacks for each entity type
- Synchronize team-linked door/plat movement so all members complete travel at the same time
- Integrate with area portals on door open/close

## External Dependencies
- `g_local.h` — all game types, macros (`FRAMETIME`, `FL_TEAMSLAVE`, state constants), `gi` interface
- **Defined elsewhere:** `T_Damage`, `BecomeExplosion1`, `KillBox`, `G_UseTargets`, `G_Find`, `G_PickTarget`, `G_Spawn`, `G_SetMovedir`, `AddPointToBounds`, `crandom`, `vtos`; `gi.sound`, `gi.soundindex`, `gi.setmodel`, `gi.linkentity`, `gi.centerprintf`, `gi.SetAreaPortalState`, `gi.dprintf`

# game/g_items.c
## File Purpose
Defines all collectable items in the game (weapons, ammo, armor, health, powerups, keys) and implements the complete lifecycle of item pickup, use, drop, respawn, and world placement. It is the authoritative item registry for the game module.

## Core Responsibilities
- Declares and populates the global `itemlist[]` item registry
- Implements pickup callbacks for every item category (armor, health, ammo, powerups, keys, weapons)
- Implements use callbacks for timed powerups (Quad, Breather, Envirosuit, Invulnerability, Silencer, Power Armor)
- Implements drop logic for weapons, ammo, and general items
- Manages item respawn scheduling via `SetRespawn` / `DoRespawn`
- Handles item world placement (`droptofloor`, `SpawnItem`, `PrecacheItem`)
- Provides lookup utilities (`FindItem`, `FindItemByClassname`, `GetItemByIndex`)

## External Dependencies
- **Includes:** `g_local.h` (pulls in all game types, `gi` import table, cvars, macros)
- **Defined elsewhere:** `gi` (game import struct), `game`, `level`, `itemlist` (self), `skill`, `deathmatch`, `coop`, `dmflags` (cvars), `G_Spawn`, `G_FreeEdict`, `G_UseTargets`, `ValidateSelectedItem`, `ArmorIndex` (defined here), all `Weapon_*` functions (in `p_weapon.c` / `g_weapon.c`)

# game/g_local.h
## File Purpose
The primary internal header for the Quake 2 game module (game DLL). It defines all game-side types, constants, and the full ("fat") `edict_t` and `gclient_s` structures, as well as declaring every cross-file symbol used within the game module.

## Core Responsibilities
- Define `GAME_INCLUDE` to unlock full struct definitions from `game.h`
- Declare complete `edict_s` and `gclient_s` layouts (server only sees opaque stubs)
- Define all game-logic enumerations and constant sets (damage types, AI flags, move types, MOD codes, etc.)
- Declare global singletons (`game`, `level`, `gi`, `globals`, `st`) shared across all game source files
- Expose all cross-file function prototypes for every game subsystem
- Define field-offset macros (`FOFS`, `STOFS`, etc.) used by the save/load and spawn systems

## External Dependencies
- `q_shared.h` — shared math, string, and type primitives
- `game.h` — engine/game interface types (`game_import_t`, `game_export_t`, opaque `edict_t`/`gclient_t` stubs, `player_state_t`, `pmove_state_t`)
- `FOFS` / `STOFS` / `LLOFS` / `CLOFS` — zero-pointer offset macros depend on `edict_t`, `spawn_temp_t`, `level_locals_t`, `gclient_t` being fully defined here
- All `cvar_t *` globals defined and registered in `g_main.c`
- `fields[]` and `itemlist[]` arrays defined in `g_save.c` and `g_items.c` respectively

# game/g_main.c
## File Purpose
This is the game DLL entry point and main frame loop for the Quake 2 game module. It initializes the game-engine interface, registers all exported game functions, and drives the per-frame simulation of every entity in the world.

## Core Responsibilities
- Expose `GetGameAPI` as the DLL entry point, wiring all game callbacks into `game_export_t`
- Maintain global game state: `game`, `level`, `gi`, `globals`, `st`
- Drive the per-frame entity update loop (`G_RunFrame`)
- Enforce deathmatch win conditions (timelimit, fraglimit) via `CheckDMRules`
- Manage level transitions: map cycling, intermission, and exit
- Provide `Sys_Error`/`Com_Printf` stubs for non-hard-linked builds

## External Dependencies
- `g_local.h` — pulls in all game types, constants, and forward declarations
- `AI_SetSightClient`, `M_CheckGround` — defined in `g_ai.c` / `g_monster.c`
- `G_RunEntity`, `G_Find`, `G_Spawn` — defined in `g_utils.c` / `g_phys.c`
- `ClientBeginServerFrame`, `ClientEndServerFrame`, `BeginIntermission` — defined in `p_client.c`
- `ServerCommand` — defined in `g_svcmds.c`
- All `gi.*` functions — provided by engine at runtime via `GetGameAPI`

# game/g_misc.c
## File Purpose
Implements the spawn and logic functions for miscellaneous game entities in Quake 2's server-side game DLL. Covers area portals, gibs, debris, decorative objects, scripted world props (teleporters, clocks, path nodes, explosive barrels), and various `misc_*`/`func_*` entity types used by map designers.

## Core Responsibilities
- Spawning and managing gib/debris physics entities thrown on death
- Handling area portal open/close state
- Implementing path corner and combat point navigation nodes for monsters
- Providing func_wall, func_object, and func_explosive brush entities
- Implementing misc_explobox (exploding barrel) with delayed detonation
- Managing decorative/scripted entities (banners, ships, teleporters, clocks, easter eggs)
- Providing teleporter trigger and destination spawners

## External Dependencies
- **Includes:** `g_local.h` (pulls in all game types, `edict_t`, `gi`, `level`, constants)
- **Defined elsewhere:** `G_Spawn`, `G_FreeEdict`, `G_UseTargets`, `G_PickTarget`, `G_Find`, `KillBox`, `T_Damage`, `T_RadiusDamage`, `M_walkmove`, `M_droptofloor`, `train_use`, `func_train_find`, `sm_meat_index`, `vectoangles`, `vectoyaw`, `AngleVectors`, `Com_sprintf`

# game/g_monster.c
## File Purpose
Provides the shared monster infrastructure for the Quake 2 game module, including weapon-fire wrappers, per-frame animation/AI ticking, environmental interaction (water/lava/slime), and the initialization pipeline for walk/fly/swim monster types.

## Core Responsibilities
- Wrap projectile/hitscan fire functions with muzzle-flash network broadcasts for monster use
- Drive per-frame animation state machine (`M_MoveFrame`) through `mmove_t` sequences
- Tick monster logic each server frame (`monster_think`): move, ground-check, categorize position, apply world effects, set visual effects
- Handle monster activation via `monster_use` and triggered spawning
- Fire death targets via `monster_death_use`
- Initialize monsters through a three-stage pipeline: `monster_start` → `*_start_go` → `monster_start_go`

## External Dependencies
- **Includes:** `g_local.h` (all game types, macros, prototypes)
- **Defined elsewhere:** `fire_bullet/shotgun/blaster/grenade/rocket/rail/bfg`, `T_Damage`, `Drop_Item`, `G_UseTargets`, `G_Find`, `G_PickTarget`, `KillBox`, `FoundTarget`, `M_CheckAttack`, `M_walkmove`, `vectoyaw`, `gi` (game import struct), `level`, `g_edicts`, `world`, `deathmatch`, `st`

# game/g_phys.c
## File Purpose
Implements the server-side physics simulation for all game entities. Dispatches per-frame movement and collision logic based on each entity's `movetype`, covering pusher platforms, toss/bounce projectiles, stepping monsters, and noclip objects.

## Core Responsibilities
- Clamp entity velocity to configured maximum each frame
- Apply gravity, friction, and rotational friction per movetype
- Slide-move resolution across multiple collision planes (`SV_FlyMove`)
- Push-move logic with rollback on blocked movement (`SV_Push`, `SV_Physics_Pusher`)
- Trigger touch dispatch after any positional change
- Run entity think functions at the correct simulation time
- Dispatch all entities through `G_RunEntity` based on `movetype`

## External Dependencies
- `g_local.h` — entity definitions, game globals, `gi` interface
- `sv_maxvelocity`, `sv_gravity` — cvars defined in server/common layer
- `M_CheckGround`, `M_CheckBottom` — defined in `g_monster.c`/`m_move.c`
- `G_TouchTriggers` — defined in `g_utils.c`
- `gi.trace`, `gi.linkentity`, `gi.sound`, `gi.pointcontents`, `gi.error` — engine interface (`gi` game import struct)

# game/g_save.c
## File Purpose
Implements the game DLL's serialization and deserialization system for save games and level transitions. Handles binary I/O of entity state, client state, level globals, and game globals by converting non-portable pointer types to portable indices before writing and restoring them on load.

## Core Responsibilities
- Define the `fields[]`, `levelfields[]`, and `clientfields[]` descriptor tables mapping field names to struct offsets and types
- Serialize and deserialize `edict_t`, `gclient_t`, and `level_locals_t` structures with pointer fixup
- Implement `WriteGame`/`ReadGame` for cross-level persistent state (client inventories, etc.)
- Implement `WriteLevel`/`ReadLevel` for per-level entity snapshots
- Convert pointer fields (edict refs, item refs, function pointers, mmove pointers) to portable integer indices before binary writes and restore them on read
- Host `InitGame`, the game DLL entry point called on new game or save load

## External Dependencies
- `g_local.h` — `edict_t`, `gclient_t`, `level_locals_t`, `game_locals_t`, field type enums, `FOFS`/`STOFS`/`LLOFS`/`CLOFS` offset macros
- `g_edicts`, `globals`, `game`, `level`, `itemlist`, `maxclients` — defined elsewhere in game DLL
- `gi` (game import interface) — `gi.cvar`, `gi.TagMalloc`, `gi.FreeTags`, `gi.linkentity`, `gi.error`, `gi.dprintf`
- `SaveClientData()`, `InitItems()` — defined elsewhere in game DLL
- Standard C: `fopen`, `fread`, `fwrite`, `fclose`, `memset`, `strcmp`, `strcpy`

# game/g_spawn.c
## File Purpose
This file implements the entity spawning subsystem for the Quake 2 game module. It parses the map's entity lump (text-format key/value pairs), maps classnames to spawn functions via a dispatch table, and initializes the world entity with all required precached assets and configstrings.

## Core Responsibilities
- Maintain the `spawns[]` dispatch table mapping classname strings to `SP_*` spawn functions
- Parse raw entity text from the BSP into `edict_t` structs via `ED_ParseEdict` / `ED_ParseField`
- Dispatch `ED_CallSpawn` to invoke the correct spawn function per entity
- Filter entities by skill level and deathmatch flags during map load
- Chain team-slave entities together via `G_FindTeams`
- Initialize the world entity (`SP_worldspawn`) with all sound/model precaches, configstrings, and light style tables
- Define HUD statusbar layout strings for singleplayer and deathmatch

## External Dependencies
- **Includes:** `g_local.h` (pulls in `edict_t`, `gitem_t`, `field_t`, `spawn_temp_t st`, `fields[]`, `itemlist`, `level`, `game`, `g_edicts`, `globals`, cvars)
- **Defined elsewhere:** `COM_Parse`, `SpawnItem`, `G_Spawn`, `G_FreeEdict`, `SaveClientData`, `InitBodyQue`, `SetItemNames`, `PrecacheItem`, `FindItem`, `PlayerTrail_Init`, `Q_stricmp`, `gi` (game import struct), all `SP_*` functions

# game/g_svcmds.c
## File Purpose
Implements server-side console command handling for the game DLL, including a test command and a full IP address filtering/banning system. Provides the `ServerCommand` entry point called by the engine when an `sv` command is issued.

## Core Responsibilities
- Dispatch server commands via `ServerCommand` to sub-handlers
- Parse dotted-quad IP strings into bitmask filter structs
- Maintain a static list of IP filters (`ipfilters[]`) for packet filtering
- Allow runtime add/remove/list/write of IP ban or allowlist entries
- Determine whether an incoming packet address should be allowed or blocked

## External Dependencies
- `g_local.h` — pulls in all game types, `gi` interface, `filterban` cvar extern
- `filterban` — cvar defined elsewhere (likely `g_main.c`)
- `gi.cprintf`, `gi.argc`, `gi.argv`, `gi.cvar` — engine game import interface
- `Q_stricmp` — defined in `q_shared.c`
- `MAX_OSPATH`, `GAMEVERSION` — macros from shared headers

# game/g_target.c
## File Purpose
Implements all `target_*` entities for the Quake 2 game logic layer. These are trigger-response objects spawned from map data that produce scripted gameplay events (sounds, explosions, level changes, lasers, etc.) when activated by other entities.

## Core Responsibilities
- Register spawn functions (`SP_*`) and use callbacks (`use_*` / `Use_*`) for each target entity type
- Produce client-side temporary entity events (multicast packets) for visual/audio effects
- Manage level state: secret/goal counters, intermission, cross-level serverflags
- Apply radius damage, laser beam tracing, and earthquake physics to world entities
- Handle looping/positional audio via `gi.sound` / `gi.positioned_sound`
- Deferred execution via `think`/`nextthink` for delayed effects (explosion, laser, lightramp, earthquake)

## External Dependencies
- `g_local.h` — `edict_t`, `level`, `game`, `g_edicts`, `globals`, `st`, spawn flags, damage flags
- `gi` game import table — `WriteByte`, `WritePosition`, `WriteDir`, `multicast`, `positioned_sound`, `sound`, `soundindex`, `linkentity`, `unlinkentity`, `trace`, `configstring`, `dprintf`, `bprintf`
- Defined elsewhere: `T_Damage`, `T_RadiusDamage`, `G_UseTargets`, `G_FreeEdict`, `G_Spawn`, `G_Find`, `G_SetMovedir`, `KillBox`, `BeginIntermission`, `ED_CallSpawn`, `fire_blaster`, `VectorMA`, `VectorNormalize`, `crandom`, `vtos`, `Com_sprintf`, `Q_stricmp`

# game/g_trigger.c
## File Purpose
Implements all trigger entity types for the Quake 2 game module. Triggers are invisible volume-based or event-driven entities that fire targets, apply forces, deal damage, or alter physics when activated by players, monsters, or other entities.

## Core Responsibilities
- Initialize trigger volumes (solid, movetype, model linkage)
- Handle multi-fire and single-fire trigger logic with configurable wait/delay
- Implement key-gated relay triggers with coop inventory management
- Provide push/hurt/gravity/monsterjump environmental trigger volumes
- Support counter-based sequencing before target firing
- Manage TRIGGERED spawnflag (dormant until enabled by another event)

## External Dependencies
- **Includes:** `g_local.h` (pulls in all game types, `edict_t`, `gi`, level state)
- **Defined elsewhere:** `G_UseTargets`, `G_SetMovedir`, `G_FreeEdict`, `T_Damage`, `FindItemByClassname`, `ITEM_INDEX`, `AngleVectors`, `VectorCompare`, `VectorScale`, `VectorCopy`, `VectorMA`, `vtos`, `g_edicts`, `game`, `level`, `st`, `coop`, `FRAMETIME`

# game/g_turret.c
## File Purpose
Implements the multi-part controllable turret entity system, consisting of a rotating base, a pitching/yawing breach (gun head), and an AI-driven infantry driver entity that autonomously targets and fires the turret.

## Core Responsibilities
- Define spawn functions for `turret_breach`, `turret_base`, and `turret_driver` entities
- Manage per-frame angle interpolation of the breach toward a target orientation
- Clamp breach pitch/yaw to configured min/max limits
- Synchronize yaw angular velocity across all team members
- Position-correct the driver entity to ride the breach as it rotates
- Handle driver AI: enemy detection, line-of-sight tracking, and fire signaling
- Handle driver death: detach from team chain and level the gun

## External Dependencies
- `g_local.h` — all game types, macros (`FRAMETIME`, `MOD_CRUSH`, AI flags), and engine interface (`gi`)
- **Defined elsewhere:** `T_Damage`, `fire_rocket`, `G_PickTarget`, `G_FreeEdict`, `FindTarget`, `visible`, `vectoangles`, `AngleVectors`, `VectorMA/Scale/Subtract/Copy/Length/Set`, `vtos`, `infantry_die`, `infantry_stand`, `monster_use`, `FindItemByClassname`, `skill`, `level`, `deathmatch`

# game/g_utils.c
## File Purpose
Miscellaneous utility functions for the Quake 2 game module. Provides entity search, spawning/freeing, target firing, vector math helpers, and trigger/solid overlap detection used throughout the game logic.

## Core Responsibilities
- Entity search by field string match and by spatial radius
- Entity spawning (slot allocation) and freeing (slot recycling)
- Target chain firing with optional delay, kill-targets, and centerprint messaging
- Vector/angle conversion utilities (temp vectors, yaw extraction, full angle decomposition)
- Movement direction resolution from special angle sentinels
- Trigger and solid overlap testing after entity movement
- Kill-box telefrag logic for teleportation

## External Dependencies
- `g_local.h` — pulls in all game types, `gi` (game import), `g_edicts`, `globals`, `level`, `game`, `maxclients`
- `T_Damage` — defined in `g_combat.c`
- `G_UseTargets` — forward-referenced by `Think_Delay` within the same file
- `AngleVectors`, `VectorLength`, `VectorCompare`, `VectorCopy`, `VectorClear`, `Com_sprintf`, `Q_stricmp` — defined in shared/common code

# game/g_weapon.c
## File Purpose
Implements all projectile and hitscan weapon firing logic for the Quake 2 game DLL. Covers bullet/pellet spread, blaster bolts, grenades, rockets, railgun, and the BFG, including their spawned entity lifecycle and impact/explosion callbacks.

## Core Responsibilities
- Hitscan weapons: bullet and shotgun pellet tracing with spread, water deflection, and splash effects
- Melee impact: range-checked hit detection with knockback for monsters/players
- Projectile spawning: blaster, grenade (standard and hand), rocket, BFG entities with movement, touch, and think callbacks
- Monster dodge triggering for non-instant projectiles
- Radius and direct damage dispatch via `T_Damage` / `T_RadiusDamage`
- Temp-entity multicast for visual/audio effects (gun puffs, explosions, rail trail, bubble trails)
- BFG-specific per-frame laser sweep logic during flight

## External Dependencies
- `g_local.h` (all engine/game types)
- `T_Damage`, `T_RadiusDamage`, `ThrowDebris`, `CanDamage`, `findradius` — combat/utility, defined in `g_combat.c` / `g_utils.c`
- `PlayerNoise` — defined in `p_weapon.c`
- `G_Spawn`, `G_FreeEdict` — entity management, `g_utils.c`
- `gi` game import table: `gi.trace`, `gi.pointcontents`, `gi.modelindex`, `gi.soundindex`, `gi.linkentity`, `gi.sound`, `gi.WriteByte`, `gi.WritePosition`, `gi.WriteDir`, `gi.multicast`
- `skill`, `deathmatch`, `coop` — cvars, defined elsewhere
- `level.time`, `FRAMETIME` — globals from `g_main.c` / `g_local.h`

# game/game.h
## File Purpose
Defines the ABI contract between the Quake 2 server engine and the game DLL. It establishes the two-way function pointer tables (`game_import_t` / `game_export_t`) and the minimal shared entity types the server must see without knowing game-internal details.

## Core Responsibilities
- Declare `GAME_API_VERSION` to enforce ABI compatibility checks at load time
- Define `solid_t` enum and `SVF_*` flags used by both server and game for collision/visibility
- Provide stub `edict_s` / `gclient_s` structs for server-side use when `GAME_INCLUDE` is not defined
- Expose `game_import_t`: all engine services callable by the game DLL
- Expose `game_export_t`: all entry points and shared data the server calls into the game DLL
- Declare `GetGameApi`, the single DLL entry point used to bootstrap the interface

## External Dependencies
- **Includes:** Implicitly depends on `q_shared.h` for `vec3_t`, `trace_t`, `entity_state_t`, `player_state_t`, `usercmd_t`, `pmove_t`, `multicast_t`, `cvar_t`, `qboolean`.
- **Defined elsewhere:** `entity_state_t`, `player_state_t`, `usercmd_t`, `pmove_t`, `multicast_t`, `cvar_t` — all in `qcommon/q_shared.h` / `qcommon/qcommon.h`. `GetGameApi` body lives in `game/g_main.c`.

# game/m_actor.c
## File Purpose
Implements the `misc_actor` entity — a scripted NPC that uses the player model and follows a chain of `target_actor` waypoints. Also defines the `target_actor` waypoint entity, which drives actor movement, speech, jumping, and combat behavior.

## Core Responsibilities
- Define all animation frame sequences for the actor (stand, walk, run, pain, attack, death, flipoff, taunt)
- Handle actor AI callbacks: pain response, attack firing, death/gib logic
- Spawn and initialize `misc_actor` entities with full monster AI wiring
- Spawn and initialize `target_actor` waypoint entities with trigger volumes
- Route actors along a target chain via `target_actor_touch` waypoint logic
- Allow actors to taunt/flip off players who damage them and broadcast chat messages

## External Dependencies
- **Includes:** `g_local.h`, `m_actor.h`
- **Defined elsewhere:** `ai_stand`, `ai_walk`, `ai_run`, `ai_move`, `ai_turn`, `ai_charge` (AI primitives, `g_ai.c`); `monster_fire_bullet`, `G_ProjectSource`, `monster_flash_offset` (`g_monster.c`/`m_flash.c`); `ThrowGib`, `ThrowHead`, `G_PickTarget`, `G_UseTargets`, `G_SetMovedir`, `G_FreeEdict` (`g_utils.c`/`g_misc.c`); `walkmonster_start` (`g_monster.c`); `gi` (game import struct, engine-provided); `g_edicts`, `level`, `game`, `deathmatch` (globals, `g_main.c`)

# game/m_actor.h
## File Purpose
Auto-generated header defining symbolic frame index constants for the `player_y` model used by the Actor entity. Maps human-readable animation state names to their sequential integer frame indices for use in animation logic.

## Core Responsibilities
- Provides `#define` constants for every animation frame across all actor animation sets
- Covers both standard (male) and variant (black `bl_`, crouching `cr_`, crouching-black `crbl_`, swimming `sw_`) animation groups
- Defines the model's uniform scale factor via `MODEL_SCALE`
- Serves as the single source of truth for frame numbering, preventing magic numbers in `m_actor.c`

## External Dependencies
- No includes.
- No external symbols.


# game/m_berserk.c
## File Purpose
Implements the Berserk monster — a melee-only humanoid enemy that charges and strikes players with spike and club attacks. It defines all animation frame sequences, AI callbacks, and the spawn function used to instantiate the entity in-world.

## Core Responsibilities
- Define all animation sequences (stand, fidget, walk, run, melee attacks, pain, death)
- Handle melee combat logic with two attack variants (spike and club)
- Respond to pain events with debounced, skill-aware reactions
- Handle death with gibbing threshold and two death animations
- Pre-cache all required sounds and models at spawn time
- Register AI callbacks (stand, walk, run, melee, sight, search) into `monsterinfo`

## External Dependencies
- `g_local.h` — core game types, entity fields, AI functions (`ai_stand`, `ai_run`, etc.), `fire_hit`, `ThrowGib`, `ThrowHead`, `walkmonster_start`
- `m_berserk.h` — frame index constants (`FRAME_*`) and `MODEL_SCALE`
- `gi` (game import) — `sound`, `soundindex`, `modelindex`, `linkentity` — defined in engine, accessed via import table
- `level`, `skill`, `deathmatch` — global game state; defined in `g_main.c` / `g_local.h`

# game/m_berserk.h
## File Purpose
Auto-generated header defining animation frame index constants for the Berserk monster model. It maps symbolic frame names to sequential integer indices used by the animation system in `game/m_berserk.c`.

## Core Responsibilities
- Enumerate all animation frame indices for the Berserk monster (frames 0–243)
- Define the model scale constant for the Berserk entity
- Provide a stable symbolic interface so `m_berserk.c` can reference frames by name rather than raw integers

## External Dependencies
- No includes.
- `MODEL_SCALE 1.000000` — consumed by `m_berserk.c` when registering the model; value of `1.0` means no geometry rescaling is applied.
- All constants are consumed exclusively by `game/m_berserk.c` (defined elsewhere).

# game/m_boss2.c
## File Purpose
Implements the Boss2 monster ("Hover Boss"), a large flying boss enemy that attacks with dual miniguns and quad-rocket salvos. It manages all animation states, attack logic, pain/death responses, and spawn initialization for this entity.

## Core Responsibilities
- Define animation frame sequences (stand, fidget, walk, run, attack phases, pain, death)
- Fire dual simultaneous bullets (left/right hardpoints) or 4-rocket salvos at the enemy
- Select attack type (machinegun vs rocket) based on range and probability
- Handle pain reactions with damage-threshold branching and skin swap at half health
- Implement a custom `CheckAttack` override with LOS tracing and high per-range attack probabilities
- Manage death sequence culminating in `BossExplode` and dead-state bounding box resize
- Spawn initialization: set stats, bind callbacks, invoke `flymonster_start`

## External Dependencies
- `g_local.h` — core game types, entity structure, helper macros
- `m_boss2.h` — `FRAME_*` constants, `MODEL_SCALE`, `MZ2_BOSS2_*` flash indices
- **Defined elsewhere:** `BossExplode`, `infront`, `flymonster_start`, `monster_fire_rocket`, `monster_fire_bullet`, `G_ProjectSource`, `monster_flash_offset`, `ai_stand`, `ai_walk`, `ai_run`, `ai_charge`, `ai_move`, `range`, `vectoyaw`

# game/m_boss2.h
## File Purpose
Auto-generated header defining animation frame index constants and the model scale for the Boss2 monster model. It maps symbolic frame names to sequential integer indices used by the animation system to reference specific frames within the monster's 3D model.

## Core Responsibilities
- Defines `#define` constants for all Boss2 animation frame indices (stand, walk, attack, pain, death)
- Defines the `MODEL_SCALE` constant for the Boss2 model
- Serves as the sole source of truth for Boss2 frame numbering, consumed by `game/m_boss2.c`

## External Dependencies
- No includes.
- Consumed by: `game/m_boss2.c` (inferred from naming convention).
- `MODEL_SCALE` value of `1.000000` indicates the Boss2 model uses native scale with no resize applied.

# game/m_boss3.c
## File Purpose
Implements a static, non-combat boss3 entity (`monster_boss3_stand`) that plays a looping idle animation in place and teleports away when triggered. It serves as a scripted cinematic/decorative monster presence rather than an AI combatant.

## Core Responsibilities
- Spawn the boss3 stand entity with correct model, bounding box, and initial frame
- Loop the boss3 stand animation across frames `FRAME_stand201`–`FRAME_stand260`
- Handle a use/trigger event that broadcasts a teleport visual effect and frees the entity

## External Dependencies
- **Includes:** `g_local.h` (game types, `edict_t`, `gi`, `level`, `FRAMETIME`, `G_FreeEdict`, `MOVETYPE_*`, `SOLID_*`, `MULTICAST_PVS`, `TE_BOSSTPORT`, `svc_temp_entity`, `VectorSet`), `m_boss32.h` (animation frame constants `FRAME_stand201`, `FRAME_stand260`)
- **Defined elsewhere:** `gi` (game import vtable), `level` (global level state), `deathmatch` (cvar), `G_FreeEdict`, `VectorSet`

# game/m_boss31.c
## File Purpose
Implements the Jorg boss monster (Boss 3 / "rider" platform), a massive bipedal mech that serves as a penultimate boss in Quake 2. Jorg carries the Makron on its back and spawns it upon death. It attacks with dual chainguns and a BFG cannon.

## Core Responsibilities
- Define all animation frame sequences (stand, walk, run, pain, attack, death)
- Handle dual-chaingun bullet fire from left and right barrels
- Handle BFG projectile fire
- Implement custom attack-check logic (`Jorg_CheckAttack`)
- Play footstep, pain, idle, and death sounds at appropriate frame callbacks
- Trigger `MakronToss` and `BossExplode` at end of death sequence
- Register entity via `SP_monster_jorg` and wire all monster callbacks

## External Dependencies
- **Includes:** `g_local.h`, `m_boss31.h`
- **Defined elsewhere:** `ai_stand`, `ai_run`, `ai_walk`, `ai_move`, `ai_charge`, `walkmonster_start`, `monster_fire_bullet`, `monster_fire_bfg`, `G_ProjectSource`, `monster_flash_offset`, `infront`, `range`, `vectoyaw`, `visible`, `BossExplode`, `MakronToss`, `MakronPrecache`, `SP_monster_makron`, `gi` (game import struct)

# game/m_boss31.h
## File Purpose
Auto-generated header defining animation frame index constants for the "Jorg" boss monster (boss3/jorg model). It maps human-readable frame names to sequential integer indices consumed by the animation system in `m_boss31.c`.

## Core Responsibilities
- Enumerate all animation frame indices for the Jorg boss model
- Cover all animation states: attack (two variants), death, pain (three variants), stand, and walk
- Expose a `MODEL_SCALE` constant for use by the spawning/rendering code

## External Dependencies
- No includes.
- `MODEL_SCALE` and `FRAME_*` constants are consumed by `game/m_boss31.c` (defined elsewhere).


# game/m_boss32.c
## File Purpose
Implements the Makron, the final boss of Quake 2. Defines all animation sequences, attack logic, pain/death responses, and the spawn/precache entry points for `monster_makron`, including a secondary torso entity spawned on death.

## Core Responsibilities
- Define all Makron animation frame sets (stand, walk, run, pain, death, sight, attacks)
- Implement three attack modes: BFG, Hyperblaster burst, and Railgun
- Handle pain response with damage-threshold branching and nightmare-mode suppression
- Handle death: gibs at critical damage, or play full 95-frame death sequence with torso ejection
- Provide a custom `Makron_CheckAttack` that performs LOS tracing before committing to attack
- Spawn a decorative torso entity (`makron_torso`) that loops independently after death
- Support `MakronToss`/`MakronSpawn` for programmatic ejection from Jorg (boss31)

## External Dependencies
- `g_local.h`, `m_boss32.h` (frame constants, `MODEL_SCALE`, `MZ2_MAKRON_*` flash offsets)
- `visible`, `infront`, `range`, `vectoyaw`, `vectoangles` — defined in `g_utils.c`
- `monster_fire_bfg`, `monster_fire_railgun`, `monster_fire_blaster` — `g_monster.c` or `g_weapon.c`
- `G_ProjectSource`, `G_Spawn`, `G_FreeEdict`, `ThrowGib`, `ThrowHead`, `walkmonster_start` — defined elsewhere in game module
- `gi` (game import struct), `level`, `skill` — engine-provided globals

# game/m_boss32.h
## File Purpose
Auto-generated header defining animation frame index constants for the Boss3 "rider" monster model. Maps named animation frames to sequential integer indices consumed by the game's animation system.

## Core Responsibilities
- Enumerate all animation frames for the boss3/rider model as preprocessor constants
- Provide a `MODEL_SCALE` constant for this model's world-space scaling factor
- Serve as the sole interface between the monster logic in `m_boss32.c` and the underlying MD2 model frame data

## External Dependencies
- No includes. Standalone constant definitions only.
- Consumed exclusively by `game/m_boss32.c` (and its CTF counterpart `ctf/m_boss32.c` if present).
- Frame indices must match the compiled MD2 model at `baseq2/models/monsters/boss3/rider`.

# game/m_brain.c
## File Purpose
Implements the "Brain" monster for Quake 2 — a melee-focused creature with a power armor screen defense and a secondary tentacle chest attack. Covers all behavioral states: stand, idle, walk, run, pain, dodge, melee, and death.

## Core Responsibilities
- Preloads all sound assets at spawn time via `gi.soundindex`
- Defines animation frame sequences (`mframe_t` arrays) for every monster state
- Implements two melee attack sequences: dual arm swings and a tentacle chest attack
- Manages power armor screen toggling during tentacle attack cycles
- Handles pain responses with three randomized animation variants
- Implements a dodge/duck behavior triggered probabilistically on incoming fire
- Handles gibbing and two death animations on entity death

## External Dependencies
- **Includes:** `g_local.h`, `m_brain.h`
- **Defined elsewhere:** `ai_stand`, `ai_walk`, `ai_run`, `ai_charge`, `ai_move`, `fire_hit`, `ThrowGib`, `ThrowHead`, `walkmonster_start`, `G_FreeEdict`, `gi` (game import struct), `level`, `skill`, `FRAME_*` constants (from `m_brain.h`), `MELEE_DISTANCE`, `MODEL_SCALE`

# game/m_brain.h
## File Purpose
Auto-generated header defining animation frame index constants for the Brain monster model in Quake 2. It maps symbolic frame names to sequential integer indices used by the animation system to index into the model's frame array.

## Core Responsibilities
- Defines all animation frame constants for the Brain monster (`FRAME_*` macros)
- Enumerates frames across all animation sequences: walk, attack, pain, death, duck, defense, and stand
- Provides the model scale constant used when rendering or collision-sizing the Brain entity

## External Dependencies
- No includes.
- No external symbols; all content is self-contained `#define` macros.


# game/m_chick.c
## File Purpose
Implements the "Chick" monster (internally called "bitch" per model path), a mid-tier enemy that combines rocket launcher ranged attacks with melee slash attacks. Defines all animation sequences, AI callbacks, combat logic, and the spawn entry point for this monster type.

## Core Responsibilities
- Register and cache all sound assets for the Chick monster on spawn
- Define frame-by-frame animation sequences (stand, walk, run, pain, death, attack, dodge)
- Implement ranged rocket attack with looping re-fire logic based on range/visibility
- Implement melee slash attack with looping re-slash logic at close range
- Handle pain response scaled to damage magnitude (3 pain animations)
- Handle death via gibbing threshold or one of two death animations
- Implement dodge behavior (ducking) to evade incoming projectiles

## External Dependencies
- **Includes:** `g_local.h`, `m_chick.h`
- **Defined elsewhere:** `ai_stand`, `ai_run`, `ai_walk`, `ai_move`, `ai_charge`, `fire_hit`, `monster_fire_rocket`, `walkmonster_start`, `ThrowGib`, `ThrowHead`, `G_ProjectSource`, `range`, `visible`, `monster_flash_offset`, `skill`, `level`, `deathmatch`, `gi` (game import struct), all `FRAME_*` constants, `MODEL_SCALE`

# game/m_chick.h
## File Purpose
Auto-generated header defining integer frame index constants for the Chick monster's skeletal animation sequences. It maps human-readable animation frame names to sequential integer indices used by the engine's model animation system.

## Core Responsibilities
- Provide compile-time integer constants for every animation frame of the Chick (internally "bitch") monster model
- Cover all animation states: attack, death, duck, pain, stand, walk, and reload/recline sequences
- Define the model scale constant used when rendering this monster
- Serve as the sole source of frame numbering truth for `game/m_chick.c`

## External Dependencies
- No includes. Intended to be included by `game/m_chick.c`.
- `MODEL_SCALE` (1.0) consumed by the spawning/rendering code in `m_chick.c`.
- Generated by the `qdata` tool from the model source at `baseq2/models/monsters/bitch`.

# game/m_flash.c
## File Purpose
Defines a shared lookup table of 3D offset vectors for every monster muzzle-flash attachment point in the game. It is compiled into both the game DLL and the client executable so both can independently resolve flash positions relative to a monster's model origin.

## Core Responsibilities
- Provides `monster_flash_offset[]`, indexed by `MZ2_*` constants defined elsewhere
- Maps each named flash type (e.g. `MZ2_TANK_BLASTER_1`) to a model-space `(x, y, z)` offset
- Covers all stock Q2 monsters: Tank, Infantry, Soldier, Gunner, Chick, Flyer, Medic, Gladiator, Hover, Actor, Supertank, Boss2, Makron, Jorg
- Extends into Rogue expansion monsters: Carrier, Turret, Stalker, Daedalus, Widow, Widow2
- Index 0 is intentionally unused (sentinel/padding entry)
- Some entries contain inline correction notes (e.g. Chick rocket sign fix, Widow2 beamer X-coordinate adjustments with commented originals)

## External Dependencies
- `q_shared.h` — provides `vec3_t` typedef; this is the only include
- `MZ2_*` constants — defined in `q_shared.h` (or `game.h`); used externally to index into this table; not referenced inside this file itself
- `vec3_t` compound-literal initialization relies on C aggregate initializer syntax; the three-float comma-separated rows are not tagged — positional correspondence to `{x, y, z}` is implicit

# game/m_flipper.c
## File Purpose
Implements the Flipper monster (an aquatic creature resembling a shark/dolphin) for Quake 2. It defines all animation sequences, AI callbacks, and the spawn function for `monster_flipper`.

## Core Responsibilities
- Register and cache all Flipper sound assets at spawn time
- Define animation frame sequences for stand, walk, run, attack, pain, and death states
- Implement melee bite attack using `fire_hit`
- Handle pain response with skin damage indicator and debounce logic
- Handle death with gibbing threshold and 56-frame death animation
- Register the entity via `swimmonster_start` as a swimming monster

## External Dependencies
- `g_local.h` — core game types, entity structure, AI functions (`ai_stand`, `ai_walk`, `ai_run`, `ai_charge`, `ai_move`), `fire_hit`, `ThrowGib`, `ThrowHead`, `swimmonster_start`
- `m_flipper.h` — frame index constants (`FRAME_flp*`), `MODEL_SCALE`
- **Defined elsewhere:** `gi` (game import struct), `level`, `skill`, `deathmatch`, `MELEE_DISTANCE`, `VectorSet`, `G_FreeEdict`

# game/m_flipper.h
## File Purpose
Auto-generated header defining animation frame index constants for the Flipper monster model (an aquatic creature). It maps named animation frames to sequential integer indices consumed by the animation system in `m_flipper.c`.

## Core Responsibilities
- Enumerates all animation frame indices for the Flipper monster model
- Groups frames by animation sequence via naming convention (`flpbit`, `flptal`, `flphor`, `flpver`, `flppn1`, `flppn2`, `flpdth`)
- Defines the model's scale factor for rendering
- Serves as the sole animation data contract between the model asset and game logic

## External Dependencies
- No includes
- No external symbols; entirely self-contained preprocessor definitions

---

**Animation Sequence Summary** (160 frames total, indices 0–159):

| Prefix | Range | Count | Sequence |
|---|---|---|---|
| `flpbit` | 0–19 | 20 | Bite attack |
| `flptal` | 20–40 | 21 | Tail attack |
| `flphor` | 41–64 | 24 | Horizontal swim |
| `flpver` | 65–93 | 29 | Vertical swim |
| `flppn1` | 94–98 | 5 | Pain type 1 |
| `flppn2` | 99–103 | 5 | Pain type 2 |
| `flpdth` | 104–159 | 56 | Death |

`MODEL_SCALE` is `1.000000`, indicating no geometry scaling is applied at load time.

# game/m_float.c
## File Purpose
Implements the Floater enemy (a hovering robotic sphere) for Quake 2's single-player game. It defines all animation sequences, AI behavior callbacks, combat logic, and the spawn function used to instantiate the monster in a level.

## Core Responsibilities
- Define all animation frame tables (`mframe_t` arrays) and move sequences (`mmove_t`) for stand, walk, run, attack, pain, and death states
- Handle three distinct attack modes: blaster fire, claw melee (wham), and energy zap
- Manage pain response with skin-swap at half health and debounce timing
- Handle death by triggering an explosion rather than a ragdoll collapse
- Register all sound assets at spawn time
- Wire up `monsterinfo` function pointers and initialize entity physics/collision properties

## External Dependencies
- **Includes:** `g_local.h` (game entity types, AI functions, damage), `m_float.h` (frame number constants, `MODEL_SCALE`)
- **Defined elsewhere:** `ai_stand`, `ai_walk`, `ai_run`, `ai_charge`, `ai_move`, `monster_fire_blaster`, `fire_hit`, `T_Damage`, `BecomeExplosion1`, `flymonster_start`, `G_ProjectSource`, `monster_flash_offset`, `gi` (game import struct), `level`, `skill`, `deathmatch`

# game/m_float.h
## File Purpose
Auto-generated header file produced by the ModelGen tool, defining symbolic frame index constants for the Floater monster's 3D model animations. It maps human-readable animation frame names to sequential integer indices used by the game's animation system.

## Core Responsibilities
- Defines all animation frame indices for the Floater monster (`float` model)
- Provides the `MODEL_SCALE` constant for this monster's mesh scaling
- Serves as the compile-time interface between the monster logic (`m_float.c`) and the model animation data

## External Dependencies
- No includes.
- Consumed entirely by `game/m_float.c` (defined elsewhere).

# game/m_flyer.c
## File Purpose
Implements the Flyer enemy — a small flying robot that attacks with blaster fire (ranged) and blade slashes (melee). Defines all animation sequences, AI state transitions, combat logic, pain/death responses, and the spawn function for `monster_flyer`.

## Core Responsibilities
- Define all animation frame sequences (stand, walk, run, start/stop, roll/bank, pain, attack, melee)
- Implement ranged blaster attack firing left/right cannons alternately
- Implement melee blade-slash attack with loop/check/end state machine
- Handle pain response with skin swap at half health and three randomized pain animations
- Handle death via explosion
- Register sounds and initialize entity fields in the spawn function
- Fix a known map bug in `jail5.bsp` at spawn time

## External Dependencies
- `g_local.h` — core game types, AI functions (`ai_stand`, `ai_run`, `ai_charge`, `ai_move`, `ai_walk`), combat helpers
- `m_flyer.h` — frame constants (`FRAME_*`), `MODEL_SCALE`, `ACTION_*` defines
- **Defined elsewhere:** `visible`, `range`, `fire_hit`, `monster_fire_blaster`, `BecomeExplosion1`, `G_ProjectSource`, `monster_flash_offset`, `flymonster_start`, `gi` (game import struct)

# game/m_flyer.h
## File Purpose
Auto-generated header defining animation frame index constants and action constants for the Flyer monster's 3D model. It maps human-readable frame names to sequential integer indices used by the animation system.

## Core Responsibilities
- Define named constants for every animation frame in the Flyer model
- Define action ID constants used to identify animation state categories
- Expose the model's scale factor for use by the renderer or physics system

## External Dependencies
- No includes.
- Consumed by: `game/m_flyer.c` (not inferable from this file alone, but standard pattern for all `m_*.h` headers).

# game/m_gladiator.c
## File Purpose
Implements the Gladiator monster AI for Quake 2, a heavy melee/ranged hybrid enemy that attacks with a cleaver and a railgun. Defines all animation frame sequences, behavioral state callbacks, and the spawn function for `monster_gladiator`.

## Core Responsibilities
- Define frame sequences for stand, walk, run, melee attack, gun attack, pain, and death animations
- Implement cleaver melee attack with hit/miss sound feedback
- Implement railgun attack that pre-targets the enemy's position before firing
- Handle pain response with skin swap at half health and air-pain variant
- Handle death with gib threshold check and corpse physics finalization
- Register all sounds and initialize entity properties at spawn time

## External Dependencies
- **Includes:** `g_local.h`, `m_gladiator.h`
- **Defined elsewhere:** `ai_stand`, `ai_walk`, `ai_run`, `ai_charge`, `ai_move`, `fire_hit`, `monster_fire_railgun`, `G_ProjectSource`, `monster_flash_offset`, `walkmonster_start`, `ThrowGib`, `ThrowHead`, `MELEE_DISTANCE`, `MODEL_SCALE`, `MZ2_GLADIATOR_RAILGUN_1`, frame constants (`FRAME_stand1` etc.), `gi` (game import struct), `level`, `skill`, `deathmatch`

# game/m_gladiator.h
## File Purpose
Auto-generated header defining animation frame index constants and model scale for the Gladiator monster. Maps symbolic frame names to sequential integer indices corresponding to frames in the Gladiator's MD2 model file.

## Core Responsibilities
- Enumerates all animation frame indices for the Gladiator monster model
- Provides a `MODEL_SCALE` constant for world-space scaling of the model
- Serves as the bridge between the animation logic in `m_gladiator.c` and the underlying MD2 frame data

## External Dependencies
- No includes.
- All symbols are self-contained `#define` constants.
- Consumed exclusively by `game/m_gladiator.c` (and potentially `ctf/m_gladiator.c` if present).

# game/m_gunner.c
## File Purpose
Implements the Gunner monster AI for Quake 2, a medium-tier humanoid enemy that wields both a chaingun and a grenade launcher. It manages all animation state machines, combat logic, ducking/dodge behavior, and the spawn entry point for `monster_gunner` entities.

## Core Responsibilities
- Define all animation frame sequences (stand, walk, run, pain, death, duck, attack variants)
- Handle dual-weapon attack logic: grenade launcher burst and chaingun fire chain
- Implement dodge/duck behavior with conditional grenade counterattack
- Drive per-frame weapon firing via `GunnerFire` and `GunnerGrenade` callbacks
- Manage pain response with damage-tier selection and nightmare-mode suppression
- Handle death: gib threshold check, corpse physics setup, death animation
- Spawn and initialize the entity via `SP_monster_gunner`

## External Dependencies
- `g_local.h` — core game definitions, entity types, AI helpers (`ai_stand`, `ai_walk`, `ai_run`, `ai_move`, `ai_charge`, `range`, `visible`)
- `m_gunner.h` — frame index constants (`FRAME_*`), `MODEL_SCALE`, `MZ2_GUNNER_*` flash offsets
- **Defined elsewhere:** `monster_flash_offset[]`, `G_ProjectSource`, `monster_fire_bullet`, `monster_fire_grenade`, `ThrowGib`, `ThrowHead`, `walkmonster_start`, `G_FreeEdict`, `gi` (game import interface), `skill`, `deathmatch`, `level`

# game/m_gunner.h
## File Purpose
Auto-generated header defining animation frame index constants and model scale for the Gunner enemy type. It maps human-readable frame names to sequential integer indices used by the animation system to drive the Gunner's skeletal mesh playback.

## Core Responsibilities
- Define integer constants for every animation frame across all Gunner state sequences (stand, walk, run, attack, pain, death, duck)
- Provide the `MODEL_SCALE` constant for the Gunner's world-space scaling factor
- Serve as the sole source of frame indexing truth consumed by `game/m_gunner.c`

## External Dependencies
- No includes; self-contained preprocessor definitions
- Consumed by: `game/m_gunner.c` (defined elsewhere)
- The numeric frame indices must match the actual frame ordering baked into the Gunner MD2 model asset (`baseq2/models/gunner/tris.md2`)

# game/m_hover.c
## File Purpose
Implements the Hover monster — a flying robot enemy that attacks with blaster fire. Defines all animation frame sequences, AI behavior callbacks, pain/death handling, and the spawn function for the `monster_hover` entity.

## Core Responsibilities
- Define all animation frame tables (`mframe_t`) and move sequences (`mmove_t`) for stand, walk, run, attack, pain, death, and transition states
- Handle blaster fire logic with per-frame effect selection and enemy targeting
- Manage pain response with damage-threshold branching and skin swap at low health
- Handle death with gibbing check, corpse physics (toss + delayed explosion), and `hover_deadthink` fallback
- Implement reattack logic with visibility and probability gating
- Register sounds and initialize entity fields in the spawn function

## External Dependencies
- `g_local.h` — core game types, AI functions (`ai_stand`, `ai_run`, `ai_walk`, `ai_move`, `ai_charge`), entity fields
- `m_hover.h` — `FRAME_*` constants, `MODEL_SCALE`
- External symbols: `visible`, `flymonster_start`, `BecomeExplosion1`, `ThrowGib`, `ThrowHead`, `G_ProjectSource`, `monster_fire_blaster`, `monster_flash_offset`, `AngleVectors`, `gi` (game import struct)

# game/m_hover.h
## File Purpose
Auto-generated header defining animation frame index constants and model scale for the Hover monster (a floating drone enemy) in Quake 2. It maps symbolic frame names to sequential integer indices consumed by the animation system in `m_hover.c`.

## Core Responsibilities
- Define all animation frame indices for the Hover monster model
- Provide the `MODEL_SCALE` constant used when registering or rendering the model
- Serve as the sole authoritative frame-index reference for `m_hover.c`

## External Dependencies
- No includes.
- No external symbols; purely self-contained macro definitions.

---

**Animation sequence summary (205 frames total, indices 0–204):**

| Sequence | Frames | Index Range | Count |
|---|---|---|---|
| `stand` | stand01–30 | 0–29 | 30 |
| `forwrd` (forward) | forwrd01–35 | 30–64 | 35 |
| `stop1` | stop101–109 | 65–73 | 9 |
| `stop2` | stop201–208 | 74–81 | 8 |
| `takeof` (takeoff) | takeof01–30 | 82–111 | 30 |
| `land` | land01 | 112 | 1 |
| `pain1` | pain101–128 | 113–140 | 28 |
| `pain2` | pain201–212 | 141–152 | 12 |
| `pain3` | pain301–309 | 153–161 | 9 |
| `death1` | death101–111 | 162–172 | 11 |
| `backwd` (backward) | backwd01–24 | 173–196 | 24 |
| `attak1` (attack) | attak101–108 | 197–204 | 8 |

`MODEL_SCALE` is `1.000000`, indicating no scaling applied to the raw model geometry.

# game/m_infantry.c
## File Purpose
Implements the Infantry monster — a standard human soldier enemy in Quake 2. It handles all behavioral states (stand, walk, run, attack, dodge, pain, death) and fires a machine gun or delivers melee punches depending on range.

## Core Responsibilities
- Define all animation frame sequences for Infantry states
- Implement machine gun fire and melee punch attacks
- Handle pain response with skin damage indicator
- Implement ducking/dodge behavior against incoming projectiles
- Handle three distinct death animations, one of which fires the machine gun during the death sequence
- Spawn and initialize the Infantry entity via `SP_monster_infantry`

## External Dependencies
- `g_local.h` — core game types, macros (`VectorSet`, `VectorMA`, etc.), entity/monster definitions
- `m_infantry.h` — frame constants (`FRAME_*`), `MODEL_SCALE`, `MZ2_INFANTRY_MACHINEGUN_*`
- External symbols: `ai_stand`, `ai_walk`, `ai_run`, `ai_move`, `ai_charge`, `monster_fire_bullet`, `fire_hit`, `G_ProjectSource`, `monster_flash_offset[]`, `M_FlyCheck`, `ThrowGib`, `ThrowHead`, `walkmonster_start`, `range`, `gi` (game import struct)

# game/m_infantry.h
## File Purpose
Auto-generated header defining animation frame index constants for the Infantry monster model. It maps symbolic frame names to sequential integer indices used by the animation system to index into the model's keyframe array.

## Core Responsibilities
- Enumerate all animation frame indices for the Infantry monster (207 total frames)
- Provide human-readable names for frame ranges (stand, walk, run, pain, duck, death, block, attack)
- Define the model's scale factor constant
- Serve as the sole source of truth for Infantry frame numbering consumed by `game/m_infantry.c`

## External Dependencies
- No includes.
- No external symbols.
- Consumed exclusively by `game/m_infantry.c` (and potentially `ctf/` equivalents).

---

**Animation frame inventory summary:**

| Animation group | Frame range | Count |
|---|---|---|
| `gun` | 0 | 1 |
| `stand` | 1–71 | 71 |
| `walk` | 72–91 | 20 |
| `run` | 92–99 | 8 |
| `pain1` | 100–109 | 10 |
| `pain2` | 110–119 | 10 |
| `duck` | 120–124 | 5 |
| `death1` | 125–144 | 20 |
| `death2` | 145–169 | 25 |
| `death3` | 170–178 | 9 |
| `block` | 179–183 | 5 |
| `attak1` | 184–198 | 15 |
| `attak2` | 199–206 | 8 |

# game/m_insane.c
## File Purpose
Implements the "insane" civilian NPC (`misc_insane`), a non-combat ambient character found in single-player maps. It supports multiple behavioral modes (standing, crawling, crucified, wandering) driven by spawnflags, and plays pain/death animations but never attacks.

## Core Responsibilities
- Registers and plays voice sounds (fist, shake, moan, screams) as animation callbacks
- Defines all animation frame sequences and transitions for standing, walking, crawling, crucified, and pain/death states
- Implements state-machine callbacks (`insane_stand`, `insane_walk`, `insane_run`) that select moves based on spawnflags and random chance
- Handles pain response with debounce, skill-level gating, and frame-context detection
- Handles death: gibbing, crucified fly-flag, crawl-vs-stand death selection
- Spawns the entity via `SP_misc_insane`, configuring physics, sounds, AI flags, and start conditions

## External Dependencies
- `g_local.h` — entity types, game imports (`gi`), AI helpers, utility macros
- `m_insane.h` — frame constants (`FRAME_*`), `MODEL_SCALE`
- `ai_stand`, `ai_walk`, `ai_move` — AI movement primitives (defined in `g_ai.c`)
- `ThrowGib`, `ThrowHead` — gib helpers (defined in `g_misc.c`)
- `walkmonster_start`, `flymonster_start` — monster init (defined in `g_monster.c`)
- `random()`, `VectorSet`, `va` — engine utility macros/functions

# game/m_insane.h
## File Purpose
Auto-generated header by ModelGen that defines frame index constants for the "insane" civilian/NPC monster model. It maps symbolic animation frame names to sequential integer indices used by the animation system in `game/m_insane.c`.

## Core Responsibilities
- Enumerate all animation frame indices for the insane monster model (frames 0–281)
- Define animation groups: standing, walking, crawling, pain (standing and crawling variants), death (standing and crawling variants), and a "cross" pose sequence
- Expose the model scale constant for use by the spawning/initialization code

## External Dependencies
- No includes
- `MODEL_SCALE` (1.0) consumed by `game/m_insane.c` during entity spawn to set render scale

---

**Notes:**
- 160 stand frames (0–159) is unusually large; this encodes the insane NPC's erratic idle behavior as a long looping sequence rather than branching AI states
- Walk frames are non-contiguous in name (walk27–walk39 precede walk1–walk26 in index order, indices 160–198); consumers must reference these constants rather than computing ranges arithmetically
- Animation groups: `stand` (0–159), `walk` (160–198), `st_pain` (199–209), `st_death` (210–226), `crawl` (227–235), `cr_pain` (236–244), `cr_death` (245–251), `cross` (252–281)

# game/m_medic.c
## File Purpose
Implements the Medic monster, a unique enemy that can both fight players with a blaster/hyperblaster and resurrect dead allied monsters via a cable-hook attack. It is one of the few monsters with active ally-restoration behavior built into its AI.

## Core Responsibilities
- Search for and target dead monsters within a 1024-unit radius for resurrection
- Execute three distinct attack modes: blaster, hyperblaster, and cable-hook healing
- Manage the `AI_MEDIC` flag to switch between combat and resurrection behavior
- Revive dead monsters via `ED_CallSpawn`, re-linking them to fight players
- Handle pain, death, gibbing, and dodging animations
- Register all sounds and set up entity fields in the spawn function

## External Dependencies
- Includes: `g_local.h`, `m_medic.h`
- External symbols: `visible`, `findradius`, `FoundTarget`, `M_CheckAttack`, `ED_CallSpawn`, `walkmonster_start`, `ThrowGib`, `ThrowHead`, `G_FreeEdict`, `monster_fire_blaster`, `G_ProjectSource`, `monster_flash_offset`, `g_edicts`, `level`, `skill`, `deathmatch`, `gi` (game import struct), all `ai_*` and animation frame constants from `m_medic.h`

# game/m_medic.h
## File Purpose
Auto-generated header defining animation frame index constants for the Medic monster model. It maps symbolic frame names to sequential integer indices used by the animation system to index into the model's keyframe array.

## Core Responsibilities
- Enumerate all animation frame indices for the Medic monster model
- Provide the model scale constant used when rendering or collision-scaling the entity
- Serve as the sole interface between `m_medic.c` animation logic and the underlying MD2 model frame data

## External Dependencies
- No includes.
- No external symbols.


# game/m_move.c
## File Purpose
Implements ground-based and aerial monster movement logic for Quake 2, including step-up stair climbing, directional pathfinding toward a goal entity, yaw rotation, and bottom-edge validation to prevent monsters from walking off ledges.

## Core Responsibilities
- Validate that a monster has solid ground beneath its corners (`M_CheckBottom`)
- Execute a single movement step for walking, swimming, and flying monsters (`SV_movestep`)
- Rotate a monster toward its ideal yaw incrementally per frame (`M_ChangeYaw`)
- Attempt a step in a specific direction, committing only if facing close enough to that direction (`SV_StepDirection`)
- Select a new chase direction when the direct path to the enemy is blocked (`SV_NewChaseDir`)
- Drive monsters toward their `goalentity` each AI frame (`M_MoveToGoal`)
- Provide a yaw-to-vector walk step helper (`M_walkmove`)

## External Dependencies
- `g_local.h` — entity definitions, `gi` game import interface, `FL_*` flags, `AI_NOSTEP`, `MASK_MONSTERSOLID`, `MASK_WATER`
- **Defined elsewhere:** `gi.trace`, `gi.pointcontents`, `gi.linkentity`, `G_TouchTriggers`, `anglemod`, `VectorAdd`, `VectorCopy`, `M_PI`

# game/m_mutant.c
## File Purpose
Implements the Mutant monster AI for Quake 2, a fast melee/jump attacker. Defines all animation frame sequences, sound callbacks, combat logic (claw strikes and leaping attack), pain/death handling, and the spawn entry point.

## Core Responsibilities
- Precache and manage mutant-specific sound indices
- Define frame sequences for stand, idle, walk, run, melee attack, jump attack, pain, and death
- Implement melee hit detection (left/right claw strikes with randomized damage)
- Implement a physics-driven leap attack with touch callback for mid-air collision damage
- Handle pain response with skin switching at half health and nightmare-mode suppression
- Handle death with gibbing threshold and two randomized death animations
- Register all monster callbacks and spawn the entity via `SP_monster_mutant`

## External Dependencies
- **Includes:** `g_local.h` (entity/game types, AI functions), `m_mutant.h` (frame constants, `MODEL_SCALE`)
- **Defined elsewhere:** `fire_hit`, `T_Damage`, `ThrowGib`, `ThrowHead`, `M_FlyCheck`, `M_CheckBottom`, `walkmonster_start`, `range`, `ai_stand`, `ai_walk`, `ai_run`, `ai_charge`, `ai_move`, `gi` (game import interface), `level`, `skill`, `deathmatch`

# game/m_mutant.h
## File Purpose
Auto-generated header defining animation frame index constants and model scale for the Mutant monster. It maps symbolic frame names to sequential integer indices corresponding to frames in the Mutant's MD2 model file.

## Core Responsibilities
- Defines `#define` constants for every animation frame index across all Mutant animation sequences (attack, death, pain, run, stand, walk)
- Provides `MODEL_SCALE` for use when transforming model-space coordinates to world-space
- Serves as the single source of truth for frame numbering so `game/m_mutant.c` can reference frames by name rather than magic integers

## External Dependencies
- No includes.
- No external symbols referenced.
- Consumed by: `game/m_mutant.c` (inferred from naming convention).


# game/m_parasite.c
## File Purpose
Implements the Parasite monster AI for Quake 2, a spider-like creature that attacks by launching a tongue/drain appendage to siphon health from the player. Covers all behavioral states: standing, walking, running, attacking, pain, death, and idle fidgeting.

## Core Responsibilities
- Define all animation frame sequences (stand, walk, run, drain attack, break, pain, death, fidget)
- Implement the drain attack with range/angle validation and health-siphoning logic
- Play contextual sounds for each action (launch, impact, suck, reel-in, sight, tap, scratch)
- Handle pain response including skin damage state and nightmare-mode suppression
- Handle death via normal death animation or gibbing
- Register the entity via `SP_monster_parasite` and configure all AI callbacks
- Manage fidget idle behavior with probabilistic looping

## External Dependencies
- `g_local.h` — entity types, game API (`gi`), damage/gib functions
- `m_parasite.h` — `FRAME_*` constants, `MODEL_SCALE`
- Defined elsewhere: `ai_stand`, `ai_run`, `ai_walk`, `ai_charge`, `ai_move`, `G_ProjectSource`, `T_Damage`, `ThrowGib`, `ThrowHead`, `walkmonster_start`, `vectoangles`, `VectorLength`, `level`, `skill`, `g_edicts`

# game/m_parasite.h
## File Purpose
Auto-generated header defining integer frame index constants for the Parasite monster's 3D model animations. It maps symbolic animation frame names to sequential integer indices consumed by the animation system in `m_parasite.c`.

## Core Responsibilities
- Define `FRAME_*` constants for all Parasite animation sequences: `break`, `death1`, `drain`, `pain1`, `run`, and `stand`
- Define the `MODEL_SCALE` constant for the Parasite model
- Serve as the single source of truth for frame numbering, preventing magic numbers in animation code

## External Dependencies
- No includes; fully self-contained
- Consumed by: `game/m_parasite.c` (defined elsewhere)
- Generated by: **ModelGen** tool (external, offline pipeline) — not to be hand-edited

---

**Animation sequence summary:**

| Sequence | Frames | Count | Index Range |
|---|---|---|---|
| `break` | 01–32 | 32 | 0–31 |
| `death1` | 01–07 | 7 | 32–38 |
| `drain` | 01–18 | 18 | 39–56 |
| `pain1` | 01–11 | 11 | 57–67 |
| `run` | 01–15 | 15 | 68–82 |
| `stand` | 01–35 | 35 | 83–117 |

`MODEL_SCALE` is `1.000000`, meaning the model is used at native export size with no engine-side scaling applied.

# game/m_player.h
## File Purpose
Auto-generated header defining integer frame index constants for the player character's skeletal animation sequences. It maps symbolic animation frame names to their sequential integer indices as stored in the player model file.

## Core Responsibilities
- Enumerate all player model animation frames as preprocessor constants
- Provide a symbolic interface so game code can reference frames by name rather than magic integers
- Define the model scale constant for the player model

## External Dependencies
- No includes
- No external symbols; all content is self-contained `#define` macros

---

**Notes on animation sequence layout (frame ranges):**

| Sequence group | First frame | Last frame | Count |
|---|---|---|---|
| `stand` (idle) | 0 | 39 | 40 |
| `run` | 40 | 45 | 6 |
| `attack` (upright) | 46 | 53 | 8 |
| `pain1/2/3` (upright) | 54 | 65 | 12 |
| `jump` | 66 | 71 | 6 |
| `flip` (gesture) | 72 | 83 | 12 |
| `salute` (gesture) | 84 | 94 | 11 |
| `taunt` (gesture) | 95 | 111 | 17 |
| `wave` (gesture) | 112 | 122 | 11 |
| `point` (gesture) | 123 | 134 | 12 |
| `crstnd` (crouch idle) | 135 | 153 | 19 |
| `crwalk` (crouch walk) | 154 | 159 | 6 |
| `crattak` (crouch attack) | 160 | 168 | 9 |
| `crpain` (crouch pain) | 169 | 172 | 4 |
| `crdeath` (crouch death) | 173 | 177 | 5 |
| `death1/2/3` (upright) | 178 | 197 | 20 |

`MODEL_SCALE 1.000000` indicates the player model uses a 1:1 world-unit scale with no additional rescaling applied at load time.

# game/m_rider.h
## File Purpose
Auto-generated header defining animation frame index constants for the "rider" monster model (boss3/rider). It maps symbolic frame names to sequential integer indices used by the animation system.

## Core Responsibilities
- Defines `FRAME_stand201` through `FRAME_stand260` as integer constants (0–59)
- Defines the model's scale factor via `MODEL_SCALE`
- Provides a symbolic interface so animation code avoids hardcoded frame numbers

## External Dependencies
- No includes.
- No external symbols.
- Intended to be included by the rider/boss3 monster implementation file.

**Notes:**
- The file contains only a single animation sequence (`stand2`, frames 201–260), spanning 60 frames (indices 0–59). The naming offset (201 vs. 0) reflects the source model's internal frame numbering, while the macro values are the engine-side zero-based indices.
- `MODEL_SCALE 1.000000` indicates no scaling is applied relative to the base model geometry.
- Marked "Do NOT Modify" — regenerating via ModelGen would overwrite changes.

# game/m_soldier.c
## File Purpose
Implements the Soldier enemy monster in three variants (Light/Blaster, Shotgun, and Super Shotgun/Machinegun), sharing a common skeleton of animation frames, AI callbacks, and weapon-fire logic distinguished entirely by `s.skinnum`.

## Core Responsibilities
- Define all animation frame sequences (stand, walk, run, pain, attack, duck, death) as `mframe_t`/`mmove_t` tables
- Dispatch weapon fire (blaster, shotgun, or bullet) based on `s.skinnum` in `soldier_fire`
- Handle pain response with debounce, skin switching to wounded appearance, and skill-gated animation suppression
- Implement dodge behavior: skill-scaled probability of duck vs. counter-attack
- Handle death with gib detection, head-shot recognition, and randomized death animations (6 variants)
- Register sound assets and wire AI callbacks during spawn via `SP_monster_soldier_x` and three variant spawn functions

## External Dependencies
- Notable includes: `g_local.h`, `m_soldier.h` (frame constants, `MODEL_SCALE`)
- External symbols used but not defined here: `ai_stand`, `ai_walk`, `ai_run`, `ai_charge`, `ai_move`, `walkmonster_start`, `monster_fire_blaster`, `monster_fire_shotgun`, `monster_fire_bullet`, `G_ProjectSource`, `monster_flash_offset`, `AngleVectors`, `vectoangles`, `ThrowGib`, `ThrowHead`, `range`, `skill`, `level`, `deathmatch`, `G_FreeEdict`, `gi` (game import struct)

# game/m_soldier.h
## File Purpose
Auto-generated header defining all animation frame index constants for the Soldier monster model. It maps symbolic frame names to sequential integer indices used by the animation system in `game/m_soldier.c`.

## Core Responsibilities
- Enumerate every animation frame for the Soldier monster as preprocessor constants
- Provide a `MODEL_SCALE` constant for world-space sizing of the model
- Serve as the sole bridge between the 3D model's frame data and the game logic that drives animations

## External Dependencies
- No includes.
- No external symbols.


# game/m_supertank.c
## File Purpose
Implements the Supertank boss monster (monster_supertank), a large armored vehicle enemy that attacks with a chaingun and rocket launcher. It manages all animation states, AI transitions, attack logic, and a staged explosion death sequence.

## Core Responsibilities
- Define all animation frame sequences (stand, run, walk, turn, attack, pain, death)
- Drive chaingun and rocket fire at frame-accurate trigger points
- Select attack mode (chaingun vs rockets) based on range
- Handle pain response with damage-threshold branching and skill-level suppression
- Execute a multi-stage BossExplode death sequence with gibs and explosions
- Register sounds and initialize entity properties via SP_monster_supertank

## External Dependencies
- `g_local.h`, `m_supertank.h` (frame constants, MODEL_SCALE)
- Defined elsewhere: `ai_stand`, `ai_run`, `ai_walk`, `ai_move`, `ai_charge`, `walkmonster_start`, `monster_fire_rocket`, `monster_fire_bullet`, `G_ProjectSource`, `monster_flash_offset[]`, `ThrowGib`, `ThrowHead`, `visible`, `BossExplode` (forward-declared), `skill`, `level`, `deathmatch`

# game/m_supertank.h
## File Purpose
Auto-generated header defining animation frame index constants for the Super Tank (boss1) monster model. It is consumed exclusively by `game/m_supertank.c` to index into the model's frame table for animation sequencing.

## Core Responsibilities
- Enumerate all animation frame indices for the Super Tank's skeletal animation sequences
- Define the model scale constant used when spawning or rendering the entity
- Serve as the sole source of truth for frame numbering, preventing magic numbers in the implementation file

## External Dependencies
- No includes.
- All symbols are self-contained `#define` constants; nothing is defined elsewhere.

---

**Frame sequence summary** (254 total frames, indices 0–253):

| Sequence | Frames | Index Range |
|---|---|---|
| `attak1` | 20 | 0–19 |
| `attak2` | 27 | 20–46 |
| `attak3` | 27 | 47–73 |
| `attak4` | 6 | 74–79 |
| `backwd` | 18 | 80–97 |
| `death` | 30 | 98–127 |
| `forwrd` | 18 | 128–145 |
| `left` | 18 | 146–163 |
| `pain1/2/3` | 12 | 164–175 |
| `right` | 18 | 176–193 |
| `stand` | 60 | 194–253 |

**Notes:**
- `death` sequence has non-contiguous source frame numbers (`death_24` → `death_31` → `death_45`) indicating frames were culled during export, but the runtime indices remain linear.
- `MODEL_SCALE 1.000000` indicates no scaling adjustment is applied relative to the raw model geometry.
- The header comment references a Windows absolute path (`G:\quake2\...`), confirming this was machine-generated by the `ModelGen` tool on the original developer's workstation.

# game/m_tank.c
## File Purpose
Implements the Tank and Tank Commander monsters for Quake 2. Defines all animation sequences, AI callbacks, attack behaviors (blaster, rocket, machinegun, melee strike), pain responses, and death handling for both variants, which share the same logic but differ in health and skin.

## Core Responsibilities
- Define all `mframe_t`/`mmove_t` animation sequences for stand, walk, run, pain, attack, and death states
- Implement three ranged attack modes: blaster burst, rocket salvo, and machinegun sweep
- Implement a melee strike attack used against dead/downed enemies
- Handle skill-level-dependent pain suppression and attack re-fire logic
- Spawn and initialize both `monster_tank` and `monster_tank_commander` entities
- Manage death: gib threshold dismemberment vs. normal death animation

## External Dependencies
- `g_local.h` — entity types, AI functions (`ai_stand`, `ai_walk`, `ai_run`, `ai_charge`, `ai_move`), game imports (`gi`), utility macros
- `m_tank.h` — frame constants (`FRAME_*`), `MODEL_SCALE`
- Defined elsewhere: `monster_fire_blaster`, `monster_fire_rocket`, `monster_fire_bullet`, `monster_flash_offset`, `G_ProjectSource`, `AngleVectors`, `VectorNormalize`, `vectoangles`, `ThrowGib`, `ThrowHead`, `walkmonster_start`, `visible`, `skill`, `level`, `deathmatch`

# game/m_tank.h
## File Purpose
Auto-generated header defining animation frame index constants for the Tank monster model in Quake 2. It maps symbolic frame names to sequential integer indices used by the animation system in `game/m_tank.c`.

## Core Responsibilities
- Exposes all frame index constants for the Tank's animation sequences: stand, walk, attack (4 variants), pain (3 variants), death, and reclining
- Defines the model scale constant used when registering or sizing the Tank model
- Serves as the single source of truth for frame numbering, preventing magic numbers in the Tank AI logic

## External Dependencies
- No includes.
- No external symbols referenced.


# game/p_client.c
## File Purpose
Manages the full lifecycle of player clients in the Quake 2 game module: connection, spawning, respawning, disconnection, death, and per-frame processing. It also handles spawn point selection, body queue management, and cooperative/deathmatch-specific hacks for broken maps.

## Core Responsibilities
- Connect, begin, disconnect, and per-frame update callbacks for player entities
- Select appropriate spawn points (singleplayer, deathmatch, coop)
- Initialize and restore persistent and per-respawn client data
- Handle player death, gibbing, obituary messages, and weapon tossing
- Manage the body queue (recycled corpse entities)
- Run `pmove` physics integration per client frame
- Patch broken coop spawn points on specific stock maps

## External Dependencies
- `g_local.h`, `m_player.h` — game-local types, frame constants (`FRAME_death*`, `FRAME_crdeath*`)
- External symbols: `G_Find`, `G_Spawn`, `G_FreeEdict`, `G_InitEdict`, `KillBox`, `Drop_Item`, `FindItem`, `FindItemByClassname`, `ThrowGib`, `ThrowClientHead`, `ChangeWeapon`, `Think_Weapon`, `PlayerNoise`, `PlayerTrail_*`, `GetChaseTarget`, `ChaseNext`, `UpdateChaseCam`, `ClientEndServerFrame`, `MoveClientToIntermission`, `Cmd_Help_f`, `SV_FilterPacket`, `gi.*` (engine interface), `meansOfDeath` (global from `g_combat.c`), `itemlist`, `g_edicts`, `game`, `level`

# game/p_hud.c
## File Purpose
Manages the player HUD (heads-up display), intermission sequencing, and deathmatch scoreboard for the Quake 2 game module. It computes per-frame player stats sent to the client renderer and handles transitioning players into intermission state between levels.

## Core Responsibilities
- Teleport all clients to the intermission camera point and freeze them
- Strip coop players of keys when crossing unit boundaries
- Build and transmit the deathmatch scoreboard layout string
- Respond to `score` and `help` console commands
- Populate `ps.stats[]` array each frame with HUD data (health, ammo, armor, timers, frags)
- Propagate stats from a chase-camera target to the spectating client
- Manage spectator-specific HUD layout flags

## External Dependencies
- `g_local.h` — pulls in all game types, `level`, `game`, `g_edicts`, cvars (`deathmatch`, `coop`, `skill`, `maxclients`), and the `gi` game import table
- `respawn`, `G_Find`, `PowerArmorType`, `ArmorIndex`, `GetItemByIndex`, `FindItem`, `DeathmatchScoreboard` — defined elsewhere in the game module
- `gi.unicast`, `gi.WriteByte`, `gi.WriteString`, `gi.imageindex`, `gi.soundindex`, `gi.sound` — engine import functions

# game/p_trail.c
## File Purpose
Implements a circular buffer of recent player positions used by AI monsters to track and pursue the player. Each trail node stores a world-space origin, a timestamp, and a yaw angle pointing toward the next node.

## Core Responsibilities
- Allocate and initialize trail node entities at map load
- Append new player positions to the circular buffer each frame/event
- Provide monster AI queries to find the oldest unseen or most recent visible trail node
- Support pursuit logic by exposing the last recorded player spot

## External Dependencies
- `g_local.h` — pulls in all game types, `edict_t`, `level`, `deathmatch` cvar, `G_Spawn`, `vectoyaw`, `VectorCopy`, `VectorSubtract`, `visible`
- `G_Spawn` — defined in `g_utils.c`
- `visible` — defined in `g_ai.c`
- `vectoyaw` — defined in `g_utils.c` or `q_shared.c`
- `level.time`, `deathmatch` — engine/game globals defined elsewhere

# game/p_view.c
## File Purpose
Computes all per-player view-state updates at the end of each server frame, including camera offsets, gun offsets, screen blends, bob/roll calculations, falling damage, world environmental effects, and player animation state.

## Core Responsibilities
- Calculate view bob, roll, and kick angles each frame
- Apply damage feedback (screen blend, view kick, pain animation/sound)
- Compute view and gun positional/angular offsets
- Determine screen color blend from environment, powerups, and damage
- Handle falling damage and fall-camera kick
- Process world environmental effects (drowning, lava, slime, water entry/exit)
- Set per-frame client effects, sounds, events, and animation frames
- Serve as the terminal per-player update pipeline via `ClientEndServerFrame`

## External Dependencies
- **Includes:** `g_local.h`, `m_player.h` (animation frame constants)
- **Defined elsewhere:** `gi` (game import interface), `T_Damage`, `PlayerNoise`, `G_SetStats`, `G_SetSpectatorStats`, `G_CheckChaseStats`, `DeathmatchScoreboardMessage`, `PowerArmorType`, `AngleVectors`, `sv_rollangle`, `sv_rollspeed`, `run_pitch`, `run_roll`, `bob_pitch`, `bob_roll`, `bob_up`, `gun_x/y/z`, `deathmatch`, `dmflags`, `snd_fry`, `level`, `world`

# game/p_weapon.c
## File Purpose
Implements all player weapon logic for Quake 2, including weapon pickup, switching, firing, and per-frame think routines. Each weapon has a dedicated fire function and a `Weapon_*` entry point that drives its animation state machine via the shared `Weapon_Generic` framework.

## Core Responsibilities
- Manage weapon state transitions (ACTIVATING → READY → FIRING → DROPPING)
- Route per-frame weapon think calls through `Think_Weapon`
- Compute muzzle/projectile spawn positions accounting for handedness
- Generate `PlayerNoise` entities for AI monster awareness
- Handle weapon pickup, use, and drop inventory logic
- Implement fallback weapon selection when ammo runs out (`NoAmmoWeaponChange`)
- Apply Quad Damage and silencer modifiers to all fire functions

## External Dependencies
- **Includes:** `g_local.h`, `m_player.h`
- **Defined elsewhere:** `G_ProjectSource`, `G_Spawn`, `SetRespawn`, `Drop_Item`, `Add_Ammo`, `FindItem`, `ITEM_INDEX`; projectile functions `fire_grenade`, `fire_grenade2`, `fire_rocket`, `fire_blaster`, `fire_bullet`, `fire_shotgun`, `fire_rail`, `fire_bfg`; `gi` interface (sound, modelindex, WriteByte/Short, multicast, linkentity, cprintf); cvars `deathmatch`, `coop`, `dmflags`, `g_select_empty`; player animation frame constants from `m_player.h`.

# game/q_shared.c
## File Purpose
Shared utility library included by both game and engine modules, providing math primitives, string utilities, byte-order handling, token parsing, and info-string manipulation. This is a self-contained "standard library" layer for the Quake 2 codebase, compiled into the game DLL directly.

## Core Responsibilities
- 3D vector and matrix math (normalize, cross product, dot product, rotation, bounds)
- Angle conversion and interpolation utilities
- Platform-portable byte-order (endianness) initialization and swap functions
- BSP plane-side classification for AABB vs. plane (`BoxOnPlaneSide`)
- String utilities: case-insensitive compare, path manipulation, `va()` formatting
- Token parser (`COM_Parse`) for config/script text streams
- Info-string key/value encoding, lookup, mutation, and validation

## External Dependencies
- **Includes:** `q_shared.h` (defines `vec3_t`, `cplane_s`, `MAX_TOKEN_CHARS`, `MAX_INFO_STRING`, `MAX_INFO_KEY`, `qboolean`, macros like `DotProduct`, `VectorNormalize`)
- **External symbols used:** `Com_Printf` (defined in `qcommon/common.c`), `PerpendicularVector` (defined in this file, called recursively by `RotatePointAroundVector`), `R_ConcatRotations` (defined in this file)
- `Q_ftol`: x86 MSVC-only naked ASM; not available on non-MSVC targets
- `sqrt`, `sin`, `cos`, `fabs`, `memcpy`, `memset`, `strcmp`, `strncpy`, `strcpy`, `strcat`, `strlen`, `strstr`, `vsprintf`: standard C library

# game/q_shared.h
## File Purpose
The universal shared header included first by all Quake 2 program modules (client, server, game DLL, renderers). It defines the engine's foundational type system, math primitives, collision structures, network protocol constants, and cross-module interfaces that must remain ABI-compatible across all subsystems.

## Core Responsibilities
- Define primitive types (`byte`, `qboolean`, `vec_t`, `vec3_t`) and platform detection macros
- Declare math library functions and vector operation macros
- Define all collision detection types (`cplane_t`, `cmodel_t`, `trace_t`, `csurface_t`)
- Define player movement types (`pmove_t`, `pmove_state_t`, `usercmd_t`) for client-side prediction
- Define network protocol constants: entity/player state structures, config string indices, temp events, muzzle flash IDs
- Declare system-level utility interfaces (hunk allocator, file system search, byte-order swapping)
- Define the `cvar_t` structure and flag constants shared by all subsystems

## External Dependencies
- **Standard C:** `<assert.h>`, `<math.h>`, `<stdio.h>`, `<stdarg.h>`, `<string.h>`, `<stdlib.h>`, `<time.h>`
- **Platform macros:** `id386`, `idaxp` guard x86/Alpha ASM paths
- `Q_ftol` — either an extern ASM fast float-to-long (x86/non-Linux) or a cast macro
- All declared functions are **defined elsewhere**: math functions in `game/q_shared.c`; system functions in platform-specific `sys_*.c`; hunk allocator in platform sys code

# irix/cd_irix.c
## File Purpose
IRIX platform stub implementation of the CD audio subsystem. All functions are no-ops that print debug traces via `Com_Printf`, indicating this was a placeholder written during the IRIX port that was never fully implemented.

## Core Responsibilities
- Satisfy the CD audio interface contract required by the engine
- Print `XXX`-prefixed debug traces for all CD audio operations (except `CDAudio_Update`, which is commented out)
- Return success (0) from `CDAudio_Init` so the engine proceeds normally

## External Dependencies
- `<sys/types.h>` — IRIX system types
- `<cdaudio.h>` — IRIX CD audio header (included but unused by any stub logic)
- `../client/client.h` — provides `Com_Printf`, `qboolean`; defined elsewhere in the engine

# irix/glw_imp.c
## File Purpose
Implements the IRIX/X11-specific OpenGL window and input management layer for the Quake 2 GL renderer. Despite the header comment claiming "Linux specific stuff," this file is the IRIX port's GLX window creation, keyboard/mouse input handling, and renderer lifecycle management.

## Core Responsibilities
- Create and manage an X11/GLX window for OpenGL rendering
- Initialize and destroy the GLX rendering context
- Translate X11 key events to Quake 2 key codes
- Process X11 mouse motion and button events
- Apply mouse input to player view angles and movement commands
- Register signal handlers for clean shutdown
- Expose the `GLimp_*` and `RW_IN_*` / `KBD_*` entry points required by the renderer/input plugin interface

## External Dependencies
- `<X11/Xlib.h>`, `<X11/extensions/XShm.h>`, `<Xm/MwmUtil.h>`, `<GL/glx.h>` — X11 and GLX platform headers
- `../ref_gl/gl_local.h` — `ri` (refimport_t), `vid`, renderer types
- `../client/keys.h` — `K_*` key constants, `Key_Event_fp_t`
- `../linux/rw_linux.h` — `in_state_t`, shared Linux/IRIX input interface
- `ri.Cvar_Get`, `ri.Cmd_AddCommand`, `ri.Vid_NewWindow`, `ri.Vid_GetModeInfo`, `ri.Con_Printf` — engine import table (defined in engine core)
- `Sys_Error` — defined in platform sys layer

# irix/q_shirix.c
## File Purpose
IRIX-specific implementation of shared system-level services for the Quake 2 engine. Provides platform abstractions for memory hunk allocation, high-resolution timing, directory creation, and filesystem directory enumeration on SGI IRIX systems.

## Core Responsibilities
- Implement the hunk memory allocator (`Hunk_Begin/Alloc/End/Free`) using `malloc` (with commented-out `mmap` fallback)
- Provide millisecond-resolution wall-clock time via `gettimeofday`
- Wrap `mkdir` for portable directory creation
- Implement case-insensitive-compatible filesystem search (`Sys_FindFirst/Next/Close`) using POSIX `opendir`/`readdir` with glob pattern matching
- Provide `strlwr` string utility (missing from IRIX libc)

## External Dependencies
- `../linux/glob.h` — `glob_match` (shared with Linux port)
- `../qcommon/qcommon.h` — `Com_Error`, `Sys_Error`, `MAX_OSPATH`, `SFF_SUBDIR`, `byte`, `qboolean`
- POSIX: `<dirent.h>`, `<sys/stat.h>`, `<sys/time.h>`, `<sys/mman.h>`, `<unistd.h>`
- `strlwr` — defined here because IRIX libc omits it; used by engine string-lowercasing calls elsewhere

# irix/qgl_irix.c
## File Purpose
Implements the IRIX-platform binding of OpenGL to the QGL indirection layer for Quake 2's ref_gl renderer. It defines all `qgl*` function pointers and provides optional per-call file logging for debugging, along with `QGL_Init` and `QGL_Shutdown` as the required port entry points.

## Core Responsibilities
- Declares all `qgl*` global function pointers consumed by ref_gl rendering code
- Declares parallel `dll*` static function pointers holding the real GL entry points
- Declares `log*` static wrapper functions that write call names to a log file then forward to `dll*`
- `QGL_Init`: directly assigns `qgl*` and `dll*` to statically linked IRIX GL symbols (no dlopen)
- `QGL_Shutdown`: NULLs all `qgl*` pointers
- `GLimp_EnableLogging`: hot-swaps `qgl*` between `log*` wrappers and `dll*` direct pointers at runtime
- `GLimp_LogNewFrame`: writes a frame delimiter to the GL call log

## External Dependencies
- `../ref_gl/gl_local.h` — defines `qboolean`, `gl_config`, `ri` (refimport), and the `#define QGL` guard that suppresses re-declaration of `qgl*` in the header
- `ri.FS_Gamedir()` — engine filesystem callback; defined elsewhere
- `glColorTableSGI` — SGI extension symbol; expected from IRIX GL headers (assigned then immediately zeroed)
- Standard C: `<stdio.h>`, `<time.h>` (via gl_local.h or system includes)

# irix/snd_irix.c
## File Purpose
Implements the IRIX-platform DMA sound backend for Quake 2 using SGI's AL (Audio Library) API. It manages an audio output port, a circular DMA buffer, and frame-accurate submission of mixed audio to the hardware.

## Core Responsibilities
- Initialize the SGI AL audio port and configure sample rate, bit depth, and channel count
- Expose a static DMA buffer to the engine's mixer via the `dma` global
- Track playback position using UST (Unadjusted System Time) timestamps
- Submit mixed audio frames to the AL port, handling buffer wrap-around
- Handle underflow/overflow by discarding stale frames before writing

## External Dependencies
- `<dmedia/dmedia.h>`, `<dmedia/audio.h>` — SGI IRIX AL/DM audio APIs
- `../client/client.h`, `../client/snd_loc.h` — engine sound types (`dma_t dma`, `paintedtime`)
- `soundtime`, `paintedtime` — defined elsewhere in the engine sound mixer
- `dma` — global `dma_t` defined in `client/snd_dma.c`

# irix/sys_irix.c
## File Purpose
Platform abstraction layer for the IRIX (SGI) operating system port of Quake 2. Implements the `Sys_*` interface required by the engine's common layer, handling startup, shutdown, console I/O, timing, and game DLL loading for MIPS-based SGI workstations.

## Core Responsibilities
- Provide the engine main loop and frame timing
- Implement console output/input for dedicated server mode
- Load and unload the game shared library (`gamemips.so`) via `dlopen`/`dlsym`
- Handle fatal errors and clean shutdown
- Perform (nominally) CD-based copy protection checks
- Forward keyboard events from the platform input layer

## External Dependencies
- `../qcommon/qcommon.h` — `Qcommon_Init`, `Qcommon_Frame`, `Qcommon_Shutdown`, `Com_Printf`, `Com_Error`, `FS_NextPath`, `Cvar_Get`, `Sys_Milliseconds`, `dedicated`
- `../linux/rw_linux.h` — `KBD_Update_fp` function pointer
- `dlfcn.h` — `dlopen`, `dlsym`, `dlclose` (POSIX dynamic linking)
- `mntent.h` — `setmntent`, `getmntent`, `endmntent` (Linux/IRIX mount table)
- `CL_Shutdown` — defined elsewhere (client layer)

# irix/vid_menu.c
## File Purpose
Implements the in-game Video Options menu for the IRIX platform port of Quake 2. It provides a dual-panel UI (Software vs. OpenGL) allowing the player to configure renderer, resolution, brightness, fullscreen, and renderer-specific options, then apply or reset them.

## Core Responsibilities
- Initialize and lay out two `menuframework_s` panels (software and OpenGL) with appropriate widgets
- Synchronize shared settings (brightness, fullscreen, driver) between both panels
- Convert menu widget values to cvar writes on "Apply"
- Handle keyboard navigation and item interaction via `VID_MenuKey`
- Draw the active panel and video banner via `VID_MenuDraw`
- Reset all menu state to current cvar defaults via `ResetDefaults`

## External Dependencies
- `../client/client.h` — `viddef`, `re` (renderer export struct)
- `../client/qmenu.h` — all menu widget types and `Menu_*` functions
- **Defined elsewhere:** `vid_ref`, `vid_fullscreen`, `vid_gamma`, `scr_viewsize` (extern cvars); `M_ForceMenuOff`, `M_PopMenu` (menu system); `Cvar_Get`, `Cvar_Set`, `Cvar_SetValue`; `Q_stricmp`; all `re.*` draw functions

# irix/vid_so.c
## File Purpose
This is the IRIX platform video/refresh DLL management module, responsible for dynamically loading and unloading the renderer shared library, wiring up the input subsystem (keyboard and mouse), and dispatching video mode changes each frame.

## Core Responsibilities
- Load/unload the refresh DLL (`ref_*.so`) at runtime via `dlopen`/`dlsym`
- Populate the `refimport_t` interface struct and retrieve `refexport_t` from the DLL
- Manage video mode metadata and window dimension updates
- Route keyboard and mouse input through function pointers resolved from the refresh DLL
- Check each frame for `vid_ref->modified` and reload the renderer accordingly
- Drop root privileges after renderer initialization (`setreuid`/`setegid`)

## External Dependencies
- `../client/client.h` — `cvar_t`, `cl`, `cls`, client state
- `../linux/rw_linux.h` — `in_state_t`, `Key_Event_fp_t`, shared Linux/IRIX input definitions
- `<dlfcn.h>` — `dlopen`, `dlsym`, `dlclose` (ELF dynamic linking)
- External symbols: `Com_Printf`, `Com_DPrintf`, `Com_Error`, `Cmd_AddCommand`, `Cvar_Get`, `Cvar_Set`, `FS_NextPath`, `FS_LoadFile`, `Key_Event`, `Sys_Milliseconds`, `S_StopAllSounds`, `Con_ToggleConsole_f`, `in_strafe` (defined elsewhere)

# linux/block16.h
## File Purpose
An x86 AT&T-syntax assembly fragment (`#include`-able header) implementing an unrolled texture block-drawing inner loop for the 16-bit-per-pixel software renderer. It is `#include`d directly into an assembly source file, not compiled independently.

## Core Responsibilities
- Render 2 texels per iteration by performing two parallel palette lookups and writing two 16-bit pixels at once.
- Advance the texture coordinate accumulator (`edx`/`ebp`) for sub-texel precision stepping.
- Step the source texture pointer (`esi`) by two rows per iteration using the texture stride (`ebx`).
- Provide multiple entry points (`LEnter16_16`, `LEnter8_16`, `LEnter4_16`, `LEnter2_16`) so the caller can handle spans whose pixel count is not a multiple of 16 by jumping into the appropriate mid-loop position.
- Expose patch points (`LBPatch0`–`LBPatch15`) so the engine can self-modify the `0x12345678` placeholder addresses at runtime to point to the active 16-bit palette translation table.

## External Dependencies
- **Included by:** an assembly (`.s`) file in `linux/` that manages the outer scan-line loop and register setup.
- **Runtime patch target:** a 16-bit palette translation table whose address replaces `0x12345678` at load/init time — defined and patched elsewhere (likely `linux/vid_so.c` or the soft-renderer initialisation path).
- No C headers or external symbols are referenced directly.

# linux/block8.h
## File Purpose
Inline x86 AT&T assembly fragment implementing an unrolled texture span-drawing loop for the software renderer's 8-bit color mode. It is `#include`d directly into a larger assembly routine and does not stand alone as a compilable translation unit.

## Core Responsibilities
- Sample two texels per iteration using bilinear-style row-strided addressing (`%esi` + `%ebx` offset)
- Apply a runtime-patched palette/colormap lookup via the `0x12345678` displacement (a sentinel patched at load time)
- Write two destination pixels per iteration to the output scanline buffer (`%edi`)
- Provide multiple entry points (`LEnter16_8`, `LEnter8_8`, `LEnter4_8`, `LEnter2_8`) for loop unrolling at 16, 8, 4, and 2 pixels remaining
- Advance the fixed-point texture coordinate accumulator (`%edx`/`%ebp`) by one step per pixel

## External Dependencies
- No `#include` directives (raw assembly fragment)
- `LBPatch0`–`LBPatch15`: labels consumed by an external self-patching mechanism that writes the real colormap base address over the `0x12345678` sentinels at startup or context switch
- Enclosing routine supplies all register state; this fragment has no prologue/epilogue

# linux/cd_linux.c
## File Purpose
Linux-specific CD audio backend for Quake 2, controlling physical CD playback via Linux kernel `ioctl` calls against `/dev/cdrom`. It implements the platform CD audio interface consumed by the engine's client layer.

## Core Responsibilities
- Open and manage the CD device file descriptor
- Issue `ioctl` commands for play, stop, pause, resume, and eject operations
- Track playback state and handle looping via periodic polling
- Remap logical track numbers to physical track numbers
- Respond to volume cvar changes by pausing/resuming
- Expose a `cd` console command for manual control

## External Dependencies
- `<linux/cdrom.h>` — Linux kernel CD ioctl interface
- `../client/client.h` — `qboolean`, `byte`, `cvar_t`, `Cvar_Get`, `Cmd_AddCommand`, `Com_Printf`, `Com_DPrintf`
- `saved_euid` (`uid_t`) — defined in platform system layer (`linux/sys_linux.c`)

# linux/d_ifacea.h
## File Purpose
Assembly-language interface header for the Linux software renderer. Defines byte offsets into C structures so that x86 assembly routines can access struct fields without relying on C's type system.

## Core Responsibilities
- Mirror field offsets of C structures from `d_iface.h`, `r_shared.h`, and `modelgen.h` for use in `.s` assembly files
- Define shared constants (`TURB_TEX_SIZE`, `CYCLE`, `MAXHEIGHT`, `CACHE_SIZE`) that must stay synchronized across C and asm
- Provide particle_t field offsets, distinguishing driver-usable fields from internal-only fields
- Provide finalvert_t, stvert_t, trivertx_t, and affinetridesc_t field offsets for alias model rendering assembly

## External Dependencies
- **Must stay in sync with** (no `#include` of these, purely a manual contract):
  - `d_iface.h` — `particle_t`, `finalvert_t`, `affinetridesc_t`, `TURB_TEX_SIZE`, `CYCLE`
  - `r_shared.h` — `ALIAS_ONSEAM`, `MAXHEIGHT`
  - `modelgen.h` — `stvert_t`, `trivertx_t`
  - `quakedef.h` — `CACHE_SIZE`
- No external symbols are referenced; this file is self-contained preprocessor definitions only.

**Notes:**
- `pt_color` at offset 12 and `pt_next` at offset 16 mark the boundary between driver-visible and engine-internal particle fields — assembly routines must not access fields at or beyond `pt_next`.
- `fv_v` at offset 0 has a special note: if moved, all `d_polysa.s` address pushes must be updated manually.
- `fv_shift = 5` encodes `fv_size = 32` as a power-of-two shift for efficient array indexing in asm.

# linux/gl_fxmesa.c
## File Purpose
Implements the Linux-specific OpenGL initialization and frame management layer for the 3Dfx Glide/fxMesa software rasterizer backend. It provides the `GLimp_*` interface required by the GL refresh module when targeting Voodoo/3Dfx hardware via the fxMesa context API.

## Core Responsibilities
- Create and destroy fxMesa rendering contexts for 3Dfx hardware
- Map engine video modes to supported 3Dfx hardware resolutions
- Register OS signal handlers for clean shutdown on crashes or termination
- Implement the `GLimp_*` entry points expected by `ref_gl`
- Perform double-buffer swap at end of each frame
- Provide a palette-setting shim (`Fake_glColorTableEXT`) bridging fxMesa's palette extension

## External Dependencies
- `<GL/fxmesa.h>` — fxMesa/Glide context API (`fxMesaCreateContext`, `fxMesaDestroyContext`, `fxMesaMakeCurrent`, `fxMesaSwapBuffers`, `GR_RESOLUTION_*`)
- `../ref_gl/gl_local.h` — `ri` refimport interface, `rserr_*` codes, `qboolean`
- `../client/keys.h` — included but not directly used in this file
- `../linux/rw_linux.h` — Linux window/input shared header
- `gl3DfxSetPaletteEXT` — defined externally (3Dfx GL extension, linked from fxMesa or Glide)
- `ri.Con_Printf`, `ri.Vid_GetModeInfo`, `ri.Vid_NewWindow` — engine callbacks via `refimport_t`

# linux/glob.c
## File Purpose
Implements a portable glob-style pattern matching library for use on Linux. Provides shell-like wildcard matching (`*`, `?`, `[SET]`) against strings, used for filename or resource lookup in the engine's Linux port.

## Core Responsibilities
- Match a full string against a glob pattern (`glob_match`)
- Handle `*` wildcard by matching against any suffix (`glob_match_after_star`)
- Support character sets `[SET]` and negated sets `[!SET]` or `[^SET]`
- Support escape sequences via `\`
- Detect whether a pattern contains any special glob characters (`glob_pattern_p`)

## External Dependencies
- `#include <stdio.h>` — included but no stdio symbols are visibly used; likely a legacy inclusion.
- `#include "../linux/glob.h"` — declares `glob_match` and `glob_pattern_p` for use by other translation units.
- No other external engine symbols are referenced.

# linux/glob.h
## File Purpose
A minimal header file exposing a single glob pattern matching function for use on Linux. It provides the interface for matching filenames or strings against shell-style wildcard patterns.

## Core Responsibilities
- Declare `glob_match` for use by other translation units

## External Dependencies
- No includes in this header.
- `glob_match` is defined in `linux/glob.c` (defined elsewhere).

# linux/in_linux.c
## File Purpose
Stub implementation of the Linux input subsystem for Quake 2. Despite the filename `in_linux.c`, the file comment identifies it as `in_null.c`, indicating this is a no-op placeholder that registers input cvars but performs no actual mouse or joystick processing.

## Core Responsibilities
- Register `in_mouse` and `in_joystick` cvars at initialization
- Satisfy the input API contract required by the engine without providing any real input handling
- Serve as a base or fallback input module on Linux where SVGAlib/X11 drivers handle input directly

## External Dependencies
- `../client/client.h` — pulls in `cvar_t`, `usercmd_t`, `qboolean`, and `Cvar_Get`
- `Cvar_Get` — defined in `qcommon/cvar.c`

# linux/net_udp.c
## File Purpose
Linux UDP network layer implementation for Quake 2. Provides IP socket creation, packet send/receive, address conversion, and a loopback buffer system for local single-player games. Despite the file-top comment saying `net_wins.c`, this is the Linux counterpart to the Win32 network layer.

## Core Responsibilities
- Create and bind non-blocking UDP sockets for server and client
- Send and receive network packets over IP (and stub IPX)
- Maintain loopback ring buffers for local client/server communication
- Convert between engine `netadr_t` and POSIX `sockaddr_in`
- Resolve hostnames and parse address strings
- Sleep/yield the server process until network activity or timeout

## External Dependencies
- **Includes:** `qcommon/qcommon.h` (engine types: `netadr_t`, `sizebuf_t`, `netsrc_t`, `MAX_MSGLEN`, `PORT_SERVER`, `PORT_ANY`, `NA_*`, `NS_*`)
- **System headers:** `sys/socket.h`, `netinet/in.h`, `netdb.h`, `sys/ioctl.h`, `errno.h`, `unistd.h`
- **Defined elsewhere:** `Com_Printf`, `Com_Error`, `Com_sprintf`, `Cvar_Get`, `net_local_adr` type constants, `dedicated` cvar, `stdin_active` flag (both `extern` in `NET_Sleep`)
- **IPX:** Declared and array-allocated but `NET_OpenIPX` is an empty stub — IPX is not implemented on Linux.

# linux/q_shlinux.c
## File Purpose
Linux-specific implementation of shared platform services for Quake 2, providing hunk (virtual) memory management, system timing, directory I/O, and file-finding utilities. Acts as the POSIX backend for platform-abstracted engine calls declared in `qcommon.h`.

## Core Responsibilities
- Allocate and manage a hunk memory arena via `mmap`/`mremap`/`munmap`
- Provide millisecond-resolution system time via `gettimeofday`
- Implement directory creation (`Sys_Mkdir`)
- Implement glob-pattern file search (`Sys_FindFirst`, `Sys_FindNext`, `Sys_FindClose`)
- Provide `strlwr` string utility (lowercase in-place)

## External Dependencies
- `../linux/glob.h` — `glob_match()` for wildcard filename matching
- `../qcommon/qcommon.h` — `Sys_Error`, `MAX_OSPATH`, `SFF_SUBDIR`, `byte`, `qboolean`
- POSIX: `<sys/mman.h>` (`mmap`, `mremap`, `munmap`), `<sys/time.h>` (`gettimeofday`), `<dirent.h>`, `<sys/stat.h>`, `<unistd.h>` (`mkdir`)

# linux/qasm.h
## File Purpose
Assembly-language include header for the Linux x86 soft renderer. It declares external symbols (via `.extern` directives) visible to GNU assembler (`.s`) files and defines byte-offset constants for C structures so assembly code can access struct fields without a C compiler.

## Core Responsibilities
- Conditionally define the `C()` macro to mangle symbol names for ELF vs. non-ELF (leading underscore) ABI conventions.
- Detect i386 architecture and set the `id386` compile-time flag.
- Emit `.extern` directives for all C-side globals accessed by the software renderer and sound mixer assembly routines.
- Define `#define` byte-offset constants for every struct field accessed from assembly (plane_t, hull_t, edge_t, surf_t, span types, sound channel types, refdef_t, etc.).
- Gate software-renderer `.extern` declarations behind `#ifndef GLQUAKE` so they are excluded from GL builds.
- Define `TRANSPARENT_COLOR` (palette index 255) shared between C and assembly.

## External Dependencies
- **Notable includes:** None — this file includes nothing itself.
- **External symbols used but not defined here:**
  - Software renderer globals: `d_zistepu`, `d_pzbuffer`, `r_turb_*`, `edge_p`, `surface_p`, `surfaces`, `span_p`, `r_apverts`, `aliastransform`, etc. — defined in `ref_soft/r_*.c` and `ref_soft/d_*.c`.
  - Sound mixer globals: `snd_scaletable`, `paintbuffer`, `snd_linear_count`, `snd_p`, `snd_vol`, `snd_out` — defined in `client/snd_mix.c`.
  - View/render globals: `vright`, `vup`, `vpn`, `BOPS_Error` — defined in client/renderer C files.
  - Floating-point constants (`float_point5`, `Float2ToThe31nd`, `fp_64k`, etc.) and span-rasterizer temporaries (`advancetable`, `reciprocal_table`, `entryvec_table`) — defined in assembly data segments in `ref_soft/*.asm` / `linux/r_*.s`.

### Notes
- All struct-offset `#define`s carry explicit warnings ("must be kept the same as in ...") tying them to their C counterparts: `model.h`, `r_local.h`, `r_shared.h`, `d_local.h`, `sound.h`, `bspfile.h`. Any struct layout change in C must be manually mirrored here — there is no compile-time enforcement.
- `d_pzbuffer` and several other symbols appear twice in the `.extern` list (duplicates are harmless to the assembler but indicate copy-paste accumulation over time).
- The `NEAR_CLIP` (0.01) and `CYCLE` (128) defines duplicate constants from `r_local.h` for use in assembly without a C include.

# linux/qgl_linux.c
## File Purpose
Linux-specific implementation of the QGL (Quake GL) abstraction layer that binds the engine's `qgl*` function pointer table to real OpenGL entry points. It also provides an optional call-logging facility that intercepts every GL call and writes it to a file for debugging.

## Core Responsibilities
- Declares all `qgl*` global function pointers used by the rest of `ref_gl`
- Declares parallel `dll*` static pointers that permanently hold the real GL addresses
- Declares `log*` static wrapper functions that write call signatures to a log file before forwarding to `dll*`
- `QGL_Init()`: binds both `qgl*` and `dll*` to the actual `gl*` symbols (linked statically on Linux)
- `QGL_Shutdown()`: NULLs all `qgl*` pointers to prevent stale use after teardown
- `GLimp_EnableLogging()`: hot-swaps `qgl*` pointers between `log*` wrappers and `dll*` passthrough; opens/closes `gl.log`
- `GLimp_LogNewFrame()`: writes a frame separator into the log

## External Dependencies
- **`../ref_gl/gl_local.h`** — provides `qboolean`, `APIENTRY`, GL type definitions, `ri` (refimport_t with `FS_Gamedir`), and declares the `qgl*` externs via the `#define QGL` guard
- **`<time.h>`** — `time`, `localtime`, `asctime` used in log file header
- **`glAccum` … `glViewport`** — all standard OpenGL 1.1 entry points; resolved by the system linker against `-lGL` (defined elsewhere, not via `dlopen`)
- `ri.FS_Gamedir()` — defined in the engine core, accessed through the refimport interface

# linux/rw_in_svgalib.c
## File Purpose
Implements keyboard and mouse input for the Linux SVGAlib software renderer backend. It maps raw keyboard scancodes to Quake 2 key constants and translates SVGAlib mouse events into engine movement and button commands.

## Core Responsibilities
- Initialize SVGAlib keyboard with a scancode-to-key translation table
- Pump keyboard events each frame via SVGAlib callbacks
- Initialize SVGAlib mouse device using cvars for device path and sample rate
- Accumulate relative mouse deltas and button state changes each frame
- Convert mouse deltas into view angle changes or movement commands
- Register `+mlook`/`-mlook` and `force_centerview` console commands

## External Dependencies
- `vga.h`, `vgakeyboard.h`, `vgamouse.h` — SVGAlib library (defined elsewhere, system library)
- `../ref_soft/r_local.h` — soft renderer locals including `ri` (refimport_t)
- `../client/keys.h` — Quake key constants (`K_ESCAPE`, `K_F1`, etc.)
- `../linux/rw_linux.h` — `in_state_t`, `Key_Event_fp_t` definitions
- `Sys_Error` — defined elsewhere in engine
- `ri.Cvar_Get`, `ri.Cmd_AddCommand`, `ri.Con_Printf` — engine import table calls

# linux/rw_linux.h
## File Purpose
Defines the shared interface between the Linux render/window driver (loaded as a shared object via `vid_so`) and the client input subsystem. It declares function pointer types and a state-passing struct used to wire keyboard and input callbacks back into the client.

## Core Responsibilities
- Defines the `Key_Event_fp_t` function pointer type for keyboard event delivery
- Declares extern function pointers for keyboard driver lifecycle (`KBD_Init_fp`, `KBD_Update_fp`, `KBD_Close_fp`)
- Defines `in_state_t` to bundle client-side input state and callbacks passed into the input driver

## External Dependencies
- `qboolean`, `vec_t` — defined elsewhere (likely `qcommon/qcommon.h` or `game/q_shared.h`)
- Actual definitions of `KBD_Update_fp`, `KBD_Init_fp`, `KBD_Close_fp` — defined in `linux/vid_so.c` or the active input backend
- `IN_CenterView_fp` target — defined in `client/cl_input.c`

# linux/rw_svgalib.c
## File Purpose
Implements the Linux SVGAlib software rendering window/display backend for Quake 2. It satisfies the platform-specific `SWimp_*` interface required by the software renderer (`ref_soft`), managing VGA mode setup, palette programming, and framebuffer blitting via the SVGAlib library.

## Core Responsibilities
- Initialize SVGAlib and enumerate available 8bpp/256-color VGA modes
- Select and configure a VGA mode matching the requested resolution
- Blit the software renderer's backbuffer to the VGA framebuffer each frame (with paged and planar support)
- Program the VGA DAC palette (6-bit scaling from 8-bit input)
- Shut down the VGA mode and free backbuffer memory
- Expose `Sys_MakeCodeWriteable` for marking memory regions executable/writable

## External Dependencies
- `vga.h`, `vgakeyboard.h`, `vgamouse.h` — SVGAlib (Linux userspace VGA library)
- `sys/mman.h` — `mprotect`
- `asm/io.h` — low-level I/O port access (included but not directly called here)
- `../ref_soft/r_local.h` — `vid`, `sw_state`, `d_8to24table`, `R_GammaCorrectAndSetPalette`
- `../linux/rw_linux.h` — `rserr_t`, shared Linux renderer interface types
- `ri` (refimport_t) — `Con_Printf`, `Vid_NewWindow`, `Vid_GetModeInfo` — defined elsewhere (engine import table)
- `VGA_UpdatePlanarScreen` — declared but defined elsewhere (likely `ref_soft`)
- `Sys_Error` — defined elsewhere in platform layer

# linux/rw_x11.c
## File Purpose
Implements the Linux X11 software rendering window and input backend for Quake 2. It provides the platform-specific `SWimp_*` entry points required by the software renderer, and handles X11 window creation, framebuffer management (with optional MIT-SHM), keyboard/mouse event processing, and palette management.

## Core Responsibilities
- Open and manage an X11 display, window, GC, and visual
- Allocate and manage double-buffered framebuffers (standard XImage or MIT-SHM XShmImage)
- Present the rendered frame via `XShmPutImage` or `XPutImage` each frame
- Translate X11 key events to Quake key codes and queue them
- Track mouse motion and button state; apply sensitivity/filtering to produce movement deltas
- Convert 8-bit indexed palette to 16-bit RGB pixel values for non-8bpp visuals
- Register signal handlers for graceful shutdown on SIGINT/SIGTERM

## External Dependencies
- `<X11/Xlib.h>`, `<X11/extensions/XShm.h>`, `<sys/shm.h>`: X11 display, SHM extension
- `../ref_soft/r_local.h`: `vid`, `sw_state`, `d_8to24table`, `ri` refimport, `R_GammaCorrectAndSetPalette`
- `../client/keys.h`: `K_*` key constants, `Key_Event_fp_t`
- `../linux/rw_linux.h`: `in_state_t` definition
- `Sys_Error`, `ri.Con_Printf`, `ri.Cvar_Get`, `ri.Cmd_AddCommand`, `ri.Vid_NewWindow`, `ri.Vid_GetModeInfo`: defined elsewhere in engine/renderer import table

# linux/snd_linux.c
## File Purpose
Linux-specific OSS (Open Sound System) audio backend for Quake 2. Initializes the DSP device via `ioctl`, memory-maps the DMA buffer, and provides the platform sound interface consumed by the portable audio mixer.

## Core Responsibilities
- Open and configure `/dev/dsp` (or user-specified device) via OSS ioctls
- Validate DSP capabilities (trigger + mmap support required)
- Negotiate sample rate, bit depth, and channel count with the hardware
- Memory-map the audio DMA buffer into the process address space
- Report current DMA playback position to the mixer
- Provide stub shutdown, submit, and paint-begin entry points

## External Dependencies
- `<linux/soundcard.h>` — OSS API (`SNDCTL_*`, `DSP_CAP_*`, `AFMT_*`, `count_info`, `audio_buf_info`)
- `<sys/mman.h>` — `mmap`
- `../client/client.h` — `Com_Printf`, `cvar_t`, `Cvar_Get`
- `../client/snd_loc.h` — `dma` global (`dma_t`), portable DMA struct
- `saved_euid` — extern `uid_t`, defined in the Linux system layer (`sys_linux.c`)

# linux/sys_linux.c
## File Purpose
Platform abstraction layer for Quake 2 on Linux. Provides the OS-facing entry point (`main`), system-level services (time, console I/O, error handling, clipboard), and dynamic game library loading via `dlopen`. Bridges the engine's `Sys_*` API to POSIX/Linux system calls.

## Core Responsibilities
- Implements the `main` loop: init, frame timing, and `Qcommon_Frame` dispatch
- Provides `Sys_Error`/`Sys_Quit` for fatal shutdown with stdin restoration
- Handles console I/O (`Sys_ConsoleInput`, `Sys_ConsoleOutput`, `Sys_Printf`)
- Loads/unloads the game `.so` via `dlopen`/`dlsym`/`dlclose`
- Performs CD-based copy protection check by scanning `/etc/mtab`
- Drops privileges at startup via `seteuid`/`setreuid`

## External Dependencies
- **Includes:** `qcommon/qcommon.h`, `linux/rw_linux.h`
- **Defined elsewhere:** `Qcommon_Init`, `Qcommon_Frame`, `Qcommon_Shutdown`, `CL_Shutdown`, `Sys_Milliseconds`, `FS_NextPath`, `Com_Error`, `Com_Printf`, `Com_DPrintf`, `Cvar_Get`, `KBD_Update_fp` (function pointer from `rw_linux.h`), `dedicated` (cvar), `ERR_FATAL`

# linux/vid_menu.c
## File Purpose
Implements the Linux-specific video settings menu for Quake 2, providing an in-game UI to configure display driver (software/software X11/OpenGL), resolution, brightness, fullscreen, and renderer-specific options. Bridges the qmenu widget system to cvars controlling the video subsystem.

## Core Responsibilities
- Build and initialize two parallel menu frameworks: software and OpenGL
- Synchronize menu widget state with current cvar values on init
- Switch active menu panel when the user changes renderer selection
- Write cvar changes back to the engine on "apply"
- Handle keyboard input for menu navigation and selection
- Draw the video menu banner and active menu panel each frame

## External Dependencies
- **Includes:** `../client/client.h`, `../client/qmenu.h`
- **Defined elsewhere:** `vid_ref`, `vid_fullscreen`, `vid_gamma`, `scr_viewsize` (extern cvars); `M_ForceMenuOff`, `M_PopMenu` (menu system); `Cvar_Get`, `Cvar_Set`, `Cvar_SetValue` (cvar system); `Menu_AddItem`, `Menu_Center`, `Menu_Draw`, `Menu_AdjustCursor`, `Menu_SlideItem`, `Menu_SelectItem` (qmenu system); `re` (renderer export struct); `viddef` (video state); key constants (`K_ESCAPE`, etc.).

# linux/vid_so.c
## File Purpose
Linux-specific video system manager that dynamically loads and unloads the renderer ("refresh") DLL at runtime via `dlopen`/`dlsym`. It also proxies keyboard and mouse input through function pointers resolved from the same shared library.

## Core Responsibilities
- Read `/etc/quake2.conf` to locate the refresh `.so` library on disk
- Enforce root-ownership security checks before loading the renderer library
- Resolve renderer (`GetRefAPI`), keyboard (`KBD_*`), and mouse (`RW_IN_*`) entry points from the loaded `.so`
- Initialize and populate the `refimport_t` struct passed into `GetRefAPI`
- Monitor `vid_ref->modified` each frame and hot-reload the renderer when it changes
- Provide thin wrappers (`IN_*`) that delegate to function pointers from the loaded library
- Manage privilege escalation/dropping (`seteuid`/`setreuid`) around `.so` loading

## External Dependencies
- `<dlfcn.h>` — `dlopen`, `dlclose`, `dlsym`, `dlerror`
- `../client/client.h` — `cl`, `cls`, `Key_Event`, `IN_CenterView`, `in_strafe`, `Cvar_*`, `Cmd_*`, `Com_*`, `FS_*`, `S_StopAllSounds`, `Cbuf_ExecuteText`
- `../linux/rw_linux.h` — `in_state_t`, `Key_Event_fp_t`
- `saved_euid` — declared `extern`, defined in `linux/sys_linux.c`
- `GetRefAPI_t`, `refexport_t`, `refimport_t`, `API_VERSION` — defined in `client/ref.h`
- `viddef_t` — defined elsewhere (likely `client/vid.h`)

# null/cd_null.c
## File Purpose
Null (stub) implementation of the CD audio subsystem. Provides no-op function bodies so the engine can compile and link on platforms or configurations where CD audio support is intentionally absent.

## Core Responsibilities
- Satisfy the CD audio interface contract required by the rest of the engine
- Allow headless/dedicated-server or unsupported-platform builds to link without a real CD audio backend
- Return success (`0`) from `CDAudio_Init` to avoid triggering error paths in callers

## External Dependencies
- `../client/client.h` — pulled in for `qboolean` and to satisfy the interface declaration; no symbols from it are actually used here.

# null/cl_null.c
## File Purpose
Provides stub implementations of the entire client subsystem for use in dedicated server builds. All functions are no-ops or minimal error reporters, allowing the server to compile and run without any client, rendering, sound, or input code.

## Core Responsibilities
- Stub out `CL_Init`, `CL_Drop`, `CL_Shutdown`, and `CL_Frame` as empty no-ops
- Stub out console printing (`Con_Print`) and screen utilities (`SCR_*`)
- Register a no-op `bind` command so client-oriented config files don't crash on load
- Redirect unknown forwarded commands to a `Com_Printf` warning instead of sending to server

## External Dependencies
- `../qcommon/qcommon.h` — pulls in `Cmd_Argv`, `Cmd_AddCommand`, `Com_Printf`
- `Cmd_Argv`, `Cmd_AddCommand`, `Com_Printf` — defined in `qcommon/cmd.c` and `qcommon/common.c`

# null/glimp_null.c
## File Purpose
Null (stub) implementation of the OpenGL platform-abstraction layer (`GLimp`). All functions are empty no-ops, providing a do-nothing build target for platforms or configurations where GL rendering is not needed.

## Core Responsibilities
- Satisfies the linker for the `GLimp_*` interface without performing any real work
- Serves as a reference template for the GLimp platform contract
- Enables headless or dedicated-server builds to link against `ref_gl` without a display system

## External Dependencies
- `../ref_gl/gl_local.h` — pulled in to match the real `GLimp` signature contracts; no symbols from it are actually used here.

# null/in_null.c
## File Purpose
Null/stub implementation of the input subsystem for platforms or configurations that have no mouse or input device support. All functions are empty no-ops, satisfying the input interface contract without performing any work.

## Core Responsibilities
- Provide a compilable, linkable input module for headless or input-less builds
- Satisfy the engine's required input API surface (`IN_*` functions)
- Serve as a safe default for the `null` platform target

## External Dependencies
- `../client/client.h` — provides `usercmd_t` and `qboolean` type definitions; the `IN_*` function signatures are part of the platform input interface declared there.
- All symbols (`usercmd_t`, `qboolean`) are **defined elsewhere**.

# null/snddma_null.c
## File Purpose
Provides a no-op null implementation of the platform-specific DMA sound driver interface. Used as a stub when no audio hardware or audio system is available, allowing the engine to compile and run silently without platform sound support.

## Core Responsibilities
- Satisfies the `SNDDMA_*` link-time interface required by the portable sound mixer
- Always reports initialization failure (`SNDDMA_Init` returns `false`)
- Returns safe zero/void values for all queries and lifecycle callbacks

## External Dependencies
- `../client/client.h` — pulls in `qboolean` and shared client types
- `../client/snd_loc.h` — declares the `SNDDMA_*` interface contract; all five symbols are defined here and expected by `snd_dma.c`

# null/swimp_null.c
## File Purpose
Provides a null (no-op) implementation of the software renderer platform interface (`SWimp_*`). Used as a stub when no actual display/windowing system is available, such as in headless server builds or null-platform configurations.

## Core Responsibilities
- Satisfies the linker's requirements for all `SWimp_*` symbols
- Allows the engine to compile and link without a real windowing backend
- Serves as a reference interface contract for the software renderer platform layer

## External Dependencies
- `../ref_soft/r_local.h` — provides `rserr_t`, `qboolean`, and other software renderer types
- `rserr_t` — defined in `ref_soft/r_local.h` (or its includes); not defined here

# null/sys_null.c
## File Purpose
A stub/null implementation of all platform-specific system functions required by the Quake 2 engine. It exists solely to aid porting efforts by providing no-op or minimal implementations that allow the engine to compile and link without a real OS backend.

## Core Responsibilities
- Provide stub implementations of all `Sys_*` engine entry points
- Provide stub implementations of the `Hunk_*` memory allocator interface
- Implement a minimal `main()` that drives the common engine loop
- Allow the engine to terminate cleanly via `Sys_Error` and `Sys_Quit`

## External Dependencies
- `../qcommon/qcommon.h` — declares `Qcommon_Init`, `Qcommon_Frame`, and all `Sys_*` / `Hunk_*` interfaces
- `errno.h` — included but not used
- `Qcommon_Init`, `Qcommon_Frame` — defined in `qcommon/common.c`
- `printf`, `vprintf`, `exit` — C standard library

# null/vid_null.c
## File Purpose
Provides a null/stub video driver for porting Quake 2 to new platforms, assuming a renderer (ref) is statically linked into the executable rather than loaded as a dynamic library. It bridges the engine's video subsystem to a statically-linked `refexport_t` implementation.

## Core Responsibilities
- Exposes `viddef` (global video state) and `re` (renderer export table)
- Builds a `refimport_t` function table and passes it to `GetRefAPI()` at init time
- Routes renderer print/error callbacks to engine `Com_Printf`/`Com_Error`
- Provides a static mode table for standard resolutions (320×240 through 1600×1200)
- Implements stub functions for menu and change-detection hooks not needed in this null driver

## External Dependencies
- `../client/client.h` — pulls in `viddef_t`, `refexport_t`, `refimport_t`, `PRINT_ALL`, `API_VERSION`, `ERR_FATAL`
- `Com_Printf`, `Com_DPrintf`, `Com_Error` — engine common layer (defined in `qcommon/common.c`)
- `Cmd_AddCommand`, `Cmd_RemoveCommand`, `Cmd_Argc`, `Cmd_Argv`, `Cbuf_ExecuteText` — command system
- `FS_LoadFile`, `FS_FreeFile`, `FS_Gamedir` — filesystem layer
- `Cvar_Get`, `Cvar_Set`, `Cvar_SetValue` — cvar system
- `GetRefAPI` — declared extern, defined in whichever statically-linked renderer is compiled in

# qcommon/cmd.c
## File Purpose
Implements Quake 2's command buffer and command execution subsystem. It manages a text-based command queue, tokenizes and dispatches commands to registered handlers, and supports aliases, cvar macro expansion, and deferred execution.

## Core Responsibilities
- Maintain a circular-style text command buffer (`cmd_text`) with insert/append/execute operations
- Tokenize command strings into argc/argv form with optional `$cvar` macro expansion
- Dispatch commands to registered `cmd_function_t` handlers, aliases, cvars, or the server
- Manage a linked-list registry of named commands (`cmd_functions`)
- Manage a linked-list of named command aliases (`cmd_alias`)
- Support deferred buffer copy (`Cbuf_CopyToDefer`/`Cbuf_InsertFromDefer`) for level transitions
- Parse early (`+set`) and late (`+cmd`) command-line arguments into the buffer

## External Dependencies
- **Includes:** `qcommon.h`
- **Defined elsewhere:** `SZ_Init`, `SZ_Write`, `SZ_Clear`; `Z_Malloc`, `Z_Free`; `COM_Parse`, `COM_Argc`, `COM_Argv`, `COM_ClearArgv`; `Cvar_VariableString`, `Cvar_Command`; `FS_LoadFile`, `FS_FreeFile`; `Com_Printf`, `Com_Error`; `CopyString`; `Cmd_ForwardToServer`; `Q_strcasecmp`; `xcommand_t` typedef (in `qcommon.h`)

# qcommon/cmodel.c
## File Purpose
Implements the collision model (BSP-based) system for Quake 2. Loads BSP map lumps into collision-ready structures and provides spatial queries including point/box traces, leaf lookups, PVS/PHS decompression, and area portal connectivity flooding.

## Core Responsibilities
- Load and parse all collision-relevant BSP lumps from a `.bsp` file
- Maintain static arrays of planes, nodes, leafs, brushes, brush sides, and submodels
- Provide box/point trace queries against brushes via recursive BSP traversal
- Construct a synthetic "box hull" for AABB-vs-world queries
- Decompress run-length encoded PVS/PHS visibility bitsets per cluster
- Manage area portal open/closed state and flood-fill area connectivity
- Expose leaf, cluster, and area accessor functions to the rest of the engine

## External Dependencies
- **Includes:** `qcommon.h` (pulls in `qfiles.h`, `qcommon.h` types, `cplane_t`, `trace_t`, `cmodel_t`, `dvis_t`, `mapsurface_t`, etc.)
- **Defined elsewhere:** `FS_LoadFile`, `FS_FreeFile`, `FS_Read`, `Com_Error`, `Com_BlockChecksum`, `Cvar_Get`, `Cvar_VariableValue`, `AngleVectors`, `BOX_ON_PLANE_SIDE`, `DotProduct`, `VectorCopy`, `VectorClear`, `VectorSubtract`, `VectorAdd`, `VectorNegate`

# qcommon/common.c
## File Purpose
Central engine glue module shared by both client and server. It provides unified initialization, per-frame orchestration, error/quit handling, message I/O serialization, zone memory allocation, and console redirection infrastructure.

## Core Responsibilities
- Initialize all engine subsystems in the correct order (`Qcommon_Init`)
- Drive the per-frame update loop, dispatching to `SV_Frame` and `CL_Frame` (`Qcommon_Frame`)
- Provide a unified error/print/quit interface usable by both client and server
- Serialize and deserialize network messages (MSG_* read/write functions)
- Manage a tracked zone heap allocator (Z_* functions)
- Manage growable byte buffers (SZ_* functions)
- Handle command-line argument storage and lookup (COM_* functions)

## External Dependencies
- `qcommon.h` — defines `sizebuf_t`, `usercmd_t`, `entity_state_t`, cvars, error codes, network constants
- `client/anorms.h` — vertex normals table included inline
- **Defined elsewhere:** `SV_Frame`, `SV_Init`, `SV_Shutdown`, `CL_Frame`, `CL_Init`, `CL_Shutdown`, `CL_Drop`, `NET_Init`, `Netchan_Init`, `Sys_Init`, `Sys_Error`, `Sys_Quit`, `Sys_ConsoleInput`, `Sys_ConsoleOutput`, `Sys_Milliseconds`, `Con_Print`, `Key_Init`, `FS_InitFilesystem`, `FS_Gamedir`, `CRC_Block`, `Z_Malloc`

# qcommon/crc.c
## File Purpose
Implements a 16-bit CRC (Cyclic Redundancy Check) using the CCITT standard (polynomial 0x1021, XMODEM variant). Used throughout the engine to verify data integrity for network packets, file validation, and content checksumming.

## Core Responsibilities
- Initialize CRC state to the standard CCITT seed value
- Process individual bytes into a running CRC accumulator
- Finalize a CRC value via XOR (no-op here since `CRC_XOR_VALUE` is `0x0000`)
- Compute a CRC over a contiguous block of bytes in one call

## External Dependencies
- **Includes:** `qcommon.h` (provides `byte` typedef and common engine definitions)
- **External symbols:** `byte` — defined in shared headers, not this file.

# qcommon/crc.h
## File Purpose
Declares the public interface for a CRC (Cyclic Redundancy Check) utility module used throughout the engine for data integrity verification.

## Core Responsibilities
- Expose incremental CRC computation functions (`Init`, `ProcessByte`, `Value`)
- Expose a convenience block-level CRC function for contiguous memory regions

## External Dependencies
- `byte` typedef — defined in `qcommon/qcommon.h` or `game/q_shared.h`, not in this file.

# qcommon/cvar.c
## File Purpose
Implements Quake 2's console variable (cvar) system — a global, named, string-valued configuration store used by all engine subsystems. Provides registration, lookup, mutation, persistence, and console command integration for cvars.

## Core Responsibilities
- Maintain a singly-linked list of all registered `cvar_t` variables
- Register new cvars or merge flags into existing ones (`Cvar_Get`)
- Set cvar values with flag-aware protection (NOSET, LATCH, USERINFO, SERVERINFO)
- Apply latched values deferred until server restart (`Cvar_GetLatchedVars`)
- Serialize archived cvars to config file (`Cvar_WriteVariables`)
- Expose console commands: `set`, `cvarlist`, and inline variable inspection
- Build info strings for user/server info transmission

## External Dependencies
- **Includes:** `qcommon.h` (pulls in `cvar_t`, CVAR_* flags, `MAX_INFO_STRING`)
- **Defined elsewhere:** `Z_Malloc`, `Z_Free`, `CopyString` (zone allocator); `Com_Printf`, `Com_sprintf`, `Com_ServerState` (common); `Cmd_AddCommand`, `Cmd_Argc`, `Cmd_Argv` (command system); `FS_SetGamedir`, `FS_ExecAutoexec` (filesystem); `Info_SetValueForKey` (info string utility)

# qcommon/files.c
## File Purpose
Implements Quake 2's virtual filesystem (VFS), providing a unified abstraction over loose files and PAK archives. It manages a prioritized search-path chain so multiple game directories and pak files can be transparently layered. All engine file I/O for assets (models, sounds, configs, etc.) flows through this module.

## Core Responsibilities
- Maintain a linked-list search path of directories and pak archives (`fs_searchpaths`)
- Open files by searching links, pak files, and loose directories in priority order
- Load and parse PAK archive headers and directory entries into memory
- Manage game directory switching (`FS_SetGamedir`) including teardown and reload
- Provide bulk file loading into Z_Malloc'd heap buffers (`FS_LoadFile`)
- Support virtual file links (alias redirects) via `fs_links`
- Register console commands: `path`, `link`, `dir`

## External Dependencies
- `qcommon.h` — engine-wide types, `Com_Error`, `Com_Printf`, `Com_DPrintf`, `Com_sprintf`, `Cvar_*`, `Cmd_*`, `Cbuf_*`, `Z_Malloc`, `Z_Free`, `CopyString`
- `qfiles.h` — `dpackheader_t`, `dpackfile_t`, `IDPAKHEADER`, `MAX_FILES_IN_PACK`
- `Sys_Mkdir`, `Sys_FindFirst`, `Sys_FindNext`, `Sys_FindClose` — platform layer (defined elsewhere)
- `CDAudio_Stop` — declared via forward declaration; defined in platform audio layer
- `Com_BlockChecksum` — defined in `qcommon/md4.c`

# qcommon/md4.c
## File Purpose
Implements the RSA MD4 message-digest algorithm (RFC 1320) as a cryptographic hash utility. Used by the Quake 2 engine primarily for block checksum verification via `Com_BlockChecksum`.

## Core Responsibilities
- Initialize, update, and finalize MD4 hash contexts
- Process 64-byte blocks through a 3-round bitwise transformation
- Encode/decode between little-endian byte streams and 32-bit word arrays
- Expose `Com_BlockChecksum` as the engine-facing checksum API

## External Dependencies
- `<string.h>` — for `memcpy`, `memset`
- No other engine headers included; all types are self-contained within this file.
- `Com_BlockChecksum` is defined here and declared externally in `qcommon/qcommon.h`.

# qcommon/net_chan.c
## File Purpose
Implements Quake 2's reliable-over-UDP networking channel (`netchan`) system. It wraps raw UDP packets with sequence numbering and a lightweight reliability layer, ensuring that "reliable" messages are retransmitted until acknowledged while "unreliable" messages are fire-and-forget.

## Core Responsibilities
- Initialize network channel globals and register CVars (`showpackets`, `showdrop`, `qport`)
- Send out-of-band (connectionless) datagrams, both raw and formatted
- Set up a `netchan_t` channel between local and remote endpoints
- Determine when a reliable message must be (re)transmitted
- Pack and send outgoing packets with sequence/ACK headers and reliable payload
- Receive and validate incoming packets, stripping headers and updating channel state

## External Dependencies
- `qcommon.h` — types (`netchan_t`, `sizebuf_t`, `netadr_t`, `netsrc_t`, `cvar_t`), constants (`MAX_MSGLEN`)
- `NET_SendPacket`, `NET_AdrToString` — defined in platform network layer (`net_udp.c` / `net_wins.c`)
- `MSG_*`, `SZ_*` — message read/write utilities, defined in `qcommon/common.c`
- `Cvar_Get`, `Com_Printf` — engine common subsystems
- `Sys_Milliseconds` — platform timer, defined in platform `sys_*.c`
- `curtime` — global integer timestamp, defined elsewhere in `qcommon`

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

## External Dependencies
- Notable includes: `qcommon.h` (pulls in `pmove_t`, `csurface_t`, `cplane_t`, math macros, content flags)
- External symbols used but not defined here: `vec3_origin`, `AngleVectors`, `VectorNormalize`, `VectorLength`, `DotProduct`, `CrossProduct`, `VectorMA`, `SHORT2ANGLE`, `MASK_WATER`, `MASK_CURRENT`, `CONTENTS_*`, `SURF_SLICK`, `PMF_*` flags, `PM_DEAD/SPECTATOR/GIB/FREEZE` enum values, `MAXTOUCH`, `Com_DPrintf`, `memset`

# qcommon/qcommon.h
## File Purpose
Central shared header for the Quake 2 engine, defining all subsystem interfaces used by both client and server (but not game.dll). It declares the engine's network messaging, protocol, command, cvar, filesystem, collision model, and system abstraction APIs.

## Core Responsibilities
- Defines the binary message serialization interface (`sizebuf_t`, `MSG_*`)
- Declares the client/server network protocol opcodes and delta-compression bit flags
- Declares command buffer (`Cbuf_*`) and command execution (`Cmd_*`) subsystems
- Declares the console variable (`Cvar_*`) subsystem
- Declares the network layer (`NET_*`) and reliable channel (`Netchan_*`) interfaces
- Declares the collision model (`CM_*`) API
- Declares filesystem (`FS_*`), memory (`Z_*`), and common utility (`Com_*`) APIs
- Declares top-level engine lifecycle entry points (`Qcommon_Init/Frame/Shutdown`)

## External Dependencies
- `../game/q_shared.h` — shared game types (`vec3_t`, `trace_t`, `pmove_t`, `cvar_t`, `qboolean`, etc.)
- `../qcommon/qfiles.h` — on-disk BSP/model format types (`cmodel_t`, etc.)
- All `MSG_*`, `SZ_*`, `CM_*`, `FS_*`, `NET_*`, `Netchan_*`, `Cvar_*`, `Cmd_*`, `Cbuf_*`, `Z_*`, `Com_*`, `Sys_*`, `CL_*`, `SV_*` implementations are **defined elsewhere** in their respective `.c` files.

# qcommon/qfiles.h
## File Purpose
Defines all on-disk binary file format structures for Quake 2 asset types. This is a pure data-layout header shared between the engine and toolchain, containing no logic — only struct declarations, constants, and format magic numbers.

## Core Responsibilities
- Define the `.pak` archive container format (header + file directory entries)
- Define the `.pcx` image format layout
- Define the `.md2` triangle mesh format (vertices, frames, skins, GL commands)
- Define the `.sp2` sprite format
- Define the `.wal` texture (mipmap) format
- Define the `.bsp` map format in full (header, lumps, planes, nodes, leaves, faces, brushes, visibility, areas)
- Declare content flags and surface flags used by both BSP data and game logic

## External Dependencies
- No includes of its own; depends on basic C types (`short`, `int`, `byte`, `char`, `float`) being defined by the including translation unit (typically via `q_shared.h` or platform headers).
- `MAX_SKINNAME` (64) is defined here and reused by `dsprframe_t` and MD2 skin offsets.
- Content flags (`CONTENTS_*`) and surface flags (`SURF_*`) defined here are also required in `q_shared.h` — the comment explicitly notes this dual-residency requirement.

# ref_gl/anorms.h
## File Purpose
A raw data table of 162 pre-computed unit normal vectors, evenly distributed across the sphere using an icosahedron-based subdivision. Used by the alias model rendering system to convert compressed 8-bit normal indices (stored in MD2 model vertex data) back into 3D lighting normals.

## Core Responsibilities
- Provides the lookup table `r_avertexnormals` (or equivalent) mapping integer indices to unit normals
- Enables decompression of per-vertex normals from MD2's compact 1-byte representation
- Supplies normals for per-vertex diffuse lighting on alias (MD2) models in the GL renderer

## External Dependencies
- No `#include` directives — not a self-contained header
- Depends on the enclosing `.c` file to supply the array declaration context
- Identical or near-identical copies exist at `client/anorms.h` and `ref_soft/anorms.h`, shared across the soft and GL renderers and the client

# ref_gl/anormtab.h
## File Purpose
This header contains a precomputed 2D lookup table of floating-point scalar values used to approximate per-normal lighting dot products for alias model (MD2) rendering in the GL renderer. Each row corresponds to a discrete light pitch angle, and each column corresponds to one of the 162 precalculated vertex normals (plus padding to 256 entries) used by Quake 2's alias model format.

## Core Responsibilities
- Provide a static, compile-time data table for normal-to-light dot product approximation
- Map (light pitch index × normal index) → scalar intensity multiplier
- Eliminate per-frame trigonometric computation for alias model lighting
- Pad each row to 256 entries (remaining entries filled with `1.00`) to allow power-of-2 indexing

## External Dependencies
- No includes.
- Intended to be used by `ref_gl/gl_rmain.c` or equivalent, which defines the enclosing array variable and the `SHADEDOT_QUANT` constant (16 rows visible here, corresponding to 16 discrete pitch quantization steps).
- Parallel structure to `client/anorms.h`, which defines the actual 3D unit normal vectors for the 162 standard Quake 2 alias model normals. This table precomputes the lighting result for each (normal, pitch) pair.


# ref_gl/gl_draw.c
## File Purpose
Implements all 2D screen-space drawing primitives for the OpenGL renderer. Handles console characters, HUD pictures, screen fills, fade overlays, and raw cinematic frame blitting.

## Core Responsibilities
- Initialize and cache the console character texture (`conchars.pcx`)
- Draw individual 8×8 console/HUD characters from a 16×16 glyph atlas
- Load and render 2D pictures (PCX files, with scrap atlas support)
- Tile a texture to fill letterbox/background regions
- Fill screen rectangles with a solid palette color
- Draw a full-screen semi-transparent black fade overlay
- Blit and scale raw 8-bit cinematic frames (with optional paletted-texture path)

## External Dependencies
- **Includes:** `gl_local.h` (pulls in all GL types, `image_t`, `gl_config`, `vid`, `d_8to24table`)
- **Defined elsewhere:** `scrap_dirty`, `Scrap_Upload` (`gl_image.c`); `r_rawpalette` (`gl_rmisc.c`); `GL_FindImage`, `GL_Bind` (`gl_image.c`); `gl_config`, `gl_tex_solid_format` (`gl_rmain.c`); `qglColorTableEXT`, all `qgl*` wrappers (`qgl_*.c`); `ri` (renderer import struct); `d_8to24table` (palette table)

# ref_gl/gl_image.c
## File Purpose
Manages all OpenGL texture loading, uploading, and lifecycle for the GL renderer. Handles image decoding (PCX, TGA, WAL), GPU upload with mip generation, scrap atlas packing for small UI images, and texture registration/eviction.

## Core Responsibilities
- Load and decode PCX, TGA, and WAL image formats from disk
- Upload 8-bit and 32-bit image data to OpenGL (with optional mipmap generation)
- Scale textures to power-of-two dimensions, applying gamma and intensity correction
- Pack small HUD/pic images into a scrap atlas texture to reduce bind overhead
- Manage the `gltextures[]` pool: allocation, registration tracking, and free-on-reload
- Provide texture filter/format mode switching at runtime
- Initialize the 8-to-24-bit palette table and gamma/intensity LUTs

## External Dependencies
- `gl_local.h` — `image_t`, `gl_state`, `ri` (refimport_t), cvars, `registration_sequence`, `r_notexture`, `r_particletexture`
- `qglBindTexture`, `qglTexImage2D`, `qglTexParameterf`, `qglDeleteTextures`, `qglColorTableEXT`, `qglSelectTextureSGIS` — defined in platform GL wrapper
- `LittleShort`, `LittleLong`, `Q_stricmp` — defined in shared utilities
- `pcx_t`, `miptex_t` — defined in `qfiles.h`
- `TEXNUM_SCRAPS`, `TEXNUM_IMAGES`, `MAX_GLTEXTURES` — constants defined elsewhere

# ref_gl/gl_light.c
## File Purpose
Implements all lighting calculations for the OpenGL renderer, covering dynamic light rendering (flashblend halos), BSP surface light marking, lightmap sampling for entities, and lightmap texture construction from static and dynamic light sources.

## Core Responsibilities
- Render dynamic lights as additive blended billboard halos (`gl_flashblend` mode)
- Mark BSP surfaces affected by dynamic lights each frame (`R_MarkLights`/`R_PushDlights`)
- Sample world lightmap data at a point for entity lighting (`R_LightPoint`)
- Accumulate dynamic light contributions into the `s_blocklights` buffer
- Build final RGBA lightmap texels from combined static + dynamic light data
- Handle monochrome lightmap modes (L, I, C, A) for alternate rendering paths

## External Dependencies
- **Includes:** `gl_local.h` (pulls in all GL, engine math, and renderer state)
- **Defined elsewhere:** `r_framecount`, `r_newrefdef`, `r_worldmodel`, `r_origin`, `vpn`, `vright`, `vup`, `currententity`, `gl_flashblend`, `gl_modulate`, `gl_monolightmap` (cvars/globals from `gl_rmain.c`); `Q_ftol` (platform math); all `qgl*` function pointers; `ri` (renderer import table)

# ref_gl/gl_local.h
## File Purpose
Central internal header for the Quake 2 OpenGL renderer (`ref_gl`). Defines all shared types, global state declarations, render CVars, and function prototypes used across the GL renderer subsystem. Acts as the single include point that binds together image management, model data, GL configuration, and the platform abstraction layer.

## Core Responsibilities
- Define `image_t` and `imagetype_t` for GPU texture management
- Declare all renderer-facing CVars (quality, extensions, lighting, particles)
- Expose the `glconfig_t` / `glstate_t` structs for hardware capability and runtime GL state
- Declare all cross-file render function prototypes (draw, model, world, sky, lighting)
- Define GL renderer identification bitmasks for hardware-specific workarounds
- Declare the `GLimp_*` platform abstraction interface
- Expose `refimport_t ri` for engine callback access

## External Dependencies
- `<GL/gl.h>`, `<GL/glu.h>` — OpenGL API
- `../client/ref.h` — `refdef_t`, `refimport_t`, `entity_t`, `particle_t`, `cvar_t`, `vec3_t`, etc.
- `qgl.h` — Quake GL function pointer wrappers
- `gl_model.h` — `model_t`, `msurface_t`, `mnode_t`, `glpoly_t`, `dlight_t`, `cplane_t`
- All `extern` globals and function bodies defined across `gl_rmain.c`, `gl_image.c`, `gl_rsurf.c`, `gl_draw.c`, `gl_light.c`, `gl_warp.c`, `gl_mesh.c`, `gl_rmisc.c`, and platform `GLimp` implementations

# ref_gl/gl_mesh.c
## File Purpose
Renders MD2 alias (triangle) models in the OpenGL renderer. Handles per-frame vertex interpolation, lighting/shading setup, frustum culling, and optional planar shadow projection for all non-BSP entities.

## Core Responsibilities
- Interpolate vertex positions between two animation frames (`GL_LerpVerts`)
- Cull alias models against the view frustum using an OBB derived from frame bounds (`R_CullAliasModel`)
- Compute and apply per-entity shading color for all shell/effect flags, fullbright, glow, IR goggles, and monochrome modes
- Draw interpolated geometry via GL commands list, with optional vertex array fast path (`GL_DrawAliasFrameLerp`)
- Render a flattened ground shadow blob (`GL_DrawAliasShadow`)
- Handle left-hand weapon mirroring via projection matrix flip

## External Dependencies
- **Includes:** `gl_local.h` (pulls in all GL types, cvars, entity/model globals)
- **Includes (data):** `anorms.h`, `anormtab.h`
- **Defined elsewhere:** `currententity`, `currentmodel`, `r_newrefdef`, `frustum`, `lightspot`, `c_alias_polys`, `gldepthmin/max`, `r_lefthand`, `gl_shadows`, `gl_vertex_arrays`, `r_lerpmodels`, `gl_monolightmap`, `r_lightlevel`, `R_LightPoint`, `R_RotateForEntity`, `GL_Bind`, `GL_TexEnv`, `MYgluPerspective`, `qglLockArraysEXT`, `qglUnlockArraysEXT`

# ref_gl/gl_model.c
## File Purpose
Handles all model loading, caching, and registration for the GL renderer. It parses and converts BSP brush models, MD2 alias models, and sprite models from on-disk formats into renderer-internal structures, and manages the model cache lifecycle tied to map registration sequences.

## Core Responsibilities
- Load and cache brush (BSP), alias (MD2), and sprite models from disk
- Convert on-disk binary formats to host endianness during load
- Manage a fixed-size model cache (`mod_known`) with name-based deduplication
- Build GPU-ready surface data: lightmaps, polygons, texture extents
- Provide PVS/cluster visibility queries (`Mod_PointInLeaf`, `Mod_ClusterPVS`)
- Implement the `R_BeginRegistration` / `R_EndRegistration` lifecycle to evict unused models and images

## External Dependencies
- **Includes:** `gl_local.h` (pulls in all renderer types, `ri` import table, math macros)
- **Defined elsewhere:**
  - `ri` — renderer import struct (`Sys_Error`, `Con_Printf`, `FS_LoadFile`, `Cvar_Get`)
  - `r_worldmodel`, `r_viewcluster`, `r_oldviewcluster`, `currentmodel` — globals in `gl_rmain.c`
  - `r_notexture` — fallback image, `gl_image.c`
  - `GL_FindImage`, `GL_FreeUnusedImages` — `gl_image.c`
  - `GL_BuildPolygonFromSurface`, `GL_SubdivideSurface` — `gl_warp.c` / `gl_rsurf.c`
  - `GL_BeginBuildingLightmaps`, `GL_CreateSurfaceLightmap`, `GL_EndBuildingLightmaps` — `gl_light.c`
  - `Hunk_Begin`, `Hunk_Alloc`, `Hunk_End`, `Hunk_Free` — engine memory allocator

# ref_gl/gl_model.h
## File Purpose
Defines the in-memory data structures for all model types (brush, sprite, alias) used by the GL renderer. Bridges on-disk BSP/mesh formats with renderer-ready representations, and declares the model management and hunk allocator API.

## Core Responsibilities
- Define in-memory brush model geometry types (vertices, edges, surfaces, nodes, leaves)
- Define the unified `model_t` container for all model types
- Declare surface flags and BSP traversal side constants
- Declare the model lifecycle API (`Mod_Init`, `Mod_ForName`, `Mod_Free`, etc.)
- Declare the hunk (zone) allocator API used for model data

## External Dependencies
- `gl_local.h` (implicit) — provides `image_t`, `cplane_t`, `dvis_t`, `MAX_QPATH`, `MAX_MD2SKINS`, `MAXLIGHTMAPS`, `vec3_t`, `qboolean`
- `cplane_t` — defined in `qcommon/qfiles.h` or shared headers
- `dvis_t` — on-disk vis structure, defined in `qcommon/qfiles.h`
- `image_t` — defined in `ref_gl/gl_local.h`

# ref_gl/gl_rmain.c
## File Purpose
Central orchestration file for the OpenGL renderer (`ref_gl`). It owns the per-frame render pipeline, manages all renderer cvars, implements the `GetRefAPI` export entry point, and handles renderer initialization and shutdown.

## Core Responsibilities
- Exports `GetRefAPI`, the DLL entry point that binds the renderer to the engine
- Drives the full 3D render pipeline: setup → world → entities → dlights → particles → alpha surfaces → screen blend
- Manages frustum setup and entity-level culling (`R_CullBox`)
- Dispatches entity rendering by model type (alias, brush, sprite, beam, null)
- Draws sprite models, beam entities, and particles directly
- Initializes/registers ~50 renderer cvars and console commands
- Handles mode-setting, GL extension detection, and stereo initialization

## External Dependencies
- `gl_local.h` — renderer-local types, macros, all qgl declarations
- `GLimp_*` — OS/platform GL implementation (context, mode, frame begin/end)
- `QGL_Init` / `QGL_Shutdown` — dynamic OpenGL function binding layer
- `R_DrawAliasModel`, `R_DrawBrushModel`, `R_DrawBeam`, `R_DrawWorld`, `R_MarkLeaves`, `R_PushDlights`, `R_RenderDlights`, `R_DrawAlphaSurfaces`, `R_LightPoint` — defined in other `ref_gl/` files
- `Mod_Init`, `Mod_FreeAll`, `Mod_PointInLeaf` — model subsystem (`gl_model.c`)
- `GL_InitImages`, `GL_ShutdownImages`, `GL_TextureMode` — image subsystem (`gl_image.c`)
- `d_8to24table` — global 8-to-32-bit color table, defined elsewhere
- `ri` (refimport) — all engine services (cvars, console, errors) accessed through this

# ref_gl/gl_rmisc.c
## File Purpose
Miscellaneous OpenGL renderer initialization and utility routines. Handles particle/fallback texture creation, TGA screenshot capture, GL state initialization, and swap interval management.

## Core Responsibilities
- Generate and upload the particle dot texture and the "no texture" fallback texture
- Capture and write TGA-format screenshots to disk
- Print GL vendor/renderer/version/extension strings to console
- Set the default OpenGL render state at renderer startup
- Update the vsync swap interval when the cvar changes

## External Dependencies
- **Includes:** `gl_local.h` (pulls in all GL types, cvars, `gl_config`, `gl_state`, `vid`, `ri`)
- **Defined elsewhere:** `r_particletexture`, `r_notexture`, `gl_config`, `gl_state`, `vid`, `ri`, `d_8to24table`, `GL_LoadPic`, `GL_TextureMode`, `GL_TextureAlphaMode`, `GL_TextureSolidMode`, `GL_TexEnv`, `GL_SetTexturePalette`, `Sys_Mkdir`, `Com_sprintf`, all `qgl*` function pointers

# ref_gl/gl_rsurf.c
## File Purpose
Implements surface-level rendering for the OpenGL renderer, covering BSP world traversal, brush model drawing, lightmap allocation/upload, and alpha/translucent surface handling. It manages both single-texture and multitexture (SGIS) paths for lightmapped world geometry.

## Core Responsibilities
- Traverse the BSP tree recursively to determine visible surfaces each frame
- Render opaque brush model and world surfaces with or without multitexture
- Manage lightmap atlas allocation, building, and dynamic updates
- Queue and draw translucent/alpha surfaces in back-to-front order
- Handle texture animation and scrolling (flowing) surfaces
- Mark visible leaves/nodes via PVS (Potentially Visible Set)
- Build GL polygon geometry from BSP surface edge data at load time

## External Dependencies
- Notable includes: `gl_local.h` (pulls in all GL types, cvars, model structs)
- External symbols used but not defined here: `R_BuildLightMap`, `R_SetCacheState` (defined in `gl_light.c`); `EmitWaterPolys`, `R_DrawSkyBox`, `R_ClearSkyBox`, `R_AddSkySurface` (warp/sky modules); `R_MarkLights` (dynamic light marking); `Mod_ClusterPVS` (model/vis module); `GL_Bind`, `GL_MBind`, `GL_EnableMultitexture`, `GL_TexEnv`, `GL_SelectTexture` (`gl_image`/`gl_rmain`); `qgl*` function pointers (GL dispatch layer); `r_worldmodel`, `r_framecount`, `r_visframecount`, `r_viewcluster`, `currententity`, `currentmodel`, `gl_state`, `r_newrefdef` (renderer globals).

# ref_gl/gl_warp.c
## File Purpose
Implements sky box rendering and water/turbulent surface warping for the OpenGL renderer. It handles subdivision of warp surfaces at load time and per-frame animated rendering of water polygons and the six-sided sky box.

## Core Responsibilities
- Subdivide warp surfaces (water, lava, slime, sky) into 64-unit grid polygons at model load time
- Render water/turbulent polygons with animated sinusoidal UV distortion each frame
- Clip sky polygons against six frustum planes and accumulate per-face UV extents
- Draw the six-sided sky box using accumulated min/max UV extents with optional rotation
- Load and bind sky cube-face textures from `env/` directory (TGA or PCX)

## External Dependencies
- `gl_local.h` — renderer types (`msurface_t`, `glpoly_t`, `image_t`, `r_newrefdef`, `r_origin`, GL wrappers)
- `warpsin.h` — 256-entry float sin table included inline
- `loadmodel` — extern `model_t*` set by the model loader
- `Hunk_Alloc`, `ri.Sys_Error` — engine memory/error services
- `GL_Bind`, `GL_FindImage`, `GL_TexEnv` — defined in other `ref_gl` files
- `gl_skymip`, `gl_picmip`, `gl_ext_palettedtexture` — cvars defined elsewhere

# ref_gl/qgl.h
## File Purpose
Declares the Quake GL abstraction layer: a complete set of function pointers mirroring the OpenGL 1.1 API (plus select extensions), allowing the engine to load OpenGL dynamically from a DLL/shared library at runtime rather than linking statically. Also declares the `QGL_Init`/`QGL_Shutdown` lifecycle interface.

## Core Responsibilities
- Expose `extern` function pointer declarations for the full OpenGL 1.1 core API via `qgl*` names
- Expose `extern` function pointer declarations for Windows WGL context management via `qwgl*` names (Win32 only)
- Declare optional extension function pointers: `EXT`, `SGIS` extensions for point parameters, color tables, compiled vertex arrays, and multitexture
- Define extension enumerant constants not present in stock `<GL/gl.h>` headers
- Declare `QGL_Init` and `QGL_Shutdown` as the public interface for loading/unloading the GL DLL

## External Dependencies
- `<windows.h>` — Win32 types (`HDC`, `HGLRC`, `BOOL`, `WINAPI`, etc.), included conditionally
- `<GL/gl.h>` — GL type definitions (`GLenum`, `GLfloat`, `GLuint`, etc.) and standard enumerants
- `QGL_Init` / `QGL_Shutdown` implementations — defined in `win32/qgl_win.c` or `linux/qgl_linux.c`
- All `qgl*` variable definitions — defined in the corresponding platform `.c` file

# ref_gl/warpsin.h
## File Purpose
A raw data header containing a precomputed sine wave lookup table scaled by 8, used to drive texture coordinate warping for liquid/warp surfaces in the OpenGL renderer. It is intended to be included directly inside an array initializer, not as a standalone declaration.

## Core Responsibilities
- Provides 256 precomputed float values representing one full cycle of `8 * sin(x)` for x in [0, 2π)
- Eliminates runtime `sin()` calls for warp surface texture animation
- Encodes both positive and negative half-cycles, forming a complete sine period

## External Dependencies
- No includes of its own
- Consumed by: `ref_gl/gl_warp.c` (defined elsewhere)

**Notes:**
- 256 entries total — designed for power-of-two masked indexing (`& 255`)
- Amplitude is 8 (range: −8 to +8), matching the warp displacement scale used in `gl_warp.c`
- Entry at index 128 is `9.79717e-16` (floating-point zero artifact) rather than exactly `0.0`, confirming values were generated programmatically via `sin()`
- No include guards — safe only because the file is raw data, not a header with declarations

# ref_soft/adivtab.h
## File Purpose
A precomputed lookup table of integer division results (quotient and remainder pairs) for all combinations of numerator in [-15...16] and denominator in [-15...16]. It eliminates runtime integer division in the software renderer's inner loops.

## Core Responsibilities
- Stores 32×32 = 1024 `{quotient, remainder}` pairs as raw brace-initializer data
- Provides O(1) division results for small signed integers used in texture/span rasterization
- Intended to be `#include`d directly into a struct/array initializer, not used as a standalone header

## External Dependencies
- No `#include` directives
- No external symbols referenced
- Depends entirely on the including translation unit for type context and array declaration

# ref_soft/anorms.h
## File Purpose
A raw data header containing 162 pre-computed unit normal vectors arranged on an icosahedron-derived sphere. These normals are used by the software renderer to approximate lighting on alias (MD2) models.

## Core Responsibilities
- Provides the Quake 2 standard normal lookup table (162 entries, matching the Quake MDL/MD2 normal encoding scheme)
- Each entry is a unit-length 3D vector `{x, y, z}` stored as float literals
- Intended to be included directly inside an array initializer or variable declaration in a `.c` file

## External Dependencies
- No `#include` directives
- No external symbols
- Depends entirely on the including `.c` file to provide the surrounding array declaration context

# ref_soft/asm_draw.h
## File Purpose
A pure-offset header that exposes byte offsets and constants for C structs shared between the software renderer's C code and its x86 assembly routines. It acts as the assembly-visible "ABI contract" so that `.s`/`.asm` files can access struct fields by numeric offset rather than C member syntax.

## Core Responsibilities
- Define `NEAR_CLIP` and `CYCLE` constants for use in both C and assembly
- Publish byte offsets for `espan_t`, `sspan_t`, `edge_t`, `surf_t`, `clipplane_t` fields
- Publish byte offsets for `medge_t`, `mvertex_t`, `refdef_t`, `mtriangle_t` fields
- Provide struct size constants (`*_size`) so assemblers can stride through arrays
- Provide shift/bit constants (`SURF_T_SHIFT`, `mtri_shift`) for fast array indexing in assembly
- Serve as the single synchronization point between C struct layout and hand-written ASM

## External Dependencies
- **Defined elsewhere** (structs whose layouts this file mirrors):
  - `espan_t`, `edge_t`, `surf_t` → `r_shared.h`
  - `sspan_t` → `d_local.h`
  - `clipplane_t` → `r_local.h`
  - `medge_t`, `mvertex_t`, `mtriangle_t` → `model.h` (or `r_model.h`)
  - `refdef_t` → `render.h`
- No `#include` directives; this file is a standalone offset table.
- Consumed by: `ref_soft/r_aclipa.asm`, `ref_soft/r_edgea.asm`, `ref_soft/r_polysa.asm`, `linux/d_polysa.s`, `linux/r_aclipa.s`, etc.

# ref_soft/block16.inc
## File Purpose
x86 assembly include fragment implementing a 16-bit-per-pixel texture block drawing loop for the software renderer. It is `#include`d or assembled inline into a larger span/block rasterizer, providing unrolled pixel-output iterations at multiple entry granularities (16, 8, 4, and 2 pixel block sizes).

## Core Responsibilities
- Reads 8-bit palette indices from a source texture span (via `esi` and `esi+ebx`)
- Expands palette indices into 16-bit RGB pixel values via a runtime-patched lookup table
- Writes two 16-bit pixels per iteration to the destination framebuffer (via `edi`)
- Advances the texture coordinate accumulator (`edx += ebp`) for sub-texel stepping
- Provides four fall-through entry points (`LEnter16_16`, `LEnter8_16`, `LEnter4_16`, `LEnter2_16`) enabling partial-block dispatch without branching

## External Dependencies
- No includes; this is a pure assembly fragment
- `12345678h` placeholder addresses are patched at load/init time by the surrounding C or assembly initializer with the address of the active 16-bit color palette lookup table
- Register ABI (`esi`, `edi`, `ebx`, `edx`, `ebp`) is a calling convention defined by the enclosing rasterizer, not within this file

# ref_soft/block8.inc
## File Purpose
x86 assembly include file providing an unrolled, hand-optimized inner loop for block-scaling texture fetch and 16-bit pixel output. It is `#include`d (or assembled directly) into a larger software renderer routine that samples 8-bit paletted texels and writes 16-bit color values to the framebuffer.

## Core Responsibilities
- Read two 8-bit texel indices per iteration from a source texture surface (via `esi` and `esi+ebx`)
- Use the high byte of the fixed-point V coordinate (`dh`) to form a 2D palette/translation lookup index
- Translate each 8-bit palette index into a 16-bit color word via a self-patching lookup table address (`12345678h` placeholder)
- Advance the fixed-point texture coordinate accumulator (`edx += ebp`)
- Write two 16-bit pixels at a time to the destination framebuffer (`edi`)
- Provide four entry points (`LEnter16_16`, `LEnter8_16`, `LEnter4_16`, `LEnter2_16`) for partially-unrolled loop dispatch based on remaining pixel count (16, 8, 4, 2 pixels)

## External Dependencies
- No includes; depends entirely on register state established by the enclosing routine
- `12345678h` addresses are **runtime-patched** by an external C or asm function that writes the actual palette translation table address into the instruction stream at `LBPatch0`–`LBPatch15`
- Companion file `block8.inc` / `block16.h` likely handles the 8-bit framebuffer variant

# ref_soft/d_if.inc
## File Purpose
x86 assembly include file that defines struct field offsets and constants mirroring C structures from `d_iface.h` and related headers. It allows assembly routines to access C struct members by byte offset without redefining types in ASM syntax.

## Core Responsibilities
- Define byte offsets for `particle_t`, `finalvert_t`, `stvert_t`, `trivertx_t`, and `affinetridesc_t` fields
- Define shared engine constants (`TURB_TEX_SIZE`, `CYCLE`, `MAXHEIGHT`, `CACHE_SIZE`, `ALIAS_ONSEAM`)
- Serve as the ASM-side contract that must stay synchronized with multiple C headers

## External Dependencies
- Must remain byte-for-byte consistent with:
  - `d_iface.h` — `particle_t`, `finalvert_t`, `affinetridesc_t`
  - `r_shared.h` — `ALIAS_ONSEAM`, `MAXHEIGHT`
  - `modelgen.h` — `stvert_t`, `trivertx_t`
  - `quakedef.h` — `CACHE_SIZE`
- No symbols are defined here; all are `equ` (assembler constants resolved at assemble time)


# ref_soft/d_ifacea.h
## File Purpose
Assembly-language interface header for the software renderer's inner-loop driver. Defines byte offsets into C structures so that hand-written x86 assembly routines can access struct fields without going through the C compiler.

## Core Responsibilities
- Mirror key constants from `d_iface.h`, `r_shared.h`, and `qcommon.h` for use in `.s`/`.asm` files
- Provide field byte offsets for `particle_t` so assembly renderers can read position and color
- Provide field byte offsets for `finalvert_t` (post-transform alias model vertices)
- Provide field byte offsets for `stvert_t` (alias model skin-texture coordinates)
- Provide field byte offsets for `trivertx_t` (compressed alias model vertex format)
- Provide field byte offsets for `affinetridesc_t` (per-triangle affine rasterisation descriptor)

## External Dependencies
- **Must stay in sync with** (manual contract, not enforced by the build):
  - `ref_soft/d_iface.h` — `particle_t`, `finalvert_t`, `affinetridesc_t`
  - `game/modelgen.h` or equivalent — `stvert_t`, `trivertx_t`
  - `r_shared.h` — `MAXHEIGHT`
  - `qcommon/qcommon.h` — `CACHE_SIZE`
- No external symbols are referenced; this is a pure constant-definition header.


# ref_soft/qasm.inc
## File Purpose
This is an x86 assembly include file for the Quake 2 software renderer. It declares external C symbols visible to assembly routines and defines byte-offset constants for C structs, enabling assembly code to directly access struct fields without going through C headers.

## Core Responsibilities
- Declares `externdef` references to all C global variables used by the software renderer's assembly routines
- Defines struct field byte offsets as assembler `equ` constants, mirroring C struct layouts
- Guards renderer-specific externs under `ifndef GLQUAKE` so the file is reusable in non-GL contexts
- Provides constants (`TRANSPARENT_COLOR`, `NEAR_CLIP`, `CYCLE`) shared between C and assembly
- Acts as the single synchronization point between C data layout and hand-written assembly

## External Dependencies

- **Mirrors (must stay in sync with):**
  - `d_iface.h` — `TRANSPARENT_COLOR`
  - `model.h` — `plane_t`, `hull_t`, `medge_t`, `mvertex_t`, `mtriangle_t`
  - `bspfile.h` — `dnode_t`
  - `sound.h` — `sfxcache_t`, `channel_t`, `portable_samplepair_t`
  - `r_local.h` — `NEAR_CLIP`, `CYCLE`, `clipplane_t`
  - `r_shared.h` — `espan_t`, `edge_t`, `surf_t`
  - `d_local.h` — `sspan_t`
  - `d_polyset.c` — `spanpackage_t`
  - `render.h` — `refdef_t`
- All symbols declared via `externdef` are **defined elsewhere** in C translation units (`r_edge.c`, `r_surf.c`, `snd_dma.c`, `snd_mix.c`, etc.)

# ref_soft/r_aclip.c
## File Purpose
Implements polygon clipping routines for Alias (MD2) model triangles in the software renderer. Clips projected screen-space vertices against the view frustum (Z-near plane) and screen-edge boundaries before rasterization.

## Core Responsibilities
- Clip individual edges against the near Z plane (`R_Alias_clip_z`)
- Clip individual edges against screen rectangle bounds (left/right/top/bottom)
- Run a Sutherland-Hodgman style polygon clipper (`R_AliasClip`) for a single clip plane at a time
- Orchestrate full multi-plane clipping of a triangle (`R_AliasClipTriangle`)
- Fan-triangulate clipped polygon output and submit to `R_DrawTriangle`

## External Dependencies
- `r_local.h` — pulls in `finalvert_t`, clip flag constants (`ALIAS_Z_CLIP`, `ALIAS_LEFT_CLIP`, etc.), `ALIAS_Z_CLIP_PLANE`, `r_refdef` (aliasvrect bounds), `aliastriangleparms`
- `R_AliasProjectAndClipTestFinalVert` — defined elsewhere (projects view-space xyz to screen)
- `R_DrawTriangle` — defined elsewhere (software rasterizer entry point)
- `aliastriangleparms` — global struct defined elsewhere; written here to pass triangle to rasterizer

# ref_soft/r_alias.c
## File Purpose
Implements alias (MD2) model rendering for the software rasterizer. Handles model transformation, bounding box culling, frame interpolation (lerping), lighting setup, skin binding, and per-vertex projection before dispatching triangles to the software span-fill rasterizer.

## Core Responsibilities
- Frustum/clip-plane bounding box rejection testing for alias models
- World-to-view transform matrix construction for each entity
- Frame interpolation: computing lerp coefficients and blending old/new frame vertices
- Per-vertex lighting calculation using precomputed vertex normals
- Skin setup and texture coordinate preparation
- Power suit shell effect vertex displacement
- Triangle dispatch to clipped or unclipped software rasterizer paths
- Left-hand weapon model mirroring (negated X scale)

## External Dependencies
- **Includes:** `r_local.h` (all soft-renderer types and globals)
- **Defined elsewhere:** `currententity`, `currentmodel`, `r_origin`, `vright`, `vup`, `vpn`, `view_clipplanes`, `r_refdef`, `aliasxscale`, `aliasyscale`, `aliasxcenter`, `aliasycenter`, `r_newrefdef`, `r_lefthand`, `r_lerpmodels`, `r_lightlevel`, `d_pdrawspans`, `aliastriangleparms`
- **Calls external:** `R_LightPoint`, `R_ConcatTransforms`, `AngleVectors`, `R_DrawTriangle`, `R_AliasClipTriangle`, `R_PolysetUpdateTables`, `R_PolysetDrawSpans8_*`, `ri.Con_Printf`

# ref_soft/r_bsp.c
## File Purpose
Implements BSP tree traversal for the software renderer, handling both world geometry rendering and submodel (bmodel) polygon clipping. It walks the BSP tree to determine visible surfaces, backface-culls polygons, and clips bmodel polygons against BSP node planes before submission to the rasterizer.

## Core Responsibilities
- Traverse the world BSP tree recursively, frustum-culling nodes and marking visible surfaces
- Render world surfaces in front-to-back order using per-leaf render keys
- Compute rotation matrices from entity Euler angles for submodel transforms
- Transform and clip bmodel polygons against BSP planes (`R_RecursiveClipBPoly`)
- Dispatch clipped bmodel faces to `R_RenderBmodelFace` or `R_RenderFace`
- Maintain `r_currentkey`/`r_currentbkey` for painter's-algorithm ordering

## External Dependencies
- **Includes:** `r_local.h` (brings in all soft-renderer types and globals)
- **Defined elsewhere:** `R_RenderFace`, `R_RenderBmodelFace`, `R_ConcatRotations`, `R_TransformFrustum`, `r_visframecount`, `r_framecount`, `r_currentkey`, `r_worldmodel`, `r_worldentity`, `r_origin`, `r_pcurrentvertbase`, `r_newrefdef`, `view_clipplanes`, `pfrustum_indexes`, `vpn`, `vright`, `vup`, `currentmodel`, `ri`

# ref_soft/r_draw.c
## File Purpose
Implements 2D screen drawing routines for the software renderer. Handles UI elements including characters, pics, tiles, solid fills, and screen fade effects by writing directly to the software framebuffer (`vid.buffer`).

## Core Responsibilities
- Load and cache the console character font (`conchars`)
- Draw individual 8×8 console/HUD characters with transparency support
- Draw named PCX images (pics) with optional transparency, at 1:1 or stretched scale
- Tile a 64×64 image across a rectangular screen region
- Fill screen rectangles with a solid palette index color
- Apply a dithered screen fade effect (darkens every other pixel)

## External Dependencies
- `r_local.h` — renderer globals, `image_t`, `vid`, `TRANSPARENT_COLOR`
- `R_FindImage` — image loading/caching (defined in `r_image.c`)
- `ri.Sys_Error`, `ri.Con_Printf` — engine callbacks (defined elsewhere in engine)
- `Com_sprintf` — defined in `qcommon`
- `vid.buffer`, `vid.rowbytes`, `vid.width`, `vid.height` — framebuffer state (defined elsewhere)

# ref_soft/r_edge.c
## File Purpose
Implements the Active Edge Table (AET) algorithm for the software renderer, converting BSP-sorted polygon edges into per-scanline span lists. It also dispatches surface filling (texture mapping, sky, turbulent water, flat background) for each visible surface using the generated spans.

## Core Responsibilities
- Manage the active edge table (AET) per scanline: insert, remove, and step edges
- Generate horizontal spans for each visible surface via leading/trailing edge processing
- Maintain a sorted surface stack (by depth key / 1/z) to resolve surface visibility
- Dispatch per-surface rasterization: solid texture, sky, turbulent, background, flat debug
- Calculate texture gradient values (`d_sdivz*`, `d_tdivz*`, `sadjust`, `tadjust`) for scanline mappers
- Handle submodel (bmodel) entities with per-surface model-space transforms

## External Dependencies
- **Includes:** `r_local.h` (all renderer types, globals, math macros)
- **Defined elsewhere:** `D_DrawSurfaces` calls `D_DrawSpans16`, `D_DrawZSpans`, `Turbulent8`, `NonTurbulent8`, `D_CacheSurface`, `D_FlatFillSurface` (other ref_soft files); `R_RotateBmodel`, `R_TransformFrustum` (r_bsp/r_main); `TransformVector`, `VectorSubtract`, `DotProduct` (math); `sw_draworder`, `sw_clearcolor`, `sw_drawflat` (cvars); `d_scalemip`, `d_minmip`, `xscaleinv`, `yscaleinv`, `xcenter`, `ycenter`, `r_newrefdef`, `r_refdef`, `r_origin`, `base_vpn/vup/vright` (renderer globals)

# ref_soft/r_image.c
## File Purpose
Manages the software renderer's image/texture system, handling loading, caching, and lifecycle of PCX, WAL, and TGA image assets. It provides the registration-sequence-based cache for all textures used by the software renderer.

## Core Responsibilities
- Maintain a fixed-size image cache (`r_images[MAX_RIMAGES]`) with registration-sequence tracking
- Load and decode PCX files (palette-indexed, RLE-compressed)
- Load and decode TGA files (24/32-bit uncompressed and RLE-compressed)
- Load WAL mip-textured wall tiles directly into multi-level `pixels[]` arrays
- Find-or-load images by name, avoiding redundant disk I/O
- Free images not touched in the current registration sequence
- Expose a debug console command to list all active images

## External Dependencies
- `r_local.h` — pulls in `image_t`, `imagetype_t`, `miptex_t`, `pcx_t`, `registration_sequence`, `r_notexture_mip`, `ri` (refimport_t), and byte-swap macros
- `ri.FS_LoadFile` / `ri.FS_FreeFile` — VFS I/O, defined in engine
- `ri.Con_Printf`, `ri.Sys_Error` — engine console/error, defined elsewhere
- `Com_PageInMemory` — defined in `qcommon`
- `registration_sequence` — global defined in `r_main.c` or equivalent
- `r_notexture_mip` — fallback texture, defined in `r_misc.c` or similar

# ref_soft/r_light.c
## File Purpose
Implements lighting calculations for the software renderer, covering dynamic light marking on BSP surfaces, static lightmap sampling, and the construction of the final per-surface light map used during rasterization.

## Core Responsibilities
- Recursively mark BSP surfaces affected by each dynamic light each frame
- Sample the static lightmap at a world-space point (used for entity lighting)
- Accumulate dynamic light contributions onto `blocklights[]`
- Combine static lightmaps and dynamic lights into the `blocklights[]` buffer in 8.8 fixed-point format
- Support negative (darkening) dynamic lights via PGM extension

## External Dependencies
- `r_local.h` — all shared renderer types (`msurface_t`, `mnode_t`, `dlight_t`, `r_drawsurf`, `r_newrefdef`, `r_worldmodel`, `r_framecount`, `VID_CBITS`, `MAXLIGHTMAPS`)
- `currententity` — global entity pointer, defined in renderer core
- `r_fullbright`, `r_framecount` — defined elsewhere in the soft renderer

# ref_soft/r_local.h
## File Purpose
Central internal header for the Quake 2 software renderer (`ref_soft`). It aggregates all shared types, constants, global variable declarations, and function prototypes used across the software rasterization subsystem. Acts as the "glue" header that every `.c` file in `ref_soft` includes.

## Core Responsibilities
- Define image, video, and rendering state types used throughout the software renderer
- Declare all renderer-global variables (frame counters, edge lists, surface caches, view state)
- Declare the full public API surface for the software renderer (Draw_*, R_*, D_*, SWimp_*)
- Define rasterizer constants (viewport limits, clip planes, turb sizes, mip levels)
- Declare cvars controlling software renderer behavior (`sw_*`, `r_*`)
- Provide the driver/implementation boundary via `SWimp_*` function declarations

## External Dependencies
- `../client/ref.h` — `refdef_t`, `refimport_t`, `entity_t`, `cvar_t`
- `r_model.h` — `model_t`, `msurface_t`, `mvertex_t`, `mplane_t`, `mnode_t`, `mleaf_t`, `medge_t`, `mtexinfo_t`
- `qcommon/qfiles.h` (transitively) — `dtriangle_t`, `fixed16_t`, `fixed8_t`
- `asm_draw.h` — must stay in sync with `clipplane_t`, `edge_t`, `espan_t`, `oldrefdef_t` (noted inline)
- `d_ifacea.h` — must stay in sync with `finalvert_t`, `MAXHEIGHT`, `TURB_TEX_SIZE`, `CYCLE`

# ref_soft/r_main.c
## File Purpose
Central orchestration file for the Quake 2 software renderer (`ref_soft`). It owns the renderer's global state, implements the per-frame render pipeline, and exposes the `GetRefAPI` entry point that the engine uses to bind all renderer functions at runtime.

## Core Responsibilities
- Declare and initialize all global renderer state (view vectors, screen geometry, frame counters, cvars)
- Register/unregister cvars and console commands on init/shutdown
- Drive the full frame render sequence: setup → PVS marking → edge drawing → entity drawing → particles → palette
- Manage video mode changes and z-buffer/surface-cache lifecycle via `R_BeginFrame` / `R_InitGraphics`
- Build the `refexport_t` vtable returned to the engine via `GetRefAPI`
- Handle palette loading, gamma correction, and cinematic palette switching
- Cull and dispatch brush-model entities through the BSP edge system
- Draw alias/sprite/beam entities in two passes (opaque then translucent)

## External Dependencies

- **Includes:** `r_local.h` (pulls in all `ref_soft` internals and `qcommon.h` transitively)
- **Defined elsewhere:**
  - `SWimp_*` — platform SW imp layer (`win32/rw_imp.c`, `linux/rw_*.c`, etc.)
  - `R_SetupFrame`, `R_TransformFrustum`, `R_BeginEdgeFrame`, `R_ScanEdges`, `R_SurfacePatch` — `r_edge.c` / `r_misc.c`
  - `R_RenderWorld`, `R_DrawSolidClippedSubmodelPolygons`, `R_DrawSubmodelPolygons` — `r_bsp.c`
  - `R_AliasDrawModel` — `r_alias.c`; `R_DrawSprite` — `r_sprite.c`; `R_DrawParticles` — `r_part.c`
  - `R_DrawAlphaSurfaces` — `r_rast.c`/`r_surf.c`; `R_IMFlatShadedQuad` — `r_draw.c`
  - `D_WarpScreen`, `D_FlushCaches` — `r_warp.c` / `r_misc.c`
  - `Mod_*` — `r_model.c`; `R_*Images` — `r_image.c`; `Draw_*` — `r_draw.c`
  - `R_LightPoint`, `R_PushDlights` — `r_light.c`
  - `Mod_ClusterPVS` — `r_model.c`
  - `sintable`, `intsintable`, `blanktable` — `r_local.h` / `r_vars`
  - `view_clipplanes`, `insubmodel`, `r_dlightframecount`, `modelorg`, `currententity`, `r_entorigin` — `r_local.h` globals defined in driver/edge files

# ref_soft/r_misc.c
## File Purpose
Miscellaneous setup and utility routines for the software renderer. Handles per-frame view parameter computation, frustum setup, mip-map scaling, and PCX screenshot output. Acts as the orchestration layer that prepares render state before geometry submission begins each frame.

## Core Responsibilities
- Compute and cache view-dependent parameters (scales, centers, clip rect) into `r_refdef` each frame
- Build frustum clip planes from screen edge normals and transform them into view space
- Set up per-scanline lookup tables (`d_scantable`, `zspantable`) for the rasterizer
- Manage mip-map bias and scaling via cvars `sw_mipcap`/`sw_mipscale`
- Apply self-modifying x86 code patches for optimized surface/alias rendering paths
- Write PCX-format screenshots to disk

## External Dependencies
- `r_local.h` — all renderer types, globals, and macros
- `Sys_MakeCodeWriteable`, `Sys_Milliseconds`, `Sys_Mkdir` — platform HAL
- `D_FlushCaches`, `Draw_Fill` — surface cache and draw subsystems
- `Mod_PointInLeaf` — BSP model subsystem
- `AngleVectors`, `VectorNormalize`, `DotProduct`, `VectorCopy` — math library (defined elsewhere)
- `ri` (refimport_t) — engine callbacks: `Con_Printf`, `FS_Gamedir`
- `d_pzbuffer`, `sc_rover`, `r_warpbuffer`, `colormap` — defined in other ref_soft translation units

# ref_soft/r_model.c
## File Purpose
Implements model loading, caching, and registration for the software renderer. Handles all three Quake 2 model types (brush/BSP, alias/MD2, sprite) and provides PVS/vis decompression utilities used during rendering.

## Core Responsibilities
- Load and cache brush, alias, and sprite models from disk
- Decompress BSP lump sub-data (vertexes, planes, nodes, leafs, faces, etc.) into renderer-side structs
- Convert 24-bit RGB lightmap data to 8-bit for the software renderer
- Provide PVS cluster visibility queries (`Mod_ClusterPVS`)
- Register/unregister models each map load, freeing stale assets
- Build leaf-to-vis and vis-to-leaf index tables for software renderer's visibility system
- Initialize and tear down inline submodels from the world BSP

## External Dependencies
- **Includes:** `r_local.h` (pulls in all renderer types and `ri` import struct)
- **Defined elsewhere:** `r_worldmodel`, `r_oldviewcluster` (renderer globals), `R_FindImage`, `R_NewMap`, `R_InitSkyBox`, `D_FlushCaches`, `R_FreeUnusedImages`, `Hunk_Begin/End/Alloc/Free`, `Com_PageInMemory`, `ri.FS_LoadFile`, `ri.Sys_Error`, `ri.Cvar_Get`, `ri.Con_Printf`

# ref_soft/r_model.h
## File Purpose
Defines the in-memory model representation structures for the software renderer (`ref_soft`). It covers brush (BSP), sprite, and alias (MD2) model types, along with the public API for model loading, caching, and BSP spatial queries.

## Core Responsibilities
- Declare in-memory BSP geometry types (`mvertex_t`, `medge_t`, `mplane_t`, `mtexinfo_t`, `msurface_t`, `mnode_t`, `mleaf_t`)
- Define the unified `model_t` container for all model types
- Expose the model management API (`Mod_Init`, `Mod_ForName`, `Mod_Free`, etc.)
- Define surface flags controlling rendering behavior (sky, turbulent water, background, flow)
- Expose BSP traversal utilities (`Mod_PointInLeaf`, `Mod_ClusterPVS`)

## External Dependencies
- `qcommon/qfiles.h` — `dmodel_t`, `dvis_t`, `MIPLEVELS`, `MAXLIGHTMAPS`, `MAX_MD2SKINS`, `MAX_QPATH`
- `ref_soft/r_local.h` (or equivalent) — `image_t`, `vec3_t`, `byte`, `qboolean`
- Assembly constraint: comments note `mvertex_t` and `mplane_t` layout is mirrored in `asm_draw.h`/`asm_i386.h` — struct layout must not change without updating those files.
- All function bodies defined elsewhere (in `ref_soft/r_model.c`).

# ref_soft/r_part.c
## File Purpose
Implements software-renderer particle drawing for the Quake 2 ref_soft renderer. Each particle is projected into screen space, z-tested, alpha-blended, and rasterized as a screen-aligned square of variable pixel size. Provides both an x86 assembly fast path and a portable C reference implementation.

## Core Responsibilities
- Transform particle world-space origins into camera/screen space using view basis vectors
- Z-clip and screen-clip each particle before rasterization
- Select a blend function (33%, 66%, or 100% opaque) based on particle alpha
- Compute screen-space pixel size scaled by inverse-Z
- Z-buffer test and write per pixel (writes guarded by `ENABLE_ZWRITES_FOR_PARTICLES`)
- Write blended color values into the 8-bit framebuffer
- Iterate over the full particle list in `R_DrawParticles`

## External Dependencies
- `r_local.h` — renderer globals (`d_pzbuffer`, `d_viewbuffer`, `d_scantable`, `d_zwidth`, `xcenter`, `ycenter`, `r_newrefdef`, `r_origin`, `vright`, `vup`, `vpn`, `xscaleshrink`, `yscaleshrink`, `d_vrect*`, `d_pix_*`, `r_screenwidth`, `PARTICLE_Z_CLIP`)
- `vid.alphamap` — 256×256 precomputed alpha blend table (defined in platform vid layer)
- `fpu_sp24_cw`, `fpu_chop_cw` — FPU control words (defined elsewhere, x86 only)

# ref_soft/r_poly.c
## File Purpose
Implements software-renderer polygon rasterization for the Quake 2 soft renderer (`ref_soft`). Handles span-based scanline rendering with affine texture mapping, depth testing, alpha blending, stipple transparency, and turbulent water surface warping.

## Core Responsibilities
- Span-based affine texture mapping across polygon scanlines in 16.16 fixed-point
- Depth (z-buffer) testing per pixel via inverse-z (`izi`)
- Multiple blending modes: opaque, 33%/66% alpha blend, stipple, turbulent warp
- Frustum clipping of polygon faces against view planes (`R_ClipPolyFace`)
- Edge scanning (left/right) to generate span lists for rasterization
- Building polygon descriptors from BSP surface data (`R_BuildPolygonFromSurface`)
- Deferred alpha surface list rendering (`R_DrawAlphaSurfaces`)

## External Dependencies
- `r_local.h` — renderer globals (`d_sdivzstepu`, `cacheblock`, `cachewidth`, `d_viewbuffer`, `d_pzbuffer`, `xscale`, `ycenter`, etc.)
- `vid.alphamap` — 256×256 palette alpha blend lookup table (defined in vid system)
- `r_turb_turb`, `sintable` — turbulence sine table (defined in `r_warp.c` or similar)
- `D_CacheSurface` — surface lightmap cache (defined in `r_surf.c`)
- `TransformVector` — view-space transform (defined in `r_main.c`)
- `view_clipplanes` — frustum planes (defined in `r_main.c`)
- `sw_stipplealpha` — cvar controlling stipple vs. blend mode (defined elsewhere)
- `r_newrefdef`, `r_refdef`, `r_origin`, `currentmodel`, `r_worldmodel` — global renderer state

# ref_soft/r_polyse.c
## File Purpose
Implements the software rasterizer's polygon span-filling pipeline for Alias (MD2) model triangles. It handles edge scanning, gradient computation, and per-pixel span drawing including opaque, 33%/66% translucent, threshold (fizzle-fade), and flat-fill modes.

## Core Responsibilities
- Classify triangle vertex ordering and select the correct edge-traversal table (`R_PolysetSetEdgeTable`)
- Compute per-axis affine gradients (s, t, light, z-inverse) across the triangle face (`R_PolysetCalcGradients`)
- Walk the left edge scanline-by-scanline, emitting `spanpackage_t` descriptors (`R_PolysetScanLeftEdge_C`)
- Drive the right-edge scan and dispatch span packets to the active draw function (`R_RasterizeAliasPolySmooth`)
- Provide multiple span-draw backends: opaque, 33% alpha blend, 66% alpha blend, constant-color blends, threshold/fizzle-fade, and flat debug fill
- Maintain and update the skin row-pointer lookup table (`R_PolysetUpdateTables`)
- Support an IR-goggles rendering mode that remaps texels through `irtable[]`

## External Dependencies
- **Includes:** `r_local.h` (brings in `r_affinetridesc`, `d_viewbuffer`, `d_pzbuffer`, `vid`, `currententity`, `r_newrefdef`, etc.)
- **Included data:** `rand1k.h`, `adivtab.h` (table data)
- **Defined elsewhere:** `errorterm`, `erroradjustup`, `erroradjustdown`, `ubasestep` (Bresenham state, likely in `r_polysa.asm`/`d_polysa.s`); `R_PolysetScanLeftEdge` (ASM version); `d_zwidth`, `r_screenwidth`, `r_aliasblendcolor`, `fpu_sp24_ceil_cw`, `fpu_chop_cw`

# ref_soft/r_rast.c
## File Purpose
Implements the software rasterizer's edge emission and clipping pipeline for the Quake 2 software renderer. It transforms world/model edges into screen-space rasterization edges, clips them against view frustum planes, and posts visible surfaces to the span-generation system. Also manages the skybox geometry construction and emission.

## Core Responsibilities
- Clip 3D edges against the view frustum (left, right, top, bottom planes) via `R_ClipEdge`
- Project clipped vertices to screen space and emit rasterization edges via `R_EmitEdge`
- Cache edge results per-frame to avoid redundant clipping work
- Post surface descriptors (`surf_t`) with 1/z gradient coefficients for the span renderer
- Initialize and emit the skybox as 6 fake BSP faces appended to `loadmodel`
- Handle translucent surfaces by deferring them to `r_alpha_surfaces` instead of the edge renderer
- Provide separate entry points for world faces (`R_RenderFace`) and brush model faces (`R_RenderBmodelFace`)

## External Dependencies
- **Includes:** `r_local.h` (all shared renderer types, globals, macros), `<assert.h>`
- **Defined elsewhere:** `r_edges`, `edge_p`, `edge_max`, `newedges[]`, `removeedges[]`, `surface_p`, `surfaces`, `surf_max`, `r_framecount`, `r_currentkey`, `r_currentbkey`, `r_clipflags`, `r_alpha_surfaces`, `r_polycount`, `r_outofsurfaces`, `r_outofedges`, `insubmodel`, `currententity`, `currentmodel`, `r_pcurrentvertbase`, `modelorg`, `r_origin`, `r_refdef`, `xscale`, `yscale`, `xscaleinv`, `yscaleinv`, `xcenter`, `ycenter`, `loadmodel`, `TransformVector`, `R_RenderFace` (called from sky code above the `#if !id386` block, so the prototype is always available)

# ref_soft/r_scan.c
## File Purpose
Portable C implementation of scan-line rasterization for the software renderer. Handles perspective-correct texture mapping for turbulent (water/lava), standard, and depth (Z) spans at 8-bit color depth.

## Core Responsibilities
- Apply full-screen sine-wave warp effect (`D_WarpScreen`)
- Render turbulent surface spans with animated UV distortion (`Turbulent8`)
- Render non-turbulent scrolling water-type surfaces without distortion (`NonTurbulent8`)
- Render standard textured spans with perspective correction in 8-pixel sub-spans (`D_DrawSpans16`)
- Write inverse-Z values into the Z-buffer for depth testing (`D_DrawZSpans`)
- Expose file-static state used by the optional x86 ASM override of `D_DrawTurbulent8Span`

## External Dependencies
- `r_local.h` — includes all shared renderer state
- `d_viewbuffer`, `d_pzbuffer`, `d_zwidth`, `r_screenwidth`, `cacheblock`, `cachewidth` — defined in renderer globals
- `d_sdivzstepu/v`, `d_tdivzstepu/v`, `d_zistepu/v`, origins, `sadjust/tadjust`, `bbextents/bbextentt` — perspective-correct rasterization parameters, defined elsewhere
- `sintable`, `intsintable`, `blanktable` — precomputed sine/zero tables, defined elsewhere
- `r_warpbuffer` — pre-rendered warp source buffer, defined elsewhere
- `vid.buffer`, `vid.rowbytes` — video output surface, defined in platform layer
- `r_newrefdef`, `r_refdef` — current frame view parameters, defined elsewhere

# ref_soft/r_sprite.c
## File Purpose
Renders a single sprite entity in the software renderer by constructing a view-aligned quadrilateral polygon in world space and submitting it to the polygon clipping/drawing pipeline. Sprites are always billboarded — fully parallel to the view plane.

## Core Responsibilities
- Validate and wrap the current entity's frame index against sprite frame count
- Fetch sprite frame metadata (dimensions, origin offsets) from model extradata
- Build four world-space vertices forming a billboard quad, UV-mapped to the sprite frame
- Configure the shared `r_polydesc` descriptor with texture data, axes, and offsets
- Dispatch to `R_ClipAndDrawPoly` with appropriate alpha for translucent or opaque sprites

## External Dependencies
- **Includes:** `r_local.h` (pulls in all soft-renderer types and globals)
- **Defined elsewhere:**
  - `r_polydesc` — defined in `r_poly.c` or `r_local`
  - `r_clip_verts` — defined in `r_poly.c` or clipping module
  - `R_ClipAndDrawPoly` — polygon clip + rasterize dispatch
  - `currententity`, `currentmodel`, `r_entorigin`, `vup`, `vright`, `vpn`, `modelorg` — renderer globals

# ref_soft/r_surf.c
## File Purpose
Implements software-renderer surface caching and rasterization for the Quake 2 soft reference renderer. It manages a linear surface cache (surfcache), resolves animated textures, applies bilinear lightmap blending per mip level, and writes lit 8-bit paletted pixels into cache blocks.

## Core Responsibilities
- Resolving animated texture frames via `R_TextureAnimation`
- Dispatching per-mip-level surface block rasterizers (`R_DrawSurfaceBlock8_mip0–3`)
- Blending lightmap values across 16×16 (mip0) down to 2×2 (mip3) texel blocks
- Managing a linear bump-pointer surface cache (`D_SCAlloc`, `D_FlushCaches`, `R_InitCaches`)
- Cache validity checking (dlight, lightadj, animated texture changes) in `D_CacheSurface`
- Detecting surface cache thrashing via `r_cache_thrash`

## External Dependencies
- `r_local.h` — pulls in all soft renderer types and globals
- `vid.colormap` — 8-bit palette lighting table (256 grades × 256 colors)
- `blocklights[1024]` — filled by `R_BuildLightMap` (defined in `r_light.c`)
- `d_roverwrapped`, `d_initial_rover` — cache thrash tracking (defined in `r_misc.c` or `r_main.c`)
- `currententity` — used by `R_TextureAnimation` (global set by caller)
- `r_framecount`, `r_newrefdef` — frame counter and ref def (defined in `r_main.c`)
- `c_surf` — debug surface count (defined elsewhere)
- `sw_surfcacheoverride` — cvar (registered elsewhere)
- `ri.Con_Printf`, `ri.Sys_Error` — renderer import table

# ref_soft/rand1k.h
## File Purpose
A raw data header containing 1,024 pre-generated random byte values in the range 0–255. It is intended to be `#include`-d directly into an array initializer within the software renderer, providing a fixed-seed lookup table for pseudo-random effects.

## Core Responsibilities
- Supply a statically embedded table of 1,024 random bytes (range 0–255) for use by the software renderer.
- Eliminate runtime random number generation overhead by providing a precomputed lookup table.
- Enable deterministic, repeatable pseudo-random access patterns for visual effects (e.g., particle noise, dithering, surface variation).

## External Dependencies
- No `#include` directives.
- No external symbols.
- Depends entirely on the including file to provide the surrounding array declaration and type context.

# server/server.h
## File Purpose
Central header for the Quake 2 server subsystem. Defines all server-side data structures, global state declarations, and cross-module function prototypes used by the server's constituent `.c` files.

## Core Responsibilities
- Define server and client lifecycle state enumerations
- Declare the two primary server state containers (`server_t` and `server_static_t`)
- Declare per-client tracking structures (`client_t`, `client_frame_t`)
- Declare challenge/connection security structures
- Export function prototypes for all server subsystem modules
- Declare shared server globals (cvars, pointers, network state)

## External Dependencies
- `../qcommon/qcommon.h` — core types (`vec3_t`, `sizebuf_t`, `netchan_t`, `netadr_t`, `cvar_t`, `trace_t`, etc.)
- `../game/game.h` — `edict_t`, `player_state_t`, `usercmd_t`, `game_export_t`
- `sv_main.c`, `sv_init.c`, `sv_send.c`, `sv_user.c`, `sv_ents.c`, `sv_game.c`, `sv_ccmds.c`, `sv_world.c` — all implement prototypes declared here

# server/sv_ccmds.c
## File Purpose
Implements operator-only console commands for the Quake 2 server, including map control, savegame management, server demo recording, and client administration. Commands are accessible only from stdin or a remote operator datagram.

## Core Responsibilities
- Register all operator console commands via `SV_InitOperatorCommands`
- Manage savegame lifecycle: write, read, copy, and wipe save slots
- Handle map transitions with proper state serialization (`gamemap`, `map`, `demomap`)
- Administer clients: kick, status display, userinfo dump
- Control master server registration and heartbeat forcing
- Start/stop server-side demo recording
- Forward unknown commands to the game DLL via `ge->ServerCommand()`

## External Dependencies
- **Includes**: `server.h` (pulls in all server types, `sv`, `svs`, `ge`, `sv_client`, `sv_player`, `master_adr`)
- **Defined elsewhere**: `SV_Map`, `SV_InitGame`, `SV_Shutdown`, `SV_DropClient`, `SV_BroadcastPrintf`, `SV_ClientPrintf`, `CM_WritePortalState`, `CM_ReadPortalState`, `NET_StringToAdr`, `NET_AdrToString`, `NET_Config`, `Netchan_OutOfBandPrint`, `FS_Gamedir`, `FS_CreatePath`, `FS_LoadFile`, `FS_Read`, `Cvar_Set`, `Cvar_ForceSet`, `Cvar_VariableValue`, `Cvar_VariableString`, `Cvar_Serverinfo`, `cvar_vars`, `Cmd_AddCommand`, `Cmd_Argc`, `Cmd_Argv`, `Cmd_Args`, `Info_Print`, `SZ_Init`, `MSG_Write*`, `Sys_FindFirst`, `Sys_FindNext`, `Sys_FindClose`, `ge->WriteLevel/ReadLevel/WriteGame/ReadGame/ServerCommand`

# server/sv_ents.c
## File Purpose
Encodes the server-side game world state into network messages for delivery to clients. Handles per-frame delta compression of entity states and player states, per-client visibility culling, and demo file recording.

## Core Responsibilities
- Build per-client visibility frames using PVS/PHS culling (`SV_BuildClientFrame`)
- Delta-encode the entity list into packet entity messages (`SV_EmitPacketEntities`)
- Delta-encode player state into `svc_playerinfo` messages (`SV_WritePlayerstateToClient`)
- Assemble and write complete frame messages to clients (`SV_WriteFrameToClient`)
- Compute a "fat PVS" covering the client's interpolation range (`SV_FatPVS`)
- Record demo messages with full (non-delta) entity snapshots
- (Disabled) Experimental compact projectile network protocol via `#if 0` blocks

## External Dependencies
- **Includes:** `server.h` (pulls in `qcommon.h`, entity/client types, map collision API)
- **Defined elsewhere:** `svs`, `sv`, `ge`, `maxclients` (server globals); `MSG_WriteDeltaEntity`, `MSG_Write*` (net message encoding); `CM_*` (collision model / BSP visibility); `EDICT_NUM` (game entity accessor); `SZ_*` (size-buffer utilities)

# server/sv_game.c
## File Purpose
This file implements the server-side interface (game import table) between the Quake 2 engine and the game DLL. It bridges engine services to the game module by populating a `game_import_t` struct with function pointers, and manages loading/unloading of the game DLL.

## Core Responsibilities
- Populate the `game_import_t` function pointer table passed to the game DLL at init time
- Provide `PF_*` (print/format) callbacks for game-to-engine communication
- Wrap multicast buffer write operations for game use
- Expose PVS/PHS visibility queries to game logic
- Manage game DLL lifecycle (load via `SV_InitGameProgs`, unload via `SV_ShutdownGameProgs`)

## External Dependencies
- `server.h` — pulls in `svs`, `sv`, `client_t`, `edict_t`, server message APIs
- `CM_*` — collision model / BSP area functions (defined in `qcommon/cmodel.c`)
- `SV_Multicast`, `SV_LinkEdict`, `SV_UnlinkEdict`, `SV_Trace`, `SV_StartSound`, `SV_ClientPrintf` — defined in other `server/sv_*.c` files
- `Sys_GetGameAPI`, `Sys_UnloadGame` — platform-specific DLL loader (defined in platform layer)
- `Z_TagMalloc`, `Z_Free`, `Z_FreeTags` — zone memory allocator (defined in `qcommon`)
- `SCR_DebugGraph` — declared extern here, defined in client rendering code

# server/sv_init.c
## File Purpose
Handles server initialization, map loading, and level transitions for the Quake 2 server. It manages the per-level `sv` structure and the persistent `svs` structure, orchestrating the full lifecycle of spawning a new server instance.

## Core Responsibilities
- Maintain and initialize the global `sv` (per-level) and `svs` (persistent) server state structures
- Register and look up model, sound, and image indices in the configstring table
- Load BSP maps, inline models, and spawn game entities via the game DLL interface
- Create entity baselines for delta-compressed client updates
- Handle savegame detection and level-return logic
- Parse and dispatch `map` command strings (cinematics, demos, PCX screens, BSP levels)
- Bootstrap a full game session including client slot allocation and network configuration

## External Dependencies
- `server.h` — all shared server types and declarations
- `ge` — game export interface (`ge->SpawnEntities`, `ge->RunFrame`, `ge->num_edicts`); defined in `sv_game.c`
- `CM_*` — collision model subsystem (`qcommon/cmodel.c`)
- `SV_ClearWorld`, `SV_ReadLevelFile` — defined in `sv_world.c` / `sv_game.c`
- `SV_InitGameProgs`, `SV_Shutdown` — defined in `sv_game.c` / `sv_main.c`
- `NET_Config`, `NET_StringToAdr` — network layer (`qcommon/net_chan.c` / platform net)
- `Z_Malloc`, `Cvar_*`, `Com_*`, `MSG_*`, `SZ_*` — qcommon utilities

# server/sv_main.c
## File Purpose
The central server management file for Quake 2, handling the per-frame server loop, client connection lifecycle, connectionless packet dispatch, master server communication, and server initialization/shutdown.

## Core Responsibilities
- Drive the main server frame loop (`SV_Frame`): timeouts, packet reads, game logic, client messaging
- Dispatch connectionless UDP packets (ping, status, info, challenge, connect, rcon)
- Manage client connection handshake via challenge/response to mitigate DoS floods
- Track and drop timed-out or disconnected clients
- Send heartbeats to and notify master servers on shutdown
- Initialize all server-side cvars on engine startup
- Execute orderly server shutdown with final message broadcast

## External Dependencies
- `server.h` — `sv`, `svs`, `client_t`, `ge`, state enums, `SV_*` prototypes
- `ge->ClientConnect`, `ge->ClientDisconnect`, `ge->ClientUserinfoChanged`, `ge->RunFrame` — game DLL interface (defined in game module)
- `Netchan_*`, `NET_*`, `MSG_*`, `SZ_*` — network/message layer (defined in `qcommon/`)
- `Cvar_Get`, `Cmd_*`, `Info_*`, `Com_*` — engine common layer
- `SV_SendClientMessages`, `SV_RecordDemoMessage`, `SV_ShutdownGameProgs`, `SV_ExecuteClientMessage` — defined in other `server/sv_*.c` files
- `host_speeds`, `dedicated`, `curtime`, `net_from`, `net_message` — globals defined elsewhere in engine

# server/sv_null.c
## File Purpose
Provides a null/stub implementation of the server subsystem for pure client-only builds. All server functions are no-ops, allowing the engine to compile and link without a real server.

## Core Responsibilities
- Satisfies the server API link requirements for client-only configurations
- Prevents the server subsystem from executing any logic or allocating any resources
- Acts as a compile-time switch to exclude the full server module

## External Dependencies
- No includes required — relies solely on built-in C types and `qboolean` being resolved at compile time (or not referenced here since it appears only as a parameter type in a stub).
- `SV_Init`, `SV_Shutdown`, `SV_Frame` — defined here as stubs; real implementations reside in `server/sv_init.c` and `server/sv_main.c`.

# server/sv_send.c
## File Purpose
Handles all outbound message transmission from the server to clients, including print messages, sound events, multicast spatial broadcasts, and per-frame client datagram assembly and rate-controlled delivery.

## Core Responsibilities
- Redirect `Com_Printf` output to packets or client message buffers
- Send targeted print messages to individual clients or all spawned clients
- Serialize and spatially filter sound events via PVS/PHS multicast
- Assemble and transmit per-frame datagrams to each spawned client
- Enforce per-client bandwidth rate limiting
- Drive demo playback by reading and forwarding recorded demo frames

## External Dependencies
- **Notable includes:** `server.h` (pulls in `qcommon.h`, `game.h`, client/server structs)
- **Defined elsewhere:** `sv_client` (current client context, `sv_main.c`), `net_from` (last received packet address, `net_chan.c`), `svs`/`sv` (server state globals), `maxclients`/`sv_paused`/`dedicated` (cvars), `CM_*` (collision model, `cmodel.c`), `SV_BuildClientFrame`/`SV_WriteFrameToClient` (`sv_ents.c`), `SV_DropClient`/`SV_Nextserver` (`sv_main.c`), `Netchan_*` (`net_chan.c`), `MSG_*`/`SZ_*` (`qcommon`)

# server/sv_user.c
## File Purpose
Handles server-side processing of messages received from connected clients, including the connection handshake sequence (new/configstrings/baselines/begin), file downloads, and per-frame user command (movement) execution.

## Core Responsibilities
- Drive the client connection state machine (cs_connected → cs_spawned) via `new`/`configstrings`/`baselines`/`begin` command sequence
- Stream configstrings and entity baselines to connecting clients in chunked packets
- Serve file download requests with access control and offset resumption
- Parse and dispatch incoming client network messages (move commands, string commands, userinfo updates)
- Replay dropped packets by re-submitting cached movement commands
- Route string commands to built-in handlers or the game DLL's `ClientCommand`
- Advance cinematic/demo/pic servers to the next server in sequence

## External Dependencies
- **Includes:** `server.h` (pulls in `sv_client`, `svs`, `sv`, `ge`, message/netchan types)
- **Defined elsewhere:** `sv_client` (`server.h`/`sv_main.c`), `net_message` (global read buffer), `ge` (game export interface), `svs`/`sv` (server state), `MSG_*`/`SZ_Write`/`COM_BlockSequenceCRCByte` (qcommon), `FS_LoadFile`/`FS_FreeFile`/`FS_FOpenFile` (files.c), `Cvar_*`/`Cbuf_*`/`Cmd_*` (qcommon), `allow_download*` cvars (sv_main.c), `file_from_pak` (files.c)

# server/sv_world.c
## File Purpose
Implements server-side world spatial query functions, including entity area management via a binary space partition tree, entity linking/unlinking, point-content tests, and swept-volume trace (collision) queries against both world geometry and entities.

## Core Responsibilities
- Build and maintain a 2D axis-aligned BSP area tree for fast entity spatial lookup
- Link/unlink entities into the area tree when they move or change state
- Encode entity bounding box dimensions into `entity_state.solid` for client prediction
- Track which BSP PVS clusters and areas each entity occupies
- Enumerate candidate entities within an AABB region (`SV_AreaEdicts`)
- Perform swept-volume collision traces (`SV_Trace`) against world and entities
- Compute point contents merging world BSP and entity hulls

## External Dependencies
- **Includes:** `server.h` (pulls in `qcommon.h`, `game.h`, entity/server types)
- **Defined elsewhere:** `CM_BoxLeafnums`, `CM_LeafCluster`, `CM_LeafArea`, `CM_PointContents`, `CM_TransformedPointContents`, `CM_BoxTrace`, `CM_TransformedBoxTrace`, `CM_HeadnodeForBox` (collision model, `qcommon/cmodel.c`); `ge->edicts` (game export struct); `sv.models[]`, `sv.state` (server state globals); `Com_DPrintf`, `Com_Printf`, `Com_Error`; `vec3_origin`; `link_t` list primitives.

# solaris/g_so.c
## File Purpose
A stub or placeholder file for the Solaris platform port of Quake 2. It contains only an empty `main` entry point with no implementation, suggesting it was either a scaffold, dead code, or a build artifact.

## Core Responsibilities
- Serves as a minimal compilation unit for the Solaris platform build
- Provides an empty `main` function (likely unused in the actual shared library build)

## External Dependencies
- No includes present.
- No external symbols referenced.

# solaris/glob.c
## File Purpose
Implements Unix-style filename glob pattern matching for the Solaris platform port. Provides `glob_match` and supporting utilities to test whether a string matches a wildcard pattern containing `*`, `?`, and `[SET]` constructs.

## Core Responsibilities
- Match a full string against a glob pattern (`glob_match`)
- Handle wildcard `*` by recursively matching any suffix (`glob_match_after_star`)
- Detect whether a pattern contains any special glob characters (`glob_pattern_p`)
- Support character sets `[SET]` and negated sets `[!SET]` / `[^SET]`
- Support escape sequences via `\` to match literal special characters

## External Dependencies
- `<stdio.h>` — included but no stdio functions are used; likely a vestigial include.
- `../linux/glob.h` — provides the declaration for `glob_match` (shared header between Linux and Solaris ports); `glob_pattern_p` and `glob_match_after_star` are file-static and not declared there.

# solaris/glob.h
## File Purpose
Single-function header declaring a glob-style pattern matching utility for the Solaris platform port. It exposes one function used to match filenames or strings against wildcard patterns.

## Core Responsibilities
- Declares the `glob_match` interface for use by Solaris-specific or shared code that needs wildcard filename/string matching.

## External Dependencies
- No includes.
- `glob_match` implementation defined in `solaris/glob.c`.

# solaris/net_udp.c
## File Purpose
Solaris platform implementation of Quake 2's UDP network layer. Provides socket creation, packet send/receive, address conversion, and loopback buffer management for single-player and multiplayer network communication.

## Core Responsibilities
- Convert between engine `netadr_t` addresses and POSIX `sockaddr_in` structures
- Send and receive UDP packets over IP (and stub IPX) sockets
- Manage in-process loopback ring buffers for local client/server communication
- Open, configure, and shut down IP sockets based on singleplayer/multiplayer mode
- Resolve hostname strings to network addresses
- Sleep the dedicated server until a socket is ready or timeout expires

## External Dependencies
- `../qcommon/qcommon.h` — `netadr_t`, `netsrc_t`, `sizebuf_t`, `Com_Printf`, `Com_Error`, `Com_sprintf`, `Cvar_Get`, `PORT_SERVER`, `PORT_ANY`, `MAX_MSGLEN`
- POSIX: `<sys/socket.h>`, `<netinet/in.h>`, `<netdb.h>`, `<sys/ioctl.h>`, `<sys/filio.h>`, `<errno.h>`
- `dedicated` cvar and `stdin_active` — defined elsewhere in the engine
- `NET_ErrorString` wraps `strerror(errno)` — defined in this file
- `stricmp` — not standard POSIX; assumed provided by platform headers or `qcommon.h`

# solaris/q_shsolaris.c
## File Purpose
Solaris platform-specific implementation of shared system services for the Quake 2 engine. Provides hunk memory management, high-resolution timing, directory creation, and filesystem directory enumeration using POSIX APIs.

## Core Responsibilities
- Implement the hunk allocator (begin/alloc/end/free) using `malloc`/`realloc`
- Provide `Sys_Milliseconds` for high-resolution wall-clock timing
- Implement `Sys_Mkdir` for directory creation
- Implement `Sys_FindFirst` / `Sys_FindNext` / `Sys_FindClose` for glob-based filesystem iteration
- Provide `strlwr` string utility (lowercase in-place)

## External Dependencies
- `../linux/glob.h` — `glob_match` for pattern matching (reused from Linux port)
- `../qcommon/qcommon.h` — `Sys_Error`, `MAX_OSPATH`, `SFF_SUBDIR`, `byte`, `qboolean`
- POSIX: `gettimeofday`, `opendir`/`readdir`/`closedir`, `stat`, `malloc`/`realloc`/`free`, `mkdir`
- `Sys_Error` — defined in `solaris/sys_solaris.c` (not in this file)

# solaris/sys_solaris.c
## File Purpose
Platform-specific system layer for Quake 2 running on Solaris (and i386 Linux via shared code patterns). Implements OS-level services including process lifecycle, console I/O, timing, and dynamic game library loading via `dlopen`.

## Core Responsibilities
- Initialize and shut down the engine process (`main`, `Sys_Quit`, `Sys_Error`)
- Drive the main game loop, throttling frames to a minimum of 1ms
- Provide console input/output for dedicated server mode
- Load and unload the game DLL (`gamei386.so` or `gamesparc.so`) at runtime
- Report file modification timestamps via `Sys_FileTime`
- Strip high-bit characters from console output for terminal safety

## External Dependencies
- `../qcommon/qcommon.h` — `Qcommon_Init`, `Qcommon_Frame`, `Qcommon_Shutdown`, `Com_Error`, `Com_Printf`, `FS_NextPath`, `Sys_Milliseconds`, `cvar_t`, `dedicated`
- `CL_Shutdown` — defined in client layer (linked externally)
- `dlfcn.h` — `dlopen`, `dlsym`, `dlclose`, `dlerror` for runtime game module loading
- `Sys_Milliseconds` — defined elsewhere (likely in a shared platform timing file)

# win32/cd_win.c
## File Purpose
Windows-specific CD audio subsystem implementation using the Win32 MCI (Media Control Interface) API. Provides playback control for audio CD tracks as background music in Quake 2, with support for looping, remapping, pause/resume, and window focus handling.

## Core Responsibilities
- Initialize and shut down the MCI CD audio device
- Play, stop, pause, and resume CD audio tracks
- Handle track remapping (logical-to-physical track translation)
- Process MCI notification messages for looping logic
- Respond to window focus changes (activate/deactivate)
- Expose a `cd` console command for manual control
- Sync enabled state with the `cd_nocd` cvar each frame

## External Dependencies
- `<windows.h>` — MCI API, Win32 types
- `../client/client.h` — `qboolean`, `byte`, `cvar_t`, `Com_Printf`, `Com_DPrintf`, `Cvar_Get`, `Cvar_VariableValue`, `Cmd_AddCommand`, `Cmd_Argc`, `Cmd_Argv`, `Q_strcasecmp`
- `cl_hwnd` — defined in `win32/sys_win.c` or `win32/vid_dll.c`; the main application window handle used as MCI callback target

# win32/conproc.c
## File Purpose
Implements a Windows-specific inter-process communication (IPC) bridge between the Quake 2 engine and an external host utility called "QHOST." It exposes console read/write and screen buffer control commands to QHOST via a shared memory buffer and Win32 event signaling.

## Core Responsibilities
- Parse command-line arguments for QHOST-provided Win32 handles (`-HFILE`, `-HPARENT`, `-HCHILD`)
- Map/unmap a shared memory buffer for IPC command exchange
- Spawn a background thread (`RequestProc`) to service QHOST requests
- Dispatch QHOST commands: write text to stdin, read text from screen buffer, get/set screen buffer line count
- Manage console window dimensions (forced to 80 columns minimum)
- Signal shutdown via a "done" event

## External Dependencies
- `<windows.h>` — all Win32 console, event, thread, and memory-mapping APIs
- `<process.h>` — `_beginthreadex`, `_endthreadex`
- `conproc.h` — declarations for `InitConProc`, `DeinitConProc` (defined elsewhere, used by `sys_win.c`)
- `QHOST` — external process providing the three IPC handles via command-line; not defined in this codebase

# win32/conproc.h
## File Purpose
Header for the Windows console process support module (`conproc.c`), which enables communication between the Quake 2 dedicated server and an external host process (`qhost`). Exposes only the two lifecycle entry points for this subsystem.

## Core Responsibilities
- Declare the init/shutdown interface for the console process (`qhost`) IPC subsystem
- Allow `conproc.c` to be included by the Windows system layer (`sys_win.c`)

## External Dependencies
- No includes in this header.
- Both symbols are defined in `win32/conproc.c`.
- Consumed by `win32/sys_win.c` (the Win32 system entry point).

# win32/glw_imp.c
## File Purpose
Implements all Win32-specific OpenGL platform layer (GLimp) functions for the Quake 2 GL renderer. It manages the Win32 window lifecycle, pixel format selection, WGL context creation, display mode switching, and per-frame buffer management.

## Core Responsibilities
- Register and create the Win32 window (`WNDCLASS` / `CreateWindowEx`)
- Configure and set the OpenGL pixel format descriptor (PFD)
- Create and activate the WGL rendering context
- Handle fullscreen mode via `ChangeDisplaySettings` (CDS), including dual-monitor fallback
- Provide per-frame begin/end hooks (stereo buffer selection, buffer swap)
- Shut down the GL context, DC, window, and display mode cleanly
- Detect OS version to gate display depth change capability

## External Dependencies
- `../ref_gl/gl_local.h` — `gl_state`, `gl_bitdepth`, `gl_drawbuffer`, `gl_driver`, `gl_allow_software`, `ri` (refimport), `rserr_t`, `qgl*` wrappers
- `glw_win.h` — `glwstate_t` definition, `WINDOW_STYLE`
- `winquake.h` — Win32 Quake environment definitions
- `qwglCreateContext`, `qwglMakeCurrent`, `qwglSwapBuffers`, etc. — defined in `win32/qgl_win.c` (WGL function pointers)
- `ri.Vid_GetModeInfo`, `ri.Vid_NewWindow`, `ri.Sys_Error`, `ri.Con_Printf`, `ri.Cvar_Get`, `ri.Cvar_SetValue` — engine import table, defined elsewhere

# win32/glw_win.h
## File Purpose
Declares the Win32-specific OpenGL window state structure (`glwstate_t`) and its single global instance. It acts as the shared interface between the Win32 GL window implementation (`glw_imp.c`) and the GL renderer.

## Core Responsibilities
- Defines the `glwstate_t` struct holding all Win32 OpenGL window handles
- Exposes the global `glw_state` instance to other translation units
- Guards against inclusion on non-Win32 platforms via a compile-time `#error`

## External Dependencies
- `<windows.h>` (implicit) — provides `HINSTANCE`, `HDC`, `HWND`, `HGLRC`, `FILE`
- `qboolean` — defined in `qcommon/qcommon.h` or `game/q_shared.h`
- `glw_imp.c` — defines `glw_state`; not visible from this header

### Notes on `glwstate_t` fields
- `wndproc` is typed as `void *` rather than `WNDPROC` to avoid a forward-declaration dependency on the window procedure signature
- `minidriver`, `allowdisplaydepthchange`, `mcd_accelerated` are boolean flags controlling GL driver selection and display mode behavior
- `log_fp` suggests optional GL call logging to a file, consistent with the `QGL_*` wrapper layer present in `ref_gl/`

# win32/in_win.c
## File Purpose
Windows 95/Win32 platform input backend handling mouse and joystick input for Quake 2. It translates raw Win32/WinMM hardware input into engine movement commands and key events each frame.

## Core Responsibilities
- Initialize and shut down mouse and joystick hardware on Windows
- Activate/deactivate mouse capture and cursor clipping based on window focus
- Convert mouse delta into view angle changes and movement commands
- Poll joystick state via WinMM (`joyGetPosEx`) and map axes to movement
- Fire `Key_Event` calls for mouse buttons, joystick buttons, and POV hat changes
- Expose `IN_Init`/`IN_Shutdown`/`IN_Frame`/`IN_Move`/`IN_Commands` as the platform input interface

## External Dependencies
- `../client/client.h` — `cl`, `cls`, `usercmd_t`, `Key_Event`, `IN_CenterView`, cvars (`sensitivity`, `m_pitch`, `m_yaw`, etc.)
- `winquake.h` — `cl_hwnd`, `ActiveApp`, Windows headers
- `sys_msg_time` — extern `unsigned`, defined in `win32/sys_win.c`
- WinMM (`joyGetNumDevs`, `joyGetPosEx`, `joyGetDevCaps`) — Windows multimedia joystick API

# win32/net_wins.c
## File Purpose
Windows-specific network layer implementation for Quake 2, providing UDP/IP and IPX socket management, loopback packet buffering for singleplayer, and address translation between engine-internal `netadr_t` and WinSock `sockaddr` types.

## Core Responsibilities
- Initialize and shut down WinSock (WSA lifecycle management)
- Create, bind, and close UDP and IPX sockets for client and server roles
- Send and receive network packets over IP and IPX protocols
- Manage loopback ring buffers for local (singleplayer) communication
- Convert between engine `netadr_t` addresses and OS `sockaddr`/`sockaddr_ipx` structures
- Resolve hostnames and parse address strings (dotted-decimal, IPX hex, hostname)
- Sleep the dedicated server thread until a socket is readable

## External Dependencies
- **Includes:** `<winsock.h>`, `<wsipx.h>`, `../qcommon/qcommon.h`
- **Defined elsewhere:** `netadr_t`, `netsrc_t`, `sizebuf_t`, `NS_CLIENT`, `NS_SERVER`, `PORT_ANY`, `PORT_SERVER`, `PORT_CLIENT`, `MAX_MSGLEN`, `dedicated` (cvar), `Cvar_Get`, `Cvar_VariableValue`, `Com_Printf`, `Com_DPrintf`, `Com_Error`, `Com_sprintf`, `va`

# win32/q_shwin.c
## File Purpose
Windows-specific platform abstraction layer providing hunk memory management, high-resolution timing, directory creation, and filesystem enumeration. It implements the Win32 side of the `Sys_*` and `Hunk_*` interfaces declared in `qcommon.h`.

## Core Responsibilities
- Implement a virtual-memory-backed hunk allocator using `VirtualAlloc`/`VirtualFree`
- Provide `Sys_Milliseconds` for engine timing via `timeGetTime`
- Wrap `_mkdir` for cross-platform directory creation
- Implement `Sys_FindFirst`/`Sys_FindNext`/`Sys_FindClose` for file glob enumeration
- Filter filesystem entries by attribute bitmasks (musthave/canthave)

## External Dependencies
- `../qcommon/qcommon.h` — `Sys_Error`, `COM_FilePath`, `Com_sprintf`, `MAX_OSPATH`, `SFF_*` flags
- `winquake.h` — Win32 types, `timeGetTime`
- Win32 API: `VirtualAlloc`, `VirtualFree`, `FormatMessage`, `GetLastError`, `timeGetTime`
- CRT: `_mkdir`, `_findfirst`, `_findnext`, `_findclose`, `_finddata_t`

# win32/qgl_win.c
## File Purpose
Windows-specific implementation of the QGL abstraction layer that binds all OpenGL and WGL function pointers by dynamically loading `opengl32.dll` at runtime. It also provides an optional logging/tracing layer that can intercept every GL call and record it to a file for debugging.

## Core Responsibilities
- Declare global `qgl*` function pointer variables used by all GL rendering code
- Load `opengl32.dll` via `LoadLibrary` and resolve every GL/WGL symbol via `GetProcAddress`
- NULL out all function pointers on shutdown and free the library handle
- Maintain a parallel set of `dll*` direct-dispatch pointers alongside `log*` interceptor wrappers
- Route all `qgl*` calls through logging wrappers when logging is enabled, writing call names/args to a file
- Set 3Dfx gamma environment variables unconditionally during `QGL_Init`
- Zero-initialize optional extension pointers (`EXT`, `SGIS`) that are bound later

## External Dependencies
- `../ref_gl/gl_local.h` — provides `glw_state` (contains `hinstOpenGL`, `log_fp`), `gl_config`, `ri`, `qboolean`
- `glw_win.h` — Windows GL window state types
- `<float.h>` — included but not visibly used
- `glw_state` — defined in `win32/glw_imp.c`
- `ri` (refimport_t) — defined in `ref_gl/gl_rmain.c`
- `gl_config` — defined in `ref_gl/gl_rmain.c`
- `Com_sprintf` — defined in `qcommon/common.c`

# win32/resource.h
## File Purpose
Auto-generated Windows resource header produced by Microsoft Developer Studio (MSVC IDE). It defines resource IDs used by the Win32 resource script `q2.rc` and tracks next-available ID counters for the IDE's resource editor.

## Core Responsibilities
- Defines the numeric ID (`IDI_ICON1`) for the application icon resource
- Provides APSTUDIO counter macros so the MSVC resource editor can assign non-conflicting IDs to new resources

## External Dependencies
- Included by: `win32/q2.rc`
- No external symbols; entirely self-contained preprocessor definitions

---

**Notes:**
- `IDI_ICON1 = 101` — the application icon, loaded via `LoadIcon()` in the Win32 startup path (likely `win32/sys_win.c` or `win32/vid_dll.c`)
- The `_APS_*` macros are IDE bookkeeping only and have no runtime effect
- The `//{{NO_DEPENDENCIES}}` sentinel is an MSVC resource editor annotation, not a functional directive

# win32/rw_ddraw.c
## File Purpose
Manages DirectDraw initialization, palette management, and shutdown for the Win32 software renderer. It sets up the 8-bit palettized DirectDraw surfaces (front, back, offscreen) used by `ref_soft` to present frames to the display.

## Core Responsibilities
- Dynamically loads `ddraw.dll` and resolves `DirectDrawCreate` at runtime
- Creates the DirectDraw object and sets exclusive fullscreen cooperative level
- Attempts linear display mode first, falls back to ModeX 320x240 if allowed
- Allocates and connects front buffer, back buffer, and offscreen rendering buffer
- Creates and attaches an 8-bit `DIRECTDRAWPALETTE` initialized from `d_8to24table`
- Locks the offscreen buffer and returns its pointer/pitch to the caller
- Provides palette update and orderly teardown

## External Dependencies
- `../ref_soft/r_local.h` — `vid`, `sw_state`, `sw_mode`, `d_8to24table`
- `rw_win.h` — `sww_state` (Win32 software renderer window state including all DirectDraw COM pointers)
- `ddraw.dll` — loaded dynamically; `DirectDrawCreate` resolved via `GetProcAddress`
- `ri` (refimport_t) — `ri.Con_Printf` used throughout; defined in the engine, passed at renderer load time

# win32/rw_dib.c
## File Purpose
Manages Windows DIB (Device Independent Bitmap) sections for the software renderer on Win32. Provides creation, palette management, and teardown of the 8-bit DIB surface that the soft renderer draws into before blitting to screen.

## Core Responsibilities
- Allocate and initialize an 8-bit DIB section backed by `vid.width × vid.height` memory
- Expose the DIB's pixel buffer and pitch to the soft renderer
- Detect palettized (8-bit desktop) display modes and configure identity palette mode
- Apply palette updates to both the DIB color table and the Win32 system palette
- Save and restore Windows system colors when entering/leaving palettized mode
- Release all GDI resources on shutdown

## External Dependencies
- `ref_soft/r_local.h` — `vid`, `d_8to24table`, `ri` (refimport_t), `sww_state` (soft Win32 window state struct)
- `rw_win.h` — `sww_state` declaration, Win32 type aliases
- Win32 GDI: `CreateDIBSection`, `CreateCompatibleDC`, `SelectObject`, `SetDIBColorTable`, `CreatePalette`, `SelectPalette`, `RealizePalette`, `SetSystemPaletteUse`, `SetSysColors`, `GetSysColor`, `ReleaseDC`, `DeleteDC`, `DeleteObject`
- `sww_state` — defined in `rw_win.h` / platform layer, not in this file

# win32/rw_imp.c
## File Purpose
Win32-specific implementation layer for the software renderer, providing window creation, graphics surface initialization (DIB or DirectDraw), frame presentation, palette management, and FPU control word setup for x86 rasterization.

## Core Responsibilities
- Create and destroy the Win32 window for the software renderer
- Initialize DIB (windowed) or DirectDraw (fullscreen) rendering surfaces
- Present the completed frame (BitBlt for DIB, BltFast/Flip for DDRAW)
- Set the software palette via DIB or DDRAW subsystem
- Handle app activation/deactivation (minimize on focus loss in fullscreen)
- Configure x87 FPU control word variants (round, truncate, ceil, single precision)
- Expose memory page protection change via `Sys_MakeCodeWriteable`

## External Dependencies
- `../ref_soft/r_local.h` — `vid`, `sw_state`, `d_8to24table`, `rserr_t`, `R_GammaCorrectAndSetPalette`
- `rw_win.h` — `swwstate_t`, `sww_state` declaration, `DIB_Init/Shutdown/SetPalette`, `DDRAW_Init/Shutdown/SetPalette`, `WINDOW_STYLE`
- `winquake.h` — Win32 and DirectDraw type definitions
- `ri` (refimport_t) — `Cvar_Get`, `Con_Printf`, `Sys_Error`, `Vid_GetModeInfo`, `Vid_NewWindow` (defined in engine, passed via import struct)
- `vid_fullscreen` in `SWimp_AppActivate` — referenced but not declared in this file (likely a bug or implicit extern from a shared header)

# win32/rw_win.h
## File Purpose
Declares the shared Win32 state structure and interface for the software renderer's Windows display backends. It provides the `swwstate_t` type that aggregates all Win32 GDI/DIB and DirectDraw handles needed by the software rasterizer's platform layer.

## Core Responsibilities
- Define `swwstate_t`: the central state bag for Win32 software-renderer windowing
- Declare GDI/DIB initialization, shutdown, and palette functions
- Declare DirectDraw initialization, shutdown, and palette functions
- Expose the single global `sww_state` instance to all translation units that include this header

## External Dependencies
- `<windows.h>` — `HINSTANCE`, `HDC`, `HWND`, `HPALETTE`, `COLORREF`, `HBITMAP`
- `<ddraw.h>` — `LPDIRECTDRAW`, `LPDIRECTDRAWSURFACE`, `LPDIRECTDRAWPALETTE`
- `qboolean` — defined in `qcommon/qcommon.h` or `game/q_shared.h` (defined elsewhere)
- `sww_state` — extern; defined in a Win32 platform `.c` file (defined elsewhere)

# win32/snd_win.c
## File Purpose
Windows-specific sound output backend for Quake 2, implementing the `SNDDMA_*` interface used by the portable sound mixer. Supports two output paths: DirectSound (preferred) and WinMM waveOut (fallback), sharing a common DMA buffer abstraction (`dma`).

## Core Responsibilities
- Load and initialize DirectSound via runtime DLL binding (`dsound.dll`)
- Create and manage DirectSound primary/secondary buffers
- Initialize WinMM waveOut as a fallback audio device
- Expose the `dma` buffer to the portable mixer via lock/unlock (`BeginPainting`/`Submit`)
- Report current playback position to the mixer (`SNDDMA_GetDMAPos`)
- Handle window focus changes by recreating/destroying DS buffers (`S_Activate`)
- Clean up all sound resources on shutdown (`FreeSound`)

## External Dependencies
- `../client/client.h`, `../client/snd_loc.h` — `dma`, `s_khz`, `s_primary`, `paintedtime`, `S_Shutdown`
- `winquake.h` — `cl_hwnd`, Windows types
- `dsound.dll` — loaded at runtime; `DirectSoundCreate` resolved via `GetProcAddress`
- WinMM (`waveOut*`) — linked statically via Windows SDK

# win32/sys_win.c
## File Purpose
Windows-specific system layer for Quake 2, providing the Win32 entry point (`WinMain`), OS abstraction functions, and game DLL loading. It bridges the platform-independent engine (`qcommon`) with Win32 APIs for timing, console I/O, clipboard, and process management.

## Core Responsibilities
- Implement `WinMain` as the application entry point and main game loop
- Parse command-line arguments from the Win32 `LPSTR` format
- Scan for the Quake 2 CD-ROM for copy protection
- Manage the dedicated server console (input/output via Win32 console API)
- Load and unload the game logic DLL (`gamex86.dll` / `gameaxp.dll`)
- Pump the Windows message queue each frame via `Sys_SendKeyEvents`
- Provide clipboard text access and window activation helpers

## External Dependencies
- `../qcommon/qcommon.h` — `Qcommon_Init`, `Qcommon_Frame`, `Qcommon_Shutdown`, `Com_Error`, `Com_Quit`, `FS_NextPath`, `dedicated`, `Sys_Milliseconds`
- `winquake.h` — `cl_hwnd`, shared Win32 types
- `conproc.h` — `InitConProc`, `DeinitConProc` (QHOST hook support)
- `CL_Shutdown` — defined in client layer
- `timeBeginPeriod` / `timeEndPeriod` / `timeGetTime` — `winmm.lib`
- `_controlfp` — MSVC CRT FPU control

# win32/vid_dll.c
## File Purpose
Win32-specific video system manager that handles loading/unloading the refresh (renderer) DLL at runtime, processes the main window's message loop, and manages video mode changes. It acts as the glue layer between the engine client and the dynamically-loaded rendering backend.

## Core Responsibilities
- Load and unload the renderer DLL (`ref_gl.dll`, `ref_soft.dll`) at runtime via `VID_LoadRefresh`
- Build and pass a `refimport_t` vtable into the renderer DLL on load
- Register and process the Win32 `WndProc` (`MainWndProc`) for the main game window
- Translate Win32 scan codes and messages into Quake key events
- Handle app activation/deactivation (input, audio, alt-tab suppression)
- Check each frame for `vid_ref` changes and hot-reload the renderer (`VID_CheckChanges`)
- Expose video mode resolution table and query interface (`VID_GetModeInfo`)

## External Dependencies
- `../client/client.h` — `cl`, `cls`, `ActiveApp`, `Minimized`, `vidref_val`, `Key_Event`, `IN_Activate`, etc.
- `winquake.h` — `global_hInstance`, `s_win95`
- `qcommon.h` (via client.h) — `Com_Printf`, `Com_Error`, `Cvar_*`, `Cmd_*`, `FS_*`
- `re` (refexport_t) — populated at load time from the renderer DLL's `GetRefAPI`
- `CDAudio_Activate`, `S_Activate`, `S_StopAllSounds` — defined in audio modules
- `SCR_DirtyScreen`, `Con_ToggleConsole_f` — defined in client screen/console modules
- `sys_msg_time` — defined in `win32/sys_win.c`

# win32/vid_menu.c
## File Purpose
Implements the Windows-specific video options menu UI for Quake 2, allowing players to select renderer (software/OpenGL/3Dfx/PowerVR), video mode, brightness, fullscreen, and renderer-specific settings. It manages two parallel menu frameworks (software and OpenGL) that share certain controls.

## Core Responsibilities
- Define and initialize all menu items for both software and OpenGL video menus
- Switch between software/OpenGL menu views based on driver selection
- Apply video setting changes to cvars and trigger renderer restarts
- Handle special-case gamma correction for 3Dfx via environment variables
- Translate key input events into menu navigation and selection
- Draw the video menu with banner graphic each frame

## External Dependencies
- **Includes:** `../client/client.h`, `../client/qmenu.h`
- **Defined elsewhere:** `vid_ref`, `vid_fullscreen`, `vid_gamma`, `scr_viewsize` (extern cvars); `viddef` (video dimensions); `re` (refexport render API); `M_ForceMenuOff`, `M_PopMenu` (menu system); `Menu_AddItem`, `Menu_Center`, `Menu_AdjustCursor`, `Menu_Draw`, `Menu_SlideItem`, `Menu_SelectItem`, `Cvar_Get`, `Cvar_Set`, `Cvar_SetValue`, `Com_sprintf` (engine utilities).

# win32/winquake.h
## File Purpose
Central Win32-specific header for the Quake 2 engine, aggregating Windows and DirectSound system handles, window state, and input callback declarations used across Win32 platform modules.

## Core Responsibilities
- Pulls in `<windows.h>` and `<dsound.h>` for Win32 and DirectSound APIs
- Declares the application `HINSTANCE` global
- Declares DirectSound interface pointers and buffer size
- Declares the main window handle and application focus/minimize state
- Defines the non-resizable window style constant
- Declares input activation and mouse event entry points
- Exports window geometry state (center coordinates and rect)

## External Dependencies
- `<windows.h>` — Win32 core API
- `<dsound.h>` — DirectSound 3 interfaces
- `qboolean` — defined in `qcommon/qcommon.h` or `game/q_shared.h`
- All declared globals are **defined elsewhere** (`sys_win.c`, `snd_win.c`, `in_win.c`, `vid_dll.c`)

