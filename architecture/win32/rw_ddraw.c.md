# win32/rw_ddraw.c

## File Purpose
Manages DirectDraw initialization, palette management, and shutdown for the Win32 software renderer. It sets up the 8-bit palettized DirectDraw surfaces (front, back, offscreen) used by `ref_soft` to present frames to the display.

## Core Responsibilities
- Dynamically loads `ddraw.dll` and resolves `DirectDrawCreate` at runtime
- Creates the DirectDraw object and sets exclusive fullscreen cooperative level
- Attempts linear display mode first, falls back to ModeX 320x240 if allowed
- Allocates and connects front buffer, back buffer, and offscreen rendering buffer
- Creates and attaches an 8-bit `DIRECTDRAWPALETTE` initialized from `d_8to24table`
- Locks the offscreen buffer and returns its pointer/pitch to the caller
- Provides palette update and orderly teardown

## Key Types / Data Structures
None (all DirectDraw types are from the Win32 SDK; no local structs defined).

## Global / File-Static State
None declared in this file. All persistent state is stored externally in `sww_state` (defined in `rw_win.h`/`rw_imp.c`).

## Key Functions

### DDRAW_Init
- **Signature:** `qboolean DDRAW_Init( unsigned char **ppbuffer, int *ppitch )`
- **Purpose:** Full DirectDraw initialization — loads DLL, creates DD object, sets display mode, allocates surfaces and palette, locks offscreen buffer for rendering.
- **Inputs:** `ppbuffer` — out-pointer for the locked pixel buffer; `ppitch` — out-pointer for the surface pitch.
- **Outputs/Return:** `true` on success; `false` on any failure (after calling `DDRAW_Shutdown`).
- **Side effects:** Writes to `sww_state` fields (`hinstDDRAW`, `lpDirectDraw`, `lpddsFrontBuffer`, `lpddsBackBuffer`, `lpddsOffScreenBuffer`, `lpddpPalette`, `modex`, `palettized`). Calls `DDRAW_SetPalette`. Clears the offscreen buffer via `memset`.
- **Calls:** `LoadLibrary`, `GetProcAddress`, `QDirectDrawCreate` (dynamic), DirectDraw COM vtable methods, `DDRAW_SetPalette`, `DDRAW_Shutdown`, `ri.Con_Printf`.
- **Notes:** Uses `goto fail` for all error paths. ModeX fallback requires `sw_mode->value == 0` and `sw_allow_modex->value` to be non-zero. Palette entries are built from global `d_8to24table` (R at bits 0–7, G at 8–15, B at 16–23 — note the byte order differs from standard RGBX in `DDRAW_SetPalette`).

### DDRAW_SetPalette
- **Signature:** `void DDRAW_SetPalette( const unsigned char *pal )`
- **Purpose:** Updates the DirectDraw palette from a 256-entry RGBA byte array (1024 bytes total, stride 4).
- **Inputs:** `pal` — pointer to palette data; R at offset 0, G at 1, B at 2, A ignored.
- **Outputs/Return:** void.
- **Side effects:** Calls `lpddpPalette->SetEntries`; prints error via `ri.Con_Printf` on failure.
- **Calls:** `sww_state.lpddpPalette->lpVtbl->SetEntries`, `ri.Con_Printf`.
- **Notes:** Early-outs silently if `lpddpPalette` is NULL. Sets `PC_RESERVED | PC_NOCOLLAPSE` flags to prevent Windows from remapping palette entries.

### DDRAW_Shutdown
- **Signature:** `void DDRAW_Shutdown( void )`
- **Purpose:** Releases all DirectDraw resources in reverse allocation order, restores display mode and cooperative level, and frees `ddraw.dll`.
- **Inputs:** None.
- **Outputs/Return:** void.
- **Side effects:** Unlocks offscreen buffer, releases all COM surface/palette/DD objects, NULLs all `sww_state` pointers, calls `FreeLibrary`.
- **Calls:** DirectDraw COM vtable methods (`Unlock`, `Release`, `RestoreDisplayMode`, `SetCooperativeLevel`), `FreeLibrary`, `ri.Con_Printf`.
- **Notes:** Each resource is guarded by a NULL check, making it safe to call from `DDRAW_Init`'s `fail` path mid-initialization.

### DDrawError *(static)*
- **Signature:** `static const char *DDrawError( int code )`
- **Purpose:** Maps a DirectDraw `HRESULT` error code to a human-readable string for console diagnostics.
- **Notes:** Exhaustive switch over all known `DDERR_*` constants; returns `"UNKNOWN"` for unrecognized codes.

## Control Flow Notes
Called during **init** of the Win32 software renderer (`rw_imp.c`): `DDRAW_Init` is invoked to set up surfaces; the returned buffer pointer and pitch are handed to `ref_soft`'s `vid.buffer`. `DDRAW_SetPalette` is called each time the game palette changes (e.g., gamma shift, level load). `DDRAW_Shutdown` is called on renderer teardown or mode change.

## External Dependencies
- `../ref_soft/r_local.h` — `vid`, `sw_state`, `sw_mode`, `d_8to24table`
- `rw_win.h` — `sww_state` (Win32 software renderer window state including all DirectDraw COM pointers)
- `ddraw.dll` — loaded dynamically; `DirectDrawCreate` resolved via `GetProcAddress`
- `ri` (refimport_t) — `ri.Con_Printf` used throughout; defined in the engine, passed at renderer load time
