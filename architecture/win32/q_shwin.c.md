# win32/q_shwin.c

## File Purpose
Windows-specific platform abstraction layer providing hunk memory management, high-resolution timing, directory creation, and filesystem enumeration. It implements the Win32 side of the `Sys_*` and `Hunk_*` interfaces declared in `qcommon.h`.

## Core Responsibilities
- Implement a virtual-memory-backed hunk allocator using `VirtualAlloc`/`VirtualFree`
- Provide `Sys_Milliseconds` for engine timing via `timeGetTime`
- Wrap `_mkdir` for cross-platform directory creation
- Implement `Sys_FindFirst`/`Sys_FindNext`/`Sys_FindClose` for file glob enumeration
- Filter filesystem entries by attribute bitmasks (musthave/canthave)

## Key Types / Data Structures
None.

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `hunkcount` | `int` | global | Tracks live hunk allocations (debug counter) |
| `membase` | `byte *` | global | Base pointer of current hunk region |
| `hunkmaxsize` | `int` | global | Maximum reserved size of current hunk |
| `cursize` | `int` | global | Bytes committed so far in current hunk |
| `curtime` | `int` | global | Last value returned by `Sys_Milliseconds` |
| `findbase` | `char[MAX_OSPATH]` | global | Directory portion of current find pattern |
| `findpath` | `char[MAX_OSPATH]` | global | Composed result path returned by find functions |
| `findhandle` | `int` | global | CRT find handle (`_findfirst` token) |

## Key Functions

### Hunk_Begin
- Signature: `void *Hunk_Begin(int maxsize)`
- Purpose: Reserves a large virtual address region for the hunk allocator without committing physical pages.
- Inputs: `maxsize` — total bytes to reserve.
- Outputs/Return: Pointer to reserved base (`membase`).
- Side effects: Sets `cursize = 0`, `hunkmaxsize`, `membase`; calls `Sys_Error` on failure.
- Calls: `VirtualAlloc` (MEM_RESERVE), `Sys_Error`
- Notes: `VIRTUAL_ALLOC` compile-time switch selects between `VirtualAlloc` and `malloc`; malloc path also zero-initialises.

### Hunk_Alloc
- Signature: `void *Hunk_Alloc(int size)`
- Purpose: Commits the next cache-line-aligned block from the reserved hunk region.
- Inputs: `size` — requested bytes (rounded up to 32-byte boundary).
- Outputs/Return: Pointer to newly committed block.
- Side effects: Advances `cursize`; calls `VirtualAlloc` (MEM_COMMIT) to grow committed range; calls `Sys_Error` on overflow or commit failure.
- Calls: `VirtualAlloc`, `FormatMessage`, `GetLastError`, `Sys_Error`
- Notes: Commits the entire range `[membase, cursize+size]` rather than just the new slice — idempotent but slightly wasteful.

### Hunk_End
- Signature: `int Hunk_End(void)`
- Purpose: Finalises hunk allocation; increments the live-hunk counter.
- Inputs: None.
- Outputs/Return: `cursize` (total committed bytes).
- Side effects: Increments `hunkcount`.
- Notes: Write-protect path is `#if 0`'d out.

### Hunk_Free
- Signature: `void Hunk_Free(void *base)`
- Purpose: Releases the entire hunk region back to the OS.
- Inputs: `base` — pointer previously returned by `Hunk_Begin`.
- Side effects: Decrements `hunkcount`; calls `VirtualFree` (MEM_RELEASE).

### Sys_Milliseconds
- Signature: `int Sys_Milliseconds(void)`
- Purpose: Returns milliseconds elapsed since first call, with upper 16 bits randomised for overflow safety.
- Inputs: None.
- Outputs/Return: Millisecond timestamp in `curtime`.
- Side effects: Initialises static `base` on first call; updates global `curtime`.
- Calls: `timeGetTime`

### Sys_FindFirst
- Signature: `char *Sys_FindFirst(char *path, unsigned musthave, unsigned canthave)`
- Purpose: Begins a file-attribute-filtered directory search.
- Inputs: `path` — glob pattern; `musthave`/`canthave` — `SFF_*` attribute masks.
- Outputs/Return: Pointer to `findpath` (static buffer) or `NULL` if no match.
- Side effects: Writes `findbase`, `findpath`, `findhandle`; calls `Sys_Error` if a find is already open.
- Calls: `COM_FilePath`, `_findfirst`, `CompareAttributes`, `Com_sprintf`

### Sys_FindNext / Sys_FindClose
- `Sys_FindNext` advances the search, applying the same attribute filter; returns `NULL` on exhaustion.
- `Sys_FindClose` calls `_findclose` and resets `findhandle` to 0.

## Control Flow Notes
`Hunk_Begin`/`Hunk_Alloc`/`Hunk_End`/`Hunk_Free` are called during map/model loading and unloading. `Sys_Milliseconds` is polled every frame by the engine main loop. The find functions are called by `qcommon/files.c` during pak/directory enumeration at startup and on `exec`/`gamedir` changes.

## External Dependencies
- `../qcommon/qcommon.h` — `Sys_Error`, `COM_FilePath`, `Com_sprintf`, `MAX_OSPATH`, `SFF_*` flags
- `winquake.h` — Win32 types, `timeGetTime`
- Win32 API: `VirtualAlloc`, `VirtualFree`, `FormatMessage`, `GetLastError`, `timeGetTime`
- CRT: `_mkdir`, `_findfirst`, `_findnext`, `_findclose`, `_finddata_t`
