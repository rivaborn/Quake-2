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

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `zhead_t` | struct | Header prepended to every zone allocation; forms a doubly-linked list for tracking and group-free |
| `sizebuf_t` | struct (external) | Growable byte buffer used for network message read/write |
| `usercmd_t` | struct (external) | Player input command transmitted over the network |
| `entity_state_t` | struct (external) | Per-entity network state used for delta compression |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `com_argc` / `com_argv` | `int` / `char*[]` | global | Stores program command-line arguments |
| `realtime` | `int` | global | Current real time in ms (set externally) |
| `abortframe` | `jmp_buf` | global | Jump target for non-fatal `ERR_DROP` errors |
| `server_state` | `int` | global | Current server state, queried via `Com_ServerState` |
| `logfile` | `FILE*` | global | Open handle to `qconsole.log` |
| `log_stats_file` | `FILE*` | global | Open handle to `stats.log` |
| `host_speeds`, `log_stats`, `developer`, `timescale`, `fixedtime`, `logfile_active`, `showtrace`, `dedicated` | `cvar_t*` | global | Engine cvars controlling frame timing, logging, and mode |
| `time_before_game`, `time_after_game`, `time_before_ref`, `time_after_ref` | `int` | global | Profiling timestamps written by game/renderer, read here |
| `z_chain`, `z_count`, `z_bytes` | `zhead_t`, `int`, `int` | global | Zone allocator list head and accounting |
| `bytedirs` | `vec3_t[]` | global | Precomputed vertex normal table (included from `client/anorms.h`) |
| `rd_target`, `rd_buffer`, `rd_buffersize`, `rd_flush` | various | static | Console redirection state |
| `chktbl` | `byte[1024]` | static | Lookup table used by `COM_BlockSequenceCRCByte` |

## Key Functions

### Qcommon_Init
- **Signature:** `void Qcommon_Init(int argc, char **argv)`
- **Purpose:** Full engine bootstrap — initializes subsystems in dependency order.
- **Inputs:** Raw `argc`/`argv` from `main`.
- **Outputs/Return:** None.
- **Side effects:** Registers cvars and commands, calls `Sys_Init`, `NET_Init`, `Netchan_Init`, `SV_Init`, `CL_Init`, executes config files, prints initialization banner.
- **Calls:** `COM_InitArgv`, `Swap_Init`, `Cbuf_Init`, `Cmd_Init`, `Cvar_Init`, `Key_Init`, `FS_InitFilesystem`, `SV_Init`, `CL_Init`, `NET_Init`, `Netchan_Init`, `Sys_Init`, `Cbuf_Execute`, `SCR_EndLoadingPlaque`.
- **Notes:** Uses `setjmp(abortframe)` so any `ERR_DROP` during init calls `Sys_Error` instead of looping.

### Qcommon_Frame
- **Signature:** `void Qcommon_Frame(int msec)`
- **Purpose:** Per-frame engine tick; applies time scaling, polls console input, and dispatches to server and client frames.
- **Inputs:** `msec` — elapsed milliseconds since last frame.
- **Outputs/Return:** None.
- **Side effects:** Reads/writes `log_stats_file`; calls `SV_Frame`, `CL_Frame`; prints host_speeds timing report; resets trace counters.
- **Calls:** `SV_Frame`, `CL_Frame`, `Cbuf_Execute`, `Sys_ConsoleInput`, `Sys_Milliseconds`, `Com_Printf`.
- **Notes:** `setjmp(abortframe)` at entry causes `ERR_DROP` to silently abort and return from this function.

### Com_Error
- **Signature:** `void Com_Error(int code, char *fmt, ...)`
- **Purpose:** Unified fatal/drop/disconnect error handler.
- **Inputs:** `code` (`ERR_FATAL`, `ERR_DROP`, `ERR_DISCONNECT`), format string.
- **Side effects:** Shuts down server/client as appropriate, closes logfile, calls `longjmp(abortframe)` for non-fatal codes or `Sys_Error` for fatal.
- **Calls:** `SV_Shutdown`, `CL_Drop`, `CL_Shutdown`, `Sys_Error`.
- **Notes:** `recursive` flag prevents infinite recursion; `ERR_DISCONNECT` skips server shutdown.

### MSG_WriteDeltaEntity
- **Signature:** `void MSG_WriteDeltaEntity(entity_state_t *from, entity_state_t *to, sizebuf_t *msg, qboolean force, qboolean newentity)`
- **Purpose:** Delta-compresses an entity state update into a network message using a multi-byte bitmask scheme.
- **Inputs:** Baseline state, target state, output buffer, force-send flag, new-entity flag.
- **Side effects:** Appends bytes to `msg` via `MSG_WriteByte`/`MSG_WriteShort`/etc.
- **Notes:** Encodes variable-width bitmask (1–4 bytes) before the payload; handles skinnum/effects/renderfx with combined 8+16-bit flags for 32-bit encoding.

### MSG_WriteDeltaUsercmd / MSG_ReadDeltaUsercmd
- **Purpose:** Delta-encode/decode player input commands into/from a network buffer, only transmitting changed fields.
- **Notes:** Always writes `msec` and `lightlevel` unconditionally.

### Z_TagMalloc / Z_Free / Z_FreeTags
- **Purpose:** Tagged zone allocator. Allocates zeroed memory with a `zhead_t` header prepended; supports bulk-free by tag.
- **Side effects:** Mutates `z_chain`, `z_count`, `z_bytes`. Calls `Com_Error(ERR_FATAL)` on allocation failure or corrupted magic.

### SZ_GetSpace
- **Signature:** `void *SZ_GetSpace(sizebuf_t *buf, int length)`
- **Purpose:** Reserves `length` bytes at the end of a `sizebuf_t`.
- **Notes:** If `allowoverflow` is not set and the buffer is full, triggers `ERR_FATAL`. Otherwise marks buffer as `overflowed` and clears it.

### Com_Printf / Com_DPrintf
- **Purpose:** Shared print functions routing to console, system output, and optional logfile. `Com_DPrintf` is gated on `developer->value`.
- **Notes:** If redirect is active (`rd_target`), output goes to `rd_buffer` instead and flushes when full.

### COM_BlockSequenceCRCByte
- **Purpose:** CRC-based sequence byte for proxy authentication of packets.
- **Inputs:** Packet base, length, sequence number.
- **Notes:** `COM_BlockSequenceCheckByte` is disabled (calls `Sys_Error`) with a comment noting it was "MASSIVELY BROKEN."

## Control Flow Notes
- **Init:** `Qcommon_Init` is called once from `main` before entering the game loop.
- **Frame:** `Qcommon_Frame` is called each iteration of the main loop; it drives `SV_Frame` then `CL_Frame`.
- **Shutdown:** `Qcommon_Shutdown` is defined but empty; actual shutdown happens through `Com_Quit` or `Com_Error`.

## External Dependencies
- `qcommon.h` — defines `sizebuf_t`, `usercmd_t`, `entity_state_t`, cvars, error codes, network constants
- `client/anorms.h` — vertex normals table included inline
- **Defined elsewhere:** `SV_Frame`, `SV_Init`, `SV_Shutdown`, `CL_Frame`, `CL_Init`, `CL_Shutdown`, `CL_Drop`, `NET_Init`, `Netchan_Init`, `Sys_Init`, `Sys_Error`, `Sys_Quit`, `Sys_ConsoleInput`, `Sys_ConsoleOutput`, `Sys_Milliseconds`, `Con_Print`, `Key_Init`, `FS_InitFilesystem`, `FS_Gamedir`, `CRC_Block`, `Z_Malloc`
