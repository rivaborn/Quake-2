# win32/sys_win.c

## File Purpose
Windows-specific system layer for Quake 2, providing the Win32 entry point (`WinMain`), OS abstraction functions, and game DLL loading. It bridges the platform-independent engine (`qcommon`) with Win32 APIs for timing, console I/O, clipboard, and process management.

## Core Responsibilities
- Implement `WinMain` as the application entry point and main game loop
- Parse command-line arguments from the Win32 `LPSTR` format
- Scan for the Quake 2 CD-ROM for copy protection
- Manage the dedicated server console (input/output via Win32 console API)
- Load and unload the game logic DLL (`gamex86.dll` / `gameaxp.dll`)
- Pump the Windows message queue each frame via `Sys_SendKeyEvents`
- Provide clipboard text access and window activation helpers

## Key Types / Data Structures
None.

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `s_win95` | `qboolean` | global | Flags whether running on Win95/98 |
| `starttime` | `int` | global | Process start time (declared, unused in this file) |
| `ActiveApp` | `int` | global | Non-zero when app has focus |
| `Minimized` | `qboolean` | global | True when window is minimized; throttles frame rate |
| `hinput` / `houtput` | `HANDLE` | static | Dedicated server console I/O handles |
| `sys_msg_time` | `unsigned` | global | Timestamp of last Windows message |
| `sys_frame_time` | `unsigned` | global | Timestamp captured at end of `Sys_SendKeyEvents` |
| `qwclsemaphore` | `HANDLE` | static | Named semaphore (code currently `#if 0`'d out) |
| `argc` / `argv` | `int` / `char*[]` | global | Parsed command-line argument count and values |
| `console_text` / `console_textlen` | `char[256]` / `int` | static | Dedicated console line-edit buffer |
| `game_library` | `HINSTANCE` | static | Handle to the loaded game DLL |
| `global_hInstance` | `HINSTANCE` | global | Win32 instance handle, shared with other win32 modules |

## Key Functions

### WinMain
- **Signature:** `int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)`
- **Purpose:** Application entry point; initializes engine and runs the main frame loop.
- **Inputs:** Standard Win32 WinMain parameters.
- **Outputs/Return:** `TRUE` (nominally; loop never exits normally).
- **Side effects:** Calls `Qcommon_Init`, drives `Qcommon_Frame` every iteration; pumps Win32 message queue; sleeps 1 ms when minimized or dedicated.
- **Calls:** `ParseCommandLine`, `Sys_ScanForCD`, `Qcommon_Init`, `Sys_Milliseconds`, `PeekMessage`, `GetMessage`, `Com_Quit`, `TranslateMessage`, `DispatchMessage`, `_controlfp`, `Qcommon_Frame`
- **Notes:** Sets FPU to 24-bit precision (`_PC_24`) each frame. Busy-waits until at least 1 ms has elapsed before calling `Qcommon_Frame`.

### Sys_Error
- **Signature:** `void Sys_Error(char *error, ...)`
- **Purpose:** Fatal error handler; shuts down engine and displays a message box.
- **Inputs:** `printf`-style format string and args.
- **Outputs/Return:** None (calls `exit(1)`).
- **Side effects:** Calls `CL_Shutdown`, `Qcommon_Shutdown`, `DeinitConProc`; closes semaphore handle; terminates process.
- **Calls:** `CL_Shutdown`, `Qcommon_Shutdown`, `vsprintf`, `MessageBox`, `CloseHandle`, `DeinitConProc`, `exit`

### Sys_Quit
- **Signature:** `void Sys_Quit(void)`
- **Purpose:** Clean shutdown initiated by game logic or user.
- **Side effects:** Ends timer period, shuts down client and common, frees dedicated console, calls `exit(0)`.
- **Calls:** `timeEndPeriod`, `CL_Shutdown`, `Qcommon_Shutdown`, `CloseHandle`, `FreeConsole`, `DeinitConProc`, `exit`

### Sys_Init
- **Signature:** `void Sys_Init(void)`
- **Purpose:** Platform initialization: sets timer resolution, detects OS version, allocates dedicated server console.
- **Side effects:** Sets `s_win95`; calls `timeBeginPeriod(1)`; for dedicated mode allocates a Win32 console and calls `InitConProc`.
- **Calls:** `timeBeginPeriod`, `GetVersionEx`, `Sys_Error`, `AllocConsole`, `GetStdHandle`, `InitConProc`

### Sys_GetGameAPI
- **Signature:** `void *Sys_GetGameAPI(void *parms)`
- **Purpose:** Locates and loads the game DLL, resolves `GetGameAPI` export, and calls it to obtain the game interface.
- **Inputs:** `parms` — passed through to the DLL's `GetGameAPI`.
- **Outputs/Return:** Pointer returned by `GetGameAPI`, or `NULL` on failure.
- **Side effects:** Sets `game_library`; searches debug dir → cwd → `FS_NextPath` chain.
- **Calls:** `_getcwd`, `Com_sprintf`, `LoadLibrary`, `Com_DPrintf`, `FS_NextPath`, `GetProcAddress`, `Sys_UnloadGame`

### Sys_ConsoleInput
- **Signature:** `char *Sys_ConsoleInput(void)`
- **Purpose:** Polls the dedicated server console for a complete input line.
- **Outputs/Return:** Pointer to `console_text` on Enter, `NULL` otherwise.
- **Side effects:** Echoes characters via `WriteFile`; modifies `console_text` / `console_textlen`.
- **Calls:** `GetNumberOfConsoleInputEvents`, `ReadConsoleInput`, `WriteFile`, `Sys_Error`

### Sys_ConsoleOutput
- **Signature:** `void Sys_ConsoleOutput(char *string)`
- **Purpose:** Writes engine output to the dedicated console, temporarily clearing the input line.
- **Calls:** `WriteFile`

### Sys_SendKeyEvents
- **Signature:** `void Sys_SendKeyEvents(void)`
- **Purpose:** Drains the Win32 message queue and captures the frame timestamp.
- **Side effects:** Updates `sys_msg_time` and `sys_frame_time`; dispatches all pending messages.
- **Calls:** `PeekMessage`, `GetMessage`, `Sys_Quit`, `TranslateMessage`, `DispatchMessage`, `timeGetTime`

### Sys_GetClipboardData
- **Signature:** `char *Sys_GetClipboardData(void)`
- **Purpose:** Returns a `malloc`'d copy of the current clipboard text, or `NULL`.
- **Side effects:** Allocates heap memory (caller must free).
- **Calls:** `OpenClipboard`, `GetClipboardData`, `GlobalLock`, `GlobalSize`, `malloc`, `strcpy`, `GlobalUnlock`, `CloseClipboard`

### ParseCommandLine
- **Signature:** `void ParseCommandLine(LPSTR lpCmdLine)`
- **Purpose:** Tokenizes the Win32 command line string into `argc`/`argv`, treating printable non-whitespace characters as token boundaries.
- **Notes:** Max `MAX_NUM_ARGVS` (128) tokens; `argv[0]` is hardcoded to `"exe"`.

## Control Flow Notes
`WinMain` is the top-level entry point. After `Qcommon_Init`, it runs an infinite loop: pump messages → spin-wait for ≥1 ms → `Qcommon_Frame`. `Sys_SendKeyEvents` is called from within `Qcommon_Frame` (defined elsewhere) to dispatch input. `Sys_Init` is called during `Qcommon_Init`. Shutdown paths go through `Sys_Quit` or `Sys_Error`.

## External Dependencies
- `../qcommon/qcommon.h` — `Qcommon_Init`, `Qcommon_Frame`, `Qcommon_Shutdown`, `Com_Error`, `Com_Quit`, `FS_NextPath`, `dedicated`, `Sys_Milliseconds`
- `winquake.h` — `cl_hwnd`, shared Win32 types
- `conproc.h` — `InitConProc`, `DeinitConProc` (QHOST hook support)
- `CL_Shutdown` — defined in client layer
- `timeBeginPeriod` / `timeEndPeriod` / `timeGetTime` — `winmm.lib`
- `_controlfp` — MSVC CRT FPU control
