# null/in_null.c

## File Purpose
Null/stub implementation of the input subsystem for platforms or configurations that have no mouse or input device support. All functions are empty no-ops, satisfying the input interface contract without performing any work.

## Core Responsibilities
- Provide a compilable, linkable input module for headless or input-less builds
- Satisfy the engine's required input API surface (`IN_*` functions)
- Serve as a safe default for the `null` platform target

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions

### IN_Init
- **Signature:** `void IN_Init(void)`
- **Purpose:** Input subsystem initialization stub.
- **Inputs:** None.
- **Outputs/Return:** None.
- **Side effects:** None.
- **Calls:** None.
- **Notes:** Called during engine startup; no-op here.

### IN_Shutdown
- **Signature:** `void IN_Shutdown(void)`
- **Purpose:** Input subsystem teardown stub.
- **Inputs:** None.
- **Outputs/Return:** None.
- **Side effects:** None.
- **Calls:** None.
- **Notes:** Called during engine shutdown; no-op here.

### IN_Commands
- **Signature:** `void IN_Commands(void)`
- **Purpose:** Per-frame input command polling stub (e.g., joystick buttons).
- **Inputs:** None.
- **Outputs/Return:** None.
- **Side effects:** None.
- **Calls:** None.
- **Notes:** Called once per frame before movement accumulation.

### IN_Frame
- **Signature:** `void IN_Frame(void)`
- **Purpose:** Per-frame input processing stub.
- **Inputs:** None.
- **Outputs/Return:** None.
- **Side effects:** None.
- **Calls:** None.
- **Notes:** Distinct from `IN_Commands`; used for window-focus or grab toggling in real implementations.

### IN_Move
- **Signature:** `void IN_Move(usercmd_t *cmd)`
- **Purpose:** Accumulate mouse/input deltas into the player movement command stub.
- **Inputs:** `cmd` — pointer to the current `usercmd_t` being built.
- **Outputs/Return:** None; `cmd` is unmodified.
- **Side effects:** None.
- **Calls:** None.
- **Notes:** In real implementations this is where mouse look deltas are written into `cmd->angularbits` or similar fields.

### IN_Activate / IN_ActivateMouse / IN_DeactivateMouse
- **Signature:** `void IN_Activate(qboolean active)` / `void IN_ActivateMouse(void)` / `void IN_DeactivateMouse(void)`
- **Purpose:** Stubs for focus/grab lifecycle management of the mouse cursor.
- **Inputs:** `IN_Activate` takes a boolean active flag; others take none.
- **Outputs/Return:** None.
- **Side effects:** None.
- **Calls:** None.
- **Notes:** Real implementations acquire/release OS mouse capture here.

## Control Flow Notes
This file participates in the per-frame loop via `IN_Commands`, `IN_Frame`, and `IN_Move`, and in the engine lifecycle via `IN_Init` and `IN_Shutdown`. Because all functions are no-ops, it has no effect on any stage.

## External Dependencies
- `../client/client.h` — provides `usercmd_t` and `qboolean` type definitions; the `IN_*` function signatures are part of the platform input interface declared there.
- All symbols (`usercmd_t`, `qboolean`) are **defined elsewhere**.
