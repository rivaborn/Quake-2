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

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `cheatvar_t` | struct | Pairs a cvar name with its forced multiplayer value for anti-cheat enforcement |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `cls` | `client_static_t` | global | Persistent client state across map loads (connection, demo, net channel) |
| `cl` | `client_state_t` | global | Per-level client state, wiped on `CL_ClearState` |
| `cl_entities` | `centity_t[MAX_EDICTS]` | global | Client-side entity array for interpolation |
| `cl_parse_entities` | `entity_state_t[MAX_PARSE_ENTITIES]` | global | Ring buffer of received entity states |
| `precache_check` | `int` | static (file) | Cursor tracking progress through the precache/download pipeline |
| `precache_model` | `byte*` | static (file) | Loaded alias model held during skin-check phase of precaching |
| `cheatvars[]` | `cheatvar_t[]` | static (file) | Table of cvars locked to specific values in multiplayer |
| `numcheatvars` | `int` | static (file) | Cached count of cheat-protected cvars |
| Many `cvar_t*` | `cvar_t*` | global | All client cvars (`cl_maxfps`, `sensitivity`, `name`, `skin`, etc.) |

## Key Functions

### CL_Init
- Signature: `void CL_Init(void)`
- Purpose: Full client subsystem initialization sequence.
- Inputs: None (reads `dedicated` cvar).
- Outputs/Return: void
- Side effects: Initializes console, video, sound, menus, screen, CD audio, input, local client state; executes `autoexec.cfg`.
- Calls: `Con_Init`, `VID_Init`, `S_Init`, `V_Init`, `M_Init`, `SCR_Init`, `CDAudio_Init`, `CL_InitLocal`, `IN_Init`, `FS_ExecAutoexec`, `Cbuf_Execute`
- Notes: Order of `S_Init`/`VID_Init` is platform-dependent (Linux/SGI invert order).

### CL_Shutdown
- Signature: `void CL_Shutdown(void)`
- Purpose: Tears down all client subsystems; guards against recursive invocation.
- Inputs: None
- Outputs/Return: void
- Side effects: Writes `config.cfg`, shuts down CD audio, sound, input, video.
- Calls: `CL_WriteConfiguration`, `CDAudio_Shutdown`, `S_Shutdown`, `IN_Shutdown`, `VID_Shutdown`

### CL_Frame
- Signature: `void CL_Frame(int msec)`
- Purpose: Per-frame client tick — enforces FPS cap, drives all subsystem updates.
- Inputs: `msec` — milliseconds elapsed since last call.
- Outputs/Return: void
- Side effects: Updates `cls.frametime`, `cl.time`, `cls.realtime`; triggers render, audio, network, prediction, effects.
- Calls: `IN_Frame`, `CL_ReadPackets`, `CL_SendCommand`, `CL_PredictMovement`, `VID_CheckChanges`, `CL_PrepRefresh`, `SCR_UpdateScreen`, `S_Update`, `CDAudio_Update`, `CL_RunDLights`, `CL_RunLightStyles`, `SCR_RunCinematic`, `SCR_RunConsole`
- Notes: Skips frame if frametime < `1000/cl_maxfps`; clamps `frametime` to 1/5s to avoid spiral-of-death; timedemo bypasses FPS cap.

### CL_InitLocal
- Signature: `void CL_InitLocal(void)`
- Purpose: Registers all client cvars and console commands.
- Inputs: None
- Outputs/Return: void
- Side effects: Populates all `cvar_t*` globals; registers ~40 console commands.
- Calls: `CL_InitInput`, `Cvar_Get` (many), `Cmd_AddCommand` (many)

### CL_Disconnect
- Signature: `void CL_Disconnect(void)`
- Purpose: Transitions client to disconnected state; sends three disconnect packets.
- Inputs: None
- Outputs/Return: void
- Side effects: Stops sounds, stops demo recording, clears client state, closes download file, resets `cls.state`.
- Calls: `CL_Stop_f`, `Netchan_Transmit` (×3), `CL_ClearState`, `SCR_StopCinematic`, `M_ForceMenuOff`, `re.CinematicSetPalette`

### CL_RequestNextDownload
- Signature: `void CL_RequestNextDownload(void)`
- Purpose: State-machine driving sequential precache and autodownload of all asset types before spawning.
- Inputs: None (reads `precache_check` cursor and `cl.configstrings`).
- Outputs/Return: void; returns early (suspends) when a download is started.
- Side effects: Advances `precache_check`; may call `CL_CheckOrDownloadFile`; on completion calls `CL_RegisterSounds`, `CL_PrepRefresh`, writes `begin` command to netchan.
- Calls: `CL_CheckOrDownloadFile`, `FS_LoadFile`, `FS_FreeFile`, `CM_LoadMap`, `CL_RegisterSounds`, `CL_PrepRefresh`
- Notes: Covers models + skins, sounds, images, player models (5 sub-items each), sky env maps, and map textures in sequence.

### CL_Record_f
- Signature: `void CL_Record_f(void)`
- Purpose: Begins demo recording; writes synthetic startup frame with serverdata, configstrings, and entity baselines.
- Inputs: Console arg 1 = demo filename.
- Side effects: Opens `.dm2` file, sets `cls.demorecording = true`, sets `cls.demowaiting = true`.
- Calls: `FS_CreatePath`, `fopen`, `SZ_Init`, `MSG_Write*`, `MSG_WriteDeltaEntity`

### CL_ReadPackets
- Signature: `void CL_ReadPackets(void)`
- Purpose: Drains the network receive queue; dispatches connectionless or sequenced server packets; handles timeout.
- Inputs: None
- Side effects: May call `CL_Disconnect` on timeout; calls `CL_ParseServerMessage` for valid packets.
- Calls: `NET_GetPacket`, `CL_ConnectionlessPacket`, `Netchan_Process`, `CL_ParseServerMessage`

### CL_FixCvarCheats
- Signature: `void CL_FixCvarCheats(void)`
- Purpose: Resets cheat-protected cvars to safe values in multiplayer.
- Notes: Skips in singleplayer (`CS_MAXCLIENTS == "1"`); lazily populates `cheatvars[].var` on first call.

## Control Flow Notes
- `CL_Init` is called once at engine startup; `CL_Shutdown` at exit.
- `CL_Frame` is the per-frame entry point, called by the engine loop with elapsed milliseconds.
- Connection lifecycle: `CL_Connect_f` → `CL_CheckForResend` (getchallenge) → `CL_ConnectionlessPacket` (challenge/client_connect) → `CL_SendConnectPacket` → `CL_Precache_f` / `CL_RequestNextDownload` → `begin` → `ca_active`.

## External Dependencies
- **Includes:** `client.h` (pulls in all client/shared headers)
- **Defined elsewhere:** `net_message`, `net_from`, `curtime`, `host_speeds`, `log_stats`, `log_stats_file`, `dedicated`, `userinfo_modified`, `allow_download*` cvars; `CL_ParseServerMessage`, `CL_PrepRefresh`, `CL_RegisterSounds`, `CL_CheckOrDownloadFile`, `CL_Download_f`, `CL_SendCmd`, `CL_PredictMovement`, `CL_ParseClientinfo`, `CM_LoadMap`, `numtexinfo`, `map_surfaces[]` (from `qcommon/cmodel.c`); all renderer entry points via `re` refexport struct.
