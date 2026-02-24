# win32/rw_dib.c

## File Purpose
Manages Windows DIB (Device Independent Bitmap) sections for the software renderer on Win32. Provides creation, palette management, and teardown of the 8-bit DIB surface that the soft renderer draws into before blitting to screen.

## Core Responsibilities
- Allocate and initialize an 8-bit DIB section backed by `vid.width × vid.height` memory
- Expose the DIB's pixel buffer and pitch to the soft renderer
- Detect palettized (8-bit desktop) display modes and configure identity palette mode
- Apply palette updates to both the DIB color table and the Win32 system palette
- Save and restore Windows system colors when entering/leaving palettized mode
- Release all GDI resources on shutdown

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `dibinfo_t` | struct | Combines `BITMAPINFOHEADER` + 256-entry `RGBQUAD` color table for `CreateDIBSection` |
| `identitypalette_t` | struct | Mirrors `LOGPALETTE` layout with 256 `PALETTEENTRY` slots; used to build identity palette for 8-bit desktop modes |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `s_systemcolors_saved` | `qboolean` | static | Guards one-time save of system colors |
| `previously_selected_GDI_obj` | `HGDIOBJ` | static | Saves the GDI object displaced by `SelectObject` so it can be restored on shutdown |
| `s_syspalindices[]` | `int[19]` | static | Array of `COLOR_*` indices identifying system UI colors to save/restore |
| `s_oldsyscolors[]` | `int[NUM_SYS_COLORS]` | static | Saved original system color values |
| `s_ipal` | `identitypalette_t` | static | Persistent storage for the identity `LOGPALETTE` passed to `CreatePalette` |

## Key Functions

### DIB_Init
- **Signature:** `qboolean DIB_Init( unsigned char **ppbuffer, int *ppitch )`
- **Purpose:** Creates the 8-bit DIB section and returns the render buffer pointer and pitch to the caller.
- **Inputs:** `ppbuffer` — out-param for pixel buffer start; `ppitch` — out-param for row stride (negative for bottom-up DIBs).
- **Outputs/Return:** `true` on success; `false` on any GDI failure (falls through to `DIB_Shutdown`).
- **Side effects:** Acquires `sww_state.hDC`, sets `sww_state.hDIBSection`, `sww_state.hdcDIBSection`, `sww_state.pDIBBase`, `sww_state.palettized`; may call `DIB_SaveSystemColors`.
- **Calls:** `GetDC`, `GetDeviceCaps`, `CreateDIBSection`, `CreateCompatibleDC`, `SelectObject`, `DIB_SaveSystemColors`, `DIB_Shutdown`, `ri.Con_Printf`.
- **Notes:** Bottom-up DIBs (positive `biHeight`) flip the buffer pointer and negate pitch so the renderer always writes top-down. Initializes DIB memory to `0xff`.

### DIB_SetPalette
- **Signature:** `void DIB_SetPalette( const unsigned char *_pal )`
- **Purpose:** Updates the DIB color table and, on 8-bit palettized desktops, forces an identity system palette so index N maps directly to physical slot N.
- **Inputs:** `_pal` — 1024-byte palette in R/G/B/A stride-4 format.
- **Outputs/Return:** void.
- **Side effects:** Modifies the DIB color table via `SetDIBColorTable`; on palettized displays creates a new `HPALETTE`, calls `SetSystemPaletteUse(SYSPAL_NOSTATIC)`, selects and realizes palette; deletes any prior `sww_state.hPal`.
- **Calls:** `SetDIBColorTable`, `SetSystemPaletteUse`, `DeleteObject`, `CreatePalette`, `SelectPalette`, `RealizePalette`, `ri.Con_Printf`, `ri.Sys_Error`.
- **Notes:** Entries 0 and 255 are hardcoded to pure black and white respectively, both in the DIB color table and the logical palette. Fatal errors on palette realization failure.

### DIB_Shutdown
- **Signature:** `void DIB_Shutdown( void )`
- **Purpose:** Releases all GDI resources acquired during `DIB_Init`/`DIB_SetPalette` and restores system state.
- **Inputs:** None.
- **Outputs/Return:** void.
- **Side effects:** Restores system colors if palettized; deletes `hPal`, restores `hpalOld`, deselects and deletes `hdcDIBSection` and `hDIBSection`, releases `hDC`.
- **Calls:** `DIB_RestoreSystemColors`, `DeleteObject`, `SelectPalette`, `RealizePalette`, `SelectObject`, `DeleteDC`, `ReleaseDC`.
- **Notes:** Safe to call even if `DIB_Init` partially failed (each handle is null-checked).

- **Notes (helpers):** `DIB_SaveSystemColors` iterates `s_syspalindices` calling `GetSysColor`; `DIB_RestoreSystemColors` calls `SetSystemPaletteUse(SYSPAL_STATIC)` then `SetSysColors` to undo palette takeover.

## Control Flow Notes
Called from the Win32 soft-renderer window management layer (`rw_imp.c` / `rw_win.h`). `DIB_Init` runs during renderer initialization; `DIB_SetPalette` is called whenever the game palette changes (map load, gamma shift); `DIB_Shutdown` runs on renderer teardown. The DIB pixel buffer pointer is handed to `vid` so the soft renderer writes directly into it; the platform layer subsequently blits via `BitBlt`/`StretchBlt`.

## External Dependencies
- `ref_soft/r_local.h` — `vid`, `d_8to24table`, `ri` (refimport_t), `sww_state` (soft Win32 window state struct)
- `rw_win.h` — `sww_state` declaration, Win32 type aliases
- Win32 GDI: `CreateDIBSection`, `CreateCompatibleDC`, `SelectObject`, `SetDIBColorTable`, `CreatePalette`, `SelectPalette`, `RealizePalette`, `SetSystemPaletteUse`, `SetSysColors`, `GetSysColor`, `ReleaseDC`, `DeleteDC`, `DeleteObject`
- `sww_state` — defined in `rw_win.h` / platform layer, not in this file
