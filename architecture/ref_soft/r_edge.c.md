# ref_soft/r_edge.c

## File Purpose
Implements the Active Edge Table (AET) algorithm for the software renderer, converting BSP-sorted polygon edges into per-scanline span lists. It also dispatches surface filling (texture mapping, sky, turbulent water, flat background) for each visible surface using the generated spans.

## Core Responsibilities
- Manage the active edge table (AET) per scanline: insert, remove, and step edges
- Generate horizontal spans for each visible surface via leading/trailing edge processing
- Maintain a sorted surface stack (by depth key / 1/z) to resolve surface visibility
- Dispatch per-surface rasterization: solid texture, sky, turbulent, background, flat debug
- Calculate texture gradient values (`d_sdivz*`, `d_tdivz*`, `sadjust`, `tadjust`) for scanline mappers
- Handle submodel (bmodel) entities with per-surface model-space transforms

## Key Types / Data Structures
None defined here; all types are from `r_local.h`.

| Name | Kind | Purpose |
|------|------|---------|
| `edge_t` | struct | AET entry: screen-space u coordinate, step, surface indices, prev/next links |
| `surf_t` | struct | Active surface: depth key, span list head, z-gradient coefficients, flags |
| `espan_t` | struct | One horizontal span: start u, pixel count, scanline v, next pointer |
| `msurface_t` | struct | BSP map surface with texture info, plane, extents |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `r_edges`, `edge_p`, `edge_max` | `edge_t *` | global | Edge pool and current allocation pointer |
| `auxedges` | `edge_t *` | global | Auxiliary edge storage |
| `surfaces`, `surface_p`, `surf_max` | `surf_t *` | global | Surface pool and current pointer |
| `newedges[MAXHEIGHT]` | `edge_t *[]` | global | Per-scanline list of edges entering the AET |
| `removeedges[MAXHEIGHT]` | `edge_t *[]` | global | Per-scanline list of edges leaving the AET |
| `span_p`, `max_span_p` | `espan_t *` | global | Span allocation pointer and overflow watermark |
| `r_currentkey` | `int` | global | Current depth sort key counter |
| `current_iv` | `int` | global | Current scanline being processed |
| `edge_head/tail/aftertail/sentinel` | `edge_t` | global | AET sentinel nodes bounding the active list |
| `fv` | `float` | global | Float cast of current scanline index (for z-gradient eval) |
| `pdrawfunc` | `void (*)(void)` | static | Pointer to span generator (forward or backward) |
| `miplevel` | `int` | static | Current mip level for surface rasterization |
| `scale_for_mip` | `float` | global | Scale factor used for mip selection |
| `ubasestep`, `errorterm`, `erroradjustup`, `erroradjustdown` | `int` | global | DDA error terms for edge stepping |
| `pface`, `pcurrentcache` | pointers | global | Current surface face and texture cache block |
| `transformed_modelorg`, `world_transformed_modelorg`, `local_modelorg` | `vec3_t` | global | Model-space origin transformed for current entity |

## Key Functions

### R_BeginEdgeFrame
- **Signature:** `void R_BeginEdgeFrame(void)`
- **Purpose:** Resets edge and surface pools; configures background surface; clears `newedges`/`removeedges` for all visible scanlines; selects forward or backward span generator.
- **Inputs:** `sw_draworder` cvar, `r_refdef.vrect`
- **Outputs/Return:** None
- **Side effects:** Writes `edge_p`, `surface_p`, `surfaces[1]`, `pdrawfunc`, `r_currentkey`, clears `newedges[]`/`removeedges[]`
- **Calls:** None (reads cvars)

### R_InsertNewEdges
- **Signature:** `void R_InsertNewEdges(edge_t *edgestoadd, edge_t *edgelist)`
- **Purpose:** Merges a sorted list of new edges into the AET sorted by u. Uses an unrolled linear scan with `goto` for speed.
- **Inputs:** New edge list (sorted by u), current AET head
- **Outputs/Return:** None (modifies AET in place)
- **Side effects:** Rewires `next`/`prev` pointers in the AET doubly-linked list
- **Notes:** `#if !id386` — x86 builds use an assembly version

### R_RemoveEdges
- **Signature:** `void R_RemoveEdges(edge_t *pedge)`
- **Purpose:** Unlinks all edges in the `nextremove` chain from the AET.
- **Notes:** `#if !id386`; trivial doubly-linked list removal

### R_StepActiveU
- **Signature:** `void R_StepActiveU(edge_t *pedge)`
- **Purpose:** Advances all AET edge u-values by their `u_step`, then re-sorts any edges that moved out of order (insertion sort pushback). Unrolled 4x for speed.
- **Side effects:** Modifies `edge_t.u`, rewires AET links
- **Notes:** `#if !id386`; sentinel `edge_aftertail` terminates the loop

### R_LeadingEdge
- **Signature:** `void R_LeadingEdge(edge_t *edge)`
- **Purpose:** Handles a surface entering the AET. Inserts the surface into the depth-sorted active surface stack. If it becomes the new top (closest), emits a span for the previously-top surface. Uses 1/z comparison to break ties between coplanar bmodel surfaces.
- **Side effects:** Writes `span_p`, modifies `surf_t.last_u`, `surf_t.spanstate`, surface stack links
- **Notes:** `#if !id386`; `goto` heavy for performance

