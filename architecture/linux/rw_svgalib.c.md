# linux/rw_svgalib.c

## File Purpose
Implements the Linux SVGAlib software rendering window/display backend for Quake 2. It satisfies the platform-specific `SWimp_*` interface required by the software renderer (`ref_soft`), managing VGA mode setup, palette programming, and framebuffer blitting via the SVGAlib library.

## Core Responsibilities
- Initialize SVGAlib and enumerate available 8bpp/256-color VGA modes
- Select and configure a VGA mode matching the requested resolution
- Blit the software renderer's backbuffer to the VGA framebuffer each frame (with paged and planar support)
- Program the VGA DAC palette (6-bit scaling from 8-bit input)
- Shut down the VGA mode and free backbuffer memory
- Expose `Sys_MakeCodeWriteable` for marking memory regions executable/writable

## Key Types / Data Structures
None (no local struct/enum/typedef definitions).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `VGA_width` | `int` | global | Active VGA mode pixel width |
| `VGA_height` | `int` | global | Active VGA mode pixel height |
| `VGA_rowbytes` | `int` | global | Bytes per scanline in VGA memory |
| `VGA_bufferrowbytes` | `int` | global | Bytes per scanline in backbuffer (planar modes ×4) |
| `VGA_planar` | `int` | global | Non-zero if current mode is planar (EGA-style) |
| `VGA_pagebase` | `byte *` | global | Pointer to VGA graphics memory base |
| `framebuffer_ptr` | `char *` | global | Working pointer into VGA memory for blitting |
| `num_modes` | `int` | global | Count of modes reported by SVGAlib |
| `modes` | `vga_modeinfo *` | global | Heap-allocated array of all VGA mode descriptors |
| `current_mode` | `int` | global | Index into `modes[]` for the active VGA mode |

## Key Functions

### VID_InitModes
- **Signature:** `void VID_InitModes(void)`
- **Purpose:** Queries SVGAlib for all video modes, copies their info into a heap array, then zeroes out unsupported entries (non-8bpp or non-256-color).
- **Inputs:** None (reads SVGAlib global state)
- **Outputs/Return:** None; populates `modes[]`, `num_modes`
- **Side effects:** `malloc` for `modes`; prints available modes via `ri.Con_Printf`
- **Calls:** `vga_lastmodenumber`, `vga_hasmode`, `vga_getmodeinfo`, `memcpy`, `malloc`, `ri.Con_Printf`
- **Notes:** Modes with `width == 0` are treated as unavailable throughout the file.

### SWimp_Init
- **Signature:** `int SWimp_Init(void *hInstance, void *wndProc)`
- **Purpose:** Entry point to initialize the SVGAlib display subsystem; calls `vga_init()` then enumerates modes.
- **Inputs:** `hInstance`, `wndProc` — unused (Windows API compatibility shims)
- **Outputs/Return:** Always `true`
- **Side effects:** Initializes SVGAlib; allocates `modes[]`
- **Calls:** `vga_init`, `VID_InitModes`

### SWimp_InitGraphics
- **Signature:** `static qboolean SWimp_InitGraphics(qboolean fullscreen)`
- **Purpose:** Finds, sets the VGA mode for the requested `vid.width`/`vid.height`, maps framebuffer memory, and allocates the software backbuffer.
- **Inputs:** `fullscreen` — unused
- **Outputs/Return:** `true` on success, `false` if mode not found
- **Side effects:** Calls `SWimp_Shutdown` first; sets VGA mode via SVGAlib; `malloc` for `vid.buffer`; calls `ri.Vid_NewWindow`; calls `Sys_Error` on critical failure
- **Calls:** `SWimp_Shutdown`, `get_mode`, `vga_setmode`, `vga_getgraphmem`, `vga_setpage`, `malloc`, `ri.Con_Printf`, `ri.Vid_NewWindow`, `Sys_Error`
- **Notes:** Planar mode doubles `vid.rowbytes` (×4) for the software buffer.

### SWimp_EndFrame
- **Signature:** `void SWimp_EndFrame(void)`
- **Purpose:** Copies the software backbuffer (`vid.buffer`) to VGA memory each frame, using planar update or paged 64 KB memcpy chunks.
- **Inputs:** None (reads `vid.buffer`, `vid.rowbytes`, `vid.height`)
- **Outputs/Return:** None
- **Side effects:** Writes to VGA hardware memory; calls `vga_setpage` to bank-switch
- **Calls:** `vga_oktowrite`, `VGA_UpdatePlanarScreen`, `vga_setpage`, `memcpy`
- **Notes:** Bails silently if `vga_oktowrite()` returns false (VT not active).

### SWimp_SetPalette
- **Signature:** `void SWimp_SetPalette(const unsigned char *palette)`
- **Purpose:** Programs the VGA DAC with a 256-entry palette, converting from 8-bit to 6-bit per channel.
- **Inputs:** `palette` — padded xRGB (4 bytes/entry); falls back to `sw_state.currentpalette` if NULL
- **Outputs/Return:** None
- **Side effects:** Writes DAC registers via `vga_setpalvec`; skips write if not VT-active
- **Calls:** `vga_getcolors`, `vga_oktowrite`, `vga_setpalvec`

### SWimp_Shutdown
- **Signature:** `void SWimp_Shutdown(void)`
- **Purpose:** Frees the software backbuffer and resets VGA to text mode.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** `free(vid.buffer)`; `vga_setmode(TEXT)`
- **Calls:** `free`, `vga_setmode`

### Sys_MakeCodeWriteable
- **Signature:** `void Sys_MakeCodeWriteable(unsigned long startaddr, unsigned long length)`
- **Purpose:** Marks a page-aligned memory region as read/write/execute (prot=7) via `mprotect`; used to allow self-modifying renderer code.
- **Inputs:** `startaddr`, `length` — target region
- **Side effects:** `mprotect` syscall; `Sys_Error` on failure
- **Calls:** `getpagesize`, `mprotect`, `Sys_Error`

## Control Flow Notes
- **Init:** `SWimp_Init` is called once at renderer startup; `SWimp_InitGraphics` (via `SWimp_SetMode`) sets up the VGA mode on resolution change.
- **Frame:** `SWimp_EndFrame` is called at the end of each rendered frame to blit `vid.buffer` to hardware.
- **Shutdown:** `SWimp_Shutdown` is called on mode changes and final teardown.

## External Dependencies
- `vga.h`, `vgakeyboard.h`, `vgamouse.h` — SVGAlib (Linux userspace VGA library)
- `sys/mman.h` — `mprotect`
- `asm/io.h` — low-level I/O port access (included but not directly called here)
- `../ref_soft/r_local.h` — `vid`, `sw_state`, `d_8to24table`, `R_GammaCorrectAndSetPalette`
- `../linux/rw_linux.h` — `rserr_t`, shared Linux renderer interface types
- `ri` (refimport_t) — `Con_Printf`, `Vid_NewWindow`, `Vid_GetModeInfo` — defined elsewhere (engine import table)
- `VGA_UpdatePlanarScreen` — declared but defined elsewhere (likely `ref_soft`)
- `Sys_Error` — defined elsewhere in platform layer
