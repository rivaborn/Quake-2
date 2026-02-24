# server/sv_null.c

## File Purpose
Provides a null/stub implementation of the server subsystem for pure client-only builds. All server functions are no-ops, allowing the engine to compile and link without a real server.

## Core Responsibilities
- Satisfies the server API link requirements for client-only configurations
- Prevents the server subsystem from executing any logic or allocating any resources
- Acts as a compile-time switch to exclude the full server module

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions

### SV_Init
- Signature: `void SV_Init(void)`
- Purpose: Stub server initialization — does nothing.
- Inputs: None
- Outputs/Return: void
- Side effects: None
- Calls: None
- Notes: Replaces the real `SV_Init` in `server/sv_init.c` when building without server support.

### SV_Shutdown
- Signature: `void SV_Shutdown(char *finalmsg, qboolean reconnect)`
- Purpose: Stub server shutdown — does nothing.
- Inputs: `finalmsg` — shutdown message string; `reconnect` — reconnect flag
- Outputs/Return: void
- Side effects: None
- Calls: None
- Notes: Parameters are intentionally ignored.

### SV_Frame
- Signature: `void SV_Frame(float time)`
- Purpose: Stub per-frame server tick — does nothing.
- Inputs: `time` — elapsed frame time
- Outputs/Return: void
- Side effects: None
- Calls: None
- Notes: Called each engine frame from the main loop; this stub ensures the loop continues without server processing.

## Control Flow Notes
In a full build, `SV_Init` is called during engine startup, `SV_Frame` is called every game frame from `Qcommon_Frame`, and `SV_Shutdown` is called on exit. This file replaces all three entry points with no-ops, completely excising the server path at link time for net-only client builds.

## External Dependencies
- No includes required — relies solely on built-in C types and `qboolean` being resolved at compile time (or not referenced here since it appears only as a parameter type in a stub).
- `SV_Init`, `SV_Shutdown`, `SV_Frame` — defined here as stubs; real implementations reside in `server/sv_init.c` and `server/sv_main.c`.
