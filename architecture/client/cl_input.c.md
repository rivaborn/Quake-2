# client/cl_input.c

## File Purpose
Translates raw keyboard, mouse, and controller input into a `usercmd_t` movement command each frame, then transmits that command to the server. It manages the full lifecycle from key-press/release tracking through angle adjustment, button encoding, and delta-compressed network transmission.

## Core Responsibilities
- Track continuous key-button press/release state with dual-key overlap support (`kbutton_t`)
- Register all `+`/`-` console commands for movement, look, attack, use, etc.
- Compute per-frame movement fractions via `CL_KeyState` (time-weighted, not binary)
- Adjust view angles from keyboard look inputs (`CL_AdjustAngles`)
- Assemble a complete `usercmd_t` per frame (`CL_CreateCmd`)
- Encode buttons, angles, impulse, and ambient light level into the command (`CL_FinishMove`)
- Send three delta-compressed commands per packet for redundancy (`CL_SendCmd`)

## Key Types / Data Structures
| Name | Kind | Purpose |
|------|------|---------|
| `kbutton_t` | struct (defined in `client.h`) | Tracks press state of a single logical button: two holding keys, accumulated msec, state bitmask |
| `usercmd_t` | struct (defined in `qcommon.h`) | Per-frame movement command sent to server: angles, forwardmove, sidemove, upmove, buttons, impulse, msec |

## Global / File-Static State
| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `cl_nodelta` | `cvar_t *` | global | Disables delta compression on outgoing cmds when set |
| `frame_msec` | `unsigned` | global | Duration of current frame in ms; used by `CL_KeyState` for time-weighting |
| `old_sys_frame_time` | `unsigned` | global | Previous frame's system time; used to compute `frame_msec` |
| `in_klook`, `in_left`, `in_right`, etc. | `kbutton_t` | global | One instance per logical input action (14 total) |
| `in_impulse` | `int` | global | Queued impulse command number, cleared after each send |
| `cl_upspeed`, `cl_forwardspeed`, `cl_sidespeed`, `cl_yawspeed`, `cl_pitchspeed`, `cl_run`, `cl_anglespeedkey` | `cvar_t *` | global | Movement speed tuning cvars |

## Key Functions

### KeyDown
- **Signature:** `void KeyDown(kbutton_t *b)`
- **Purpose:** Records a key press into a button slot; sets state bits for "down" and "impulse down".
- **Inputs:** `b` — button to update; reads `Cmd_Argv(1)` (key number) and `Cmd_Argv(2)` (timestamp).
- **Outputs/Return:** void
- **Side effects:** Modifies `b->down[]`, `b->state`, `b->downtime`.
- **Calls:** `Cmd_Argv`, `atoi`, `Com_Printf`
- **Notes:** Supports two simultaneous physical keys per logical button. Falls back to `sys_frame_time - 100` if no timestamp is provided (manual console entry).

### KeyUp
- **Signature:** `void KeyUp(kbutton_t *b)`
- **Purpose:** Releases one physical key from a button slot; accumulates held milliseconds; sets "impulse up" bit.
- **Inputs:** `b` — button to update; reads `Cmd_Argv(1)` (key number) and `Cmd_Argv(2)` (uptime).
- **Outputs/Return:** void
- **Side effects:** Modifies `b->down[]`, `b->state`, `b->msec`.
- **Calls:** `Cmd_Argv`, `atoi`
- **Notes:** Console-typed release (`k == 0`) clears both slots unconditionally for unsticking.

### CL_KeyState
- **Signature:** `float CL_KeyState(kbutton_t *key)`
- **Purpose:** Returns fraction of the current frame (0.0–1.0) that the key was held, enabling sub-frame-accurate movement scaling.
- **Inputs:** `key` — button to query; uses global `frame_msec` and `sys_frame_time`.
- **Outputs/Return:** Clamped float in `[0, 1]`.
- **Side effects:** Clears `key->msec`; clears impulse bits from `key->state`; advances `key->downtime` if still held.
- **Calls:** none
- **Notes:** `frame_msec` must be set before this is called (done in `CL_CreateCmd`).

