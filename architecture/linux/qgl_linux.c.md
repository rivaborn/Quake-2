# linux/qgl_linux.c

## File Purpose
Linux-specific implementation of the QGL (Quake GL) abstraction layer that binds the engine's `qgl*` function pointer table to real OpenGL entry points. It also provides an optional call-logging facility that intercepts every GL call and writes it to a file for debugging.

## Core Responsibilities
- Declares all `qgl*` global function pointers used by the rest of `ref_gl`
- Declares parallel `dll*` static pointers that permanently hold the real GL addresses
- Declares `log*` static wrapper functions that write call signatures to a log file before forwarding to `dll*`
- `QGL_Init()`: binds both `qgl*` and `dll*` to the actual `gl*` symbols (linked statically on Linux)
- `QGL_Shutdown()`: NULLs all `qgl*` pointers to prevent stale use after teardown
- `GLimp_EnableLogging()`: hot-swaps `qgl*` pointers between `log*` wrappers and `dll*` passthrough; opens/closes `gl.log`
- `GLimp_LogNewFrame()`: writes a frame separator into the log

## Key Types / Data Structures
None.

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `log_fp` | `FILE *` | static | Log file handle; NULL when logging is disabled |
| `qgl*` (~230 entries) | function pointers | global | Active GL dispatch table used by all ref_gl code |
| `dll*` (~230 entries) | function pointers | static | Permanent copy of real GL addresses; never swapped |

## Key Functions

### QGL_Init
- **Signature:** `qboolean QGL_Init( const char *dllname )`
- **Purpose:** Initializes the QGL dispatch table by assigning all `qgl*` and `dll*` pointers directly to statically-linked `gl*` symbols. Extensions (`qglPointParameterfEXT`, `qglColorTableEXT`, `qglSelectTextureSGIS`, etc.) are zeroed out.
- **Inputs:** `dllname` — accepted but unused on Linux (no `dlopen` performed)
- **Outputs/Return:** Always returns `true`
- **Side effects:** Writes all global `qgl*` and file-static `dll*` pointers
- **Calls:** None (direct symbol assignment only)
- **Notes:** `qglGetTexLevelParameterfv`/`iv` are commented out during init, indicating a known Linux driver incompatibility at the time

### QGL_Shutdown
- **Signature:** `void QGL_Shutdown( void )`
- **Purpose:** Sets every `qgl*` pointer to NULL, making any subsequent GL call through the table a guaranteed crash rather than a silent misbehavior
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** Clears all global `qgl*` pointers
- **Calls:** Nothing

### GLimp_EnableLogging
- **Signature:** `void GLimp_EnableLogging( qboolean enable )`
- **Purpose:** Toggles GL call logging at runtime. When enabled, opens `<gamedir>/gl.log` (if not already open) and redirects all `qgl*` pointers to the `log*` wrappers. When disabled, restores `qgl*` to `dll*` direct pointers
- **Inputs:** `enable` — non-zero to activate logging
- **Outputs/Return:** void
- **Side effects:** Opens `log_fp` (file I/O); rewrites all ~230 `qgl*` pointers
- **Calls:** `time`, `localtime`, `asctime`, `sprintf`, `fopen`, `fprintf`, `ri.FS_Gamedir()`

### GLimp_LogNewFrame
- **Signature:** `void GLimp_LogNewFrame( void )`
- **Purpose:** Writes a `*** R_BeginFrame ***` marker to the log to delimit per-frame GL call groups
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** Writes to `log_fp` (undefined behavior if `log_fp` is NULL)

### Notes
- All ~230 `log*` functions are trivial one-line wrappers: `fprintf(log_fp, "glFoo\n"); dllFoo(args);` — not individually documented here

## Control Flow Notes
`QGL_Init` is called once during renderer initialization (from `GLimp_Init` or equivalent in `linux/gl_fxmesa.c` / `linux/rw_x11.c`). `QGL_Shutdown` is called on renderer teardown. `GLimp_EnableLogging` is toggled by the `gl_log` cvar handler in `ref_gl/gl_rmain.c`. The `log*` layer is entirely transparent to the rest of the engine — callers always go through `qgl*`.

## External Dependencies
- **`../ref_gl/gl_local.h`** — provides `qboolean`, `APIENTRY`, GL type definitions, `ri` (refimport_t with `FS_Gamedir`), and declares the `qgl*` externs via the `#define QGL` guard
- **`<time.h>`** — `time`, `localtime`, `asctime` used in log file header
- **`glAccum` … `glViewport`** — all standard OpenGL 1.1 entry points; resolved by the system linker against `-lGL` (defined elsewhere, not via `dlopen`)
- `ri.FS_Gamedir()` — defined in the engine core, accessed through the refimport interface
