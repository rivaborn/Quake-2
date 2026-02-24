# game/g_svcmds.c

## File Purpose
Implements server-side console command handling for the game DLL, including a test command and a full IP address filtering/banning system. Provides the `ServerCommand` entry point called by the engine when an `sv` command is issued.

## Core Responsibilities
- Dispatch server commands via `ServerCommand` to sub-handlers
- Parse dotted-quad IP strings into bitmask filter structs
- Maintain a static list of IP filters (`ipfilters[]`) for packet filtering
- Allow runtime add/remove/list/write of IP ban or allowlist entries
- Determine whether an incoming packet address should be allowed or blocked

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `ipfilter_t` | struct | Holds a `mask` and `compare` (both `unsigned`) to match IP addresses with wildcard support |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `ipfilters` | `ipfilter_t[1024]` | global | Array of active IP filters |
| `numipfilters` | `int` | global | Count of currently active entries in `ipfilters` |

## Key Functions

### StringToFilter
- **Signature:** `static qboolean StringToFilter(char *s, ipfilter_t *f)`
- **Purpose:** Parses a dotted-quad IP string (with optional omitted octets) into a mask/compare pair.
- **Inputs:** `s` — null-terminated IP string; `f` — output filter struct
- **Outputs/Return:** `qtrue` on success, `qfalse` on malformed input
- **Side effects:** Prints error via `gi.cprintf` on bad input
- **Calls:** `atoi`, `gi.cprintf`
- **Notes:** Omitted trailing octets have mask byte `0` (wildcard). Uses `*(unsigned *)` cast to pack byte arrays — assumes little-endian layout.

### SV_FilterPacket
- **Signature:** `qboolean SV_FilterPacket(char *from)`
- **Purpose:** Tests an incoming address string against all active IP filters to decide if the packet should be allowed or blocked.
- **Inputs:** `from` — address string in dotted-quad (optionally with `:port`)
- **Outputs/Return:** `filterban->value` if matched (ban mode → block); `!filterban->value` if unmatched
- **Side effects:** None
- **Calls:** None (manual parsing loop)
- **Notes:** Stops parsing at `:` to strip port. Returns `(int)filterban->value` on match; the cvar controls whether the list is a banlist or allowlist.

### SVCmd_AddIP_f
- **Signature:** `void SVCmd_AddIP_f(void)`
- **Purpose:** Adds an IP filter entry from the `sv addip <mask>` command.
- **Inputs:** `gi.argv(2)` — IP mask string
- **Outputs/Return:** void
- **Side effects:** Modifies `ipfilters[]`, increments `numipfilters`
- **Calls:** `StringToFilter`, `gi.argc`, `gi.argv`, `gi.cprintf`
- **Notes:** Reuses slots where `compare == 0xffffffff` (sentinel for free/invalid). Caps at `MAX_IPFILTERS` (1024).

### SVCmd_RemoveIP_f
- **Signature:** `void SVCmd_RemoveIP_f(void)`
- **Purpose:** Removes an exact-match IP filter entry.
- **Inputs:** `gi.argv(2)` — IP mask string to remove
- **Outputs/Return:** void
- **Side effects:** Shifts `ipfilters[]` array down, decrements `numipfilters`
- **Calls:** `StringToFilter`, `gi.argc`, `gi.argv`, `gi.cprintf`
- **Notes:** Match requires both `mask` and `compare` to be identical; cannot remove a subnet by specifying a host within it.

### SVCmd_ListIP_f
- **Signature:** `void SVCmd_ListIP_f(void)`
- **Purpose:** Prints all current IP filters to the console.
- **Side effects:** Console output only via `gi.cprintf`
- **Calls:** `gi.cprintf`

### SVCmd_WriteIP_f
- **Signature:** `void SVCmd_WriteIP_f(void)`
- **Purpose:** Writes current filter list to `<gamedir>/listip.cfg` as executable config commands.
- **Inputs:** Reads `game` cvar to determine output path
- **Outputs/Return:** void
- **Side effects:** Creates/overwrites `listip.cfg` on disk; reads `filterban` cvar value
- **Calls:** `gi.cvar`, `gi.cprintf`, `sprintf`, `fopen`, `fprintf`, `fclose`
- **Notes:** Falls back to `GAMEVERSION` macro if `game` cvar string is empty.

### ServerCommand
- **Signature:** `void ServerCommand(void)`
- **Purpose:** Engine-facing entry point; dispatches `sv <cmd>` commands to sub-handlers.
- **Inputs:** None directly — reads `gi.argv(1)` for subcommand name
- **Outputs/Return:** void
- **Side effects:** Delegates to sub-handlers
- **Calls:** `gi.argv`, `Q_stricmp`, all `SVCmd_*` and `Svcmd_Test_f`

## Control Flow Notes
`ServerCommand` is the sole engine entry point. It is called by the engine whenever the server operator issues an `sv` command. It does not participate in per-frame updates. `SV_FilterPacket` is called by the server (or game) during connection filtering, outside of the normal frame loop.

## External Dependencies
- `g_local.h` — pulls in all game types, `gi` interface, `filterban` cvar extern
- `filterban` — cvar defined elsewhere (likely `g_main.c`)
- `gi.cprintf`, `gi.argc`, `gi.argv`, `gi.cvar` — engine game import interface
- `Q_stricmp` — defined in `q_shared.c`
- `MAX_OSPATH`, `GAMEVERSION` — macros from shared headers
