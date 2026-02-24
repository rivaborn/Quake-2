# server/sv_ents.c

## File Purpose
Encodes the server-side game world state into network messages for delivery to clients. Handles per-frame delta compression of entity states and player states, per-client visibility culling, and demo file recording.

## Core Responsibilities
- Build per-client visibility frames using PVS/PHS culling (`SV_BuildClientFrame`)
- Delta-encode the entity list into packet entity messages (`SV_EmitPacketEntities`)
- Delta-encode player state into `svc_playerinfo` messages (`SV_WritePlayerstateToClient`)
- Assemble and write complete frame messages to clients (`SV_WriteFrameToClient`)
- Compute a "fat PVS" covering the client's interpolation range (`SV_FatPVS`)
- Record demo messages with full (non-delta) entity snapshots
- (Disabled) Experimental compact projectile network protocol via `#if 0` blocks

## Key Types / Data Structures
None defined in this file; relies on types from `server.h`.

## Global / File-Static State
| Name | Type | Scope | Purpose |
|------|-------|--------|---------|
| `fatpvs` | `byte[65536/8]` | static (file-level) | Accumulated PVS bitmask covering client viewpoint ± 8 units; recomputed each frame per client |

## Key Functions

### SV_FatPVS
- **Signature:** `void SV_FatPVS(vec3_t org)`
- **Purpose:** Builds `fatpvs` by OR-ing cluster PVS bitmasks for all BSP leafs within an 8-unit box around `org`, covering client interpolation movement.
- **Inputs:** `org` — client eye position
- **Outputs/Return:** Writes result into `fatpvs` global
- **Side effects:** Overwrites `fatpvs`; calls `CM_BoxLeafnums`, `CM_ClusterPVS`, `CM_NumClusters`
- **Calls:** `CM_BoxLeafnums`, `CM_LeafCluster`, `CM_ClusterPVS`, `CM_NumClusters`, `Com_Error`
- **Notes:** Deduplicates clusters before OR-ing. Fatals if no leafs found.

### SV_BuildClientFrame
- **Signature:** `void SV_BuildClientFrame(client_t *client)`
- **Purpose:** Constructs a `client_frame_t` snapshot: runs PVS/PHS/area culling over all edicts, copies visible entity states into the circular `svs.client_entities` ring buffer, and captures the player state and area bits.
- **Inputs:** `client` — the target client
- **Outputs/Return:** Populates `client->frames[sv.framenum & UPDATE_MASK]`
- **Side effects:** Advances `svs.next_client_entities`; writes into `svs.client_entities`; calls `SV_FatPVS`
- **Calls:** `CM_PointLeafnum`, `CM_LeafArea`, `CM_LeafCluster`, `CM_WriteAreaBits`, `SV_FatPVS`, `CM_ClusterPHS`, `CM_AreasConnected`, `CM_HeadnodeVisible`, `EDICT_NUM`, `VectorSubtract`, `VectorLength`, `Com_DPrintf`
- **Notes:** Skips `SVF_NOCLIENT` entities. Sound-only entities culled at >400 units. Players' own missiles have `solid` cleared. Entity number fixup emits a debug print if `ent->s.number` is inconsistent.

### SV_EmitPacketEntities
- **Signature:** `void SV_EmitPacketEntities(client_frame_t *from, client_frame_t *to, sizebuf_t *msg)`
- **Purpose:** Writes a delta-compressed entity list into `msg`. Entities are compared by number; new entities delta from baselines, removed entities emit `U_REMOVE`, unchanged/moved entities delta from old state.
- **Inputs:** `from` — previous acknowledged frame (NULL for full update); `to` — current frame; `msg` — output buffer
- **Outputs/Return:** Writes directly into `msg`
- **Side effects:** None beyond writing to `msg`
- **Calls:** `MSG_WriteByte`, `MSG_WriteShort`, `MSG_WriteDeltaEntity`
- **Notes:** Terminates list with `MSG_WriteShort(msg, 0)`. `U_NUMBER16` used for entity numbers ≥ 256. Player entities always sent as "new entity" forcing `oldorigin` update to prevent warping.

### SV_WritePlayerstateToClient
- **Signature:** `void SV_WritePlayerstateToClient(client_frame_t *from, client_frame_t *to, sizebuf_t *msg)`
- **Purpose:** Delta-encodes the `player_state_t` (pmove, viewangles, weapon, blend, FOV, stats) into `msg`.
- **Inputs:** `from` — prior frame (NULL → zero baseline); `to` — current frame; `msg` — output buffer
- **Outputs/Return:** Writes into `msg`
- **Side effects:** None beyond writing to `msg`
- **Calls:** `MSG_WriteByte`, `MSG_WriteShort`, `MSG_WriteChar`, `MSG_WriteAngle16`, `MSG_WriteLong`
- **Notes:** `PS_WEAPONINDEX` is always written unconditionally. Stats are packed into a 32-bit bitmask; only changed stats are sent.

### SV_WriteFrameToClient
- **Signature:** `void SV_WriteFrameToClient(client_t *client, sizebuf_t *msg)`
- **Purpose:** Writes one complete `svc_frame` message: frame number, delta reference, suppressed packet count, area bits, player state, and packet entities.
- **Inputs:** `client`, `msg`
- **Side effects:** Resets `client->surpressCount` to 0
- **Calls:** `SV_WritePlayerstateToClient`, `SV_EmitPacketEntities`, `MSG_WriteByte`, `MSG_WriteLong`, `SZ_Write`
- **Notes:** Falls back to NULL `oldframe` if `lastframe` is stale by ≥ `UPDATE_BACKUP - 3` frames.

### SV_RecordDemoMessage
- **Signature:** `void SV_RecordDemoMessage(void)`
- **Purpose:** Writes a full (non-delta) entity snapshot to `svs.demofile`, followed by accumulated multicast data.
- **Side effects:** Writes to `svs.demofile`; clears `svs.demo_multicast`
- **Calls:** `EDICT_NUM`, `MSG_WriteDeltaEntity`, `SZ_Write`, `SZ_Clear`, `fwrite`, `LittleLong`
- **Notes:** Uses a zero-filled `nostate` as the delta base so every entity is fully encoded. Frame message omits player state.

## Control Flow Notes
- `SV_BuildClientFrame` is called once per server frame per connected client (from `sv_main.c`).
- `SV_WriteFrameToClient` is called when flushing updates to each client, consuming the frame built above.
- `SV_RecordDemoMessage` is called each server frame when a demo is active.

## External Dependencies
- **Includes:** `server.h` (pulls in `qcommon.h`, entity/client types, map collision API)
- **Defined elsewhere:** `svs`, `sv`, `ge`, `maxclients` (server globals); `MSG_WriteDeltaEntity`, `MSG_Write*` (net message encoding); `CM_*` (collision model / BSP visibility); `EDICT_NUM` (game entity accessor); `SZ_*` (size-buffer utilities)
