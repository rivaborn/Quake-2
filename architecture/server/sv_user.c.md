# server/sv_user.c

## File Purpose
Handles server-side processing of messages received from connected clients, including the connection handshake sequence (new/configstrings/baselines/begin), file downloads, and per-frame user command (movement) execution.

## Core Responsibilities
- Drive the client connection state machine (cs_connected → cs_spawned) via `new`/`configstrings`/`baselines`/`begin` command sequence
- Stream configstrings and entity baselines to connecting clients in chunked packets
- Serve file download requests with access control and offset resumption
- Parse and dispatch incoming client network messages (move commands, string commands, userinfo updates)
- Replay dropped packets by re-submitting cached movement commands
- Route string commands to built-in handlers or the game DLL's `ClientCommand`
- Advance cinematic/demo/pic servers to the next server in sequence

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `ucmd_t` | struct | Maps a string command name to a handler function pointer |
| `ucmds[]` | array of `ucmd_t` | Dispatch table for all recognized client string commands |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `sv_player` | `edict_t *` | global | Shortcut to the current client's game entity; set before command dispatch |

## Key Functions

### SV_New_f
- Signature: `void SV_New_f(void)`
- Purpose: Sends initial server handshake data to a newly connected client and begins the configstring fetch sequence.
- Inputs: Implicit — `sv_client` global; `sv`, `svs` server state.
- Outputs/Return: Writes `svc_serverdata` + stuffed `cmd configstrings` into client's netchan message buffer.
- Side effects: Sets `sv_client->edict`, clears `sv_client->lastcmd`; may call `SV_BeginDemoserver`.
- Calls: `SV_BeginDemoserver`, `Cvar_VariableString`, `MSG_Write*`, `EDICT_NUM`, `memset`, `va`.
- Notes: Guards against re-entry if client is already `cs_spawned`. Spawncount mismatch detection is handled in downstream handlers, not here.

### SV_Configstrings_f
- Signature: `void SV_Configstrings_f(void)`
- Purpose: Streams configstrings to a connecting client in chunks bounded by `MAX_MSGLEN/2`.
- Inputs: `Cmd_Argv(1)` = spawncount, `Cmd_Argv(2)` = start index.
- Outputs/Return: Writes `svc_configstring` messages; stuffs continuation or `cmd baselines` command.
- Side effects: Appends to `sv_client->netchan.message`.
- Calls: `SV_New_f` (on spawncount mismatch), `MSG_WriteByte`, `MSG_WriteShort`, `MSG_WriteString`, `va`.
- Notes: Skips empty configstrings. Chunked design prevents oversized packets.

### SV_Baselines_f
- Signature: `void SV_Baselines_f(void)`
- Purpose: Streams entity baseline states to a connecting client in chunks.
- Inputs: `Cmd_Argv(1)` = spawncount, `Cmd_Argv(2)` = start entity index.
- Outputs/Return: Writes `svc_spawnbaseline` delta-encoded messages; stuffs `precache` or continuation command.
- Side effects: Appends to `sv_client->netchan.message`.
- Calls: `SV_New_f`, `MSG_WriteDeltaEntity`, `MSG_WriteByte`, `MSG_WriteString`, `va`, `memset`.
- Notes: Only writes entities with non-zero `modelindex`, `sound`, or `effects`.

### SV_Begin_f
- Signature: `void SV_Begin_f(void)`
- Purpose: Finalizes client connection; transitions client to `cs_spawned` and notifies the game DLL.
- Inputs: `Cmd_Argv(1)` = spawncount.
- Outputs/Return: None directly; side effects complete the handshake.
- Side effects: Sets `sv_client->state = cs_spawned`; calls `ge->ClientBegin(sv_player)`; flushes deferred commands via `Cbuf_InsertFromDefer`.
- Calls: `SV_New_f`, `ge->ClientBegin`, `Cbuf_InsertFromDefer`.

