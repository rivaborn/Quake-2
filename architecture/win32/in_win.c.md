# win32/in_win.c

## File Purpose
Windows 95/Win32 platform input backend handling mouse and joystick input for Quake 2. It translates raw Win32/WinMM hardware input into engine movement commands and key events each frame.

## Core Responsibilities
- Initialize and shut down mouse and joystick hardware on Windows
- Activate/deactivate mouse capture and cursor clipping based on window focus
- Convert mouse delta into view angle changes and movement commands
- Poll joystick state via WinMM (`joyGetPosEx`) and map axes to movement
- Fire `Key_Event` calls for mouse buttons, joystick buttons, and POV hat changes
- Expose `IN_Init`/`IN_Shutdown`/`IN_Frame`/`IN_Move`/`IN_Commands` as the platform input interface

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `_ControlList` | enum | Named logical axis roles: Forward, Look, Side, Turn, Up |
| `JOYINFOEX` (`ji`) | struct (WinMM) | Holds raw joystick position, button, and POV data from each poll |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `dwAxisMap[6]` | `DWORD[]` | global | Maps each physical joystick axis to a logical `_ControlList` role |
| `dwControlMap[6]` | `DWORD[]` | global | Absolute vs. relative control mode per axis |
| `pdwRawValue[6]` | `PDWORD[]` | global | Pointers into `ji` fields for each axis (set by `RawValuePointer`) |
| `ji` | `JOYINFOEX` | static | Single shared joystick state buffer, reused every poll |
| `mouseactive` | `qboolean` | global | Whether mouse is currently captured |
| `mouseinitialized` | `qboolean` | global | Whether mouse startup succeeded |
| `joy_avail` | `qboolean` | global | Whether a valid joystick was found at startup |
| `joy_advancedinit` | `qboolean` | global | Deferred advanced axis init flag |
| `in_appactive` | `qboolean` | global | Whether the application window is focused |
| `window_center_x/y` | `int` | global | Screen-space center of window; cursor is reset here each frame |
| `mouse_oldbuttonstate` | `int` | global | Previous frame button bitmask for edge detection |
| `joy_oldbuttonstate` | `DWORD` | global | Previous frame joystick button bitmask for edge detection |
| `joy_oldpovstate` | `DWORD` | global | Previous frame POV hat bitmask for edge detection |

## Key Functions

### IN_ActivateMouse
- **Signature:** `void IN_ActivateMouse(void)`
- **Purpose:** Captures mouse to window, clips cursor, hides cursor, sets acceleration parameters.
- **Inputs:** None (reads `mouseinitialized`, `in_mouse`, `mouseactive`, `cl_hwnd`)
- **Outputs/Return:** void
- **Side effects:** Sets `mouseactive = true`; calls `SetCapture`, `ClipCursor`, `ShowCursor`, `SetCursorPos`; may call `SystemParametersInfo(SPI_SETMOUSE)` to override OS acceleration.
- **Calls:** `GetSystemMetrics`, `GetWindowRect`, `SetCursorPos`, `SetCapture`, `ClipCursor`, `ShowCursor`, `SystemParametersInfo`

### IN_DeactivateMouse
- **Signature:** `void IN_DeactivateMouse(void)`
- **Purpose:** Releases mouse capture, restores cursor visibility and original OS mouse parameters.
- **Side effects:** Sets `mouseactive = false`; calls `ClipCursor(NULL)`, `ReleaseCapture`, `ShowCursor`, optionally restores `originalmouseparms`.

### IN_MouseMove
- **Signature:** `void IN_MouseMove(usercmd_t *cmd)`
- **Purpose:** Computes delta from window center, applies optional filtering and sensitivity, writes to `cmd->sidemove`/`forwardmove` or `cl.viewangles`, then recenters cursor.
- **Inputs:** `cmd` — movement command being built
- **Side effects:** Modifies `cl.viewangles[YAW/PITCH]`, `cmd->sidemove/forwardmove`; calls `SetCursorPos` to recenter.
- **Calls:** `GetCursorPos`, `SetCursorPos`

### IN_JoyMove
- **Signature:** `void IN_JoyMove(usercmd_t *cmd)`
- **Purpose:** Reads joystick axes, normalizes to –1..1, applies per-axis threshold/sensitivity, and writes to `cmd` movement fields or `cl.viewangles`.
- **Inputs:** `cmd` — movement command being built
- **Side effects:** Modifies `cmd->forwardmove/sidemove/upmove`, `cl.viewangles[PITCH/YAW]`; triggers deferred `Joy_AdvancedUpdate_f` on first call.
- **Calls:** `Joy_AdvancedUpdate_f`, `IN_ReadJoystick`

### IN_Commands
- **Signature:** `void IN_Commands(void)`
- **Purpose:** Detects joystick button and POV hat edge transitions and fires `Key_Event` for each.
- **Side effects:** Updates `joy_oldbuttonstate`, `joy_oldpovstate`; calls `Key_Event`.

### IN_StartupJoystick
- **Signature:** `void IN_StartupJoystick(void)`
- **Purpose:** Enumerates WinMM joystick devices, validates the first responding one, reads capabilities.
- **Side effects:** Sets `joy_avail`, `joy_id`, `joy_numbuttons`, `joy_haspov`; calls `Com_Printf`.

### Joy_AdvancedUpdate_f
- **Signature:** `void Joy_AdvancedUpdate_f(void)`
- **Purpose:** Rebuilds `dwAxisMap`, `dwControlMap`, `pdwRawValue`, and `joy_flags` from cvars. Called once deferred (first `IN_JoyMove`) or manually via console command.
- **Side effects:** Overwrites the three axis mapping globals.

### IN_Init / IN_Shutdown / IN_Frame / IN_Move / IN_Activate
- `IN_Init`: registers all mouse/joystick cvars, adds `+mlook`/`-mlook`/`joy_advancedupdate` commands, calls startup routines.
- `IN_Shutdown`: calls `IN_DeactivateMouse`.
- `IN_Frame`: per-frame mouse focus logic — deactivates during console/menu in windowed mode, otherwise activates.
- `IN_Move`: dispatches `IN_MouseMove` and, if `ActiveApp`, `IN_JoyMove`.
- `IN_Activate`: sets `in_appactive`; forces mouse recheck on next frame.

## Control Flow Notes
- `IN_Init` is called at engine startup; `IN_Shutdown` at exit.
- `IN_Frame` is called every frame before command generation to manage capture state.
- `IN_Commands` is called by the client command pump to generate key events from joystick buttons.
- `IN_Move` is called during `CL_CreateCmd` to integrate device deltas into the current `usercmd_t`.

## External Dependencies
- `../client/client.h` — `cl`, `cls`, `usercmd_t`, `Key_Event`, `IN_CenterView`, cvars (`sensitivity`, `m_pitch`, `m_yaw`, etc.)
- `winquake.h` — `cl_hwnd`, `ActiveApp`, Windows headers
- `sys_msg_time` — extern `unsigned`, defined in `win32/sys_win.c`
- WinMM (`joyGetNumDevs`, `joyGetPosEx`, `joyGetDevCaps`) — Windows multimedia joystick API
