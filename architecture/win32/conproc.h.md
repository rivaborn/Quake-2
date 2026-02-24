# win32/conproc.h

## File Purpose
Header for the Windows console process support module (`conproc.c`), which enables communication between the Quake 2 dedicated server and an external host process (`qhost`). Exposes only the two lifecycle entry points for this subsystem.

## Core Responsibilities
- Declare the init/shutdown interface for the console process (`qhost`) IPC subsystem
- Allow `conproc.c` to be included by the Windows system layer (`sys_win.c`)

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions

### InitConProc
- **Signature:** `void InitConProc (int argc, char **argv);`
- **Purpose:** Initializes the console process support layer, establishing IPC with a `qhost` parent process if one is present.
- **Inputs:** `argc`, `argv` — command-line arguments passed from `WinMain`/`main`, used to detect `qhost`-related flags or handles.
- **Outputs/Return:** `void`
- **Side effects:** Not inferable from this file alone; likely creates shared memory or named pipes (defined in `conproc.c`).
- **Calls:** Not inferable from this file.
- **Notes:** Only relevant on Win32 dedicated server builds that use `qhost` as a launcher/monitor.

### DeinitConProc
- **Signature:** `void DeinitConProc (void);`
- **Purpose:** Shuts down the console process IPC subsystem and releases associated resources.
- **Inputs:** None.
- **Outputs/Return:** `void`
- **Side effects:** Not inferable from this file alone; likely closes handles opened by `InitConProc`.
- **Calls:** Not inferable from this file.
- **Notes:** Paired shutdown counterpart to `InitConProc`; should be called on engine exit.

## Control Flow Notes
`InitConProc` is called early in Win32 startup (likely from `WinMain` in `sys_win.c`), and `DeinitConProc` is called during shutdown. Neither function participates in the per-frame loop.

## External Dependencies
- No includes in this header.
- Both symbols are defined in `win32/conproc.c`.
- Consumed by `win32/sys_win.c` (the Win32 system entry point).
