# linux/q_shlinux.c

## File Purpose
Linux-specific implementation of shared platform services for Quake 2, providing hunk (virtual) memory management, system timing, directory I/O, and file-finding utilities. Acts as the POSIX backend for platform-abstracted engine calls declared in `qcommon.h`.

## Core Responsibilities
- Allocate and manage a hunk memory arena via `mmap`/`mremap`/`munmap`
- Provide millisecond-resolution system time via `gettimeofday`
- Implement directory creation (`Sys_Mkdir`)
- Implement glob-pattern file search (`Sys_FindFirst`, `Sys_FindNext`, `Sys_FindClose`)
- Provide `strlwr` string utility (lowercase in-place)

## Key Types / Data Structures
None.

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `membase` | `byte *` | global | Base pointer of current hunk `mmap` region |
| `maxhunksize` | `int` | global | Maximum bytes reserved for the current hunk |
| `curhunksize` | `int` | global | Bytes committed so far within the hunk |
| `curtime` | `int` | global | Last millisecond timestamp returned by `Sys_Milliseconds` |
| `findbase` | `char[MAX_OSPATH]` | static | Directory portion of the active file search |
| `findpath` | `char[MAX_OSPATH]` | static | Full path of the last matched file |
| `findpattern` | `char[MAX_OSPATH]` | static | Glob pattern portion of the active file search |
| `fdir` | `DIR *` | static | Open directory handle for an in-progress file search |

## Key Functions

### Hunk_Begin
- **Signature:** `void *Hunk_Begin(int maxsize)`
- **Purpose:** Reserves a virtual memory region for a new hunk arena without committing physical pages.
- **Inputs:** `maxsize` — maximum bytes the hunk may grow to.
- **Outputs/Return:** Pointer to usable hunk base (past the internal size header).
- **Side effects:** Sets `membase`, `maxhunksize`, `curhunksize`; writes size header at `membase`; calls `mmap`.
- **Calls:** `mmap`, `Sys_Error`
- **Notes:** Stores a `sizeof(int)` header before the returned pointer, used by `Hunk_Free` to know region size.

### Hunk_Alloc
- **Signature:** `void *Hunk_Alloc(int size)`
- **Purpose:** Sub-allocates from the active hunk arena; size is cache-line (32-byte) aligned.
- **Inputs:** `size` — bytes requested.
- **Outputs/Return:** Pointer to allocated block within the hunk.
- **Side effects:** Advances `curhunksize`.
- **Calls:** `Sys_Error` on overflow.
- **Notes:** No individual free — the entire arena is freed atomically via `Hunk_Free`.

### Hunk_End
- **Signature:** `int Hunk_End(void)`
- **Purpose:** Shrinks the hunk's mapped region to exactly the amount actually used, releasing unused virtual address space.
- **Inputs:** None (uses globals).
- **Outputs/Return:** `curhunksize` (bytes used).
- **Side effects:** Calls `mremap` in-place (`flags=0`); updates size header in `membase`.
- **Calls:** `mremap`, `Sys_Error`
- **Notes:** `mremap` with `flags=0` means the mapping must stay at the same address; fails if the kernel cannot satisfy this.

### Hunk_Free
- **Signature:** `void Hunk_Free(void *base)`
- **Purpose:** Unmaps the entire hunk region, reading the stored size from the header word.
- **Inputs:** `base` — pointer previously returned by `Hunk_Begin`.
- **Side effects:** Calls `munmap`; frees all memory in the arena.
- **Calls:** `munmap`, `Sys_Error`

### Sys_Milliseconds
- **Signature:** `int Sys_Milliseconds(void)`
- **Purpose:** Returns engine time in milliseconds, relative to first call.
- **Inputs:** None.
- **Outputs/Return:** Milliseconds elapsed since first call.
- **Side effects:** Sets `secbase` on first call; updates `curtime`.
- **Calls:** `gettimeofday`
- **Notes:** `secbase` is `static` local; first call returns sub-second offset only, not zero.

### Sys_FindFirst / Sys_FindNext / Sys_FindClose
- **Signatures:** `char *Sys_FindFirst(char *path, unsigned musthave, unsigned canhave)`, `char *Sys_FindNext(unsigned musthave, unsigned canhave)`, `void Sys_FindClose(void)`
- **Purpose:** POSIX directory iteration with glob-pattern matching and attribute filtering (directory vs. file).
- **Inputs:** `path` — glob path; `musthave`/`canhave` — `SFF_*` attribute flags.
- **Outputs/Return:** Pointer to static `findpath` buffer, or `NULL` when exhausted.
- **Side effects:** Opens/reads/closes `fdir` (static `DIR *`); writes `findbase`, `findpath`, `findpattern`.
- **Calls:** `opendir`, `readdir`, `closedir`, `glob_match`, `CompareAttributes`, `Sys_Error`, `stat`
- **Notes:** Not reentrant. `"*.*"` is normalized to `"*"` for POSIX compatibility. `.` and `..` are always excluded.

## Control Flow Notes
Called during engine initialization and per-frame from the filesystem layer (`qcommon/files.c`) for file enumeration. `Hunk_Begin`/`Hunk_Alloc`/`Hunk_End` are invoked during model and map loading; `Hunk_Free` on level unload. `Sys_Milliseconds` is polled every frame by `common.c` for timing.

## External Dependencies
- `../linux/glob.h` — `glob_match()` for wildcard filename matching
- `../qcommon/qcommon.h` — `Sys_Error`, `MAX_OSPATH`, `SFF_SUBDIR`, `byte`, `qboolean`
- POSIX: `<sys/mman.h>` (`mmap`, `mremap`, `munmap`), `<sys/time.h>` (`gettimeofday`), `<dirent.h>`, `<sys/stat.h>`, `<unistd.h>` (`mkdir`)
