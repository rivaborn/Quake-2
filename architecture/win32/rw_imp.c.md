# win32/rw_imp.c

## File Purpose
Win32-specific implementation layer for the software renderer, providing window creation, graphics surface initialization (DIB or DirectDraw), frame presentation, palette management, and FPU control word setup for x86 rasterization.

## Core Responsibilities
- Create and destroy the Win32 window for the software renderer
- Initialize DIB (windowed) or DirectDraw (fullscreen) rendering surfaces
- Present the completed frame (BitBlt for DIB, BltFast/Flip for DDRAW)
- Set the software palette via DIB or DDRAW subsystem
- Handle app activation/deactivation (minimize on focus loss in fullscreen)
- Configure x87 FPU control word variants (round, truncate, ceil, single precision)
- Expose memory page protection change via `Sys_MakeCodeWriteable`

## Key Types / Data Structures
None defined here; uses types from included headers.

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `sww_state` | `swwstate_t` | global | Central Win32 SW renderer state (window handle, DC, DDRAW surfaces, flags) |
| `fpu_ceil_cw` | `unsigned` | global (id386 only) | FPU control word: ceil mode, extended precision |
| `fpu_chop_cw` | `unsigned` | global (id386 only) | FPU control word: RTZ/truncate, extended precision |
| `fpu_full_cw` | `unsigned` | global (id386 only) | FPU control word: round-to-nearest, extended precision |
| `fpu_cw` | `unsigned` | global (id386 only) | Saved current FPU control word |
| `fpu_pushed_cw` | `unsigned` | global (id386 only) | Push/pop scratch for FPU CW |
| `fpu_sp24_cw` | `unsigned` | global (id386 only) | FPU CW: round-to-nearest, 24-bit single precision |
| `fpu_sp24_ceil_cw` | `unsigned` | global (id386 only) | FPU CW: ceil, 24-bit single precision |

## Key Functions

### VID_CreateWindow
- **Signature:** `void VID_CreateWindow(int width, int height, int stylebits)`
- **Purpose:** Registers the Win32 window class and creates the application window at the configured position.
- **Inputs:** Desired client area `width`/`height`, Win32 style bits.
- **Outputs/Return:** None; fatal error on failure.
- **Side effects:** Sets `sww_state.hWnd`; calls `ri.Vid_NewWindow` to notify sound/input subsystems.
- **Calls:** `ri.Cvar_Get`, `RegisterClass`, `AdjustWindowRect`, `CreateWindowEx`, `ShowWindow`, `UpdateWindow`, `SetForegroundWindow`, `SetFocus`, `ri.Vid_NewWindow`, `ri.Sys_Error`.
- **Notes:** Always uses class name `"Quake 2"`; topmost extended style applied only when fullscreen.

### SWimp_Init
- **Signature:** `int SWimp_Init(void *hInstance, void *wndProc)`
- **Purpose:** Stores the HINSTANCE and window procedure pointer into `sww_state`; must be called before any window/graphics init.
- **Inputs:** Win32 instance handle, window procedure pointer.
- **Outputs/Return:** Always returns `true`.
- **Side effects:** Writes `sww_state.hInstance`, `sww_state.wndproc`.
- **Calls:** None.

### SWimp_InitGraphics *(static)*
- **Signature:** `static qboolean SWimp_InitGraphics(qboolean fullscreen)`
- **Purpose:** Tears down any existing surfaces, creates the window, then initializes either DIB (windowed) or DirectDraw (fullscreen) rendering surfaces.
- **Inputs:** `fullscreen` flag.
- **Outputs/Return:** `true` on success, `false` on surface init failure.
- **Side effects:** Calls `SWimp_Shutdown`; sets `vid.buffer` and `vid.rowbytes` (zeroes them on failure).
- **Calls:** `SWimp_Shutdown`, `VID_CreateWindow`, `DIB_Init`, `DDRAW_Init`.

### SWimp_EndFrame
- **Signature:** `void SWimp_EndFrame(void)`
- **Purpose:** Blits the completed software-rendered backbuffer to the screen each frame.
- **Inputs:** None (reads `sw_state.fullscreen`, `sww_state` members, `vid`).
- **Outputs/Return:** None.
- **Side effects:** For DIB: `BitBlt` to screen DC. For DDRAW: unlocks off-screen buffer, blits to back buffer, flips/presents; re-locks off-screen buffer and updates `vid.buffer`/`vid.rowbytes` from `DDSURFACEDESC`. Handles `DDERR_SURFACELOST` with a Restore+retry.
- **Calls:** `BitBlt`; DDRAW COM vtable calls (`Unlock`, `BltFast`, `Flip`, `Restore`, `Lock`).
- **Notes:** `modex` path does back→front flip; non-modex blits directly to front buffer via `lpddsBackBuffer` vtable pointer (apparent variable naming inconsistency in original code).

