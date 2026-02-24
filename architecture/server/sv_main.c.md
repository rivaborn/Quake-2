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

## Key Types / Data Structures
None defined here; uses types from `server.h`.

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `master_adr` | `netadr_t[MAX_MASTERS]` | global | Addresses of master/group servers |
| `sv_client` | `client_t *` | global | Pointer to the client currently being processed |
| `sv_paused` | `cvar_t *` | global | Whether game is paused |
| `sv_timedemo` | `cvar_t *` | global | Timedemo mode flag |
| `sv_enforcetime` | `cvar_t *` | global | Enforce client move timing |
| `timeout` | `cvar_t *` | global | Seconds before inactive client is dropped |
| `zombietime` | `cvar_t *` | global | Seconds a zombie client slot is held |
| `rcon_password` | `cvar_t *` | global | Remote console password |
| `allow_download*` | `cvar_t *` | global | Per-category download permission flags |
| `sv_noreload` | `cvar_t *` | global | Skip level-state reload on re-entry |
| `maxclients` | `cvar_t *` | global | Maximum simultaneous clients |
| `hostname` | `cvar_t *` | global | Server hostname string |
| `public_server` | `cvar_t *` | global | Controls heartbeat transmission |
| `sv_reconnect_limit` | `cvar_t *` | global | Minimum seconds between reconnects |

## Key Functions

### SV_Frame
- Signature: `void SV_Frame(int msec)`
- Purpose: Top-level per-frame server tick; orchestrates all server subsystems.
- Inputs: `msec` — elapsed milliseconds since last call.
- Outputs/Return: void
- Side effects: Advances `svs.realtime`; drives game, network, and master server subsystems.
- Calls: `SV_CheckTimeouts`, `SV_ReadPackets`, `SV_CalcPings`, `SV_GiveMsec`, `SV_RunGameFrame`, `SV_SendClientMessages`, `SV_RecordDemoMessage`, `Master_Heartbeat`, `SV_PrepWorldFrame`, `NET_Sleep`
- Notes: Returns early if `svs.initialized` is false. Implements low/high clamp logic to keep `svs.realtime` and `sv.time` from diverging beyond 100 ms.

### SVC_DirectConnect
- Signature: `void SVC_DirectConnect(void)`
- Purpose: Handles incoming client connection requests; performs challenge validation, slot allocation, and game-layer acceptance.
- Inputs: Implicit — reads from `net_from` and `net_message` globals via `Cmd_Argv`.
- Outputs/Return: void; sends `client_connect` OOB packet on success.
- Side effects: Allocates a `client_t` slot in `svs.clients`; sets `sv_client`; initializes `netchan` and datagram buffer; calls `ge->ClientConnect`.
- Calls: `NET_CompareBaseAdr`, `NET_IsLocalAddress`, `Netchan_OutOfBandPrint`, `Netchan_Setup`, `SV_UserinfoChanged`, `SZ_Init`
- Notes: Uses a `goto gotnewcl` label for reconnect reuse. A `temp` stack `client_t` guards partial init until acceptance is confirmed.

### SV_DropClient
- Signature: `void SV_DropClient(client_t *drop)`
- Purpose: Disconnects a single client, notifying the game DLL and freeing download state.
- Inputs: `drop` — pointer to the client to remove.
- Outputs/Return: void
- Side effects: Writes `svc_disconnect` to client message buffer; calls `ge->ClientDisconnect`; frees download file; sets state to `cs_zombie`.
- Calls: `MSG_WriteByte`, `ge->ClientDisconnect`, `FS_FreeFile`
- Notes: Not called during full server shutdown — `SV_FinalMessage`/`SV_Shutdown` handle that path.

### SV_CheckTimeouts
- Signature: `void SV_CheckTimeouts(void)`
- Purpose: Scans all clients each frame; drops stale connected/spawned clients and recycles zombie slots.
- Inputs: None (reads `svs.realtime`, `timeout->value`, `zombietime->value`).
- Outputs/Return: void
- Side effects: May call `SV_DropClient`; transitions client states to `cs_free`.
- Calls: `SV_BroadcastPrintf`, `SV_DropClient`

