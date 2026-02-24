# null/swimp_null.c

## File Purpose
Provides a null (no-op) implementation of the software renderer platform interface (`SWimp_*`). Used as a stub when no actual display/windowing system is available, such as in headless server builds or null-platform configurations.

## Core Responsibilities
- Satisfies the linker's requirements for all `SWimp_*` symbols
- Allows the engine to compile and link without a real windowing backend
- Serves as a reference interface contract for the software renderer platform layer

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions

### SWimp_BeginFrame
- Signature: `void SWimp_BeginFrame(float camera_separation)`
- Purpose: No-op. In real implementations, prepares the display surface for a new frame.
- Inputs: `camera_separation` — stereo separation offset (unused here)
- Outputs/Return: void
- Side effects: None
- Calls: None
- Notes: Stereo rendering hint parameter is silently ignored.

### SWimp_EndFrame
- Signature: `void SWimp_EndFrame(void)`
- Purpose: No-op. In real implementations, presents/blits the completed frame to the display.
- Inputs: None
- Outputs/Return: void
- Side effects: None
- Calls: None

### SWimp_Init
- Signature: `int SWimp_Init(void *hInstance, void *wndProc)`
- Purpose: No-op. In real implementations, initializes the windowing/display subsystem.
- Inputs: `hInstance`, `wndProc` — platform window handles (unused)
- Outputs/Return: `int` — no explicit return; undefined behavior in a real build (no `return` statement)
- Side effects: None
- Notes: Missing `return` statement is a latent bug; real platforms return 0 on success.

### SWimp_SetPalette
- Signature: `void SWimp_SetPalette(const unsigned char *palette)`
- Purpose: No-op. In real implementations, uploads an 8-bit color palette to the display hardware.
- Inputs: `palette` — 256-entry RGB palette pointer (unused)
- Outputs/Return: void
- Side effects: None

### SWimp_Shutdown
- Signature: `void SWimp_Shutdown(void)`
- Purpose: No-op. In real implementations, tears down the windowing subsystem.
- Inputs: None
- Outputs/Return: void
- Side effects: None

### SWimp_SetMode
- Signature: `rserr_t SWimp_SetMode(int *pwidth, int *pheight, int mode, qboolean fullscreen)`
- Purpose: No-op. In real implementations, sets the display resolution and fullscreen state.
- Inputs: `pwidth`/`pheight` — resolution output pointers; `mode` — video mode index; `fullscreen` — toggle
- Outputs/Return: `rserr_t` — no explicit return; undefined behavior (missing `return`)
- Side effects: None
- Notes: Same missing-return defect as `SWimp_Init`.

### SWimp_AppActivate
- Signature: `void SWimp_AppActivate(qboolean active)`
- Purpose: No-op. In real implementations, handles app focus gain/loss events (e.g., pause sound, release input).
- Inputs: `active` — focus state (unused)
- Outputs/Return: void
- Side effects: None

## Control Flow Notes
This file participates in no active init/frame/shutdown flow. It is a dead-end stub; all calls into it return immediately. It is selected at link time when building for the `null` platform target in place of a real `swimp_*.c` implementation.

## External Dependencies
- `../ref_soft/r_local.h` — provides `rserr_t`, `qboolean`, and other software renderer types
- `rserr_t` — defined in `ref_soft/r_local.h` (or its includes); not defined here