### SWimp_SetMode
- **Signature:** `rserr_t SWimp_SetMode(int *pwidth, int *pheight, int mode, qboolean fullscreen)`
- **Purpose:** Queries mode dimensions, attempts fullscreen init (falling back to windowed on failure), and finalizes gamma/palette.
- **Inputs:** Output width/height pointers, mode index, fullscreen flag.
- **Outputs/Return:** `rserr_ok`, `rserr_invalid_mode`, `rserr_invalid_fullscreen`, or `rserr_unknown`.
- **Side effects:** Calls `SWimp_InitGraphics`; sets `sw_state.fullscreen`; calls `R_GammaCorrectAndSetPalette`.
- **Calls:** `ri.Con_Printf`, `ri.Vid_GetModeInfo`, `SWimp_InitGraphics`, `R_GammaCorrectAndSetPalette`.

### SWimp_SetPalette
- **Signature:** `void SWimp_SetPalette(const unsigned char *palette)`
- **Purpose:** Applies a 4-byte-padded xRGB palette to the active surface type; falls back to `sw_state.currentpalette` if NULL.
- **Inputs:** Palette pointer (may be NULL).
- **Outputs/Return:** None.
- **Side effects:** Calls `DIB_SetPalette` or `DDRAW_SetPalette`.
- **Calls:** `DIB_SetPalette`, `DDRAW_SetPalette`.

### SWimp_Shutdown
- **Signature:** `void SWimp_Shutdown(void)`
- **Purpose:** Releases DIB and DDRAW resources, destroys the window, and unregisters the window class.
- **Inputs:** None.
- **Outputs/Return:** None.
- **Side effects:** Nulls `sww_state.hWnd`; calls `DestroyWindow`, `UnregisterClass`.
- **Calls:** `ri.Con_Printf`, `DIB_Shutdown`, `DDRAW_Shutdown`, `ShowWindow`, `DestroyWindow`, `UnregisterClass`.

### SWimp_AppActivate
- **Signature:** `void SWimp_AppActivate(qboolean active)`
- **Purpose:** Responds to focus gain/loss; restores window on activation, minimizes on deactivation if fullscreen and not initializing.
- **Calls:** `SetForegroundWindow`, `ShowWindow`.
- **Notes:** Reads file-scope `vid_fullscreen` cvar pointer (declared elsewhere in the translation unit or as an extern—not visible in this file; likely a dangling reference bug in the original code).

### Sys_SetFPCW
- **Signature:** `void Sys_SetFPCW(void)` (`#if id386` only)
- **Purpose:** Uses inline x86 assembly (`fnstcw`/bit manipulation) to pre-compute FPU control word variants used by the software rasterizer for fast mode switching.
- **Side effects:** Writes all six `fpu_*_cw` globals.
- **Notes:** No-op stub provided for non-x86 builds.

### Sys_MakeCodeWriteable
- **Signature:** `void Sys_MakeCodeWriteable(unsigned long startaddr, unsigned long length)`
- **Purpose:** Changes memory protection of a code region to `PAGE_READWRITE` to allow self-modifying code patches in the software renderer.
- **Calls:** `VirtualProtect`, `ri.Sys_Error`.

## Control Flow Notes
- `SWimp_Init` is called at renderer load time with the app's HINSTANCE and WndProc.
- `SWimp_SetMode` is called when the video mode changes; it drives `SWimp_InitGraphics` → `VID_CreateWindow` + surface init.
- `SWimp_EndFrame` is called once per rendered frame to present the backbuffer.
- `SWimp_Shutdown` is called on renderer teardown or before a mode change (also called internally by `SWimp_InitGraphics`).
- `Sys_SetFPCW` is called at startup to pre-compute FPU CW constants used throughout the rasterizer.

## External Dependencies
- `../ref_soft/r_local.h` — `vid`, `sw_state`, `d_8to24table`, `rserr_t`, `R_GammaCorrectAndSetPalette`
- `rw_win.h` — `swwstate_t`, `sww_state` declaration, `DIB_Init/Shutdown/SetPalette`, `DDRAW_Init/Shutdown/SetPalette`, `WINDOW_STYLE`
- `winquake.h` — Win32 and DirectDraw type definitions
- `ri` (refimport_t) — `Cvar_Get`, `Con_Printf`, `Sys_Error`, `Vid_GetModeInfo`, `Vid_NewWindow` (defined in engine, passed via import struct)
- `vid_fullscreen` in `SWimp_AppActivate` — referenced but not declared in this file (likely a bug or implicit extern from a shared header)
