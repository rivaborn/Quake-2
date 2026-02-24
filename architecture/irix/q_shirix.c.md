# irix/q_shirix.c

## File Purpose
IRIX-specific implementation of shared system-level services for the Quake 2 engine. Provides platform abstractions for memory hunk allocation, high-resolution timing, directory creation, and filesystem directory enumeration on SGI IRIX systems.

## Core Responsibilities
- Implement the hunk memory allocator (`Hunk_Begin/Alloc/End/Free`) using `malloc` (with commented-out `mmap` fallback)
- Provide millisecond-resolution wall-clock time via `gettimeofday`
- Wrap `mkdir` for portable directory creation
- Implement case-insensitive-compatible filesystem search (`Sys_FindFirst/Next/Close`) using POSIX `opendir`/`readdir` with glob pattern matching
- Provide `strlwr` string utility (missing from IRIX libc)

## Key Types / Data Structures
None.

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `membase` | `byte *` | global | Base pointer for active hunk allocation |
| `maxhunksize` | `int` | global | Maximum bytes for current hunk |
| `curhunksize` | `int` | global | Bytes allocated so far in current hunk |
| `curtime` | `int` | global | Last millisecond timestamp returned |
| `findbase` | `char[MAX_OSPATH]` | static | Directory path for current file search |
| `findpath` | `char[MAX_OSPATH]` | static | Full path of most recently matched entry |
| `findpattern` | `char[MAX_OSPATH]` | static | Glob pattern for current file search |
| `fdir` | `DIR *` | static | Open directory handle for current search |

## Key Functions

### Hunk_Begin
- **Signature:** `void *Hunk_Begin(int maxsize)`
- **Purpose:** Initialize a new hunk allocation arena of `maxsize` bytes.
- **Inputs:** `maxsize` — requested arena size in bytes
- **Outputs/Return:** Pointer to usable memory (past embedded size header)
- **Side effects:** Allocates heap via `malloc`; sets `membase`, `maxhunksize`, `curhunksize`; writes `curhunksize` into first `sizeof(int)` bytes
- **Calls:** `malloc`, `Com_Error`
- **Notes:** `mmap(MAP_PRIVATE)` path is commented out. Stores a header int before the returned pointer; callers must not assume the raw allocation starts at the returned address.

### Hunk_Alloc
- **Signature:** `void *Hunk_Alloc(int size)`
- **Purpose:** Sub-allocate from the current hunk arena, aligned to 32-byte cache lines.
- **Inputs:** `size` — bytes requested
- **Outputs/Return:** Pointer to zeroed (by `malloc`) region within hunk
- **Side effects:** Advances `curhunksize`
- **Calls:** `Com_Error` on overflow
- **Notes:** Alignment via `(size+31)&~31`. Fatally aborts if overflow.

### Hunk_End
- **Signature:** `int Hunk_End(void)`
- **Purpose:** Finalize hunk allocation and return total bytes used.
- **Inputs:** None
- **Outputs/Return:** `curhunksize`
- **Side effects:** None
- **Notes:** On Linux/IRIX `malloc` path this is a no-op bookkeeping call; on `mmap` path it would shrink the mapping.

### Hunk_Free
- **Signature:** `void Hunk_Free(void *base)`
- **Purpose:** Release an entire hunk arena.
- **Inputs:** `base` — pointer previously returned by `Hunk_Begin`
- **Side effects:** `free`s allocation including the prepended header
- **Notes:** Adjusts pointer back by `sizeof(int)` to recover original `malloc` address.

### Sys_Milliseconds
- **Signature:** `int Sys_Milliseconds(void)`
- **Purpose:** Return elapsed milliseconds since first call (monotonic-ish wall clock).
- **Inputs:** None
- **Outputs/Return:** Milliseconds as `int`; also stored in `curtime`
- **Side effects:** Sets `secbase` on first call; writes `curtime`
- **Calls:** `gettimeofday`
- **Notes:** Not truly monotonic — susceptible to wall-clock adjustments.

### Sys_FindFirst / Sys_FindNext / Sys_FindClose
- **Signatures:** `char *Sys_FindFirst(char *path, unsigned musthave, unsigned canhave)`, `char *Sys_FindNext(...)`, `void Sys_FindClose(void)`
- **Purpose:** Iterative directory search with glob pattern and attribute filtering (mirrors Win32 `FindFirstFile` semantics).
- **Side effects:** Opens/reads/closes `fdir` (static `DIR*`); writes `findbase`, `findpath`, `findpattern`
- **Calls:** `opendir`, `readdir`, `closedir`, `glob_match`, `CompareAttributes`, `Sys_Error`
- **Notes:** Only `SFF_SUBDIR` attribute flag is checked. `"*.*"` is normalized to `"*"`. Only one search can be active at a time.

## Control Flow Notes
Called during engine init and per-frame for timing (`Sys_Milliseconds`). Hunk functions are used during map/model load. File search functions are used by the VFS layer (`files.c`) to enumerate pak/directory contents.

## External Dependencies
- `../linux/glob.h` — `glob_match` (shared with Linux port)
- `../qcommon/qcommon.h` — `Com_Error`, `Sys_Error`, `MAX_OSPATH`, `SFF_SUBDIR`, `byte`, `qboolean`
- POSIX: `<dirent.h>`, `<sys/stat.h>`, `<sys/time.h>`, `<sys/mman.h>`, `<unistd.h>`
- `strlwr` — defined here because IRIX libc omits it; used by engine string-lowercasing calls elsewhere
