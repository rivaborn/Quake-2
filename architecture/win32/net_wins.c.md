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

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `loopmsg_t` | struct | Single loopback message: raw bytes + length |
| `loopback_t` | struct | Ring buffer of `MAX_LOOPBACK` (4) loopback messages with `get`/`send` indices |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `loopbacks[2]` | `loopback_t` | global | One ring buffer per socket role (NS_CLIENT / NS_SERVER) |
| `ip_sockets[2]` | `int` | global | UDP socket handles per role |
| `ipx_sockets[2]` | `int` | global | IPX socket handles per role |
| `net_shownet` | `cvar_t *` | global | Console variable for net debug output |
| `noudp` | `cvar_t *` | static | Disables UDP socket creation when set |
| `noipx` | `cvar_t *` | static | Disables IPX socket creation when set |
| `winsockdata` | `WSADATA` | static | WinSock library initialization data |

## Key Functions

### NET_Init
- **Signature:** `void NET_Init(void)`
- **Purpose:** Bootstraps WinSock 1.1, registers cvars (`noudp`, `noipx`, `net_shownet`)
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** Calls `WSAStartup`; fatal error on failure
- **Calls:** `WSAStartup`, `Com_Error`, `Com_Printf`, `Cvar_Get`
- **Notes:** Must be called before any socket operation

### NET_Shutdown
- **Signature:** `void NET_Shutdown(void)`
- **Purpose:** Closes all open sockets and shuts down WinSock
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** Calls `NET_Config(false)`, then `WSACleanup`
- **Calls:** `NET_Config`, `WSACleanup`

### NET_Config
- **Signature:** `void NET_Config(qboolean multiplayer)`
- **Purpose:** Toggles network sockets on/off; singleplayer uses only loopback
- **Inputs:** `multiplayer` — true to open sockets, false to close all
- **Outputs/Return:** None
- **Side effects:** Opens/closes `ip_sockets` and `ipx_sockets`; guarded by `old_config` to avoid redundant transitions
- **Calls:** `NET_OpenIP`, `NET_OpenIPX`, `closesocket`
- **Notes:** `old_config` is `static`, so repeated calls with same value are no-ops

### NET_GetPacket
- **Signature:** `qboolean NET_GetPacket(netsrc_t sock, netadr_t *net_from, sizebuf_t *net_message)`
- **Purpose:** Reads next inbound packet; checks loopback first, then IP socket, then IPX socket
- **Inputs:** `sock` — NS_CLIENT or NS_SERVER; output pointers for sender address and message buffer
- **Outputs/Return:** `true` if a packet was received
- **Side effects:** Populates `net_from` and `net_message->data`/`cursize`
- **Calls:** `NET_GetLoopPacket`, `recvfrom`, `WSAGetLastError`, `SockadrToNetadr`, `Com_Printf`, `Com_Error`
- **Notes:** Oversize packets are silently dropped with a warning; `WSAEWOULDBLOCK` is treated as "no data"

### NET_SendPacket
- **Signature:** `void NET_SendPacket(netsrc_t sock, int length, void *data, netadr_t to)`
- **Purpose:** Dispatches a packet to the appropriate socket based on destination address type
- **Inputs:** Socket role, byte length, data pointer, destination `netadr_t`
- **Outputs/Return:** None
- **Side effects:** Calls `sendto` on the OS socket; routes loopback to `NET_SendLoopPacket`
- **Calls:** `NET_SendLoopPacket`, `NetadrToSockadr`, `sendto`, `WSAGetLastError`, `Com_Error`, `Com_Printf`, `Com_DPrintf`
- **Notes:** `WSAEWOULDBLOCK` and broadcast-unavailable on PPP (`WSAEADDRNOTAVAIL`) are silently swallowed

### NET_IPSocket
- **Signature:** `int NET_IPSocket(char *net_interface, int port)`
- **Purpose:** Creates, configures (non-blocking, broadcast), and binds a UDP socket
- **Inputs:** Interface address string (or NULL/"localhost" for `INADDR_ANY`), port number
- **Outputs/Return:** Socket handle on success, 0 on failure
- **Side effects:** Allocates an OS socket descriptor
- **Calls:** `socket`, `ioctlsocket`, `setsockopt`, `NET_StringToSockaddr`, `bind`, `closesocket`

### NET_IPXSocket
- **Signature:** `int NET_IPXSocket(int port)`
- **Purpose:** Creates, configures, and binds an IPX datagram socket
- **Inputs:** Port (socket number)
- **Outputs/Return:** Socket handle on success, 0 on failure
- **Side effects:** Allocates an OS socket descriptor
- **Calls:** `socket`, `ioctlsocket`, `setsockopt`, `bind`, `closesocket`

### NET_Sleep
- **Signature:** `void NET_Sleep(int msec)`
- **Purpose:** Blocks the dedicated server up to `msec` milliseconds waiting for socket activity
- **Inputs:** Timeout in milliseconds
- **Outputs/Return:** None
- **Side effects:** Calls `select` on server sockets; returns immediately for non-dedicated clients
- **Calls:** `select`, `FD_ZERO`, `FD_SET`

### NET_StringToAdr
- **Signature:** `qboolean NET_StringToAdr(char *s, netadr_t *a)`
- **Purpose:** Parses a string address ("localhost", hostname, dotted-decimal, IPX) into `netadr_t`
- **Inputs:** Address string, output `netadr_t`
- **Outputs/Return:** `true` on success
- **Calls:** `NET_StringToSockaddr`, `SockadrToNetadr`

- **Notes:** `NetadrToSockadr`/`SockadrToNetadr`, `NET_CompareAdr`, `NET_CompareBaseAdr`, `NET_AdrToString`, `NET_GetLoopPacket`, `NET_SendLoopPacket`, `NET_ErrorString`, `NET_IsLocalAddress`, `NET_OpenIP`, `NET_OpenIPX` are straightforward helpers not requiring full entries.

## Control Flow Notes
- Called during engine startup via `NET_Init`, then `NET_Config(true)` when multiplayer begins.
- Each server frame calls `NET_GetPacket` (NS_SERVER) to drain inbound packets; `NET_Sleep` throttles the dedicated server loop between frames.
- Singleplayer: `NET_Config(false)` leaves only loopback active; client and server exchange packets via the ring buffers in `loopbacks[2]`.
- On shutdown: `NET_Shutdown` → `NET_Config(false)` → `WSACleanup`.

## External Dependencies
- **Includes:** `<winsock.h>`, `<wsipx.h>`, `../qcommon/qcommon.h`
- **Defined elsewhere:** `netadr_t`, `netsrc_t`, `sizebuf_t`, `NS_CLIENT`, `NS_SERVER`, `PORT_ANY`, `PORT_SERVER`, `PORT_CLIENT`, `MAX_MSGLEN`, `dedicated` (cvar), `Cvar_Get`, `Cvar_VariableValue`, `Com_Printf`, `Com_DPrintf`, `Com_Error`, `Com_sprintf`, `va`