### R_LeadingEdgeBackwards
- **Signature:** `void R_LeadingEdgeBackwards(edge_t *edge)`
- **Purpose:** Same as `R_LeadingEdge` but for back-to-front (`sw_draworder`) mode; key comparison is reversed; no 1/z tie-breaking.

### R_TrailingEdge
- **Signature:** `void R_TrailingEdge(surf_t *surf, edge_t *edge)`
- **Purpose:** Handles a surface leaving the AET. If the departing surface is currently on top, emits a span and passes `last_u` to the newly-exposed surface below.
- **Side effects:** Writes `span_p`, modifies surface stack links, `spanstate`

### R_GenerateSpans
- **Signature:** `void R_GenerateSpans(void)`
- **Purpose:** Walks the AET for the current scanline, calling `R_TrailingEdge`/`R_LeadingEdge` for each edge, then `R_CleanupSpan` to terminate any open spans at the screen edge.
- **Notes:** `#if !id386`

### R_GenerateSpansBackward
- **Signature:** `void R_GenerateSpansBackward(void)`
- **Purpose:** Same as above but calls `R_LeadingEdgeBackwards` instead; used when `sw_draworder` is set.

### R_ScanEdges
- **Signature:** `void R_ScanEdges(void)`
- **Purpose:** Main scanline loop. Allocates span buffer on stack (cache-aligned), iterates scanlines from top to bottom: inserts new edges, generates spans, flushes `D_DrawSurfaces` if span buffer is near full, removes dead edges, steps active u values. Processes the last scanline separately without step/remove.
- **Side effects:** Calls `D_DrawSurfaces` (may be called multiple times per frame); writes `span_p`, `current_iv`, `fv`; reads all AET and surface state

### D_MipLevelForScale
- **Signature:** `int D_MipLevelForScale(float scale)`
- **Purpose:** Selects mip level 0–3 by comparing scale against `d_scalemip[]` thresholds; clamps to `d_minmip`.

### D_CalcGradients
- **Signature:** `void D_CalcGradients(msurface_t *pface)`
- **Purpose:** Computes screen-space perspective-correct texture gradient coefficients (`d_sdivzstepu`, `d_tdivzstepu`, etc.) and `sadjust`/`tadjust` from the surface texture axes, view scale, and current mip level. Applies scrolling offset for `SURF_FLOWING` textures.
- **Side effects:** Writes `d_sdivzstepu/v`, `d_tdivzstepu/v`, `d_sdivzorigin`, `d_tdivzorigin`, `sadjust`, `tadjust`, `bbextents`, `bbextentt`

### D_DrawSurfaces
- **Signature:** `void D_DrawSurfaces(void)`
- **Purpose:** Iterates all active surfaces and dispatches to the appropriate filler: `D_SolidSurf`, `D_SkySurf`, `D_BackgroundSurf`, `D_TurbulentSurf`, or `D_DrawflatSurfaces` (debug). Resets model origin and frustum after each call.
- **Side effects:** Calls rasterizers, calls `R_TransformFrustum`; writes `modelorg`, `transformed_modelorg`, `r_drawnpolycount`

### D_SolidSurf / D_TurbulentSurf / D_SkySurf / D_BackgroundSurf
- All follow the pattern: set z-gradient globals, optionally rotate bmodel, call `D_CalcGradients`, call scanline span drawers (`D_DrawSpans16`, `Turbulent8`, etc.), call `D_DrawZSpans`. Restore view state afterward if submodel.

## Control Flow Notes
- **Init:** `R_BeginEdgeFrame` called at frame start to reset pools.
- **Per-polygon:** BSP traversal (elsewhere) emits edges into `newedges[]`/`removeedges[]`.
- **Per-frame render:** `R_ScanEdges` is the main entry point — it drives the scanline loop, AET management, and span generation.
- **Rasterization:** `D_DrawSurfaces` is called from within `R_ScanEdges` (possibly multiple times on overflow) and once at the end.
- **Shutdown:** No explicit shutdown; pools are reset each frame.

## External Dependencies
- **Includes:** `r_local.h` (all renderer types, globals, math macros)
- **Defined elsewhere:** `D_DrawSurfaces` calls `D_DrawSpans16`, `D_DrawZSpans`, `Turbulent8`, `NonTurbulent8`, `D_CacheSurface`, `D_FlatFillSurface` (other ref_soft files); `R_RotateBmodel`, `R_TransformFrustum` (r_bsp/r_main); `TransformVector`, `VectorSubtract`, `DotProduct` (math); `sw_draworder`, `sw_clearcolor`, `sw_drawflat` (cvars); `d_scalemip`, `d_minmip`, `xscaleinv`, `yscaleinv`, `xcenter`, `ycenter`, `r_newrefdef`, `r_refdef`, `r_origin`, `base_vpn/vup/vright` (renderer globals)
