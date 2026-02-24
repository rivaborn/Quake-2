# linux/rw_linux.h

## File Purpose
Defines the shared interface between the Linux render/window driver (loaded as a shared object via `vid_so`) and the client input subsystem. It declares function pointer types and a state-passing struct used to wire keyboard and input callbacks back into the client.

## Core Responsibilities
- Defines the `Key_Event_fp_t` function pointer type for keyboard event delivery
- Declares extern function pointers for keyboard driver lifecycle (`KBD_Init_fp`, `KBD_Update_fp`, `KBD_Close_fp`)
- Defines `in_state_t` to bundle client-side input state and callbacks passed into the input driver

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `Key_Event_fp_t` | typedef (function pointer) | Callback signature for delivering a key event (key index + pressed/released) to the client |
| `in_state_t` | struct | Aggregates pointers to client state and callbacks needed by the platform input driver |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `KBD_Update_fp` | `void (*)(void)` | global (extern) | Points to the keyboard poll/update function provided by the active input backend |
| `KBD_Init_fp` | `void (*)(Key_Event_fp_t)` | global (extern) | Points to the keyboard initialization function; receives the event callback |
| `KBD_Close_fp` | `void (*)(void)` | global (extern) | Points to the keyboard shutdown function |

## Key Functions
None defined in this header.

## Control Flow Notes
This header sits at the seam between `vid_so.c` (the shared-object video/input loader) and the concrete input backends (e.g., `rw_x11.c`, `rw_svgalib.c`). During initialization, `vid_so` loads a render `.so`, resolves `KBD_Init_fp`/`KBD_Update_fp`/`KBD_Close_fp` from it, and passes an `in_state_t` populated with client-side pointers (`IN_CenterView_fp`, `Key_Event_fp`, `viewangles`, `in_strafe_state`) so the input backend can fire events and read/write client state without a hard link back to the client binary.

## External Dependencies
- `qboolean`, `vec_t` — defined elsewhere (likely `qcommon/qcommon.h` or `game/q_shared.h`)
- Actual definitions of `KBD_Update_fp`, `KBD_Init_fp`, `KBD_Close_fp` — defined in `linux/vid_so.c` or the active input backend
- `IN_CenterView_fp` target — defined in `client/cl_input.c`
