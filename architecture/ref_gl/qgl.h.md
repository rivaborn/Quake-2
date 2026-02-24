# ref_gl/qgl.h

## File Purpose
Declares the Quake GL abstraction layer: a complete set of function pointers mirroring the OpenGL 1.1 API (plus select extensions), allowing the engine to load OpenGL dynamically from a DLL/shared library at runtime rather than linking statically. Also declares the `QGL_Init`/`QGL_Shutdown` lifecycle interface.

## Core Responsibilities
- Expose `extern` function pointer declarations for the full OpenGL 1.1 core API via `qgl*` names
- Expose `extern` function pointer declarations for Windows WGL context management via `qwgl*` names (Win32 only)
- Declare optional extension function pointers: `EXT`, `SGIS` extensions for point parameters, color tables, compiled vertex arrays, and multitexture
- Define extension enumerant constants not present in stock `<GL/gl.h>` headers
- Declare `QGL_Init` and `QGL_Shutdown` as the public interface for loading/unloading the GL DLL

## Key Types / Data Structures
None.

## Global / File-Static State
All symbols below are `extern` function pointers defined in a corresponding `.c` file (platform-specific `qgl_win.c` / `qgl_linux.c`).

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `qgl*` (~300 entries) | `void (APIENTRY *)(...)` | global (extern) | Indirection wrappers for every core GL function |
| `qwgl*` (~20 entries, Win32 only) | `BOOL/HGLRC/etc. (WINAPI *)(...)` | global (extern) | WGL context and pixel-format management |
| `qglPointParameterfEXT` | `void (APIENTRY *)(...)` | global (extern) | Point size attenuation extension |
| `qglColorTableEXT` | `void (APIENTRY *)(...)` | global (extern) | Shared texture palette extension |
| `qglLockArraysEXT` / `qglUnlockArraysEXT` | `void (APIENTRY *)(...)` | global (extern) | Compiled vertex array (CVA) extension |
| `qglMTexCoord2fSGIS` / `qglSelectTextureSGIS` | `void (APIENTRY *)(...)` | global (extern) | SGIS multitexture extension |

## Key Functions

### QGL_Init
- Signature: `qboolean QGL_Init( const char *dllname )`
- Purpose: Load the OpenGL shared library named `dllname` and resolve all `qgl*`/`qwgl*` function pointers.
- Inputs: Path/name of the GL DLL or shared object.
- Outputs/Return: `qtrue` on success, `qfalse` on failure.
- Side effects: Populates all global `qgl*` function pointer variables.
- Calls: Not inferable from this file (implemented in platform `.c`).
- Notes: Must be called before any `qgl*` function is used.

### QGL_Shutdown
- Signature: `void QGL_Shutdown( void )`
- Purpose: Unload the GL library and null out all function pointers.
- Inputs: None.
- Outputs/Return: void.
- Side effects: Frees the DLL handle; all `qgl*` pointers become invalid.
- Calls: Not inferable from this file.
- Notes: Called on renderer shutdown or DLL reload.

## Control Flow Notes
This header is included by all `ref_gl/` rendering source files. At renderer init, `QGL_Init` is called (from `gl_rmain.c` or the platform `vid_*.c`) to populate the pointers; every subsequent GL call in the renderer goes through the `qgl*` indirection. On shutdown, `QGL_Shutdown` is called to clean up.

## External Dependencies
- `<windows.h>` — Win32 types (`HDC`, `HGLRC`, `BOOL`, `WINAPI`, etc.), included conditionally
- `<GL/gl.h>` — GL type definitions (`GLenum`, `GLfloat`, `GLuint`, etc.) and standard enumerants
- `QGL_Init` / `QGL_Shutdown` implementations — defined in `win32/qgl_win.c` or `linux/qgl_linux.c`
- All `qgl*` variable definitions — defined in the corresponding platform `.c` file
