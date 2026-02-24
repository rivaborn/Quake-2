# solaris/q_shsolaris.c

## File Purpose
Solaris platform-specific implementation of shared system services for the Quake 2 engine. Provides hunk memory management, high-resolution timing, directory creation, and filesystem directory enumeration using POSIX APIs.

## Core Responsibilities
- Implement the hunk allocator (begin/alloc/end/free) using `malloc`/`realloc`
- Provide `Sys_Milliseconds` for high-resolution wall-clock timing
- Implement `Sys_Mkdir` for directory creation
- Implement `Sys_FindFirst` / `Sys_FindNext` / `Sys_FindClose` for glob-based filesystem iteration
- Provide `strlwr` string utility (lowercase in-place)

## Key Types / Data Structures
None.

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `membase` | `byte *` | global | Base pointer for current hunk allocation |
| `maxhunksize` | `int` | global | Maximum bytes reserved for current hunk |
| `curhunksize` | `int` | global | Bytes consumed so far in current hunk |
| `curtime` | `int` | global | Last computed millisecond timestamp |
| `findbase` | `char[MAX_OSPATH]` | static | Directory portion of the search path |
| `findpath` | `char[MAX_OSPATH]` | static | Full path of the last matched entry |
| `findpattern` | `char[MAX_OSPATH]` | static | Glob pattern extracted from search path |
| `fdir` | `DIR *` | static | Open directory handle for iteration |

## Key Functions

### Hunk_Begin
- **Signature:** `void *Hunk_Begin(int maxsize)`
- **Purpose:** Initialize a new hunk arena by allocating a flat buffer.
- **Inputs:** `maxsize` — maximum bytes the hunk will ever use.
- **Outputs/Return:** Pointer to the base of the allocation.
- **Side effects:** Sets `membase`, `maxhunksize`, `curhunksize`; calls `Sys_Error` on failure.
- **Calls:** `malloc`, `Sys_Error`
- **Notes:** Uses `malloc` rather than `mmap`; unlike the Linux version, memory is committed immediately.

### Hunk_Alloc
- **Signature:** `void *Hunk_Alloc(int size)`
- **Purpose:** Suballocate from the current hunk, aligned to 32-byte cache lines.
- **Inputs:** `size` — requested byte count.
- **Outputs/Return:** Pointer to the allocated region within the hunk.
- **Side effects:** Advances `curhunksize`; calls `Sys_Error` on overflow.
- **Calls:** `Sys_Error`
- **Notes:** No individual-block freeing; the entire hunk is freed at once via `Hunk_Free`.

### Hunk_End
- **Signature:** `int Hunk_End(void)`
- **Purpose:** Shrink the hunk reservation down to actual usage.
- **Inputs:** None (uses globals `membase`, `curhunksize`).
- **Outputs/Return:** `curhunksize` — actual bytes used.
- **Side effects:** Calls `realloc`; calls `Sys_Error` if the base pointer moves.
- **Calls:** `realloc`, `Sys_Error`
- **Notes:** Assumes `realloc` returns the same pointer; fatal if it does not.

### Hunk_Free
- **Signature:** `void Hunk_Free(void *base)`
- **Purpose:** Release an entire hunk arena.
- **Inputs:** `base` — pointer previously returned by `Hunk_Begin`.
- **Calls:** `free`

### Sys_Milliseconds
- **Signature:** `int Sys_Milliseconds(void)`
- **Purpose:** Return elapsed milliseconds since first call, using `gettimeofday`.
- **Inputs:** None.
- **Outputs/Return:** Millisecond timestamp (`curtime`).
- **Side effects:** Initializes `secbase` on first call; updates `curtime`.
- **Calls:** `gettimeofday`
- **Notes:** `secbase` is a local `static`; first call returns only the sub-second offset.

### Sys_FindFirst
- **Signature:** `char *Sys_FindFirst(char *path, unsigned musthave, unsigned canhave)`
- **Purpose:** Begin a directory search; return the first matching entry.
- **Inputs:** `path` — glob path; `musthave`/`canhave` — attribute flags (e.g. `SFF_SUBDIR`).
- **Outputs/Return:** Static string `findpath`, or `NULL` if no match.
- **Side effects:** Opens `fdir`; writes `findbase`, `findpattern`, `findpath`.
- **Calls:** `opendir`, `readdir`, `glob_match`, `CompareAttributes`, `Sys_Error`
- **Notes:** Treats `*.*` as `*`. Calls `Sys_Error` if `fdir` is already open (missing `Sys_FindClose`).

### Sys_FindNext
- **Signature:** `char *Sys_FindNext(unsigned musthave, unsigned canhave)`
- **Purpose:** Advance to the next matching directory entry.
- **Inputs:** Attribute flags same as `Sys_FindFirst`.
- **Outputs/Return:** Static string `findpath`, or `NULL` when exhausted.
- **Calls:** `readdir`, `glob_match`, `CompareAttributes`

### Sys_FindClose
- **Signature:** `void Sys_FindClose(void)`
- **Purpose:** Close the active directory handle.
- **Side effects:** Calls `closedir`; sets `fdir = NULL`.

### Notes
- `CompareAttributes` is a static helper filtering `.`/`..` and checking `stat` mode against `SFF_SUBDIR` flags.
- `strlwr` mutates the string in-place; has no return statement (undefined behavior if return value is used).
- `Sys_Mkdir` wraps `mkdir` with mode `0777` and ignores errors.

## Control Flow Notes
These functions are called from engine startup (hunk allocation during map/model loading), every frame (`Sys_Milliseconds` for timing), and during filesystem scans (`Sys_FindFirst`/`Next`/`Close` in `files.c`). Not part of the render or game logic paths directly.

## External Dependencies
- `../linux/glob.h` — `glob_match` for pattern matching (reused from Linux port)
- `../qcommon/qcommon.h` — `Sys_Error`, `MAX_OSPATH`, `SFF_SUBDIR`, `byte`, `qboolean`
- POSIX: `gettimeofday`, `opendir`/`readdir`/`closedir`, `stat`, `malloc`/`realloc`/`free`, `mkdir`
- `Sys_Error` — defined in `solaris/sys_solaris.c` (not in this file)
