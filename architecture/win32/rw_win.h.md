# win32/rw_win.h

## File Purpose
Declares the shared Win32 state structure and interface for the software renderer's Windows display backends. It provides the `swwstate_t` type that aggregates all Win32 GDI/DIB and DirectDraw handles needed by the software rasterizer's platform layer.

## Core Responsibilities
- Define `swwstate_t`: the central state bag for Win32 software-renderer windowing
- Declare GDI/DIB initialization, shutdown, and palette functions
- Declare DirectDraw initialization, shutdown, and palette functions
- Expose the single global `sww_state` instance to all translation units that include this header

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `swwstate_t` | struct | Aggregates all Win32 handles and flags for the software renderer window: GDI context, DIB section, DirectDraw objects, palette handles, and initialization state |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `sww_state` | `swwstate_t` | global (extern) | Singleton holding all Win32 software-renderer state; defined in a corresponding `.c` file (likely `rw_imp.c` or `rw_dib.c`) |

## Key Functions

Only declarations are present; implementations reside elsewhere.

### DIB_Init
- **Signature:** `qboolean DIB_Init( unsigned char **ppbuffer, int *ppitch )`
- **Purpose:** Initializes a GDI DIB section as the software render target.
- **Inputs:** `ppbuffer` — out-param for the pixel buffer pointer; `ppitch` — out-param for scanline pitch in bytes.
- **Outputs/Return:** `qboolean` — true on success.
- **Side effects:** Allocates a DIB section; populates `sww_state.hdcDIBSection`, `sww_state.hDIBSection`, `sww_state.pDIBBase`.
- **Calls:** Not inferable from this file.
- **Notes:** `pDIBBase` is explicitly noted as not used directly for rendering — callers receive the buffer via `ppbuffer`.

### DIB_Shutdown
- **Signature:** `void DIB_Shutdown( void )`
- **Purpose:** Tears down the DIB section and releases associated GDI resources.
- **Inputs:** None.
- **Outputs/Return:** None.
- **Side effects:** Frees `hDIBSection`, `hdcDIBSection`; nulls relevant `sww_state` fields.
- **Calls:** Not inferable from this file.

### DIB_SetPalette
- **Signature:** `void DIB_SetPalette( const unsigned char *palette )`
- **Purpose:** Uploads an 8-bit palette to the DIB/GDI layer for paletted rendering.
- **Inputs:** `palette` — 768-byte RGB palette array.
- **Outputs/Return:** None.
- **Side effects:** Updates `sww_state.hPal`; may call Win32 palette realization APIs.
- **Calls:** Not inferable from this file.

### DDRAW_Init
- **Signature:** `qboolean DDRAW_Init( unsigned char **ppbuffer, int *ppitch )`
- **Purpose:** Initializes DirectDraw and allocates front/back/offscreen surfaces as the render target.
- **Inputs:** Same out-param convention as `DIB_Init`.
- **Outputs/Return:** `qboolean` — true on success.
- **Side effects:** Loads `DDRAW.DLL` into `sww_state.hinstDDRAW`; creates `lpDirectDraw`, `lpddsFrontBuffer`, `lpddsBackBuffer`, `lpddsOffScreenBuffer`.
- **Calls:** Not inferable from this file.

### DDRAW_Shutdown
- **Signature:** `void DDRAW_Shutdown( void )`
- **Purpose:** Releases all DirectDraw COM objects and unloads the DLL.
- **Side effects:** Frees surfaces and DirectDraw object; unloads `hinstDDRAW`.

### DDRAW_SetPalette
- **Signature:** `void DDRAW_SetPalette( const unsigned char *palette )`
- **Purpose:** Uploads the palette to the DirectDraw palette object (`lpddpPalette`).
- **Side effects:** Updates DirectDraw palette entries on the active surface.

## Control Flow Notes
This header sits in the **initialization and frame-present** path of the Win32 software renderer. On startup, either `DIB_Init` or `DDRAW_Init` is called (mutually exclusive backends) to establish a pixel buffer. Each frame, the renderer writes into that buffer and then blits/presents it. On shutdown, the corresponding `*_Shutdown` is called. The `initializing` flag in `swwstate_t` guards re-entrant or partial-init states.

## External Dependencies
- `<windows.h>` — `HINSTANCE`, `HDC`, `HWND`, `HPALETTE`, `COLORREF`, `HBITMAP`
- `<ddraw.h>` — `LPDIRECTDRAW`, `LPDIRECTDRAWSURFACE`, `LPDIRECTDRAWPALETTE`
- `qboolean` — defined in `qcommon/qcommon.h` or `game/q_shared.h` (defined elsewhere)
- `sww_state` — extern; defined in a Win32 platform `.c` file (defined elsewhere)
