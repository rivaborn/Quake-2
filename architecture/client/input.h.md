# client/input.h

## File Purpose
Declares the public interface for external (non-keyboard) input devices such as mice and joysticks. Acts as a platform-abstraction boundary, allowing the client to drive input polling without coupling to platform-specific implementation details.

## Core Responsibilities
- Expose lifecycle hooks (`IN_Init`, `IN_Shutdown`) for input device setup and teardown
- Provide a per-frame polling hook (`IN_Frame`) for device state updates
- Allow devices to inject console commands (`IN_Commands`)
- Contribute device-derived movement deltas to the user command (`IN_Move`)
- Allow the client to notify input devices of focus/activation changes (`IN_Activate`)

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions

### IN_Init
- Signature: `void IN_Init(void)`
- Purpose: Initialize external input devices.
- Inputs: None
- Outputs/Return: None
- Side effects: Platform-specific device acquisition (mouse capture, joystick open, etc.)
- Calls: Not inferable from this file.
- Notes: Called once at client startup.

### IN_Shutdown
- Signature: `void IN_Shutdown(void)`
- Purpose: Release external input devices and clean up resources.
- Inputs: None
- Outputs/Return: None
- Side effects: Platform-specific device release.
- Calls: Not inferable from this file.
- Notes: Counterpart to `IN_Init`; called at client shutdown.

### IN_Commands
- Signature: `void IN_Commands(void)`
- Purpose: Give input devices an opportunity to push commands onto the command buffer (e.g., joystick button bindings).
- Inputs: None
- Outputs/Return: None
- Side effects: May append to the engine command script buffer.
- Calls: Not inferable from this file.
- Notes: Called once per frame before movement processing.

### IN_Frame
- Signature: `void IN_Frame(void)`
- Purpose: Per-frame update tick for input devices; handles state polling and any device-specific bookkeeping.
- Inputs: None
- Outputs/Return: None
- Side effects: Updates internal device state; may interact with windowing system.
- Calls: Not inferable from this file.

### IN_Move
- Signature: `void IN_Move(usercmd_t *cmd)`
- Purpose: Accumulate additional movement (e.g., mouse look, joystick axes) on top of the keyboard-derived user command.
- Inputs: `cmd` — partially populated `usercmd_t` from keyboard processing.
- Outputs/Return: None (mutates `*cmd` in place).
- Side effects: Modifies `cmd->angles` or `cmd->forwardmove`/`sidemove` fields.
- Calls: Not inferable from this file.
- Notes: Called during `CL_CreateCmd` or equivalent frame command construction.

### IN_Activate
- Signature: `void IN_Activate(qboolean active)`
- Purpose: Notify input devices whether the application window is active/focused, enabling or disabling capture accordingly.
- Inputs: `active` — `true` to acquire input, `false` to release.
- Outputs/Return: None
- Side effects: May capture or release mouse cursor; platform-specific.
- Calls: Not inferable from this file.

## Control Flow Notes
Called by the client each frame in this order: `IN_Frame` → `IN_Commands` (command pump) → `IN_Move` (during user command build). `IN_Activate` is triggered by window focus events, not the frame loop. `IN_Init`/`IN_Shutdown` bracket the client session lifetime.

## External Dependencies
- `usercmd_t` — defined in `qcommon/qcommon.h` or `game/q_shared.h`; not defined here.
- `qboolean` — engine-wide boolean typedef; defined elsewhere.
- Platform implementations live in `win32/in_win.c`, `linux/in_linux.c`, etc.
