# ref_soft/r_polyse.c

## File Purpose
Implements the software rasterizer's polygon span-filling pipeline for Alias (MD2) model triangles. It handles edge scanning, gradient computation, and per-pixel span drawing including opaque, 33%/66% translucent, threshold (fizzle-fade), and flat-fill modes.

## Core Responsibilities
- Classify triangle vertex ordering and select the correct edge-traversal table (`R_PolysetSetEdgeTable`)
- Compute per-axis affine gradients (s, t, light, z-inverse) across the triangle face (`R_PolysetCalcGradients`)
- Walk the left edge scanline-by-scanline, emitting `spanpackage_t` descriptors (`R_PolysetScanLeftEdge_C`)
- Drive the right-edge scan and dispatch span packets to the active draw function (`R_RasterizeAliasPolySmooth`)
- Provide multiple span-draw backends: opaque, 33% alpha blend, 66% alpha blend, constant-color blends, threshold/fizzle-fade, and flat debug fill
- Maintain and update the skin row-pointer lookup table (`R_PolysetUpdateTables`)
- Support an IR-goggles rendering mode that remaps texels through `irtable[]`

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `spanpackage_t` | struct | Per-scanline span descriptor: destination ptr, z-buffer ptr, pixel count, texture ptr, s/t fracs, light, z-inverse |
| `edgetable` | struct | Describes which vertex pointers form the left/right edges and whether the top is flat |
| `adivtab_t` | struct | Lookup-table entry for fast integer floor-division (quotient + remainder) |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `aliastriangleparms` | `aliastriangleparms_t` | global | Input triangle vertices for the current draw call |
| `r_p0/r_p1/r_p2` | `int[6]` | global | Unpacked vertex attributes (u,v,s,t,light,zi) |
| `d_pdrawspans` | `void(*)(spanpackage_t*)` | global | Function pointer selecting the active span rasterizer |
| `edgetables[12]` | `edgetable` | global | All possible triangle edge configurations |
| `pedgetable` | `edgetable*` | global | Points to the currently active entry in `edgetables` |
| `a_spans` | `spanpackage_t*` | global | Pointer to the span-package array for the current triangle |
| `d_pedgespanpackage` | `spanpackage_t*` | global | Cursor into `a_spans` during left-edge scan |
| `skintable[MAX_LBM_HEIGHT]` | `byte*[]` | global | Row-start pointers into the current skin texture |
| `irtable[256]` | `byte[]` | global | IR-goggle palette remap table (PGM extension) |
| `iractive` | `byte` | global | Flag enabling IR-goggle rendering mode |
| `rand1k[]/rand1k_index` | `int[]/int` | global | 1024-entry random table + index for fizzle-fade |
| `adivtab[32*32]` | `adivtab_t` (static) | static | Fast floor-div table for small integer operands |
| `d_xdenom` | `int` | global | Cross-product denominator for gradient calculations |
| Numerous `d_*/r_*step*` vars | `int` | global | Rasterizer step accumulators (s, t, light, zi, dest, z) |

## Key Functions

### R_DrawTriangle
- **Signature:** `void R_DrawTriangle(void)`
- **Purpose:** Entry point — validates the triangle is non-degenerate, unpacks `aliastriangleparms` into `r_p0/r_p1/r_p2`, then dispatches to edge setup and rasterization.
- **Inputs:** `aliastriangleparms` (global)
- **Outputs/Return:** void; fills framebuffer and z-buffer as side effects
- **Side effects:** Writes `r_p0–r_p2`, `a_spans`, `d_xdenom`; calls rasterizer
- **Calls:** `R_PolysetSetEdgeTable`, `R_RasterizeAliasPolySmooth`
- **Notes:** Back-face culled if `d_xdenom >= 0`; degenerate edges short-circuit early.

### R_PolysetCalcGradients
- **Signature:** `void R_PolysetCalcGradients(int skinwidth)`
- **Purpose:** Computes the screen-space affine step values for s, t, light, and z-inverse in both x and y using the triangle's cross-product denominator.
- **Inputs:** `skinwidth`, global `r_p0–r_p2`, `d_xdenom`
- **Outputs/Return:** void; writes `r_lstepx/y`, `r_sstepx/y`, `r_tstepx/y`, `r_zistepx/y`, `a_sstepxfrac`, `a_tstepxfrac`, `a_ststepxwhole`
- **Side effects:** Modifies ~10 global step variables
- **Calls:** none
- **Notes:** Has two implementations: x86 inline-ASM path (`#if id386 && !defined __linux__`) using FPU ceil-mode trick for light, and portable C path.

