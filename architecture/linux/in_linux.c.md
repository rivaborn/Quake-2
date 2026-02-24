# linux/in_linux.c

## File Purpose
Stub implementation of the Linux input subsystem for Quake 2. Despite the filename `in_linux.c`, the file comment identifies it as `in_null.c`, indicating this is a no-op placeholder that registers input cvars but performs no actual mouse or joystick processing.

## Core Responsibilities
- Register `in_mouse` and `in_joystick` cvars at initialization
- Satisfy the input API contract required by the engine without providing any real input handling
- Serve as a base or fallback input module on Linux where SVGAlib/X11 drivers handle input directly

## Key Types / Data Structures
None.

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `in_mouse` | `cvar_t *` | global | Controls whether mouse input is enabled (default `"1"`, archived) |
| `in_joystick` | `cvar_t *` | global | Controls whether joystick input is enabled (default `"0"`, archived) |

## Key Functions

### IN_Init
- **Signature:** `void IN_Init(void)`
- **Purpose:** Initializes the input subsystem by registering console variables.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** Registers `in_mouse` and `in_joystick` cvars via `Cvar_Get`; values persist across sessions via `CVAR_ARCHIVE`.
- **Calls:** `Cvar_Get`
- **Notes:** Only meaningful work done in this entire file; all other functions are no-ops.

### IN_Shutdown
- **Signature:** `void IN_Shutdown(void)`
- **Purpose:** Stub shutdown — no resources to release.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** None
- **Calls:** None
- **Notes:** No-op.

### IN_Commands
- **Signature:** `void IN_Commands(void)`
- **Purpose:** Stub for polling input device button events into the command buffer each frame.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** None
- **Calls:** None
- **Notes:** No-op; real implementations would inject joystick button presses here.

### IN_Move
- **Signature:** `void IN_Move(usercmd_t *cmd)`
- **Purpose:** Stub for accumulating mouse/joystick deltas into a user command each frame.
- **Inputs:** `cmd` — pointer to the `usercmd_t` being built for the current frame
- **Outputs/Return:** None
- **Side effects:** None (cmd is not modified)
- **Calls:** None
- **Notes:** No-op; real implementations would add look/strafe deltas to `cmd->angles` and `cmd->sidemove`.

### IN_Activate
- **Signature:** `void IN_Activate(qboolean active)`
- **Purpose:** Stub for grabbing or releasing the input focus (e.g., mouse grab on window focus change).
- **Inputs:** `active` — `true` to acquire input, `false` to release
- **Outputs/Return:** None
- **Side effects:** None
- **Calls:** None
- **Notes:** No-op.

## Control Flow Notes
Called by the engine each frame: `IN_Commands` is polled before movement processing; `IN_Move` is called during `CL_CreateCmd` to fill the `usercmd_t`. `IN_Init`/`IN_Shutdown` bracket the client lifetime. Because all functions are stubs, this file contributes nothing to the actual input pipeline at runtime.

## External Dependencies
- `../client/client.h` — pulls in `cvar_t`, `usercmd_t`, `qboolean`, and `Cvar_Get`
- `Cvar_Get` — defined in `qcommon/cvar.c`
