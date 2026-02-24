# solaris/sys_solaris.c

## File Purpose
Platform-specific system layer for Quake 2 running on Solaris (and i386 Linux via shared code patterns). Implements OS-level services including process lifecycle, console I/O, timing, and dynamic game library loading via `dlopen`.

## Core Responsibilities
- Initialize and shut down the engine process (`main`, `Sys_Quit`, `Sys_Error`)
- Drive the main game loop, throttling frames to a minimum of 1ms
- Provide console input/output for dedicated server mode
- Load and unload the game DLL (`gamei386.so` or `gamesparc.so`) at runtime
- Report file modification timestamps via `Sys_FileTime`
- Strip high-bit characters from console output for terminal safety

## Key Types / Data Structures
None.

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `nostdout` | `cvar_t *` | global | Suppresses stdout output when set |
| `sys_frame_time` | `unsigned` | global | Timestamp (ms) captured each frame for input subsystems |
| `stdin_active` | `qboolean` | global | Tracks whether stdin is still readable (clears on EOF) |
| `game_library` | `void *` | static | Handle to the loaded game `.so`, managed by dlopen/dlclose |

## Key Functions

### main
- Signature: `int main(int argc, char **argv)`
- Purpose: Engine entry point; initializes common systems and runs the frame loop.
- Inputs: Command-line arguments
- Outputs/Return: Does not return normally (infinite loop; exit via `_exit`)
- Side effects: Sets stdin to non-blocking (`FNDELAY`); calls `Qcommon_Init`, then drives `Qcommon_Frame` repeatedly
- Calls: `Qcommon_Init`, `Sys_Milliseconds`, `Qcommon_Frame`, `Cvar_Get`, `fcntl`
- Notes: Dead code block (`#if 0`) for forcing dedicated mode is present but disabled. Busy-waits until at least 1ms has elapsed before dispatching each frame.

### Sys_GetGameAPI
- Signature: `void *Sys_GetGameAPI(void *parms)`
- Purpose: Iterates filesystem search paths to find and `dlopen` the architecture-specific game shared library, then resolves and calls `GetGameAPI`.
- Inputs: `parms` — passed through to the game's `GetGameAPI` function
- Outputs/Return: Return value of `GetGameAPI(parms)` (game API struct pointer), or `NULL` on failure
- Side effects: Sets `game_library`; logs to console via `Com_Printf`/`Com_DPrintf`
- Calls: `getcwd`, `FS_NextPath`, `dlopen`, `dlsym`, `Sys_UnloadGame`, `Com_Error`, `Com_Printf`, `Com_DPrintf`
- Notes: Architecture selected at compile time (`__i386__` → `gamei386.so`, `__sun__` → `gamesparc.so`); hard errors on unknown arch via `#error`.

### Sys_UnloadGame
- Signature: `void Sys_UnloadGame(void)`
- Purpose: Closes the game shared library and nulls the handle.
- Side effects: Calls `dlclose(game_library)`; sets `game_library = NULL`

### Sys_ConsoleInput
- Signature: `char *Sys_ConsoleInput(void)`
- Purpose: Non-blocking read of stdin for dedicated server console commands.
- Inputs: None (reads from fd 0)
- Outputs/Return: Static buffer with null-terminated command string, or `NULL` if nothing available
- Side effects: Sets `stdin_active = false` on EOF
- Notes: Only active when `dedicated->value` is set; uses `select` with zero timeout to avoid blocking.

### Sys_Error
- Signature: `void Sys_Error(char *error, ...)`
- Purpose: Fatal error handler; prints to stderr, shuts down engine, and exits with code 1.
- Side effects: Restores stdin blocking mode; calls `CL_Shutdown`, `Qcommon_Shutdown`, `_exit(1)`

### Sys_Quit
- Signature: `void Sys_Quit(void)`
- Purpose: Clean shutdown path; restores stdin, shuts down engine, exits cleanly.
- Side effects: Calls `CL_Shutdown`, `Qcommon_Shutdown`, `_exit(0)`

### Sys_Printf / Sys_ConsoleOutput
- Notes: Both respect `nostdout`. `Sys_Printf` sanitizes output by masking high bits and escaping non-printable bytes as `[XX]` hex. `Sys_ConsoleOutput` is a raw `fputs` wrapper.

## Control Flow Notes
`main` is the top-level driver. After `Qcommon_Init`, it enters an infinite loop calling `Qcommon_Frame(time)` with elapsed milliseconds. There is no platform event pump here (no window system on Solaris server); input comes solely from stdin. Shutdown flows through `Sys_Quit` or `Sys_Error`, both of which call `_exit` directly.

## External Dependencies
- `../qcommon/qcommon.h` — `Qcommon_Init`, `Qcommon_Frame`, `Qcommon_Shutdown`, `Com_Error`, `Com_Printf`, `FS_NextPath`, `Sys_Milliseconds`, `cvar_t`, `dedicated`
- `CL_Shutdown` — defined in client layer (linked externally)
- `dlfcn.h` — `dlopen`, `dlsym`, `dlclose`, `dlerror` for runtime game module loading
- `Sys_Milliseconds` — defined elsewhere (likely in a shared platform timing file)