### R_RasterizeAliasPolySmooth
- **Signature:** `void R_RasterizeAliasPolySmooth(void)`
- **Purpose:** Orchestrates full triangle rasterization: scans left edge(s) into `a_spans`, then drives `d_pdrawspans` along the right edge(s).
- **Inputs:** `pedgetable`, all `d_*` globals, `r_affinetridesc`
- **Outputs/Return:** void; writes framebuffer/z-buffer via span draw function
- **Side effects:** Writes all `d_*step*` globals; calls left-edge scanner and span draw function pointer
- **Calls:** `R_PolysetCalcGradients`, `R_PolysetSetUpForLineScan`, `R_PolysetScanLeftEdge`/`_C`, `(*d_pdrawspans)`
- **Notes:** Handles triangles with 1 or 2 left-edge segments and 1 or 2 right-edge segments. Terminates span list with sentinel `count = -999999`.

### R_PolysetScanLeftEdge_C
- **Signature:** `void R_PolysetScanLeftEdge_C(int height)`
- **Purpose:** Walks the left triangle edge row-by-row, writing one `spanpackage_t` per scanline using Bresenham-style error accumulation.
- **Inputs:** `height` (row count), all `d_*` scan globals
- **Outputs/Return:** void; populates `a_spans` via `d_pedgespanpackage`
- **Side effects:** Advances `d_pedgespanpackage`, `d_pdest`, `d_pz`, `d_ptex`, `d_sfrac`, `d_tfrac`, `d_light`, `d_zi`
- **Notes:** C fallback; x86 ASM version lives in `r_polysa.asm`/`d_polysa.s`.

### R_PolysetDrawSpans8_Opaque
- **Signature:** `void R_PolysetDrawSpans8_Opaque(spanpackage_t *pspanpackage)`
- **Purpose:** Opaque per-pixel span rasterizer with z-test, lighting lookup, and optional IR-goggle remap.
- **Inputs:** span list terminated by `count == -999999`
- **Side effects:** Writes `vid.colormap`-lit pixels and z values to framebuffer/z-buffer
- **Notes:** Compiled only on non-x86 (`#if !id386`); x86 uses ASM equivalent.

- **`R_PolysetDrawSpans8_33/66`**: 33%/66% alpha-blend variants using `vid.alphamap[src*256+dst]` or `[src+dst*256]`; note 33% does not update z-buffer.
- **`R_PolysetDrawThreshSpans8`**: Fizzle-fade using `rand1k[]` against `vis_thresh`; skips z-write on culled pixels.
- **`R_PolysetDrawSpansConstant8_33/66`**: Constant-color blend variants for `r_aliasblendcolor`, no texture sampling.
- **`R_PolysetFillSpans8`**: Debug flat-fill using incrementing `d_aflatcolor`; no z-buffer.

### R_PolysetSetEdgeTable
- **Signature:** `void R_PolysetSetEdgeTable(void)`
- **Purpose:** Examines the y-ordering of `r_p0/p1/p2` and sets `pedgetable` to the correct entry from `edgetables[12]`.
- **Notes:** Handles all degenerate flat-top/flat-bottom cases.

### R_PolysetSetUpForLineScan
- **Signature:** `void R_PolysetSetUpForLineScan(fixed8_t su, fixed8_t sv, fixed8_t eu, fixed8_t ev)`
- **Purpose:** Initialises Bresenham parameters (`ubasestep`, `erroradjustup`, `erroradjustdown`) for edge walking.
- **Calls:** `FloorDivMod` (for operands outside the `adivtab` range)

### FloorDivMod
- **Purpose:** Mathematically correct floor-division with remainder for both positive and negative numerators (marked FIXME for removal).

## Control Flow Notes
Called during the per-frame Alias model render pass. `R_DrawAliasModel` (elsewhere) sets `aliastriangleparms` and `d_pdrawspans`, then calls `R_DrawTriangle` per triangle. This file owns the entire triangle-to-pixel pipeline for the software renderer.

## External Dependencies
- **Includes:** `r_local.h` (brings in `r_affinetridesc`, `d_viewbuffer`, `d_pzbuffer`, `vid`, `currententity`, `r_newrefdef`, etc.)
- **Included data:** `rand1k.h`, `adivtab.h` (table data)
- **Defined elsewhere:** `errorterm`, `erroradjustup`, `erroradjustdown`, `ubasestep` (Bresenham state, likely in `r_polysa.asm`/`d_polysa.s`); `R_PolysetScanLeftEdge` (ASM version); `d_zwidth`, `r_screenwidth`, `r_aliasblendcolor`, `fpu_sp24_ceil_cw`, `fpu_chop_cw`
