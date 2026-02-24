# null/cl_null.c

## File Purpose
Provides stub implementations of the entire client subsystem for use in dedicated server builds. All functions are no-ops or minimal error reporters, allowing the server to compile and run without any client, rendering, sound, or input code.

## Core Responsibilities
- Stub out `CL_Init`, `CL_Drop`, `CL_Shutdown`, and `CL_Frame` as empty no-ops
- Stub out console printing (`Con_Print`) and screen utilities (`SCR_*`)
- Register a no-op `bind` command so client-oriented config files don't crash on load
- Redirect unknown forwarded commands to a `Com_Printf` warning instead of sending to server

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions

### Key_Init
- **Signature:** `void Key_Init(void)`
- **Purpose:** Registers the `bind` console command with a no-op handler so dedicated servers don't crash when loading configs that contain `bind` directives.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** Calls `Cmd_AddCommand`, adding `"bind"` to the command registry.
- **Calls:** `Cmd_AddCommand`
- **Notes:** The only function here with a meaningful side effect; all others are pure stubs.

### Cmd_ForwardToServer
- **Signature:** `void Cmd_ForwardToServer(void)`
- **Purpose:** Intercepts client commands that would normally be forwarded to the server and prints an "Unknown command" warning instead.
- **Inputs:** None (reads current command via `Cmd_Argv(0)`)
- **Outputs/Return:** None
- **Side effects:** Writes to console via `Com_Printf`.
- **Calls:** `Cmd_Argv`, `Com_Printf`
- **Notes:** In the full client, this function serializes the command and sends it over the network. Here it is a safe dead-end.

**Notes on remaining stubs:** `CL_Init`, `CL_Drop`, `CL_Shutdown`, `CL_Frame`, `Con_Print`, `SCR_DebugGraph`, `SCR_BeginLoadingPlaque`, `SCR_EndLoadingPlaque`, and `Key_Bind_Null_f` are all empty bodies satisfying the linker's requirements for symbols the engine core references unconditionally.

## Control Flow Notes
The engine core (`qcommon`) calls `CL_Init` at startup, `CL_Frame` each tick, and `CL_Shutdown` at exit regardless of build type. This file satisfies those call sites for dedicated-server builds so the same `qcommon` object files can be linked without conditional compilation throughout.

## External Dependencies
- `../qcommon/qcommon.h` — pulls in `Cmd_Argv`, `Cmd_AddCommand`, `Com_Printf`
- `Cmd_Argv`, `Cmd_AddCommand`, `Com_Printf` — defined in `qcommon/cmd.c` and `qcommon/common.c`
