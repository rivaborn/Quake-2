# ctf/g_svcmds.c

## File Purpose
Implements the CTF game module's server-side command dispatch. It handles the `sv` console command by routing subcommands to registered handler functions.

## Core Responsibilities
- Receive and dispatch server commands issued via the `sv` console command
- Provide a test command (`sv test`) for diagnostic purposes
- Report unknown subcommands back to the server console

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions

### Svcmd_Test_f
- **Signature:** `void Svcmd_Test_f(void)`
- **Purpose:** Diagnostic no-op that prints a confirmation message to verify the server command routing is functional.
- **Inputs:** None.
- **Outputs/Return:** None (void).
- **Side effects:** Calls `gi.cprintf(NULL, PRINT_HIGH, ...)` to print to the server console.
- **Calls:** `gi.cprintf`
- **Notes:** `NULL` as the first argument to `gi.cprintf` targets the server console rather than a specific client.

---

### ServerCommand
- **Signature:** `void ServerCommand(void)`
- **Purpose:** Primary entry point called by the engine whenever an `sv` command is issued from the server console. Reads the first argument and dispatches to the appropriate handler.
- **Inputs:** None directly; reads arguments via `gi.argv(1)`.
- **Outputs/Return:** None (void).
- **Side effects:** May print to the server console via `gi.cprintf`. Delegates side effects to subcommand handlers.
- **Calls:** `gi.argv`, `Q_stricmp`, `Svcmd_Test_f`, `gi.cprintf`
- **Notes:** Only one subcommand (`test`) is registered in this CTF version. In contrast, the base `game/g_svcmds.c` typically registers additional commands (e.g., `addip`, `removeip`, `listip`). The CTF module's version is a minimal stub.

## Control Flow Notes
`ServerCommand` is an engine-facing entry point exported through the `game_export_t` interface. It is called by the server when the operator types `sv <cmd>` at the console. This happens outside of the normal per-frame game loop — it is an on-demand administrative path.

## External Dependencies
- **Includes:** `g_local.h` (pulls in all CTF game types, `game_import_t gi`, and shared utilities)
- **External symbols used:**
  - `gi.argv` — engine function to retrieve console command arguments
  - `gi.cprintf` — engine function for console output
  - `Q_stricmp` — case-insensitive string comparison (defined in `q_shared.c`)
