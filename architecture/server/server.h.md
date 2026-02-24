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

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `server_state_t` | enum | Lifecycle state of the server (dead, loading, game, cinematic, demo, pic) |
| `server_t` | struct | Per-map server state: time, frame, configstrings, baselines, multicast buffer, demo file |
| `client_state_t` | enum | Per-client connection state (free, zombie, connected, spawned) |
| `client_frame_t` | struct | Snapshot of a single server frame for a client; used for delta compression |
| `client_t` | struct | Full per-client state: network channel, frames, download, ping, userinfo, associated edict |
| `server_static_t` | struct | Persistent server state across map changes: client array, challenges, demo recording |
| `challenge_t` | struct | Anti-spoofing connection challenge record (address, challenge value, time) |
| `redirect_t` | enum | Output redirection target for console commands (none, client, packet) |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `svs` | `server_static_t` | global | Persistent server info, survives map changes |
| `sv` | `server_t` | global | Current map/session server state |
| `sv_client` | `client_t *` | global | Currently-executing client context pointer |
| `sv_player` | `edict_t *` | global | Edict of the currently-executing client |
| `ge` | `game_export_t *` | global | Interface to the loaded game DLL |
| `net_from` | `netadr_t` | global | Source address of the last received network packet |
| `net_message` | `sizebuf_t` | global | Buffer for the last received network message |
| `master_adr[MAX_MASTERS]` | `netadr_t[8]` | global | Addresses of master servers for heartbeats |
| `sv_outputbuf` | `char[...]` | global | Redirect output buffer for `SV_FlushRedirect` |
| `sv_paused`, `maxclients`, `sv_noreload`, `sv_airaccelerate`, `sv_enforcetime` | `cvar_t *` | global | Server configuration cvars |

## Key Functions

Prototypes only — implementations are in the listed source files.

### EDICT_NUM / NUM_FOR_EDICT
- Signature: Macros
- Purpose: Convert between edict index integers and `edict_t *` pointers using the game DLL's edict array and stride
- Notes: Depend on `ge->edicts` and `ge->edict_size` being valid; undefined behavior if called before game progs are initialized

### SV_Trace
- Signature: `trace_t SV_Trace(vec3_t start, vec3_t mins, vec3_t maxs, vec3_t end, edict_t *passedict, int contentmask)`
- Purpose: Performs a swept box trace through world geometry and entities
- Inputs: Start/end points, box extents, entity to exclude, content filter mask
- Outputs/Return: `trace_t` with fraction, hit normal, contents, and solid flags
- Side effects: None declared
- Notes: `passedict` is excluded from clipping; handles both BSP and entity solids

### SV_LinkEdict / SV_UnlinkEdict
- Signature: `void SV_LinkEdict(edict_t *ent)` / `void SV_UnlinkEdict(edict_t *ent)`
- Purpose: Insert or remove an entity from the world spatial index
- Notes: Must be called after any change to origin, mins, maxs, or solid; `SV_LinkEdict` updates `absmin`/`absmax` and PVS leaf assignments

### SV_Multicast
- Signature: `void SV_Multicast(vec3_t origin, multicast_t to)`
- Purpose: Sends the current `sv.multicast` buffer to a spatially-filtered set of clients

### SV_BuildClientFrame / SV_WriteFrameToClient
- Signature: `void SV_BuildClientFrame(client_t *client)` / `void SV_WriteFrameToClient(client_t *client, sizebuf_t *msg)`
- Purpose: Construct and serialize a delta-compressed world frame for a specific client
- Notes: Core of the server's per-frame network update path

## Control Flow Notes

This header is included by all server `.c` files. The server lifecycle flows through:
- **Init**: `SV_InitGame` → `SV_InitGameProgs` → `SV_Map`
- **Frame**: `SV_PrepWorldFrame` → `SV_BuildClientFrame` → `SV_SendClientMessages`
- **Shutdown**: `SV_ShutdownGameProgs`, `SV_DropClient`

`server_static_t` (`svs`) persists across map loads; `server_t` (`sv`) is reset per map. `client_frame_t` frames are stored in a circular buffer (`UPDATE_BACKUP` deep) enabling delta compression.

## External Dependencies
- `../qcommon/qcommon.h` — core types (`vec3_t`, `sizebuf_t`, `netchan_t`, `netadr_t`, `cvar_t`, `trace_t`, etc.)
- `../game/game.h` — `edict_t`, `player_state_t`, `usercmd_t`, `game_export_t`
- `sv_main.c`, `sv_init.c`, `sv_send.c`, `sv_user.c`, `sv_ents.c`, `sv_game.c`, `sv_ccmds.c`, `sv_world.c` — all implement prototypes declared here
