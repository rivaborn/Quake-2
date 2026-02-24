# irix/qgl_irix.c

## File Purpose
Implements the IRIX-platform binding of OpenGL to the QGL indirection layer for Quake 2's ref_gl renderer. It defines all `qgl*` function pointers and provides optional per-call file logging for debugging, along with `QGL_Init` and `QGL_Shutdown` as the required port entry points.

## Core Responsibilities
- Declares all `qgl*` global function pointers consumed by ref_gl rendering code
- Declares parallel `dll*` static function pointers holding the real GL entry points
- Declares `log*` static wrapper functions that write call names to a log file then forward to `dll*`
- `QGL_Init`: directly assigns `qgl*` and `dll*` to statically linked IRIX GL symbols (no dlopen)
- `QGL_Shutdown`: NULLs all `qgl*` pointers
- `GLimp_EnableLogging`: hot-swaps `qgl*` between `log*` wrappers and `dll*` direct pointers at runtime
- `GLimp_LogNewFrame`: writes a frame delimiter to the GL call log

## Key Types / Data Structures
None.

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `log_fp` | `FILE *` | static | Log file handle; NULL when logging disabled |
| `qgl*` (~245 entries) | function pointers | global | Active GL dispatch table used by all ref_gl code |
| `dll*` (~245 entries) | function pointers | static (most) | Stores real GL entry points; target when logging off |

## Key Functions

### QGL_Init
- **Signature:** `qboolean QGL_Init( const char *dllname )`
- **Purpose:** Binds all `qgl*` and `dll*` pointers directly to statically linked IRIX OpenGL symbols (e.g., `glAccum`, `glBegin`). Sets `gl_config.allow_cds = true`. Extension pointers (`qglPointParameterfEXT`, `qglSelectTextureSGIS`, `qglMTexCoord2fSGIS`) are set to NULL; `qglColorTableEXT` is nominally assigned `glColorTableSGI` then immediately zeroed.
- **Inputs:** `dllname` — accepted but unused (no dynamic loading on IRIX)
- **Outputs/Return:** Always returns `true`
- **Side effects:** Writes `gl_config.allow_cds`; populates ~245 global and static function pointers
- **Calls:** None (direct symbol assignment only)
- **Notes:** Unlike the Win32 counterpart, no `LoadLibrary`/`GetProcAddress` is used; GL is linked statically. `qglGetTexLevelParameterfv`/`iv` are commented out, left NULL after `QGL_Init`.

### QGL_Shutdown
- **Signature:** `void QGL_Shutdown( void )`
- **Purpose:** NULLs every `qgl*` pointer to sever the GL dispatch table.
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** All `qgl*` globals set to NULL; does not close any library handle
- **Calls:** None
- **Notes:** Does not NULL `dll*` pointers; those retain their values.

### GLimp_EnableLogging
- **Signature:** `void GLimp_EnableLogging( qboolean enable )`
- **Purpose:** Toggles GL call logging. When enabling, opens `<gamedir>/gl.log` (if not already open) with a timestamp header, then redirects all `qgl*` to `log*` wrappers. When disabling, restores `qgl*` to `dll*` direct pointers.
- **Inputs:** `enable` — non-zero to activate logging
- **Outputs/Return:** void
- **Side effects:** May open `log_fp`; reassigns all `qgl*` pointers; I/O to log file on every subsequent GL call when enabled
- **Calls:** `time`, `localtime`, `asctime`, `sprintf`, `fopen`, `fprintf`; uses `ri.FS_Gamedir()`
- **Notes:** Log file is never explicitly closed in this file. `qglGetTexLevelParameterfv`/`iv` are commented out in the enable branch but restored in the disable branch.

### GLimp_LogNewFrame
- **Signature:** `void GLimp_LogNewFrame( void )`
- **Purpose:** Writes a `*** R_BeginFrame ***` marker to the log file to delimit frames in the GL call trace.
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** Writes to `log_fp` (undefined behavior if `log_fp` is NULL)
- **Notes:** No NULL guard on `log_fp`; caller must ensure logging is active.

## Control Flow Notes
`QGL_Init` is called during renderer initialization (before any GL calls). `QGL_Shutdown` is called on renderer teardown. `GLimp_EnableLogging` can be toggled at any point during runtime. All ref_gl rendering code calls through `qgl*` pointers, making the logging swap transparent.

## External Dependencies
- `../ref_gl/gl_local.h` — defines `qboolean`, `gl_config`, `ri` (refimport), and the `#define QGL` guard that suppresses re-declaration of `qgl*` in the header
- `ri.FS_Gamedir()` — engine filesystem callback; defined elsewhere
- `glColorTableSGI` — SGI extension symbol; expected from IRIX GL headers (assigned then immediately zeroed)
- Standard C: `<stdio.h>`, `<time.h>` (via gl_local.h or system includes)
