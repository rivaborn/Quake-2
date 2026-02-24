# linux/cd_linux.c

## File Purpose
Linux-specific CD audio backend for Quake 2, controlling physical CD playback via Linux kernel `ioctl` calls against `/dev/cdrom`. It implements the platform CD audio interface consumed by the engine's client layer.

## Core Responsibilities
- Open and manage the CD device file descriptor
- Issue `ioctl` commands for play, stop, pause, resume, and eject operations
- Track playback state and handle looping via periodic polling
- Remap logical track numbers to physical track numbers
- Respond to volume cvar changes by pausing/resuming
- Expose a `cd` console command for manual control

## Key Types / Data Structures
None (no custom structs; uses `struct cdrom_tochdr`, `struct cdrom_tocentry`, `struct cdrom_ti`, `struct cdrom_subchnl` from `<linux/cdrom.h>`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `cdValid` | `qboolean` | static | Whether a valid audio CD is present |
| `playing` | `qboolean` | static | Currently playing |
| `wasPlaying` | `qboolean` | static | Was playing before pause |
| `initialized` | `qboolean` | static | Init completed successfully |
| `enabled` | `qboolean` | static | CD audio enabled (toggle) |
| `playLooping` | `qboolean` | static | Current track set to loop |
| `cdvolume` | `float` | static | Cached volume to detect cvar changes |
| `remap[100]` | `byte[100]` | static | Track number remapping table |
| `playTrack` | `byte` | static | Currently playing track number |
| `maxTrack` | `byte` | static | Highest track number on disc |
| `cdfile` | `int` | static | File descriptor for CD device |
| `cd_volume` | `cvar_t *` | global | Volume cvar (`cd_volume`) |
| `cd_nocd` | `cvar_t *` | global | Disable CD audio cvar |
| `cd_dev` | `cvar_t *` | global | Device path cvar (default `/dev/cdrom`) |

## Key Functions

### CDAudio_Init
- **Signature:** `int CDAudio_Init(void)`
- **Purpose:** Opens the CD device, initializes track remap table, reads disc TOC, registers `cd` console command.
- **Inputs:** None (reads `nocdaudio`, `cd_nocd`, `cd_dev` cvars)
- **Outputs/Return:** `0` on success, `-1` on failure
- **Side effects:** Sets `cdfile`, `initialized`, `enabled`; temporarily elevates to saved euid via `seteuid(saved_euid)` to open the device; calls `Cmd_AddCommand`
- **Calls:** `Cvar_Get`, `seteuid`, `open`, `getuid`, `CDAudio_GetAudioDiskInfo`, `Cmd_AddCommand`, `Com_Printf`
- **Notes:** Uses `saved_euid` (extern) to handle setuid permission requirements for raw device access.

### CDAudio_Play
- **Signature:** `void CDAudio_Play(int track, qboolean looping)`
- **Purpose:** Begins playback of a remapped audio track.
- **Inputs:** Logical track number; looping flag
- **Outputs/Return:** void
- **Side effects:** Sets `playing`, `playTrack`, `playLooping`; stops current track if different one is playing; pauses immediately if `cd_volume` is 0
- **Calls:** `CDAudio_GetAudioDiskInfo`, `CDAudio_Stop`, `ioctl` (`CDROMREADTOCENTRY`, `CDROMPLAYTRKIND`, `CDROMRESUME`), `CDAudio_Pause`
- **Notes:** Skips data tracks via `CDROM_DATA_TRACK` check; applies `remap[]` before range validation.

### CDAudio_Update
- **Signature:** `void CDAudio_Update(void)`
- **Purpose:** Per-frame poll: detects track completion for looping and handles volume cvar changes.
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** May call `CDAudio_Pause`/`CDAudio_Resume` on volume change; restarts track if looping and playback ended; polls every 2 seconds via `lastchk` static
- **Calls:** `Cvar_SetValue`, `CDAudio_Pause`, `CDAudio_Resume`, `ioctl` (`CDROMSUBCHNL`), `CDAudio_Play`, `time`
- **Notes:** Volume control is binary (0 = pause, nonzero = resume); `lastchk` is `static time_t` local to function.

### CDAudio_Shutdown
- **Signature:** `void CDAudio_Shutdown(void)`
- **Purpose:** Stops playback and closes the device.
- **Side effects:** Calls `CDAudio_Stop`, `close(cdfile)`, resets `cdfile = -1`

### CDAudio_Activate
- **Signature:** `void CDAudio_Activate(qboolean active)`
- **Purpose:** Pauses or resumes playback on application focus loss/gain.

### CD_f *(static)*
- Console command handler for `cd on/off/reset/remap/play/loop/stop/pause/resume/eject/info/close`.

### Notes
- `CDAudio_Eject`, `CDAudio_CloseDoor`, `CDAudio_GetAudioDiskInfo` are trivial static helpers wrapping single `ioctl` calls.

## Control Flow Notes
- `CDAudio_Init` called at engine startup; `CDAudio_Shutdown` at exit.
- `CDAudio_Update` called each client frame to poll disc status and respond to cvar changes.
- `CDAudio_Activate` called on window focus events.

## External Dependencies
- `<linux/cdrom.h>` — Linux kernel CD ioctl interface
- `../client/client.h` — `qboolean`, `byte`, `cvar_t`, `Cvar_Get`, `Cmd_AddCommand`, `Com_Printf`, `Com_DPrintf`
- `saved_euid` (`uid_t`) — defined in platform system layer (`linux/sys_linux.c`)
