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

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `loopmsg_t` | struct | Single loopback message: raw byte buffer + length |
| `loopback_t` | struct | Ring buffer of `MAX_LOOPBACK` (4) messages with `get`/`send` indices |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `net_local_adr` | `netadr_t` | global | Cached local address, returned as source of loopback packets |
| `loopbacks[2]` | `loopback_t[2]` | global | One ring buffer per `netsrc_t` (NS_CLIENT=0, NS_SERVER=1) |
| `ip_sockets[2]` | `int[2]` | global | UDP socket FDs indexed by `netsrc_t` |
| `ipx_sockets[2]` | `int[2]` | global | IPX socket FDs (unused on Linux; always 0) |

## Key Functions

### NET_Socket
- **Signature:** `int NET_Socket(char *net_interface, int port)`
- **Purpose:** Creates, configures, and binds a non-blocking broadcast-capable UDP socket.
- **Inputs:** Interface name or IP string (`"localhost"` → `INADDR_ANY`); port number or `PORT_ANY` for ephemeral.
- **Outputs/Return:** Socket FD on success; `0` on any failure.
- **Side effects:** Allocates an OS socket FD; prints errors via `Com_Printf`.
- **Calls:** `socket`, `ioctl(FIONBIO)`, `setsockopt(SO_BROADCAST)`, `NET_StringToSockaddr`, `bind`, `close`, `NET_ErrorString`
- **Notes:** Uses `stricmp` for "localhost" comparison — non-POSIX but common in Quake codebases.

### NET_GetPacket
- **Signature:** `qboolean NET_GetPacket(netsrc_t sock, netadr_t *net_from, sizebuf_t *net_message)`
- **Purpose:** Reads one inbound packet from the loopback buffer or a real UDP socket.
- **Inputs:** Socket channel enum, output address pointer, output message buffer.
- **Outputs/Return:** `true` if a packet was received and placed in `net_message`.
- **Side effects:** Advances loopback `get` index; fills `net_message->data` and `cursize`.
- **Calls:** `NET_GetLoopPacket`, `recvfrom`, `SockadrToNetadr`, `NET_ErrorString`, `NET_AdrToString`, `Com_Printf`
- **Notes:** Iterates protocol=0 (IP) then protocol=1 (IPX); `EWOULDBLOCK`/`ECONNREFUSED` are silently skipped. Oversize packets are logged and dropped.

### NET_SendPacket
- **Signature:** `void NET_SendPacket(netsrc_t sock, int length, void *data, netadr_t to)`
- **Purpose:** Dispatches a packet to the correct socket based on address type.
- **Inputs:** Channel, byte length, data pointer, destination `netadr_t`.
- **Outputs/Return:** None.
- **Side effects:** Writes to loopback or calls `sendto`; logs errors via `Com_Printf`; calls `Com_Error` on unknown address type.
- **Calls:** `NET_SendLoopPacket`, `NetadrToSockadr`, `sendto`, `NET_ErrorString`

### NET_Config
- **Signature:** `void NET_Config(qboolean multiplayer)`
- **Purpose:** Opens or closes all network sockets depending on game mode.
- **Inputs:** `true` to open sockets for multiplayer; `false` to close all.
- **Side effects:** Modifies `ip_sockets[]` and `ipx_sockets[]`; calls `close()`.
- **Calls:** `NET_OpenIP`, `NET_OpenIPX`, `close`
- **Notes:** Single-player relies entirely on loopback; no sockets needed.

### NET_Sleep
- **Signature:** `void NET_Sleep(int msec)`
- **Purpose:** Blocks the dedicated server up to `msec` milliseconds, waking on socket or stdin activity.
- **Inputs:** Timeout in milliseconds.
- **Side effects:** Calls `select`; checks extern `dedicated` cvar and `stdin_active` flag.
- **Calls:** `FD_ZERO`, `FD_SET`, `select`
- **Notes:** No-ops if not a dedicated server. References two externs not defined in this file.

### Notes (trivial helpers)
- `NetadrToSockadr` / `SockadrToNetadr`: bidirectional struct conversion between engine and POSIX address types.
- `NET_CompareAdr` / `NET_CompareBaseAdr`: byte-level equality checks; `NET_CompareBaseAdr` ignores port.
- `NET_AdrToString` / `NET_BaseAdrToString`: format IP to static string buffer (not thread-safe).
- `NET_StringToSockaddr` / `NET_StringToAdr`: parse dotted-decimal or hostname strings; handle optional `:port` suffix.
- `NET_GetLoopPacket` / `NET_SendLoopPacket`: ring-buffer loopback I/O; `send` targets the opposite channel (`sock^1`).
- `NET_Init`: empty stub; initialization deferred to `NET_Config`.
- `NET_Shutdown`: delegates to `NET_Config(false)`.
- `NET_ErrorString`: returns `strerror(errno)`.

## Control Flow Notes
- `NET_Init` is called at engine startup (no-op here).
- `NET_Config(true/false)` is called when game mode changes (single-player ↔ multiplayer).
- Each frame the engine calls `NET_GetPacket` for both NS_CLIENT and NS_SERVER channels to drain incoming data.
- `NET_SendPacket` is called throughout the frame by client and server subsystems.
- `NET_Sleep` is called by the dedicated server main loop to yield CPU between frames.

## External Dependencies
- **Includes:** `qcommon/qcommon.h` (engine types: `netadr_t`, `sizebuf_t`, `netsrc_t`, `MAX_MSGLEN`, `PORT_SERVER`, `PORT_ANY`, `NA_*`, `NS_*`)
- **System headers:** `sys/socket.h`, `netinet/in.h`, `netdb.h`, `sys/ioctl.h`, `errno.h`, `unistd.h`
- **Defined elsewhere:** `Com_Printf`, `Com_Error`, `Com_sprintf`, `Cvar_Get`, `net_local_adr` type constants, `dedicated` cvar, `stdin_active` flag (both `extern` in `NET_Sleep`)
- **IPX:** Declared and array-allocated but `NET_OpenIPX` is an empty stub — IPX is not implemented on Linux.
