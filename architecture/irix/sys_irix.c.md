# irix/sys_irix.c

## File Purpose
Platform abstraction layer for the IRIX (SGI) operating system port of Quake 2. Implements the `Sys_*` interface required by the engine's common layer, handling startup, shutdown, console I/O, timing, and game DLL loading for MIPS-based SGI workstations.

## Core Responsibilities
- Provide the engine main loop and frame timing
- Implement console output/input for dedicated server mode
- Load and unload the game shared library (`gamemips.so`) via `dlopen`/`dlsym`
- Handle fatal errors and clean shutdown
- Perform (nominally) CD-based copy protection checks
- Forward keyboard events from the platform input layer

## Key Types / Data Structures
None.

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `nostdout` | `cvar_t *` | global | Suppresses stdout output when non-zero |
| `sys_frame_time` | `unsigned` | global | Timestamp (ms) captured each frame for input subsystems |
| `saved_euid` | `uid_t` | global | Saves effective UID before dropping privileges at startup |
| `stdin_active` | `qboolean` | global | Set false on stdin EOF to stop polling console input |
| `game_library` | `void *` | static | Handle to the loaded game `.so`, managed by load/unload functions |

## Key Functions

### main
- **Signature:** `int main(int argc, char **argv)`
- **Purpose:** Engine entry point; initializes engine, then runs the main game loop.
- **Inputs:** Command-line arguments.
- **Outputs/Return:** Does not return (infinite loop); exits via `_exit`.
- **Side effects:** Calls `Qcommon_Init`, sets EUID to real UID, queries `nostdout` cvar, drives `Qcommon_Frame` each iteration.
- **Calls:** `geteuid`, `seteuid`, `getuid`, `Qcommon_Init`, `Cvar_Get`, `Sys_Milliseconds`, `Qcommon_Frame`
- **Notes:** Busy-waits until at least 1 ms has elapsed before calling `Qcommon_Frame`. stdin non-blocking mode is commented out.

### Sys_GetGameAPI
- **Signature:** `void *Sys_GetGameAPI(void *parms)`
- **Purpose:** Locates and loads the game shared library, resolves `GetGameAPI`, and returns the game API struct.
- **Inputs:** `parms` — passed directly to the game's `GetGameAPI` entry point.
- **Outputs/Return:** Pointer returned by `GetGameAPI(parms)`, or `NULL` on failure.
- **Side effects:** Writes to `game_library`; drops setuid privileges via `setreuid`/`setegid`; iterates `FS_NextPath`.
- **Calls:** `setreuid`, `getuid`, `setegid`, `getgid`, `getcwd`, `FS_NextPath`, `dlopen`, `dlsym`, `Sys_UnloadGame`, `Com_Printf`, `Com_DPrintf`, `Com_Error`
- **Notes:** IRIX target hardcodes `gamemips.so`; fails to compile on non-SGI targets (`#error Unknown arch`). Guarded by `REF_HARD_LINKED` for static linking.

### Sys_UnloadGame
- **Signature:** `void Sys_UnloadGame(void)`
- **Purpose:** Closes the game shared library handle and nulls the pointer.
- **Calls:** `dlclose`

### Sys_Error
- **Signature:** `void Sys_Error(char *error, ...)`
- **Purpose:** Formats and prints a fatal error, shuts down the engine, and exits with code 1.
- **Side effects:** Resets stdin to blocking mode; calls `CL_Shutdown`, `Qcommon_Shutdown`, `_exit(1)`.

### Sys_Quit
- **Signature:** `void Sys_Quit(void)`
- **Purpose:** Clean shutdown; resets stdin blocking mode and exits with code 0.
- **Calls:** `CL_Shutdown`, `Qcommon_Shutdown`, `fcntl`, `_exit`

### Sys_ConsoleInput
- **Signature:** `char *Sys_ConsoleInput(void)`
- **Purpose:** Non-blocking poll of stdin for dedicated server console commands.
- **Outputs/Return:** Pointer to static buffer with null-terminated line, or `NULL` if no input.
- **Notes:** Only active when `dedicated->value` is set; sets `stdin_active = false` on EOF; returns pointer to a single shared static buffer (not reentrant).

### Sys_SendKeyEvents
- **Signature:** `void Sys_SendKeyEvents(void)`
- **Purpose:** Pumps platform keyboard input and records the current frame timestamp.
- **Side effects:** Calls `KBD_Update_fp` (function pointer from `rw_linux.h`); updates `sys_frame_time`.

### Sys_CopyProtect
- **Signature:** `void Sys_CopyProtect(void)`
- **Purpose:** Intended to verify Quake 2 CD is mounted via iso9660; currently short-circuits after printing a disabled notice.
- **Notes:** Dead code path after the early `return`; the full implementation scans `/etc/mtab` for ISO 9660 mounts and checks for `quake2.exe` on the disc.

### Notes
- `Sys_Printf` strips high bits and replaces non-printable characters with hex escapes; contains a post-format buffer overrun check that is too late to be useful.
- `Sys_FileTime`, `Sys_Warn`, `Sys_Init`, `Sys_AppActivate`, `Sys_GetClipboardData` are trivial stubs or thin wrappers.
- `Sys_MakeCodeWriteable` is compiled out (`#if 0`).

## Control Flow Notes
`main` calls `Qcommon_Init` once, then loops forever calling `Qcommon_Frame(time)`. Shutdown is triggered externally by `Sys_Quit` or `Sys_Error`, both of which call `_exit` directly.

## External Dependencies
- `../qcommon/qcommon.h` — `Qcommon_Init`, `Qcommon_Frame`, `Qcommon_Shutdown`, `Com_Printf`, `Com_Error`, `FS_NextPath`, `Cvar_Get`, `Sys_Milliseconds`, `dedicated`
- `../linux/rw_linux.h` — `KBD_Update_fp` function pointer
- `dlfcn.h` — `dlopen`, `dlsym`, `dlclose` (POSIX dynamic linking)
- `mntent.h` — `setmntent`, `getmntent`, `endmntent` (Linux/IRIX mount table)
- `CL_Shutdown` — defined elsewhere (client layer)
