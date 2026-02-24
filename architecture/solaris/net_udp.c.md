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

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `loopmsg_t` | struct | Single loopback message holding raw bytes and length |
| `loopback_t` | struct | Ring buffer of `MAX_LOOPBACK` messages with get/send indices |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `net_local_adr` | `netadr_t` | global | Canonical local address used as source for loopback packets |
| `loopbacks[2]` | `loopback_t[2]` | global | One ring buffer per network source (NS_CLIENT / NS_SERVER) |
| `ip_sockets[2]` | `int[2]` | global | UDP socket FDs indexed by `netsrc_t` (client/server) |
| `ipx_sockets[2]` | `int[2]` | global | IPX socket FDs (unused on Solaris; always 0) |

## Key Functions

### NET_Socket
- **Signature:** `int NET_Socket(char *net_interface, int port)`
- **Purpose:** Creates, configures, and binds a non-blocking broadcast-capable UDP socket.
- **Inputs:** Interface name or IP string; port number (`PORT_ANY` binds ephemeral).
- **Outputs/Return:** Socket FD on success, `0` on failure.
- **Side effects:** Allocates OS socket; prints errors via `Com_Printf`.
- **Calls:** `socket`, `ioctl(FIONBIO)`, `setsockopt(SO_BROADCAST)`, `NET_StringToSockaddr`, `bind`, `close`, `NET_ErrorString`
- **Notes:** Uses `INADDR_ANY` when interface is empty or `"localhost"`.

### NET_GetPacket
- **Signature:** `qboolean NET_GetPacket(netsrc_t sock, netadr_t *net_from, sizebuf_t *net_message)`
- **Purpose:** Reads one incoming packet—loopback first, then IP, then IPX sockets.
- **Inputs:** Which side (`NS_CLIENT`/`NS_SERVER`), output address and message buffer.
- **Outputs/Return:** `true` if a packet was received and placed in `net_message`.
- **Side effects:** Advances loopback `get` index; fills `net_message->data` and `cursize`.
- **Calls:** `NET_GetLoopPacket`, `recvfrom`, `SockadrToNetadr`, `Com_Printf`, `NET_AdrToString`, `NET_ErrorString`
- **Notes:** Silently drops oversized packets and EWOULDBLOCK/ECONNREFUSED errors.

### NET_SendPacket
- **Signature:** `void NET_SendPacket(netsrc_t sock, int length, void *data, netadr_t to)`
- **Purpose:** Dispatches a packet to loopback or a real UDP socket based on destination type.
- **Inputs:** Source side, byte count, payload pointer, destination address.
- **Outputs/Return:** None.
- **Side effects:** Writes to loopback ring or calls `sendto`; fatal error on unknown address type.
- **Calls:** `NET_SendLoopPacket`, `NetadrToSockadr`, `sendto`, `Com_Error`, `NET_ErrorString`

### NET_Config
- **Signature:** `void NET_Config(qboolean multiplayer)`
- **Purpose:** Toggles networking on/off; closes sockets for singleplayer, opens them for multiplayer.
- **Inputs:** `multiplayer` flag.
- **Side effects:** Opens or `close()`s `ip_sockets` and `ipx_sockets`; calls `NET_OpenIP`.
- **Calls:** `close`, `NET_OpenIP`, `NET_OpenIPX`

### NET_Sleep
- **Signature:** `void NET_Sleep(int msec)`
- **Purpose:** Blocks the dedicated server up to `msec` milliseconds or until the server socket or stdin is readable.
- **Inputs:** Timeout in milliseconds.
- **Side effects:** Blocks calling thread via `select`.
- **Calls:** `select`, `FD_ZERO`, `FD_SET`
- **Notes:** Returns immediately if not a dedicated server or no server socket is open. Externally references `dedicated` cvar and `stdin_active`.

### Notes on minor helpers
- `NetadrToSockadr` / `SockadrToNetadr`: trivial struct field copies between engine and POSIX address types.
- `NET_CompareAdr` / `NET_CompareBaseAdr`: byte-level IP equality; base variant ignores port and handles loopback/IPX.
- `NET_AdrToString` / `NET_BaseAdrToString`: format into static 64-byte buffers (not reentrant).
- `NET_StringToSockaddr`: resolves dotted-decimal or hostname + optional `:port` via `gethostbyname`.
- `NET_Init` / `NET_Shutdown`: `Init` is a no-op; `Shutdown` calls `NET_Config(false)`.

## Control Flow Notes
`NET_Init` is called at engine startup (no-op here). `NET_Config(true)` is called when a multiplayer session begins, opening sockets. Each frame the engine calls `NET_GetPacket` and `NET_SendPacket` for both client and server sides. `NET_Sleep` is used in the dedicated server loop to yield CPU. `NET_Shutdown` / `NET_Config(false)` closes all sockets on exit.

## External Dependencies
- `../qcommon/qcommon.h` — `netadr_t`, `netsrc_t`, `sizebuf_t`, `Com_Printf`, `Com_Error`, `Com_sprintf`, `Cvar_Get`, `PORT_SERVER`, `PORT_ANY`, `MAX_MSGLEN`
- POSIX: `<sys/socket.h>`, `<netinet/in.h>`, `<netdb.h>`, `<sys/ioctl.h>`, `<sys/filio.h>`, `<errno.h>`
- `dedicated` cvar and `stdin_active` — defined elsewhere in the engine
- `NET_ErrorString` wraps `strerror(errno)` — defined in this file
- `stricmp` — not standard POSIX; assumed provided by platform headers or `qcommon.h`
