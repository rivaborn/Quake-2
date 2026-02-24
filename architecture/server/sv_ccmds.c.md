# server/sv_ccmds.c

## File Purpose
Implements operator-only console commands for the Quake 2 server, including map control, savegame management, server demo recording, and client administration. Commands are accessible only from stdin or a remote operator datagram.

## Core Responsibilities
- Register all operator console commands via `SV_InitOperatorCommands`
- Manage savegame lifecycle: write, read, copy, and wipe save slots
- Handle map transitions with proper state serialization (`gamemap`, `map`, `demomap`)
- Administer clients: kick, status display, userinfo dump
- Control master server registration and heartbeat forcing
- Start/stop server-side demo recording
- Forward unknown commands to the game DLL via `ge->ServerCommand()`

## Key Types / Data Structures
None (uses types defined in `server.h`).

## Global / File-Static State
None declared in this file; all state accessed via externals (`svs`, `sv`, `ge`, `sv_client`, `sv_player`, `master_adr`).

## Key Functions

### SV_InitOperatorCommands
- Signature: `void SV_InitOperatorCommands(void)`
- Purpose: Registers all operator console commands with the command subsystem.
- Inputs: None (reads `dedicated->value` to conditionally register `say`).
- Outputs/Return: void
- Side effects: Populates the command table via repeated `Cmd_AddCommand` calls.
- Calls: `Cmd_AddCommand` (×16), reads `dedicated->value`.
- Notes: `say` is only registered on dedicated servers.

---

### SV_SetPlayer
- Signature: `qboolean SV_SetPlayer(void)`
- Purpose: Resolves a player identifier (slot number or name) from `Cmd_Argv(1)` and sets the globals `sv_client` and `sv_player`.
- Inputs: `Cmd_Argv(1)` — numeric slot index or player name string.
- Outputs/Return: `true` on success; `false` if not found or slot inactive.
- Side effects: Writes `sv_client`, `sv_player` globals.
- Calls: `Cmd_Argc`, `Cmd_Argv`, `atoi`, `strcmp`, `Com_Printf`.
- Notes: Used as a guard/resolver by `SV_Kick_f`, `SV_DumpUser_f`.

---

### SV_WipeSavegame
- Signature: `void SV_WipeSavegame(char *savename)`
- Purpose: Deletes all files in `save/<savename>/` — `.ssv`, `.sav`, and `.sv2` files.
- Inputs: `savename` — subdirectory name under `save/`.
- Outputs/Return: void
- Side effects: Filesystem deletions; uses `Sys_FindFirst`/`Sys_FindNext`/`Sys_FindClose` for glob iteration.
- Calls: `FS_Gamedir`, `Com_sprintf`, `remove`, `Sys_FindFirst`, `Sys_FindNext`, `Sys_FindClose`.

---

### SV_CopySaveGame
- Signature: `void SV_CopySaveGame(char *src, char *dst)`
- Purpose: Wipes `dst` slot, then copies all save files from `src` to `dst`, including paired `.sav`/`.sv2` files.
- Inputs: `src`, `dst` — save slot directory names.
- Side effects: Filesystem reads/writes; calls `SV_WipeSavegame`.
- Calls: `SV_WipeSavegame`, `CopyFile`, `FS_CreatePath`, `Sys_FindFirst`, `Sys_FindNext`, `Sys_FindClose`.

---

### SV_WriteLevelFile / SV_ReadLevelFile
- Signature: `void SV_WriteLevelFile(void)` / `void SV_ReadLevelFile(void)`
- Purpose: Serialize/deserialize per-level state — `sv.configstrings`, portal state, and game-DLL level data — to/from `save/current/<mapname>.sv2` and `.sav`.
- Side effects: Filesystem I/O; calls `ge->WriteLevel`/`ge->ReadLevel` into the game DLL.
- Calls: `CM_WritePortalState`/`CM_ReadPortalState`, `ge->WriteLevel`/`ge->ReadLevel`, `FS_Read`, `fwrite`.

---