### CL_AdjustAngles
- **Signature:** `void CL_AdjustAngles(void)`
- **Purpose:** Applies keyboard yaw and pitch deltas to `cl.viewangles` each frame.
- **Inputs:** Global `in_speed`, `in_strafe`, `in_klook`, direction buttons; cvars for speeds.
- **Side effects:** Modifies `cl.viewangles[YAW]` and `cl.viewangles[PITCH]`.
- **Calls:** `CL_KeyState`
- **Notes:** `in_speed` scales turn rate by `cl_anglespeedkey`; `in_strafe` suppresses yaw turning (strafes instead); `in_klook` redirects forward/back into pitch.

### CL_BaseMove
- **Signature:** `void CL_BaseMove(usercmd_t *cmd)`
- **Purpose:** Fills keyboard-derived translation axes into `cmd`; applies run-speed doubling.
- **Inputs:** All directional `kbutton_t` globals, speed cvars.
- **Side effects:** Calls `CL_AdjustAngles`; zeroes then populates `*cmd`.
- **Calls:** `CL_AdjustAngles`, `CL_KeyState`, `memset`, `VectorCopy`

### CL_FinishMove
- **Signature:** `void CL_FinishMove(usercmd_t *cmd)`
- **Purpose:** Encodes button bits, frame milliseconds, clamped/quantised angles, impulse, and ambient light level into the command before sending.
- **Side effects:** Clears `in_attack`/`in_use` impulse bits; resets `in_impulse`; modifies `cl.viewangles` via `CL_ClampPitch`.
- **Calls:** `CL_ClampPitch`, `ANGLE2SHORT`, `SHORT2ANGLE`
- **Notes:** `ms` is capped at 100 if `>250` to reject unreasonable frame times.

### CL_CreateCmd
- **Signature:** `usercmd_t CL_CreateCmd(void)`
- **Purpose:** Top-level per-frame entry point that assembles a complete `usercmd_t` from keyboard, mouse, and other controllers.
- **Side effects:** Updates `frame_msec`, `old_sys_frame_time`; calls `IN_Move` for mouse/joystick contribution.
- **Calls:** `CL_BaseMove`, `IN_Move`, `CL_FinishMove`

### CL_SendCmd
- **Signature:** `void CL_SendCmd(void)`
- **Purpose:** Calls `CL_CreateCmd`, stores the result in the circular `cl.cmds[]` buffer, then transmits the last three commands delta-compressed in one packet for drop recovery.
- **Side effects:** Writes to `cls.netchan`; may call `SCR_FinishCinematic` to skip a cinematic on any button press; sends userinfo update if `userinfo_modified`.
- **Calls:** `CL_CreateCmd`, `MSG_WriteByte/Long/DeltaUsercmd`, `SZ_Init`, `Netchan_Transmit`, `COM_BlockSequenceCRCByte`, `CL_FixUpGender`, `Cvar_Userinfo`, `SCR_FinishCinematic`
- **Notes:** No-ops (or sends keepalive only) when disconnected/connecting/connected-but-not-active.

### CL_InitInput
- **Signature:** `void CL_InitInput(void)`
- **Purpose:** Registers all `+`/`-` movement console commands and initialises speed/delta cvars.
- **Calls:** `Cmd_AddCommand` (×33), `Cvar_Get`

## Control Flow Notes
- **Init:** `CL_InitInput` called once at client startup; registers commands and cvars.
- **Per frame:** `CL_SendCmd` is the frame-level driver — called from the client frame loop. It invokes `CL_CreateCmd` → `CL_BaseMove` → `CL_AdjustAngles` + `CL_KeyState` → `IN_Move` → `CL_FinishMove`, then transmits.
- **Key events:** `KeyDown`/`KeyUp` are invoked asynchronously by the key-event system through the registered console commands.

## External Dependencies
- **Includes:** `client.h` (pulls in `kbutton_t`, `usercmd_t`, `cl`, `cls`, cvars, etc.)
- **Defined elsewhere:** `sys_frame_time` (platform layer), `IN_Move` (platform input: mouse/joystick), `Netchan_Transmit`, `MSG_Write*`, `COM_BlockSequenceCRCByte`, `SCR_FinishCinematic`, `CL_FixUpGender`, `anykeydown`, `cl_lightlevel`, `curtime`