### SV_BeginDownload_f / SV_NextDownload_f
- Signature: `void SV_BeginDownload_f(void)` / `void SV_NextDownload_f(void)`
- Purpose: `BeginDownload` validates access controls, loads the requested file, and sends the first chunk. `NextDownload` sends subsequent 1 KB chunks until complete.
- Inputs: `BeginDownload`: `Cmd_Argv(1)` = filename, `Cmd_Argv(2)` = optional byte offset. `NextDownload`: implicit client download state.
- Outputs/Return: Writes `svc_download` messages; sends `-1` size on denial/failure.
- Side effects: `FS_LoadFile`/`FS_FreeFile` on `sv_client->download`; updates `downloadcount`.
- Calls: `FS_LoadFile`, `FS_FreeFile`, `SZ_Write`, `MSG_Write*`.
- Notes: Path traversal (`..`), leading `/`, leading `.`, and pak-sourced maps are all denied. Per-category cvars (`allow_download_*`) gate each asset type. `strncmp` prefix lengths for `players/` and `models/` are both `6`, a likely copy-paste bug (should be `8` and `7` respectively).

### SV_ExecuteUserCommand
- Signature: `void SV_ExecuteUserCommand(char *s)`
- Purpose: Tokenizes a string command and dispatches it to a built-in handler or the game DLL.
- Inputs: Raw command string `s`.
- Outputs/Return: None.
- Side effects: Sets `sv_player`; may invoke any `ucmds[]` handler or `ge->ClientCommand`.
- Calls: `Cmd_TokenizeString`, handler via `ucmds[]` table, `ge->ClientCommand`.

### SV_ExecuteClientMessage
- Signature: `void SV_ExecuteClientMessage(client_t *cl)`
- Purpose: Main per-client message pump; parses the incoming `net_message` and dispatches all contained commands for one frame.
- Inputs: `cl` — the client whose message buffer is being processed; reads from global `net_message`.
- Outputs/Return: None.
- Side effects: May call `SV_DropClient`; updates `cl->lastframe`, `cl->frame_latency[]`, `cl->lastcmd`, `cl->userinfo`; invokes `ge->ClientThink` for movement.
- Calls: `MSG_ReadByte/Long/String/DeltaUsercmd`, `SV_ClientThink`, `SV_ExecuteUserCommand`, `SV_DropClient`, `SV_UserinfoChanged`, `COM_BlockSequenceCRCByte`.
- Notes: Enforces one `clc_move` per message; caps string commands at `MAX_STRINGCMDS` (8) to prevent spam. Dropped-packet replay re-submits `lastcmd` up to 20 drop slots. CRC checksum validation guards movement data integrity.

### SV_Nextserver / SV_Nextserver_f
- Purpose: Advances to the next map/cinematic in sequence; reads the `nextserver` cvar and stuffs the command into `Cbuf`.
- Notes: `SV_Nextserver` guards against advancing out of a live game (`ss_game`) except in coop `ss_pic` mode.

## Control Flow Notes
- Called from `sv_main.c` during the per-frame client processing loop.
- `SV_ExecuteClientMessage` is the primary entry point each frame per client.
- The connection handshake flows: `SV_New_f` → `SV_Configstrings_f` (possibly multiple calls) → `SV_Baselines_f` (possibly multiple calls) → client `precache` → `SV_Begin_f`; each step is triggered by a stuffed command the client echoes back.

## External Dependencies
- **Includes:** `server.h` (pulls in `sv_client`, `svs`, `sv`, `ge`, message/netchan types)
- **Defined elsewhere:** `sv_client` (`server.h`/`sv_main.c`), `net_message` (global read buffer), `ge` (game export interface), `svs`/`sv` (server state), `MSG_*`/`SZ_Write`/`COM_BlockSequenceCRCByte` (qcommon), `FS_LoadFile`/`FS_FreeFile`/`FS_FOpenFile` (files.c), `Cvar_*`/`Cbuf_*`/`Cmd_*` (qcommon), `allow_download*` cvars (sv_main.c), `file_from_pak` (files.c)
