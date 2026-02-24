# ref_soft/r_scan.c

## File Purpose
Portable C implementation of scan-line rasterization for the software renderer. Handles perspective-correct texture mapping for turbulent (water/lava), standard, and depth (Z) spans at 8-bit color depth.

## Core Responsibilities
- Apply full-screen sine-wave warp effect (`D_WarpScreen`)
- Render turbulent surface spans with animated UV distortion (`Turbulent8`)
- Render non-turbulent scrolling water-type surfaces without distortion (`NonTurbulent8`)
- Render standard textured spans with perspective correction in 8-pixel sub-spans (`D_DrawSpans16`)
- Write inverse-Z values into the Z-buffer for depth testing (`D_DrawZSpans`)
- Expose file-static state used by the optional x86 ASM override of `D_DrawTurbulent8Span`

## Key Types / Data Structures
None (uses types from `r_local.h`).

| Name | Kind | Purpose |
|------|------|---------|
| `espan_t` | struct (external) | Linked list of horizontal pixel spans with `u`, `v`, `count`, `pnext` |
| `fixed16_t` | typedef (external) | 16.16 fixed-point integer for texture coordinates |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `r_turb_pbase` | `unsigned char *` | global | Base pointer into texture cache block for turbulent spans |
| `r_turb_pdest` | `unsigned char *` | global | Current write pointer into the framebuffer for turbulent spans |
| `r_turb_s` | `fixed16_t` | global | Current S texture coordinate (16.16) for turbulent span |
| `r_turb_t` | `fixed16_t` | global | Current T texture coordinate (16.16) for turbulent span |
| `r_turb_sstep` | `fixed16_t` | global | Per-pixel S step for turbulent span |
| `r_turb_tstep` | `fixed16_t` | global | Per-pixel T step for turbulent span |
| `r_turb_turb` | `int *` | global | Pointer into sine table at current time offset for UV distortion |
| `r_turb_spancount` | `int` | global | Remaining pixel count for current sub-span in turbulent renderer |
| `rowptr` / `column` | `byte*[]` / `int[]` | static (in `D_WarpScreen`) | Cached warp remapping tables, rebuilt on resolution change |
| `cached_width/height` | `int` | static (in `D_WarpScreen`) | Detect resolution change to invalidate warp cache |

## Key Functions

### D_WarpScreen
- **Signature:** `void D_WarpScreen(void)`
- **Purpose:** Full-screen sine-wave distortion applied to the rendered view to simulate underwater/warp effects.
- **Inputs:** `r_newrefdef` (width, height, time, x/y offset), `r_refdef.vrect`, `r_warpbuffer`, `vid.buffer`, `intsintable`
- **Outputs/Return:** Writes warped pixels directly to `vid.buffer`
- **Side effects:** Updates `rowptr[]` and `column[]` static caches on resolution change; reads `r_warpbuffer`
- **Calls:** None (inline pixel sampling)
- **Notes:** Processes 4 pixels per inner loop iteration; resolution change detection avoids rebuilding the warp table every frame.

### D_DrawTurbulent8Span
- **Signature:** `void D_DrawTurbulent8Span(void)`
- **Purpose:** Inner-loop pixel writer for turbulent surfaces; samples a 64×64 texture with sine-displaced UV coordinates.
- **Inputs:** Globals `r_turb_s/t`, `r_turb_sstep/tstep`, `r_turb_turb`, `r_turb_pbase`, `r_turb_pdest`, `r_turb_spancount`
- **Outputs/Return:** Writes `r_turb_spancount` pixels to `r_turb_pdest`; advances the pointer
- **Side effects:** Modifies all `r_turb_*` globals
- **Calls:** None
- **Notes:** Compiled only when `id386` is not defined; x86 targets use an ASM version. UV wrap is via `& 63` (64-texel tile).

