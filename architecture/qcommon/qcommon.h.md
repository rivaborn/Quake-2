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

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `sizebuf_t` | struct | Growable byte buffer for network message read/write with overflow tracking |
| `netadr_t` | struct | Network address: type (loopback/IP/IPX), raw IP/IPX bytes, port |
| `netchan_t` | struct | Full reliable UDP channel: sequencing, ACK state, staging buffers |
| `netadrtype_t` | enum | Address family discriminator (loopback, broadcast, IP, IPX) |
| `netsrc_t` | enum | Socket role: NS_CLIENT or NS_SERVER |
| `svc_ops_e` | enum | Server-to-client message opcodes |
| `clc_ops_e` | enum | Client-to-server message opcodes |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `bigendien` | `qboolean` | global | Runtime endianness flag |
| `cvar_vars` | `cvar_t *` | global | Head of linked cvar list |
| `userinfo_modified` | `qboolean` | global | Set when any CVAR_USERINFO cvar changes |
| `net_from` | `netadr_t` | global | Source address of last received packet |
| `net_message` | `sizebuf_t` | global | Buffer for last received packet |
| `net_message_buffer` | `byte[MAX_MSGLEN]` | global | Backing store for `net_message` |
| `pm_airaccelerate` | `float` | global | Air acceleration constant shared between client prediction and server |
| `developer` | `cvar_t *` | global | Developer mode toggle |
| `dedicated` | `cvar_t *` | global | Dedicated server mode toggle |
| `host_speeds` | `cvar_t *` | global | Frame timing profiling toggle |
| `log_stats` | `cvar_t *` | global | Stats logging toggle |
| `log_stats_file` | `FILE *` | global | Stats log output file |
| `time_before_game` / `time_after_game` / `time_before_ref` / `time_after_ref` | `int` | global | Per-frame profiling timestamps |
| `bytedirs` | `vec3_t[162]` | global | Precalculated unit direction vectors for compressed direction encoding |

## Key Functions

### Qcommon_Init / Qcommon_Frame / Qcommon_Shutdown
- Signature: `void Qcommon_Init(int argc, char **argv)` / `void Qcommon_Frame(int msec)` / `void Qcommon_Shutdown(void)`
- Purpose: Top-level engine lifecycle. Init bootstraps all subsystems; Frame drives one engine tick; Shutdown tears everything down.
- Inputs: argc/argv for init; elapsed milliseconds for frame.
- Outputs/Return: void
- Side effects: Initializes/ticks/destroys all global subsystems.
- Notes: These are the primary entry points called by platform `main()`.

### SZ_Init / SZ_GetSpace / SZ_Write / SZ_Print / SZ_Clear
- Signature: e.g. `void SZ_Init(sizebuf_t *buf, byte *data, int length)`
- Purpose: Manage `sizebuf_t` read/write buffers used as the backing store for all network messages.
- Notes: `SZ_GetSpace` triggers `Com_Error` if `allowoverflow` is false and the buffer would overflow.

### MSG_Write* / MSG_Read*
- Purpose: Type-safe serialization/deserialization of primitives, coordinates, angles, strings, entity deltas, and user commands into/from `sizebuf_t`.
- Notes: `MSG_WriteDeltaEntity` and `MSG_ReadDeltaUsercmd` implement delta compression using the `U_*` and `CM_*` bit flags defined in this file.

### Netchan_Transmit / Netchan_Process
- Signature: `void Netchan_Transmit(netchan_t *chan, int length, byte *data)` / `qboolean Netchan_Process(netchan_t *chan, sizebuf_t *msg)`
- Purpose: Send/receive packets over a reliable sequenced UDP channel, handling ACKs and retransmission of unacknowledged reliable messages.
- Outputs/Return: `Netchan_Process` returns false if the packet is out of sequence and should be dropped.

### CM_BoxTrace / CM_TransformedBoxTrace
- Signature: `trace_t CM_BoxTrace(vec3_t start, vec3_t end, vec3_t mins, vec3_t maxs, int headnode, int brushmask)`
- Purpose: BSP-based swept AABB collision trace used by both physics and projectile code.
- Notes: Transformed variant handles rotated inline models (doors, platforms).

### Pmove
- Signature: `void Pmove(pmove_t *pmove)`
- Purpose: Shared player movement simulation; identical code runs on client (prediction) and server (authoritative).
- Side effects: Modifies `pmove_t` in place; reads `pm_airaccelerate`.

### Com_Error
- Signature: `void Com_Error(int code, char *fmt, ...)`
- Purpose: Fatal/recoverable error dispatch. `ERR_FATAL` exits the process; `ERR_DROP` disconnects; `ERR_QUIT` is a clean exit.

### Z_Malloc / Z_Free / Z_TagMalloc / Z_FreeTags
- Purpose: Tagged zone memory allocator; `Z_Malloc` returns zeroed memory; `Z_FreeTags` bulk-frees by tag (used for map load/unload).

## Control Flow Notes
- `Qcommon_Init` is called once from `main()` and chains `Cbuf_Init → Cmd_Init → Cvar_Init → NET_Init → FS_InitFilesystem → SV_Init → CL_Init`.
- `Qcommon_Frame` is called every OS tick; it drives `SV_Frame` and `CL_Frame`, bracketed by `time_before_*/time_after_*` profiling.
- `Netchan_Process` / `Netchan_Transmit` are called inside `SV_Frame` and `CL_Frame` per-connection.

## External Dependencies
- `../game/q_shared.h` — shared game types (`vec3_t`, `trace_t`, `pmove_t`, `cvar_t`, `qboolean`, etc.)
- `../qcommon/qfiles.h` — on-disk BSP/model format types (`cmodel_t`, etc.)
- All `MSG_*`, `SZ_*`, `CM_*`, `FS_*`, `NET_*`, `Netchan_*`, `Cvar_*`, `Cmd_*`, `Cbuf_*`, `Z_*`, `Com_*`, `Sys_*`, `CL_*`, `SV_*` implementations are **defined elsewhere** in their respective `.c` files.
