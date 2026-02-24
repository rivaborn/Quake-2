# client/cdaudio.h

## File Purpose
Public interface header for the CD audio subsystem. Declares the six lifecycle and control functions that the engine calls to manage CD music playback.

## Core Responsibilities
- Expose CD audio initialization and shutdown entry points
- Declare playback control functions (play, stop, update)
- Provide an activation toggle for focus/minimize handling

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions

### CDAudio_Init
- Signature: `int CDAudio_Init(void)`
- Purpose: Initialize the CD audio subsystem and hardware/OS interface.
- Inputs: None
- Outputs/Return: Integer status code; non-zero likely indicates failure.
- Side effects: Platform-specific CD device acquisition.
- Calls: Not inferable from this file.
- Notes: Must be called before any other CDAudio function.

### CDAudio_Shutdown
- Signature: `void CDAudio_Shutdown(void)`
- Purpose: Release all CD audio resources and close the device.
- Inputs: None
- Outputs/Return: None
- Side effects: Closes platform CD device handle.
- Calls: Not inferable from this file.
- Notes: Engine shutdown counterpart to `CDAudio_Init`.

### CDAudio_Play
- Signature: `void CDAudio_Play(int track, qboolean looping)`
- Purpose: Begin playback of a specific CD track, optionally looping.
- Inputs: `track` — 1-based CD track number; `looping` — whether to loop continuously.
- Outputs/Return: None
- Side effects: Starts CD drive playback; may stop any currently playing track.
- Calls: Not inferable from this file.
- Notes: Track numbering follows standard Red Book CD conventions.

### CDAudio_Stop
- Signature: `void CDAudio_Stop(void)`
- Purpose: Halt CD playback immediately.
- Inputs: None
- Outputs/Return: None
- Side effects: Stops CD drive playback.
- Calls: Not inferable from this file.

### CDAudio_Update
- Signature: `void CDAudio_Update(void)`
- Purpose: Per-frame pump for the CD audio system; handles looping logic and cvar-driven changes.
- Inputs: None
- Outputs/Return: None
- Side effects: May restart playback if looping; reads CD-related cvars.
- Calls: Not inferable from this file.
- Notes: Expected to be called once per game frame from the client update loop.

### CDAudio_Activate
- Signature: `void CDAudio_Activate(qboolean active)`
- Purpose: Pause or resume CD playback when the application loses or regains focus.
- Inputs: `active` — `true` to resume, `false` to pause.
- Outputs/Return: None
- Side effects: Pauses/resumes the CD drive.
- Calls: Not inferable from this file.
- Notes: Typically wired to OS window focus/minimize events.

## Control Flow Notes
This header sits at the boundary between the platform-independent client layer and platform-specific CD implementations (e.g., `win32/cd_win.c`, `linux/cd_linux.c`). `CDAudio_Init` is called during client startup, `CDAudio_Update` is called each frame, and `CDAudio_Shutdown` is called on exit. `CDAudio_Activate` is driven by OS focus events.

## External Dependencies
- `qboolean` — defined in `qcommon/qcommon.h` or `game/q_shared.h`; no includes are present in this header, so the including translation unit must provide it.
