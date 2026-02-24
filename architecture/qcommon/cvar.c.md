# qcommon/cvar.c

## File Purpose
Implements Quake 2's console variable (cvar) system — a global, named, string-valued configuration store used by all engine subsystems. Provides registration, lookup, mutation, persistence, and console command integration for cvars.

## Core Responsibilities
- Maintain a singly-linked list of all registered `cvar_t` variables
- Register new cvars or merge flags into existing ones (`Cvar_Get`)
- Set cvar values with flag-aware protection (NOSET, LATCH, USERINFO, SERVERINFO)
- Apply latched values deferred until server restart (`Cvar_GetLatchedVars`)
- Serialize archived cvars to config file (`Cvar_WriteVariables`)
- Expose console commands: `set`, `cvarlist`, and inline variable inspection
- Build info strings for user/server info transmission

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `cvar_t` | struct (defined in `qcommon.h`) | Represents one cvar: name, string value, float value, flags, latched_string, modified bit, next pointer |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `cvar_vars` | `cvar_t *` | global | Head of the linked list of all registered cvars |
| `userinfo_modified` | `qboolean` | global | Dirty flag set when any CVAR_USERINFO cvar changes; triggers network retransmit |

## Key Functions

### Cvar_Get
- **Signature:** `cvar_t *Cvar_Get(char *var_name, char *var_value, int flags)`
- **Purpose:** Register a cvar, or if it already exists, OR in the new flags and return it without changing the value.
- **Inputs:** Name string, default value string, bitmask of CVAR_* flags
- **Outputs/Return:** Pointer to existing or newly allocated `cvar_t`; NULL on invalid info name/value
- **Side effects:** Allocates via `Z_Malloc`/`CopyString`; prepends to `cvar_vars` list
- **Calls:** `Cvar_InfoValidate`, `Cvar_FindVar`, `Z_Malloc`, `CopyString`, `Com_Printf`

### Cvar_Set2
- **Signature:** `cvar_t *Cvar_Set2(char *var_name, char *value, qboolean force)`
- **Purpose:** Core set implementation. Enforces NOSET/LATCH protections when `force==false`; bypasses them when `force==true`. Creates the cvar if missing.
- **Inputs:** Name, new value string, force flag
- **Outputs/Return:** Updated `cvar_t *`
- **Side effects:** Frees/reallocates `var->string`; may set `var->latched_string`; sets `userinfo_modified`; may call `FS_SetGamedir`/`FS_ExecAutoexec` when `game` cvar changes
- **Calls:** `Cvar_FindVar`, `Cvar_Get`, `Cvar_InfoValidate`, `Com_ServerState`, `Z_Free`, `CopyString`, `FS_SetGamedir`, `FS_ExecAutoexec`, `Com_Printf`
- **Notes:** Changing the `"game"` cvar has a hard-coded special case that switches the game directory immediately (or on latch apply)

### Cvar_FullSet
- **Signature:** `cvar_t *Cvar_FullSet(char *var_name, char *value, int flags)`
- **Purpose:** Unconditionally sets value AND replaces flags entirely; used for user/server info sync.
- **Side effects:** Same as `Cvar_Set2`; also replaces `var->flags` wholesale

### Cvar_GetLatchedVars
- **Signature:** `void Cvar_GetLatchedVars(void)`
- **Purpose:** Promote all pending `latched_string` values to active `string` at level load/server restart.
- **Side effects:** Frees old strings, applies `FS_SetGamedir`/`FS_ExecAutoexec` for the `game` cvar

### Cvar_WriteVariables
- **Signature:** `void Cvar_WriteVariables(char *path)`
- **Purpose:** Appends `set <name> "<value>"` lines for all CVAR_ARCHIVE cvars to a file (config persistence).
- **Side effects:** File I/O (`fopen`/`fprintf`/`fclose`)

### Cvar_BitInfo / Cvar_Userinfo / Cvar_Serverinfo
- **Purpose:** Collect all cvars matching a flag bit into a single info key-value string for network transmission.
- **Notes:** Returns pointer to a single `static char info[MAX_INFO_STRING]` — not reentrant.

### Cvar_Init
- **Signature:** `void Cvar_Init(void)`
- **Purpose:** Engine startup registration — adds `set` and `cvarlist` console commands.

## Control Flow Notes
- Called during engine init: `Cvar_Init` registers commands; individual subsystems call `Cvar_Get` to declare their cvars.
- Per-frame: nothing here is called on a tick basis directly; consumers poll `var->value` or `var->modified`.
- Server restart boundary: `Cvar_GetLatchedVars` is called to flush LATCH cvars before a new map/game loads.
- Shutdown/save: `Cvar_WriteVariables` is called when writing `config.cfg`.

## External Dependencies
- **Includes:** `qcommon.h` (pulls in `cvar_t`, CVAR_* flags, `MAX_INFO_STRING`)
- **Defined elsewhere:** `Z_Malloc`, `Z_Free`, `CopyString` (zone allocator); `Com_Printf`, `Com_sprintf`, `Com_ServerState` (common); `Cmd_AddCommand`, `Cmd_Argc`, `Cmd_Argv` (command system); `FS_SetGamedir`, `FS_ExecAutoexec` (filesystem); `Info_SetValueForKey` (info string utility)
