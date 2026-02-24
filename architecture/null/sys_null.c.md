# null/sys_null.c

## File Purpose
A stub/null implementation of all platform-specific system functions required by the Quake 2 engine. It exists solely to aid porting efforts by providing no-op or minimal implementations that allow the engine to compile and link without a real OS backend.

## Core Responsibilities
- Provide stub implementations of all `Sys_*` engine entry points
- Provide stub implementations of the `Hunk_*` memory allocator interface
- Implement a minimal `main()` that drives the common engine loop
- Allow the engine to terminate cleanly via `Sys_Error` and `Sys_Quit`

## Key Types / Data Structures
None.

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `curtime` | `int` | global | Current time (milliseconds); used by the engine timing system |
| `sys_frame_time` | `unsigned` | global | Frame timestamp; consumed by input/event subsystems |

## Key Functions

### main
- **Signature:** `void main(int argc, char **argv)`
- **Purpose:** Entry point; initializes the common engine layer and runs the frame loop indefinitely.
- **Inputs:** Standard `argc`/`argv` command-line arguments.
- **Outputs/Return:** Never returns (infinite loop).
- **Side effects:** Calls `Qcommon_Init` once, then `Qcommon_Frame` with a hardcoded `0.1` second delta per iteration.
- **Calls:** `Qcommon_Init`, `Qcommon_Frame`
- **Notes:** Frame time is hardcoded to `0.1`; no real timing is performed. This is only suitable for stub/porting builds.

### Sys_Error
- **Signature:** `void Sys_Error(char *error, ...)`
- **Purpose:** Fatal error handler; prints a formatted error message to stdout and exits with code 1.
- **Inputs:** `error` — printf-style format string; variadic arguments.
- **Outputs/Return:** Does not return (`exit(1)`).
- **Side effects:** Writes to stdout, terminates the process.
- **Calls:** `printf`, `vprintf`, `va_start`, `va_end`, `exit`
- **Notes:** Only meaningful implementation in this file aside from `main`.

### Sys_Quit
- **Signature:** `void Sys_Quit(void)`
- **Purpose:** Clean shutdown; exits the process with code 0.
- **Side effects:** Terminates the process via `exit(0)`.

### Notes on remaining stubs
- `Sys_mkdir` / `Sys_Mkdir` — duplicate stubs (differing case), both no-ops; likely a latent bug or oversight.
- `Hunk_Begin`, `Hunk_Alloc`, `Hunk_Free`, `Hunk_End` — all return `NULL`/`0`; hunk memory is non-functional.
- `Sys_GetGameAPI`, `Sys_ConsoleInput`, `Sys_GetClipboardData`, `Sys_FindFirst`, `Sys_FindNext` — all return `NULL`.
- `Sys_Milliseconds` — returns constant `0`; timing is inoperative.
- `Sys_ConsoleOutput`, `Sys_SendKeyEvents`, `Sys_AppActivate`, `Sys_CopyProtect`, `Sys_FindClose`, `Sys_Init`, `Sys_UnloadGame` — all empty no-ops.

## Control Flow Notes
This file owns `main()`. On startup it calls `Qcommon_Init` then enters the engine's main loop via `Qcommon_Frame`. No real frame pacing, input, rendering, or memory management occurs — all platform hooks are dead stubs.

## External Dependencies
- `../qcommon/qcommon.h` — declares `Qcommon_Init`, `Qcommon_Frame`, and all `Sys_*` / `Hunk_*` interfaces
- `errno.h` — included but not used
- `Qcommon_Init`, `Qcommon_Frame` — defined in `qcommon/common.c`
- `printf`, `vprintf`, `exit` — C standard library
