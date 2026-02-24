# server/sv_send.c

## File Purpose
Handles all outbound message transmission from the server to clients, including print messages, sound events, multicast spatial broadcasts, and per-frame client datagram assembly and rate-controlled delivery.

## Core Responsibilities
- Redirect `Com_Printf` output to packets or client message buffers
- Send targeted print messages to individual clients or all spawned clients
- Serialize and spatially filter sound events via PVS/PHS multicast
- Assemble and transmit per-frame datagrams to each spawned client
- Enforce per-client bandwidth rate limiting
- Drive demo playback by reading and forwarding recorded demo frames

## Key Types / Data Structures
None (uses types defined in `server.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|------|-------|-------|---------|
| `sv_outputbuf` | `char[SV_OUTPUTBUF_LENGTH]` | global | Shared buffer for redirected console output (packet/client redirect) |

## Key Functions

### SV_FlushRedirect
- **Signature:** `void SV_FlushRedirect(int sv_redirected, char *outputbuf)`
- **Purpose:** Flushes accumulated redirected console output either as an out-of-band packet print or into the current client's reliable message stream.
- **Inputs:** Redirect mode (`RD_PACKET` or `RD_CLIENT`), accumulated output buffer.
- **Outputs/Return:** None.
- **Side effects:** Writes to `net_from` (out-of-band) or `sv_client->netchan.message`.
- **Calls:** `Netchan_OutOfBandPrint`, `MSG_WriteByte`, `MSG_WriteString`
- **Notes:** Callback for the common redirect system; `sv_client` must be valid when `RD_CLIENT` is used.

### SV_ClientPrintf
- **Signature:** `void SV_ClientPrintf(client_t *cl, int level, char *fmt, ...)`
- **Purpose:** Sends a formatted print message to a single client if the message level meets the client's threshold.
- **Inputs:** Target client, print level, printf-style format string.
- **Outputs/Return:** None.
- **Side effects:** Appends `svc_print` to `cl->netchan.message`.
- **Calls:** `MSG_WriteByte`, `MSG_WriteString`
- **Notes:** Silently drops message if `level < cl->messagelevel`.

### SV_BroadcastPrintf
- **Signature:** `void SV_BroadcastPrintf(int level, char *fmt, ...)`
- **Purpose:** Sends a formatted print message to all `cs_spawned` clients whose message level threshold is met; also echoes to the dedicated server console with high-bit masking.
- **Inputs:** Print level, printf-style format string.
- **Outputs/Return:** None.
- **Side effects:** Writes to each qualifying client's `netchan.message`; calls `Com_Printf` on dedicated servers.
- **Calls:** `MSG_WriteByte`, `MSG_WriteString`, `Com_Printf`

### SV_BroadcastCommand
- **Signature:** `void SV_BroadcastCommand(char *fmt, ...)`
- **Purpose:** Stuffs a console command string to all clients via reliable multicast.
- **Inputs:** Printf-style command string.
- **Outputs/Return:** None.
- **Side effects:** Writes `svc_stufftext` into `sv.multicast`, then calls `SV_Multicast`.
- **Calls:** `MSG_WriteByte`, `MSG_WriteString`, `SV_Multicast`

### SV_Multicast
- **Signature:** `void SV_Multicast(vec3_t origin, multicast_t to)`
- **Purpose:** Delivers the contents of `sv.multicast` to spatially filtered clients (ALL / PVS / PHS), with optional reliability. Clears `sv.multicast` on exit.
- **Inputs:** World-space origin (may be NULL for ALL), multicast scope enum.
- **Outputs/Return:** None.
- **Side effects:** Appends to `client->netchan.message` (reliable) or `client->datagram` (unreliable) for each qualifying client; writes to `svs.demo_multicast` if recording; clears `sv.multicast`.
- **Calls:** `CM_PointLeafnum`, `CM_LeafCluster`, `CM_LeafArea`, `CM_ClusterPVS`, `CM_ClusterPHS`, `CM_AreasConnected`, `SZ_Write`, `SZ_Clear`, `Com_Error`
- **Notes:** Area connectivity is checked in addition to the cluster bitmask. `_R` variants set `reliable = true` via intentional fallthrough.

### SV_StartSound
- **Signature:** `void SV_StartSound(vec3_t origin, edict_t *entity, int channel, int soundindex, float volume, float attenuation, float timeofs)`
- **Purpose:** Serializes a sound event into `sv.multicast` with appropriate flags, then multicasts to PHS or all clients depending on channel flags and attenuation.
- **Inputs:** Optional explicit origin, source entity, channel (bit 3 = no-PHS, bit 4 = reliable), sound index, volume, attenuation, time offset.
- **Outputs/Return:** None.
- **Side effects:** Writes to `sv.multicast`; invokes `SV_Multicast`.
- **Calls:** `Com_Error`, `NUM_FOR_EDICT`, `MSG_WriteByte`, `MSG_WriteShort`, `MSG_WritePos`, `VectorCopy`, `SV_Multicast`
- **Notes:** `ATTN_NONE` forces `use_phs = false`. BSP entity origins are computed as bbox midpoints. Volume/attenuation/offset are only written when they differ from defaults.

### SV_SendClientDatagram
- **Signature:** `qboolean SV_SendClientDatagram(client_t *client)`
- **Purpose:** Builds the complete outbound frame for one client: entity/player state, then appends accumulated unreliable datagram data, and transmits.
- **Inputs:** Target client.
- **Outputs/Return:** Always `true`.
- **Side effects:** Calls `SV_BuildClientFrame`, `SV_WriteFrameToClient`; clears `client->datagram`; calls `Netchan_Transmit`; records message size for rate estimation.
- **Calls:** `SV_BuildClientFrame`, `SZ_Init`, `SV_WriteFrameToClient`, `SZ_Write`, `SZ_Clear`, `Com_Printf`, `Netchan_Transmit`

### SV_RateDrop
- **Signature:** `qboolean SV_RateDrop(client_t *c)`
- **Purpose:** Determines whether a client should be skipped this frame due to exceeding its bandwidth budget (rolling window over `RATE_MESSAGES` frames).
- **Inputs:** Client pointer.
- **Outputs/Return:** `true` if the client should be suppressed.
- **Side effects:** Increments `c->surpressCount`; zeroes current frame's message size slot.
- **Notes:** Loopback clients are never dropped.

### SV_SendClientMessages
- **Signature:** `void SV_SendClientMessages(void)`
- **Purpose:** Per-frame entry point that drives demo playback reads and dispatches outbound messages to every connected client based on their state.
- **Inputs:** None (reads global `sv`, `svs`, `curtime`).
- **Outputs/Return:** None.
- **Side effects:** Calls `SV_DemoCompleted`, `SV_DropClient`, `SV_BroadcastPrintf`, `SV_RateDrop`, `SV_SendClientDatagram`, `Netchan_Transmit` per client.
- **Notes:** Cinematic/demo/pic states bypass entity framing and send raw demo buffer. Clients not yet `cs_spawned` receive keepalive transmits only.

## Control Flow Notes
`SV_SendClientMessages` is the frame-level entry point called once per server frame (from `SV_Frame` in `sv_main.c`). It orchestrates: demo file reads → per-client overflow checks → rate limiting → `SV_SendClientDatagram` for spawned clients. `SV_Multicast` and `SV_StartSound` are called mid-frame by game logic to stage data into `sv.multicast` and per-client datagrams before `SV_SendClientMessages` flushes them.

## External Dependencies
- **Notable includes:** `server.h` (pulls in `qcommon.h`, `game.h`, client/server structs)
- **Defined elsewhere:** `sv_client` (current client context, `sv_main.c`), `net_from` (last received packet address, `net_chan.c`), `svs`/`sv` (server state globals), `maxclients`/`sv_paused`/`dedicated` (cvars), `CM_*` (collision model, `cmodel.c`), `SV_BuildClientFrame`/`SV_WriteFrameToClient` (`sv_ents.c`), `SV_DropClient`/`SV_Nextserver` (`sv_main.c`), `Netchan_*` (`net_chan.c`), `MSG_*`/`SZ_*` (`qcommon`)
