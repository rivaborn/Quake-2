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

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `netchan_t` | struct | Defined in `qcommon.h`; holds all per-connection state: sequences, reliable buffers, socket, remote address, qport |
| `sizebuf_t` | struct | Defined in `qcommon.h`; growable byte buffer used for packet assembly and reading |
| `netadr_t` | struct | Defined in `qcommon.h`; network address (IP + port) |
| `netsrc_t` | enum | Defined in `qcommon.h`; `NS_CLIENT` or `NS_SERVER`, selects socket and qport behavior |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `showpackets` | `cvar_t *` | global | Debug CVar; logs sent/received packet info |
| `showdrop` | `cvar_t *` | global | Debug CVar; logs dropped/out-of-order packets |
| `qport` | `cvar_t *` | global | Client's random port identifier; workaround for NAT remapping |
| `net_from` | `netadr_t` | global | Address of the last received packet's sender |
| `net_message` | `sizebuf_t` | global | Buffer for the most recently received packet |
| `net_message_buffer` | `byte[MAX_MSGLEN]` | global | Backing store for `net_message` |

## Key Functions

### Netchan_Init
- **Signature:** `void Netchan_Init(void)`
- **Purpose:** One-time initialization; registers CVars and picks a random qport from current milliseconds.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** Registers `showpackets`, `showdrop`, `qport` CVars; calls `Sys_Milliseconds()`.
- **Calls:** `Sys_Milliseconds`, `Cvar_Get`, `va`
- **Notes:** `qport` is seeded randomly to survive NAT remapping.

### Netchan_OutOfBand
- **Signature:** `void Netchan_OutOfBand(int net_socket, netadr_t adr, int length, byte *data)`
- **Purpose:** Sends a connectionless datagram prefixed with sequence `-1` (sentinel for out-of-band).
- **Inputs:** Socket handle, destination address, payload length and pointer.
- **Outputs/Return:** None
- **Side effects:** Calls `NET_SendPacket` (I/O).
- **Calls:** `SZ_Init`, `MSG_WriteLong`, `SZ_Write`, `NET_SendPacket`
- **Notes:** Sequence `-1` tells the receiver to handle this without an existing `netchan`.

### Netchan_OutOfBandPrint
- **Signature:** `void Netchan_OutOfBandPrint(int net_socket, netadr_t adr, char *format, ...)`
- **Purpose:** Convenience wrapper — formats a string then delegates to `Netchan_OutOfBand`.
- **Inputs:** Socket, address, printf-style format string + variadic args.
- **Outputs/Return:** None
- **Side effects:** Writes to static buffer; calls `NET_SendPacket` indirectly.
- **Calls:** `vsprintf`, `Netchan_OutOfBand`
- **Notes:** Uses a `static char` buffer of `MAX_MSGLEN - 4`; not thread-safe.

### Netchan_Setup
- **Signature:** `void Netchan_Setup(netsrc_t sock, netchan_t *chan, netadr_t adr, int qport)`
- **Purpose:** Zero-initializes and configures a new channel to a remote address.
- **Inputs:** Socket type, channel pointer, remote address, qport value.
- **Outputs/Return:** None (mutates `*chan`)
- **Side effects:** Sets `chan->last_received = curtime`; initializes `chan->message` sizebuf with overflow allowed.
- **Calls:** `memset`, `SZ_Init`

### Netchan_CanReliable
- **Signature:** `qboolean Netchan_CanReliable(netchan_t *chan)`
- **Purpose:** Returns true if no unacknowledged reliable message is pending.
- **Inputs:** Channel pointer.
- **Outputs/Return:** `true` if `reliable_length == 0`.
- **Side effects:** None.

### Netchan_NeedReliable
- **Signature:** `qboolean Netchan_NeedReliable(netchan_t *chan)`
- **Purpose:** Determines if a reliable message must be included in the next outgoing packet (either a drop was detected or the buffer has new data).
- **Inputs:** Channel pointer.
- **Outputs/Return:** Boolean.
- **Side effects:** None.
- **Notes:** Drop detection: `incoming_acknowledged > last_reliable_sequence` but `incoming_reliable_acknowledged != reliable_sequence`.

### Netchan_Transmit
- **Signature:** `void Netchan_Transmit(netchan_t *chan, int length, byte *data)`
- **Purpose:** Assembles and sends one UDP packet: 8-byte sequence header (+ 2-byte qport for clients), reliable payload if needed, then unreliable payload if space permits.
- **Inputs:** Channel, unreliable data length and pointer.
- **Outputs/Return:** None
- **Side effects:** Increments `chan->outgoing_sequence`; updates `chan->last_sent`; copies message buf to `reliable_buf`; calls `NET_SendPacket`.
- **Calls:** `Netchan_NeedReliable`, `SZ_Init`, `MSG_WriteLong`, `MSG_WriteShort`, `SZ_Write`, `NET_SendPacket`, `Com_Printf`, `NET_AdrToString`
- **Notes:** Sets `chan->fatal_error` on overflow. Unreliable data is silently dropped if it won't fit; reliable data always fits by design (MAX_MSGLEN constraint).

### Netchan_Process
- **Signature:** `qboolean Netchan_Process(netchan_t *chan, sizebuf_t *msg)`
- **Purpose:** Parses an incoming packet's header, validates sequence order, updates channel ACK state, and positions `msg` read pointer at the payload.
- **Inputs:** Channel, inbound message buffer.
- **Outputs/Return:** `false` if packet is stale/duplicate; `true` if valid.
- **Side effects:** Updates `chan->incoming_sequence`, `incoming_acknowledged`, `incoming_reliable_acknowledged`, `incoming_reliable_sequence`, `reliable_length`, `dropped`, `last_received`.
- **Calls:** `MSG_BeginReading`, `MSG_ReadLong`, `MSG_ReadShort`, `Com_Printf`, `NET_AdrToString`
- **Notes:** Out-of-order packets are discarded without killing the connection. Reliable ACK clears `reliable_length`, freeing the buffer for the next reliable message.

## Control Flow Notes
- **Init:** `Netchan_Init` is called once at engine startup from `NET_Init` / `Qcommon_Init`.
- **Per-frame send:** Game/server calls `Netchan_Transmit` each frame to push state to the remote.
- **Per-frame receive:** The network receive loop calls `Netchan_Process` on each arriving packet before dispatching payload to the client or server.
- Out-of-band functions (`Netchan_OutOfBand*`) are used during connection negotiation (challenges, connection requests) before a `netchan_t` is established.

## External Dependencies
- `qcommon.h` — types (`netchan_t`, `sizebuf_t`, `netadr_t`, `netsrc_t`, `cvar_t`), constants (`MAX_MSGLEN`)
- `NET_SendPacket`, `NET_AdrToString` — defined in platform network layer (`net_udp.c` / `net_wins.c`)
- `MSG_*`, `SZ_*` — message read/write utilities, defined in `qcommon/common.c`
- `Cvar_Get`, `Com_Printf` — engine common subsystems
- `Sys_Milliseconds` — platform timer, defined in platform `sys_*.c`
- `curtime` — global integer timestamp, defined elsewhere in `qcommon`