### SV_WriteServerFile / SV_ReadServerFile
- Signature: `void SV_WriteServerFile(qboolean autosave)` / `void SV_ReadServerFile(void)`
- Purpose: Serialize/deserialize server-global state — comment, mapcmd, all `CVAR_LATCH` cvars — to/from `server.ssv`; also invokes game DLL game-state save/load.
- Side effects: Filesystem I/O; `SV_ReadServerFile` calls `SV_InitGame` and restores cvars via `Cvar_ForceSet`; calls `ge->WriteGame`/`ge->ReadGame`.
- Notes: Autosave writes `"ENTERING <mapname>"` as comment; manual save writes a timestamp.

---

### SV_GameMap_f
- Signature: `void SV_GameMap_f(void)`
- Purpose: Saves current level state (if in-game) and transitions to the next map; archives to autosave slot on non-dedicated servers.
- Inputs: `Cmd_Argv(1)` — map name; leading `*` clears current savegame.
- Side effects: Temporarily clears `cl->edict->inuse` flags for all clients during level write; calls `malloc`/`free`; invokes `SV_Map`, `SV_WriteLevelFile`, `SV_WriteServerFile`, `SV_CopySaveGame`.
- Notes: Core map-change path; `SV_Map_f` delegates here after resetting state.

---

### SV_ServerRecord_f / SV_ServerStop_f
- Signature: `void SV_ServerRecord_f(void)` / `void SV_ServerStop_f(void)`
- Purpose: Begin/end server-side demo recording to `demos/<name>.dm2`. The startup message writes a complete snapshot of configstrings and protocol handshake.
- Side effects: Opens/closes `svs.demofile`; initializes `svs.demo_multicast`; writes binary demo header via `MSG_Write*` into a stack buffer.

---

### Notes (minor functions)
- `CopyFile`: Raw binary file copy using a 64 KB stack buffer.
- `SV_SetMaster_f`: Parses master server addresses, pings them, resets heartbeat timer.
- `SV_Kick_f`, `SV_ConSay_f`, `SV_Status_f`, `SV_DumpUser_f`: Thin client-management wrappers.
- `SV_Heartbeat_f`: Forces immediate heartbeat by setting `svs.last_heartbeat = -9999999`.
- `SV_KillServer_f`: Calls `SV_Shutdown` then `NET_Config(false)`.
- `SV_ServerCommand_f`: Forwards raw command to `ge->ServerCommand()`.

## Control Flow Notes
- `SV_InitOperatorCommands` is called once during server initialization.
- Map transitions flow: `SV_Map_f` → sets `ss_dead`, wipes save, calls `SV_GameMap_f` → saves level, calls `SV_Map`.
- Load flow: `SV_Loadgame_f` → `SV_CopySaveGame` → `SV_ReadServerFile` (calls `SV_InitGame` internally) → `SV_Map`.
- Save flow: `SV_Savegame_f` → `SV_WriteLevelFile` → `SV_WriteServerFile` → `SV_CopySaveGame`.

## External Dependencies
- **Includes**: `server.h` (pulls in all server types, `sv`, `svs`, `ge`, `sv_client`, `sv_player`, `master_adr`)
- **Defined elsewhere**: `SV_Map`, `SV_InitGame`, `SV_Shutdown`, `SV_DropClient`, `SV_BroadcastPrintf`, `SV_ClientPrintf`, `CM_WritePortalState`, `CM_ReadPortalState`, `NET_StringToAdr`, `NET_AdrToString`, `NET_Config`, `Netchan_OutOfBandPrint`, `FS_Gamedir`, `FS_CreatePath`, `FS_LoadFile`, `FS_Read`, `Cvar_Set`, `Cvar_ForceSet`, `Cvar_VariableValue`, `Cvar_VariableString`, `Cvar_Serverinfo`, `cvar_vars`, `Cmd_AddCommand`, `Cmd_Argc`, `Cmd_Argv`, `Cmd_Args`, `Info_Print`, `SZ_Init`, `MSG_Write*`, `Sys_FindFirst`, `Sys_FindNext`, `Sys_FindClose`, `ge->WriteLevel/ReadLevel/WriteGame/ReadGame/ServerCommand`
