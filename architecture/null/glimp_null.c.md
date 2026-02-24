# null/glimp_null.c

## File Purpose
Null (stub) implementation of the OpenGL platform-abstraction layer (`GLimp`). All functions are empty no-ops, providing a do-nothing build target for platforms or configurations where GL rendering is not needed.

## Core Responsibilities
- Satisfies the linker for the `GLimp_*` interface without performing any real work
- Serves as a reference template for the GLimp platform contract
- Enables headless or dedicated-server builds to link against `ref_gl` without a display system

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions

### GLimp_BeginFrame
- Signature: `void GLimp_BeginFrame(float camera_separation)`
- Purpose: No-op stub for frame begin (stereo separation setup on real platforms).
- Inputs: `camera_separation` — ignored.
- Outputs/Return: void
- Side effects: None.
- Calls: None.
- Notes: On real platforms this would configure stereo eye offset.

### GLimp_EndFrame
- Signature: `void GLimp_EndFrame(void)`
- Purpose: No-op stub for buffer swap / frame present.
- Inputs: None.
- Outputs/Return: void
- Side effects: None.
- Calls: None.

### GLimp_Init
- Signature: `int GLimp_Init(void *hinstance, void *hWnd)`
- Purpose: No-op stub for platform GL context initialization.
- Inputs: `hinstance`, `hWnd` — platform window handles, ignored.
- Outputs/Return: `int` — no explicit return (undefined behavior; real impl returns success/failure).
- Side effects: None.
- Calls: None.

### GLimp_Shutdown
- Signature: `void GLimp_Shutdown(void)`
- Purpose: No-op stub for GL context teardown.
- Side effects: None.
- Calls: None.

### GLimp_SetMode
- Signature: `int GLimp_SetMode(int *pwidth, int *pheight, int mode, qboolean fullscreen)`
- Purpose: No-op stub for display mode/resolution switching.
- Inputs: All ignored.
- Outputs/Return: `int` — no explicit return (undefined behavior).
- Side effects: None.
- Calls: None.

### GLimp_AppActivate
- Signature: `void GLimp_AppActivate(qboolean active)`
- Purpose: No-op stub for focus/minimize events.
- Side effects: None.

### GLimp_EnableLogging
- Signature: `void GLimp_EnableLogging(qboolean enable)`
- Purpose: No-op stub for GL call logging toggle.
- Side effects: None.

### GLimp_LogNewFrame
- Signature: `void GLimp_LogNewFrame(void)`
- Purpose: No-op stub for per-frame log separator.
- Side effects: None.

## Control Flow Notes
Not part of any active init/frame/shutdown pipeline. These stubs are never called in a meaningful execution path; they exist solely to satisfy the link step for null/headless builds.

## External Dependencies
- `../ref_gl/gl_local.h` — pulled in to match the real `GLimp` signature contracts; no symbols from it are actually used here.