### SVC_GetChallenge
- Signature: `void SVC_GetChallenge(void)`
- Purpose: Issues a random challenge number to a connecting client to prevent IP spoofing/DoS.
- Inputs: Implicit `net_from`.
- Outputs/Return: void; sends `challenge N` OOB reply.
- Side effects: Writes into `svs.challenges[]`; evicts oldest entry on overflow.
- Calls: `NET_CompareBaseAdr`, `Netchan_OutOfBandPrint`

### SVC_RemoteCommand
- Signature: `void SVC_RemoteCommand(void)`
- Purpose: Executes a remote console command if `rcon_password` matches; redirects output back to sender.
- Inputs: Implicit `net_message` / `Cmd_Argv`.
- Outputs/Return: void
- Side effects: Calls `Cmd_ExecuteString`; redirects `Com_Printf` to packet via `Com_BeginRedirect`.
- Calls: `Rcon_Validate`, `Com_BeginRedirect`, `Com_EndRedirect`, `Cmd_ExecuteString`

### SV_Init
- Signature: `void SV_Init(void)`
- Purpose: One-time engine startup registration of all server cvars and operator commands.
- Inputs: None.
- Outputs/Return: void
- Side effects: Registers ~20 cvars; initializes `net_message` sizebuf.
- Calls: `SV_InitOperatorCommands`, `Cvar_Get`, `SZ_Init`

### SV_Shutdown
- Signature: `void SV_Shutdown(char *finalmsg, qboolean reconnect)`
- Purpose: Orderly server teardown — broadcasts final message, notifies masters, unloads game DLL, frees all server memory.
- Inputs: `finalmsg` — string shown to clients; `reconnect` — whether clients should reconnect.
- Outputs/Return: void
- Side effects: Frees `svs.clients`, `svs.client_entities`; closes demo files; zeroes `sv` and `svs`.
- Calls: `SV_FinalMessage`, `Master_Shutdown`, `SV_ShutdownGameProgs`, `Z_Free`, `Com_SetServerState`

### Notes
- `SV_StatusString` and `SVC_Status/Info/Ping/Ack` are trivial OOB query responders.
- `SV_CalcPings` averages `frame_latency[]` ring buffer entries into `cl->ping` each frame.
- `SV_GiveMsec` replenishes `commandMsec` budget every 16 frames to cap cheat-speed movement.
- `SV_PrepWorldFrame` clears `ent->s.event` on all edicts before the next game frame.
- `SV_UserinfoChanged` extracts `name`, `rate`, and `msg` from the userinfo string into `client_t` fields.

## Control Flow Notes
`SV_Init` is called once at engine startup. Each engine tick calls `SV_Frame(msec)`, which is the server's heartbeat: it advances time, processes network I/O, runs one game frame via `ge->RunFrame()`, transmits results, and maintains master server registration. `SV_Shutdown` is called at map change or engine exit.

## External Dependencies
- `server.h` — `sv`, `svs`, `client_t`, `ge`, state enums, `SV_*` prototypes
- `ge->ClientConnect`, `ge->ClientDisconnect`, `ge->ClientUserinfoChanged`, `ge->RunFrame` — game DLL interface (defined in game module)
- `Netchan_*`, `NET_*`, `MSG_*`, `SZ_*` — network/message layer (defined in `qcommon/`)
- `Cvar_Get`, `Cmd_*`, `Info_*`, `Com_*` — engine common layer
- `SV_SendClientMessages`, `SV_RecordDemoMessage`, `SV_ShutdownGameProgs`, `SV_ExecuteClientMessage` — defined in other `server/sv_*.c` files
- `host_speeds`, `dedicated`, `curtime`, `net_from`, `net_message` — globals defined elsewhere in engine
