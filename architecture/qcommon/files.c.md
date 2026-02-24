# qcommon/files.c

## File Purpose
Implements Quake 2's virtual filesystem (VFS), providing a unified abstraction over loose files and PAK archives. It manages a prioritized search-path chain so multiple game directories and pak files can be transparently layered. All engine file I/O for assets (models, sounds, configs, etc.) flows through this module.

## Core Responsibilities
- Maintain a linked-list search path of directories and pak archives (`fs_searchpaths`)
- Open files by searching links, pak files, and loose directories in priority order
- Load and parse PAK archive headers and directory entries into memory
- Manage game directory switching (`FS_SetGamedir`) including teardown and reload
- Provide bulk file loading into Z_Malloc'd heap buffers (`FS_LoadFile`)
- Support virtual file links (alias redirects) via `fs_links`
- Register console commands: `path`, `link`, `dir`

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `packfile_t` | struct | In-memory record of a single file within a PAK: name, offset, length |
| `pack_t` | struct | Loaded PAK archive: path, open FILE handle, file count, `packfile_t` array |
| `filelink_t` | struct | Virtual path alias: maps a `from` prefix to a `to` prefix |
| `searchpath_t` | struct | One node in the search chain; holds either a directory path or a `pack_t*` |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `fs_gamedir` | `char[MAX_OSPATH]` | global | Current writable game directory path |
| `fs_basedir` | `cvar_t *` | global | CVar: base path to the Quake 2 install root |
| `fs_cddir` | `cvar_t *` | global | CVar: optional CD-ROM data path |
| `fs_gamedirvar` | `cvar_t *` | global | CVar: active game mod directory name |
| `fs_links` | `filelink_t *` | global | Head of virtual file link list |
| `fs_searchpaths` | `searchpath_t *` | global | Head of full search path chain |
| `fs_base_searchpaths` | `searchpath_t *` | global | Marks the base (non-mod) portion of the search path |
| `file_from_pak` | `int` | global | Set to 1 when last `FS_FOpenFile` resolved from a PAK |

## Key Functions

### FS_FOpenFile
- **Signature:** `int FS_FOpenFile(char *filename, FILE **file)`
- **Purpose:** Core VFS lookup. Finds and opens a file by searching links, then each search path entry (pak or directory).
- **Inputs:** Relative virtual path, pointer-to-FILE for output.
- **Outputs/Return:** File length on success; `-1` on failure. `*file` set to open `FILE*` positioned at file start.
- **Side effects:** Sets global `file_from_pak`. Opens OS file handles. Prints debug output via `Com_DPrintf`.
- **Calls:** `Com_sprintf`, `fopen`, `fseek`, `Q_strcasecmp`, `FS_filelength`, `Com_DPrintf`, `Com_Error`
- **Notes:** Two compile-time variants: full (`#ifndef NO_ADDONS`) searches links then all search paths; demo-mode (`#else`) restricts to `config.cfg`, `players/`, and a single pak. PAK lookup opens a **new** file handle per call, seeked to offset—caller is responsible for closing.

### FS_LoadFile
- **Signature:** `int FS_LoadFile(char *path, void **buffer)`
- **Purpose:** Allocates a Z_Malloc buffer and reads an entire file into it.
- **Inputs:** Virtual path; `buffer` pointer (may be NULL to query length only).
- **Outputs/Return:** File length; `-1` if not found. `*buffer` points to loaded data or NULL.
- **Side effects:** Heap allocation via `Z_Malloc`. Caller must free with `FS_FreeFile`.
- **Calls:** `FS_FOpenFile`, `Z_Malloc`, `FS_Read`, `fclose`

### FS_LoadPackFile
- **Signature:** `pack_t *FS_LoadPackFile(char *packfile)`
- **Purpose:** Opens and parses a `.pak` file, building in-memory directory.
- **Inputs:** OS path to `.pak` file.
- **Outputs/Return:** Heap-allocated `pack_t*`; NULL if file missing or (in `NO_ADDONS` mode) checksum mismatch.
- **Side effects:** `Z_Malloc` for `pack_t` and `packfile_t[]`; leaves `pack->handle` open for the lifetime of the search path.
- **Calls:** `fopen`, `fread`, `fseek`, `LittleLong`, `Com_BlockChecksum`, `Z_Malloc`, `Com_Error`, `Com_Printf`

### FS_AddGameDirectory
- **Signature:** `void FS_AddGameDirectory(char *dir)`
- **Purpose:** Prepends a directory and its pak files (pak0–pak9) to the search path.
- **Inputs:** OS directory path.
- **Side effects:** Updates `fs_gamedir`; allocates and links `searchpath_t` nodes; calls `FS_LoadPackFile` for each pak.

### FS_SetGamedir
- **Signature:** `void FS_SetGamedir(char *dir)`
- **Purpose:** Tears down all mod-level search paths (above `fs_base_searchpaths`) and re-initializes for a new game directory.
- **Side effects:** Closes pak handles, frees search path nodes; triggers `vid_restart`/`snd_restart` for non-dedicated servers; updates CVars `gamedir` and `game`.
- **Notes:** Rejects paths containing `..`, `/`, `\`, `:` as a security measure.

### FS_InitFilesystem
- **Signature:** `void FS_InitFilesystem(void)`
- **Purpose:** Engine startup entry point. Registers console commands, initializes CVars, builds base search path.
- **Calls:** `Cmd_AddCommand`, `Cvar_Get`, `FS_AddGameDirectory`, `FS_SetGamedir`

### FS_Read
- **Signature:** `void FS_Read(void *buffer, int len, FILE *f)`
- **Purpose:** Chunked read loop (64 KB blocks) with CD-audio stop retry on zero-byte read.
- **Side effects:** May call `CDAudio_Stop()` once on stall; fatal error on persistent failure.

### FS_Link_f
- **Signature:** `void FS_Link_f(void)`
- **Purpose:** Console command handler to create, update, or delete a `filelink_t` alias.
- **Side effects:** Allocates/frees `filelink_t` nodes; modifies `fs_links`.

## Control Flow Notes
- **Init:** `FS_InitFilesystem` called once during `Qcommon_Init`. Builds base search path (basedir/baseq2, cddir/baseq2), saves `fs_base_searchpaths`, then optionally calls `FS_SetGamedir` for mod override.
- **Per-request:** `FS_FOpenFile` / `FS_LoadFile` are called on-demand throughout the frame by client, server, and renderer subsystems.
- **Shutdown:** No explicit shutdown function; PAK handles remain open until process exit or `FS_SetGamedir` teardown.

## External Dependencies
- `qcommon.h` — engine-wide types, `Com_Error`, `Com_Printf`, `Com_DPrintf`, `Com_sprintf`, `Cvar_*`, `Cmd_*`, `Cbuf_*`, `Z_Malloc`, `Z_Free`, `CopyString`
- `qfiles.h` — `dpackheader_t`, `dpackfile_t`, `IDPAKHEADER`, `MAX_FILES_IN_PACK`
- `Sys_Mkdir`, `Sys_FindFirst`, `Sys_FindNext`, `Sys_FindClose` — platform layer (defined elsewhere)
- `CDAudio_Stop` — declared via forward declaration; defined in platform audio layer
- `Com_BlockChecksum` — defined in `qcommon/md4.c`