### Turbulent8
- **Signature:** `void Turbulent8(espan_t *pspan)`
- **Purpose:** Perspective-correct turbulent texture mapper; drives `D_DrawTurbulent8Span` in 16-pixel sub-spans.
- **Inputs:** Linked list of `espan_t` spans; `d_sdivz*`, `d_tdivz*`, `d_zi*` globals; `sintable`; `cacheblock`
- **Outputs/Return:** None; writes to `d_viewbuffer` via `r_turb_pdest`
- **Side effects:** Sets all `r_turb_*` globals; calls `D_DrawTurbulent8Span`
- **Calls:** `D_DrawTurbulent8Span`
- **Notes:** Sub-span size is 16 pixels; steps are computed by shift (mid-span) or divide (last sub-span) to avoid texture overrun.

### NonTurbulent8
- **Signature:** `void NonTurbulent8(espan_t *pspan)`
- **Purpose:** Variant of `Turbulent8` for scrolling water surfaces where turbulence amplitude is zero; uses `blanktable` instead of `sintable`.
- **Inputs:** Same as `Turbulent8`; uses `blanktable` (all zeros) for `r_turb_turb`
- **Outputs/Return:** None; writes to `d_viewbuffer`
- **Side effects:** Same as `Turbulent8`
- **Calls:** `D_DrawTurbulent8Span`
- **Notes:** Added by PGM (Quake 2 enhancement). Structurally identical to `Turbulent8` except the turb table pointer.

### D_DrawSpans16
- **Signature:** `void D_DrawSpans16(espan_t *pspan)`
- **Purpose:** Perspective-correct 8-bit texture mapper for standard (non-turbulent) surfaces, subdivided in 8-pixel sub-spans.
- **Inputs:** Span list; `d_sdivz*`, `d_tdivz*`, `d_zi*`; `cacheblock`, `cachewidth`
- **Outputs/Return:** Writes pixels to `d_viewbuffer`
- **Side effects:** None beyond framebuffer writes
- **Calls:** None (inline pixel loop)
- **Notes:** Compiled only when `id386` not defined. Despite the name and FIXME comment, sub-spans are 8 pixels, not 16.

### D_DrawZSpans
- **Signature:** `void D_DrawZSpans(espan_t *pspan)`
- **Purpose:** Fills the Z-buffer with 16-bit inverse-Z values for each span.
- **Inputs:** Span list; `d_ziorigin`, `d_zistepv`, `d_zistepu`; `d_pzbuffer`, `d_zwidth`
- **Outputs/Return:** Writes to `d_pzbuffer` (array of `short`)
- **Side effects:** Writes Z-buffer
- **Calls:** None
- **Notes:** Handles odd-alignment by writing the first short separately; packs two `short` values per `int` write for throughput. Compiled only when `id386` not defined.

## Control Flow Notes
Called during the surface-rendering phase of each frame. `Turbulent8` / `NonTurbulent8` are invoked by the BSP surface drawer for water/lava/slime/scrolling surfaces. `D_DrawSpans16` handles solid world surfaces. `D_DrawZSpans` runs alongside to populate depth data. `D_WarpScreen` is a post-process pass applied after the view is rendered to `r_warpbuffer`.

## External Dependencies
- `r_local.h` — includes all shared renderer state
- `d_viewbuffer`, `d_pzbuffer`, `d_zwidth`, `r_screenwidth`, `cacheblock`, `cachewidth` — defined in renderer globals
- `d_sdivzstepu/v`, `d_tdivzstepu/v`, `d_zistepu/v`, origins, `sadjust/tadjust`, `bbextents/bbextentt` — perspective-correct rasterization parameters, defined elsewhere
- `sintable`, `intsintable`, `blanktable` — precomputed sine/zero tables, defined elsewhere
- `r_warpbuffer` — pre-rendered warp source buffer, defined elsewhere
- `vid.buffer`, `vid.rowbytes` — video output surface, defined in platform layer
- `r_newrefdef`, `r_refdef` — current frame view parameters, defined elsewhere
