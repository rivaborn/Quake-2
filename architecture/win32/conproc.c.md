# win32/conproc.c

## File Purpose
Implements a Windows-specific inter-process communication (IPC) bridge between the Quake 2 engine and an external host utility called "QHOST." It exposes console read/write and screen buffer control commands to QHOST via a shared memory buffer and Win32 event signaling.

## Core Responsibilities
- Parse command-line arguments for QHOST-provided Win32 handles (`-HFILE`, `-HPARENT`, `-HCHILD`)
- Map/unmap a shared memory buffer for IPC command exchange
- Spawn a background thread (`RequestProc`) to service QHOST requests
- Dispatch QHOST commands: write text to stdin, read text from screen buffer, get/set screen buffer line count
- Manage console window dimensions (forced to 80 columns minimum)
- Signal shutdown via a "done" event

## Key Types / Data Structures
None (no custom structs; uses Win32 types throughout).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `heventDone` | `HANDLE` | global | Signals the request thread to terminate |
| `hfileBuffer` | `HANDLE` | global | Shared memory file mapping from QHOST |
| `heventChildSend` | `HANDLE` | global | Event signaled by child (engine) to QHOST after reply |
| `heventParentSend` | `HANDLE` | global | Event signaled by QHOST when a command is ready |
| `hStdout` | `HANDLE` | global | Console output handle |
| `hStdin` | `HANDLE` | global | Console input handle |
| `ccom_argc` | `int` | global | Saved argument count |
| `ccom_argv` | `char**` | global | Saved argument vector |

## Key Functions

### InitConProc
- **Signature:** `void InitConProc(int argc, char **argv)`
- **Purpose:** Initializes the QHOST IPC channel. Extracts Win32 handles from argv, creates the done-event, spawns the request thread, captures stdio handles, and sets console size.
- **Inputs:** `argc`, `argv` — program arguments containing optional `-HFILE`, `-HPARENT`, `-HCHILD` handle values
- **Outputs/Return:** void
- **Side effects:** Sets all six globals; spawns a thread; resizes the console window
- **Calls:** `CCheckParm`, `CreateEvent`, `_beginthreadex`, `GetStdHandle`, `SetConsoleCXCY`
- **Notes:** Silently returns if any of the three handles is missing; no error is fatal.

### DeinitConProc
- **Signature:** `void DeinitConProc(void)`
- **Purpose:** Signals the request thread to exit by firing `heventDone`.
- **Side effects:** Sets `heventDone` event; thread will exit on next `WaitForMultipleObjects` iteration.

### RequestProc
- **Signature:** `unsigned _stdcall RequestProc(void *arg)`
- **Purpose:** Background thread loop; waits for QHOST commands in the shared buffer, dispatches them, writes results back, then signals QHOST.
- **Inputs:** `arg` — unused
- **Outputs/Return:** 0 on exit
- **Side effects:** Calls `GetMappedBuffer`/`ReleaseMappedBuffer`; modifies shared buffer in-place; signals `heventChildSend`
- **Calls:** `WaitForMultipleObjects`, `GetMappedBuffer`, `WriteText`, `ReadText`, `GetScreenBufferLines`, `SetScreenBufferLines`, `ReleaseMappedBuffer`, `SetEvent`, `_endthreadex`
- **Notes:** Command code is in `pBuffer[0]`; results overwrite `pBuffer[0]`; exits if `heventDone` fires or buffer mapping fails.

### WriteText
- **Signature:** `BOOL WriteText(LPCTSTR szText)`
- **Purpose:** Injects text into the console input queue as synthesized `KEY_EVENT` input records, simulating keyboard input.
- **Side effects:** Writes to `hStdin` via `WriteConsoleInput`; mutates the input string (replaces `\n` (10) with `\r` (13)) in-place.
- **Notes:** Uses `CharToCode` for scan codes; sets shift-state flag for uppercase characters.

### SetConsoleCXCY
- **Signature:** `BOOL SetConsoleCXCY(HANDLE hStdout, int cx, int cy)`
- **Purpose:** Resizes both the console screen buffer and window to the requested dimensions, clamping to the largest supported size.
- **Notes:** Must sequence buffer/window resize carefully depending on whether shrinking or growing to avoid Win32 API constraint violations.

- **Notes (minor helpers):** `GetMappedBuffer`/`ReleaseMappedBuffer` wrap `MapViewOfFile`/`UnmapViewOfFile`. `GetScreenBufferLines`/`SetScreenBufferLines` wrap `GetConsoleScreenBufferInfo` and `SetConsoleCXCY`. `ReadText` wraps `ReadConsoleOutputCharacter`. `CharToCode` maps ASCII chars to hardware scan codes.

## Control Flow Notes
- Called from `sys_win.c` during startup (`InitConProc`) and shutdown (`DeinitConProc`).
- `RequestProc` runs on a persistent background thread for the entire engine lifetime when QHOST is present.
- The main engine thread is not blocked; all QHOST servicing is asynchronous.

## External Dependencies
- `<windows.h>` — all Win32 console, event, thread, and memory-mapping APIs
- `<process.h>` — `_beginthreadex`, `_endthreadex`
- `conproc.h` — declarations for `InitConProc`, `DeinitConProc` (defined elsewhere, used by `sys_win.c`)
- `QHOST` — external process providing the three IPC handles via command-line; not defined in this codebase
