# linux/sys_linux.c

## File Purpose
Platform abstraction layer for Quake 2 on Linux. Provides the OS-facing entry point (`main`), system-level services (time, console I/O, error handling, clipboard), and dynamic game library loading via `dlopen`. Bridges the engine's `Sys_*` API to POSIX/Linux system calls.

## Core Responsibilities
- Implements the `main` loop: init, frame timing, and `Qcommon_Frame` dispatch
- Provides `Sys_Error`/`Sys_Quit` for fatal shutdown with stdin restoration
- Handles console I/O (`Sys_ConsoleInput`, `Sys_ConsoleOutput`, `Sys_Printf`)
- Loads/unloads the game `.so` via `dlopen`/`dlsym`/`dlclose`
- Performs CD-based copy protection check by scanning `/etc/mtab`
- Drops privileges at startup via `seteuid`/`setreuid`

## Key Types / Data Structures
None.

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `nostdout` | `cvar_t *` | global | Suppresses stdout output when non-zero |
| `sys_frame_time` | `unsigned` | global | Millisecond timestamp captured each input poll |
| `saved_euid` | `uid_t` | global | Stores effective UID before privilege drop at startup |
| `stdin_active` | `qboolean` | global | Tracks whether stdin is still readable (EOF guard) |
| `game_library` | `void *` | static | Handle to the loaded game `.so` |

## Key Functions

### main
- **Signature:** `int main(int argc, char **argv)`
- **Purpose:** Engine entry point; initializes engine, sets up non-blocking stdin, runs the frame loop.
- **Inputs:** Command-line args forwarded to `Qcommon_Init`.
- **Outputs/Return:** Never returns (infinite loop); exits via `_exit` on error/quit.
- **Side effects:** Drops effective UID to real UID, sets `FNDELAY` on fd 0, calls `Qcommon_Frame` every iteration.
- **Calls:** `seteuid`, `Qcommon_Init`, `fcntl`, `Cvar_Get`, `Sys_Milliseconds`, `Qcommon_Frame`
- **Notes:** Spin-waits until at least 1 ms has elapsed before dispatching a frame; no sleep/yield between iterations.

### Sys_GetGameAPI
- **Signature:** `void *Sys_GetGameAPI(void *parms)`
- **Purpose:** Locates and loads the arch-specific game `.so` (`gamei386.so` or `gameaxp.so`) by iterating filesystem search paths, then resolves and calls `GetGameAPI`.
- **Inputs:** `parms` — passed through to the game DLL's `GetGameAPI`.
- **Outputs/Return:** Return value of `GetGameAPI(parms)`, or `NULL` on failure.
- **Side effects:** Sets `game_library`; drops setuid/setgid privileges via `setreuid`/`setegid`; allocates OS resources (dlopen handle).
- **Calls:** `setreuid`, `setegid`, `getcwd`, `FS_NextPath`, `dlopen`, `dlsym`, `Com_DPrintf`, `Sys_UnloadGame`, `Com_Error`
- **Notes:** Calls `Com_Error(ERR_FATAL,...)` if called while a library is already loaded. Path constructed as `<cwd>/<searchpath>/<gamename>`.

### Sys_UnloadGame
- **Signature:** `void Sys_UnloadGame(void)`
- **Purpose:** Closes the game `.so` handle and nulls the pointer.
- **Side effects:** Calls `dlclose`; sets `game_library = NULL`.

### Sys_Error
- **Signature:** `void Sys_Error(char *error, ...)`
- **Purpose:** Fatal error handler — shuts down client and engine, restores stdin blocking mode, prints to stderr, and exits.
- **Side effects:** Calls `CL_Shutdown`, `Qcommon_Shutdown`, `fcntl`, `fprintf(stderr,...)`, `_exit(1)`.

### Sys_Quit
- **Signature:** `void Sys_Quit(void)`
- **Purpose:** Clean shutdown path — mirrors `Sys_Error` but exits with code 0.
- **Side effects:** `CL_Shutdown`, `Qcommon_Shutdown`, restores stdin blocking, `_exit(0)`.

### Sys_ConsoleInput
- **Signature:** `char *Sys_ConsoleInput(void)`
- **Purpose:** Non-blocking read of one line from stdin; dedicated server only.
- **Inputs:** None (reads from fd 0).
- **Outputs/Return:** Pointer to static buffer with null-terminated line, or `NULL`.
- **Side effects:** Sets `stdin_active = false` on EOF. Returns `NULL` for non-dedicated clients.
- **Notes:** Uses `select` with zero timeout to avoid blocking.

### Sys_CopyProtect
- **Signature:** `void Sys_CopyProtect(void)`
- **Purpose:** Verifies a mounted Quake 2 ISO (iso9660) CD-ROM contains `quake2.exe` before allowing play.
- **Side effects:** Calls `Com_Error(ERR_FATAL,...)` if no valid CD found. Runs only once via `checked` static guard.

### Sys_SendKeyEvents
- **Signature:** `void Sys_SendKeyEvents(void)`
- **Purpose:** Polls platform keyboard input and snapshots `sys_frame_time`.
- **Side effects:** Calls `KBD_Update_fp()` (function pointer, non-dedicated only); sets `sys_frame_time`.

## Control Flow Notes
`main` drives the top-level game loop: `Qcommon_Init` → spin on `Sys_Milliseconds` for ≥1ms → `Qcommon_Frame(time)`. Shutdown occurs only via `Sys_Quit` or `Sys_Error`, both of which call `_exit` directly without returning to `main`. `Sys_SendKeyEvents` is called within `Qcommon_Frame` (defined elsewhere) each frame.

## External Dependencies
- **Includes:** `qcommon/qcommon.h`, `linux/rw_linux.h`
- **Defined elsewhere:** `Qcommon_Init`, `Qcommon_Frame`, `Qcommon_Shutdown`, `CL_Shutdown`, `Sys_Milliseconds`, `FS_NextPath`, `Com_Error`, `Com_Printf`, `Com_DPrintf`, `Cvar_Get`, `KBD_Update_fp` (function pointer from `rw_linux.h`), `dedicated` (cvar), `ERR_FATAL`
