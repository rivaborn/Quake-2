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

## Key Types / Data Structures
None defined in this file; uses types from `client.h`.

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `svc_strings` | `char *[256]` | global | Human-readable names for `svc_*` command bytes; used for debug net logging |

## Key Functions

### CL_CheckOrDownloadFile
- **Signature:** `qboolean CL_CheckOrDownloadFile(char *filename)`
- **Purpose:** Checks if a file exists locally; if not, initiates or resumes a download request to the server.
- **Inputs:** `filename` — relative path of file to check/download
- **Outputs/Return:** `true` if file already exists or path is rejected; `false` if download was initiated
- **Side effects:** Opens/sets `cls.download` file handle; writes `clc_stringcmd` download request to `cls.netchan.message`; increments `cls.downloadnumber`
- **Calls:** `FS_LoadFile`, `COM_StripExtension`, `CL_DownloadFileName`, `fopen`, `fseek`, `ftell`, `MSG_WriteByte`, `MSG_WriteString`
- **Notes:** Rejects paths containing `..`. Supports resume by checking for existing `.tmp` file and sending byte offset to server.

### CL_ParseDownload
- **Signature:** `void CL_ParseDownload(void)`
- **Purpose:** Handles an incoming `svc_download` block; writes data to temp file and requests next block, or finalizes and renames on 100%.
- **Inputs:** Reads from `net_message`
- **Outputs/Return:** None
- **Side effects:** File I/O on `cls.download`; on completion, renames `.tmp` to final filename; calls `CL_RequestNextDownload`; writes `nextdl` command to netchan
- **Calls:** `MSG_ReadShort`, `MSG_ReadByte`, `fclose`, `fopen`, `fwrite`, `rename`, `CL_DownloadFileName`, `FS_CreatePath`, `CL_RequestNextDownload`, `MSG_WriteByte`, `SZ_Print`
- **Notes:** Size of `-1` means server rejected the file. Opens the file lazily on first block.

### CL_ParseServerData
- **Signature:** `void CL_ParseServerData(void)`
- **Purpose:** Handles `svc_serverdata`; resets client state, validates protocol version, sets game directory, and either starts a cinematic or prepares for level load.
- **Inputs:** Reads from `net_message`
- **Outputs/Return:** None
- **Side effects:** Calls `CL_ClearState`; sets `cls.state`, `cls.serverProtocol`, `cl.servercount`, `cl.gamedir`, `cl.playernum`; may call `Cvar_Set("game", ...)` or `SCR_PlayCinematic`
- **Calls:** `CL_ClearState`, `MSG_ReadLong`, `MSG_ReadByte`, `MSG_ReadString`, `MSG_ReadShort`, `Com_ServerState`, `Cvar_Set`, `SCR_PlayCinematic`
- **Notes:** Contains a protocol 34 demo compatibility hack. Sets `cl.refresh_prepped = false` to trigger re-prep on next frame.

### CL_LoadClientinfo
- **Signature:** `void CL_LoadClientinfo(clientinfo_t *ci, char *s)`
- **Purpose:** Parses a `"name\model/skin"` configstring and registers the player model, skin, weapon models, and HUD icon via the renderer.
- **Inputs:** `ci` — destination clientinfo struct; `s` — raw configstring value
- **Outputs/Return:** None; populates `ci` fields
- **Side effects:** Calls renderer registration functions (`re.RegisterModel`, `re.RegisterSkin`, `re.RegisterPic`)
- **Calls:** `re.RegisterModel`, `re.RegisterSkin`, `re.RegisterPic`, `Q_stricmp`, `Com_sprintf`
- **Notes:** Falls back to `male/grunt` defaults if model/skin not found. Iterates `cl_weaponmodels[]` up to `num_cl_weaponmodels`; stops at index 0 if `cl_vwep` is off. Nulls all fields on partial load failure.

### CL_ParseStartSoundPacket
- **Signature:** `void CL_ParseStartSoundPacket(void)`
- **Purpose:** Reads a `svc_sound` message and starts playback with optional volume, attenuation, time offset, entity association, and world position.
- **Inputs:** Reads from `net_message`
- **Outputs/Return:** None
- **Side effects:** Calls `S_StartSound`
- **Calls:** `MSG_ReadByte`, `MSG_ReadShort`, `MSG_ReadPos`, `S_StartSound`
- **Notes:** Silently returns if `cl.sound_precache[sound_num]` is NULL. Entity number is packed into the high bits of `channel`.

### CL_ParseServerMessage
- **Signature:** `void CL_ParseServerMessage(void)`
- **Purpose:** Main per-frame dispatch loop; reads bytes from `net_message` and calls the appropriate handler for each `svc_*` command.
- **Inputs:** None (reads `net_message` global)
- **Outputs/Return:** None
- **Side effects:** Dispatches to all sub-parsers; calls `CL_AddNetgraph`; writes demo message if recording
- **Calls:** Nearly all `CL_Parse*` functions, plus `Cbuf_Execute`, `Cbuf_AddText`, `SCR_CenterPrint`, `S_StartLocalSound`, `CL_WriteDemoMessage`, `CL_AddNetgraph`
- **Notes:** `svc_playerinfo`, `svc_packetentities`, and `svc_deltapacketentities` are errors if seen outside a frame context. Demo write happens after frame parse to ensure validity.

## Control Flow Notes
Called once per client frame from the main client loop when a packet arrives. `CL_ParseServerMessage` is the entry point; it loops until the message buffer is exhausted. Connection setup flows through `CL_ParseServerData` → `CL_ParseConfigString` → `CL_ParseBaseline` on initial connect. Per-frame entity/player state is delegated to `CL_ParseFrame` (defined in `cl_ents.c`).

## External Dependencies
- **Includes:** `client.h` (pulls in all client state, `cls`, `cl`, `net_message`, cvar refs)
- **Defined elsewhere:** `net_message`, `cl`, `cls`, `con`, `re` (renderer export), `S_StartSound`, `S_BeginRegistration`, `S_EndRegistration`, `S_RegisterSound`, `CDAudio_Play`, `CM_InlineModel`, `FS_LoadFile`, `FS_Gamedir`, `FS_CreatePath`, `CL_ParseFrame`, `CL_ParseTEnt`, `CL_ParseMuzzleFlash`, `CL_ParseMuzzleFlash2`, `CL_ParseInventory`, `CL_ParseEntityBits`, `CL_ParseDelta`, `CL_RequestNextDownload`, `CL_WriteDemoMessage`, `CL_AddNetgraph`, `CL_SetLightstyle`, `CL_RegisterTEntSounds`, `SCR_PlayCinematic`, `SCR_CenterPrint`, `cl_shownet`, `cl_noskins`, `cl_vwep`, `cl_weaponmodels`, `num_cl_weaponmodels`
