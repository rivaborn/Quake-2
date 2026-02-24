# win32/cd_win.c

## File Purpose
Windows-specific CD audio subsystem implementation using the Win32 MCI (Media Control Interface) API. Provides playback control for audio CD tracks as background music in Quake 2, with support for looping, remapping, pause/resume, and window focus handling.

## Core Responsibilities
- Initialize and shut down the MCI CD audio device
- Play, stop, pause, and resume CD audio tracks
- Handle track remapping (logical-to-physical track translation)
- Process MCI notification messages for looping logic
- Respond to window focus changes (activate/deactivate)
- Expose a `cd` console command for manual control
- Sync enabled state with the `cd_nocd` cvar each frame

## Key Types / Data Structures
None (uses Win32 MCI structs: `MCI_OPEN_PARMS`, `MCI_SET_PARMS`, `MCI_STATUS_PARMS`, `MCI_PLAY_PARMS`, `MCI_GENERIC_PARMS` — all from `<windows.h>`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `cdValid` | `qboolean` | static | Whether a valid audio CD is present |
| `playing` | `qboolean` | static | Whether a track is currently playing |
| `wasPlaying` | `qboolean` | static | Whether playback was active before pause |
| `initialized` | `qboolean` | static | Whether MCI device was successfully opened |
| `enabled` | `qboolean` | static | Whether CD audio is enabled |
| `playLooping` | `qboolean` | static | Whether current track is in loop mode |
| `remap[100]` | `byte[]` | static | Track number remapping table |
| `cdrom` | `byte` | static | Unused drive letter field |
| `playTrack` | `byte` | static | Currently playing track number |
| `maxTrack` | `byte` | static | Number of tracks on the disc |
| `wDeviceID` | `UINT` | global | MCI device handle |
| `loopcounter` | `int` | global | Counts loop iterations for looptrack switching |
| `cd_nocd` | `cvar_t *` | global | Disables CD audio when non-zero |
| `cd_loopcount` | `cvar_t *` | global | Number of loops before switching to ambient track |
| `cd_looptrack` | `cvar_t *` | global | Ambient/fallback track number after looping |

## Key Functions

### CDAudio_Init
- **Signature:** `int CDAudio_Init(void)`
- **Purpose:** Opens the MCI cdaudio device, sets TMSF time format, initializes remap table, registers `cd` console command.
- **Inputs:** None
- **Outputs/Return:** `0` on success, `-1` on failure
- **Side effects:** Sets `wDeviceID`, `initialized`, `enabled`, `cdValid`; registers cvar and command
- **Calls:** `Cvar_Get`, `mciSendCommand`, `CDAudio_GetAudioDiskInfo`, `Cmd_AddCommand`, `Com_Printf`
- **Notes:** Returns `-1` early (without closing device) if `cd_nocd` is set. If no disc is present, sets `enabled = false` but continues without error.

### CDAudio_Play2
- **Signature:** `void CDAudio_Play2(int track, qboolean looping)`
- **Purpose:** Core playback function; remaps track, validates it as audio, issues MCI_PLAY with notification callback.
- **Inputs:** `track` — logical track number; `looping` — loop flag
- **Outputs/Return:** void
- **Side effects:** Sets `playing`, `playTrack`, `playLooping`; may call `CDAudio_Stop`; pauses immediately if `cd_nocd` is set
- **Calls:** `CDAudio_GetAudioDiskInfo`, `CDAudio_Stop`, `mciSendCommand`, `CDAudio_Pause`, `Cvar_VariableValue`
- **Notes:** Uses `MCI_NOTIFY` so playback completion is handled asynchronously via `CDAudio_MessageHandler`.

### CDAudio_Play
- **Signature:** `void CDAudio_Play(int track, qboolean looping)`
- **Purpose:** Public entry point; resets `loopcounter` to 0 then delegates to `CDAudio_Play2`.
- **Inputs/Outputs:** Same as `CDAudio_Play2`
- **Side effects:** Resets `loopcounter`
- **Calls:** `CDAudio_Play2`

### CDAudio_MessageHandler
- **Signature:** `LONG CDAudio_MessageHandler(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)`
- **Purpose:** Handles `MM_MCINOTIFY` Windows messages to drive looping logic and detect failures.
- **Inputs:** Standard Win32 window message parameters; `lParam` must equal `wDeviceID`
- **Outputs/Return:** `0` on handled, `1` on unhandled/wrong device
- **Side effects:** May call `CDAudio_Play2` to restart/switch tracks; may call `CDAudio_Stop` on failure
- **Calls:** `CDAudio_Play2`, `CDAudio_Stop`, `Com_DPrintf`
- **Notes:** After `loopcount` loops of the same track, switches to `cd_looptrack` as ambient music.

### CDAudio_Update
- **Signature:** `void CDAudio_Update(void)`
- **Purpose:** Per-frame sync between `cd_nocd` cvar and internal `enabled` state.
- **Side effects:** May stop playback or resume it; toggles `enabled`
- **Calls:** `CDAudio_Stop`, `CDAudio_Resume`

### CDAudio_Shutdown
- **Signature:** `void CDAudio_Shutdown(void)`
- **Purpose:** Stops playback and closes the MCI device on engine exit.
- **Calls:** `CDAudio_Stop`, `mciSendCommand`

### CDAudio_Activate
- **Signature:** `void CDAudio_Activate(qboolean active)`
- **Purpose:** Pauses CD on window focus loss, resumes on focus regain.
- **Calls:** `CDAudio_Resume`, `CDAudio_Pause`

- **Notes:** `CDAudio_Eject`, `CDAudio_CloseDoor`, `CDAudio_GetAudioDiskInfo`, `CDAudio_Stop`, `CDAudio_Pause`, `CDAudio_Resume`, and `CD_f` are straightforward helpers; `CD_f` dispatches the `cd` console command to all above public APIs.

## Control Flow Notes
- `CDAudio_Init` is called once at engine startup; `CDAudio_Shutdown` at exit.
- `CDAudio_Update` is called every client frame to poll cvar state.
- `CDAudio_MessageHandler` is called from the Win32 message pump (in `sys_win.c` or `vid_dll.c`) when `MM_MCINOTIFY` arrives on `cl_hwnd`.
- `CDAudio_Activate` is called by the window focus handler.

## External Dependencies
- `<windows.h>` — MCI API, Win32 types
- `../client/client.h` — `qboolean`, `byte`, `cvar_t`, `Com_Printf`, `Com_DPrintf`, `Cvar_Get`, `Cvar_VariableValue`, `Cmd_AddCommand`, `Cmd_Argc`, `Cmd_Argv`, `Q_strcasecmp`
- `cl_hwnd` — defined in `win32/sys_win.c` or `win32/vid_dll.c`; the main application window handle used as MCI callback target
