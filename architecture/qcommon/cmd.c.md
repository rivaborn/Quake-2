# qcommon/cmd.c

## File Purpose
Implements Quake 2's command buffer and command execution subsystem. It manages a text-based command queue, tokenizes and dispatches commands to registered handlers, and supports aliases, cvar macro expansion, and deferred execution.

## Core Responsibilities
- Maintain a circular-style text command buffer (`cmd_text`) with insert/append/execute operations
- Tokenize command strings into argc/argv form with optional `$cvar` macro expansion
- Dispatch commands to registered `cmd_function_t` handlers, aliases, cvars, or the server
- Manage a linked-list registry of named commands (`cmd_functions`)
- Manage a linked-list of named command aliases (`cmd_alias`)
- Support deferred buffer copy (`Cbuf_CopyToDefer`/`Cbuf_InsertFromDefer`) for level transitions
- Parse early (`+set`) and late (`+cmd`) command-line arguments into the buffer

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `cmdalias_t` | struct | Linked-list node mapping an alias name to a command string |
| `cmd_function_t` | struct | Linked-list node mapping a command name to an `xcommand_t` function pointer |
| `sizebuf_t` | typedef (external) | Generic sized byte buffer; used for `cmd_text` |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `cmd_alias` | `cmdalias_t *` | global | Head of alias linked list |
| `cmd_wait` | `qboolean` | global | Flag to pause buffer execution until next frame |
| `alias_count` | `int` | global | Loop counter to detect runaway alias recursion |
| `cmd_text` | `sizebuf_t` | global | Active command buffer descriptor |
| `cmd_text_buf` | `byte[8192]` | global | Backing storage for `cmd_text` |
| `defer_text_buf` | `byte[8192]` | global | Buffer for deferred commands across map loads |
| `cmd_argc` | `int` | static | Token count for current parsed command |
| `cmd_argv` | `char*[MAX_STRING_TOKENS]` | static | Token array for current parsed command |
| `cmd_args` | `char[MAX_STRING_CHARS]` | static | Raw concatenated args string (argv[1]…) |
| `cmd_functions` | `cmd_function_t *` | static | Head of registered command linked list |

## Key Functions

### Cbuf_Init
- **Signature:** `void Cbuf_Init(void)`
- **Purpose:** Initializes the command text buffer.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** Calls `SZ_Init` to bind `cmd_text` to `cmd_text_buf`.
- **Calls:** `SZ_Init`
- **Notes:** Must be called before any buffer operations.

### Cbuf_Execute
- **Signature:** `void Cbuf_Execute(void)`
- **Purpose:** Drains the command buffer, executing one command per iteration until empty or `cmd_wait` is set.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** Resets `alias_count`; consumes and mutates `cmd_text`; may set `cmd_wait = false`.
- **Calls:** `Cmd_ExecuteString`, `memmove`
- **Notes:** Respects quoted strings when scanning for `;` delimiters. `cmd_wait` causes early exit, deferring remaining buffer to next frame.

### Cmd_TokenizeString
- **Signature:** `void Cmd_TokenizeString(char *text, qboolean macroExpand)`
- **Purpose:** Parses a command line string into `cmd_argc`/`cmd_argv`, optionally expanding `$cvar` macros.
- **Inputs:** `text` — raw command string; `macroExpand` — whether to expand `$cvar` references.
- **Outputs/Return:** None (populates static state)
- **Side effects:** Frees previous `cmd_argv` entries via `Z_Free`; allocates new ones via `Z_Malloc`.
- **Calls:** `Cmd_MacroExpandString`, `COM_Parse`, `Z_Free`, `Z_Malloc`
- **Notes:** Stops at `\n`; builds `cmd_args` from argv[1] onward.

### Cmd_MacroExpandString
- **Signature:** `char *Cmd_MacroExpandString(char *text)`
- **Purpose:** Replaces `$token` references with their cvar values in a command string.
- **Inputs:** `text` — raw command string
- **Outputs/Return:** Pointer to static `expanded[]` buffer, or `NULL` on overflow/error.
- **Side effects:** Uses a static buffer; not reentrant.
- **Calls:** `COM_Parse`, `Cvar_VariableString`
- **Notes:** Caps expansion iterations at 100 to prevent infinite loops; ignores `$` inside quoted strings.

### Cmd_ExecuteString
- **Signature:** `void Cmd_ExecuteString(char *text)`
- **Purpose:** Tokenizes a command and dispatches it: registered command → alias → cvar → server forward.
- **Inputs:** `text` — command line string
- **Outputs/Return:** None
- **Side effects:** Calls matched handler; may call `Cbuf_InsertText` for aliases; may forward to server.
- **Calls:** `Cmd_TokenizeString`, `Cvar_Command`, `Cmd_ForwardToServer`, `Cbuf_InsertText`, `Q_strcasecmp`
- **Notes:** Command name lookup is case-insensitive. Null `function` pointer in a `cmd_function_t` triggers a `"cmd ..."` server forward.

### Cbuf_AddEarlyCommands / Cbuf_AddLateCommands
- **Purpose:** Parse `+set`-prefixed args early (before init) and `+cmd`-prefixed args late (after init); feed them into the command buffer.
- **Notes:** `Cbuf_AddLateCommands` returns `true` if any commands were added, used to suppress the demo loop.

### Cmd_AddCommand / Cmd_RemoveCommand
- **Purpose:** Register or unregister a named command and its handler in the `cmd_functions` list.
- **Notes:** `Cmd_AddCommand` guards against duplicate names and name collisions with cvars.

### Cmd_Init
- **Signature:** `void Cmd_Init(void)`
- **Purpose:** Registers built-in commands: `cmdlist`, `exec`, `echo`, `alias`, `wait`.
- **Calls:** `Cmd_AddCommand`

## Control Flow Notes
- **Init:** `Cbuf_Init` → `Cmd_Init` called during `Qcommon_Init`.
- **Per-frame:** `Cbuf_Execute` is called each frame from the main loop to drain queued commands.
- **Map load:** `Cbuf_CopyToDefer`/`Cbuf_InsertFromDefer` stash and restore pending commands across server restarts.

## External Dependencies
- **Includes:** `qcommon.h`
- **Defined elsewhere:** `SZ_Init`, `SZ_Write`, `SZ_Clear`; `Z_Malloc`, `Z_Free`; `COM_Parse`, `COM_Argc`, `COM_Argv`, `COM_ClearArgv`; `Cvar_VariableString`, `Cvar_Command`; `FS_LoadFile`, `FS_FreeFile`; `Com_Printf`, `Com_Error`; `CopyString`; `Cmd_ForwardToServer`; `Q_strcasecmp`; `xcommand_t` typedef (in `qcommon.h`)
