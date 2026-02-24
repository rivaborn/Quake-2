# ref_soft/r_poly.c

## File Purpose
Implements software-renderer polygon rasterization for the Quake 2 soft renderer (`ref_soft`). Handles span-based scanline rendering with affine texture mapping, depth testing, alpha blending, stipple transparency, and turbulent water surface warping.

## Core Responsibilities
- Span-based affine texture mapping across polygon scanlines in 16.16 fixed-point
- Depth (z-buffer) testing per pixel via inverse-z (`izi`)
- Multiple blending modes: opaque, 33%/66% alpha blend, stipple, turbulent warp
- Frustum clipping of polygon faces against view planes (`R_ClipPolyFace`)
- Edge scanning (left/right) to generate span lists for rasterization
- Building polygon descriptors from BSP surface data (`R_BuildPolygonFromSurface`)
- Deferred alpha surface list rendering (`R_DrawAlphaSurfaces`)

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `spanletvars_t` | struct | Per-spanlet rasterization state: texture pointers, s/t accumulators, z-buffer pointer, step values, span count, screen coords |
| `polydesc_t` | typedef (extern) | Polygon descriptor: vertices, texture, plane info, draw function pointer, stipple parity |
| `espan_t` | typedef (extern) | Emitted span: screen u/v start + pixel count |
| `emitpoint_t` | typedef (extern) | Projected vertex: screen u/v, 1/z, s/t texture coords |
| `vec5_t` | typedef (extern) | 5-component float vector: xyz + st, used for clip space vertices |
| `clipplane_t` | typedef (extern) | Clip plane with normal and dist |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `s_spanletvars` | `spanletvars_t` | global | Shared spanlet rasterization state accessed by all draw spanlet functions |
| `r_polyblendcolor` | `int` | static | Palette index for constant-color (flat-shaded) blend spans |
| `s_polygon_spans` | `espan_t *` | static | Points to span list buffer during rasterization |
| `r_polydesc` | `polydesc_t` | global | Current polygon descriptor; set before calling `R_DrawPoly` |
| `r_alpha_surfaces` | `msurface_t *` | global | Linked list of deferred alpha surfaces for end-of-frame rendering |
| `clip_current` | `int` | static | Ping-pong index (0/1) into `r_clip_verts` double buffer |
| `r_clip_verts` | `vec5_t [2][MAXWORKINGVERTS+2]` | global | Double-buffered clip vertex workspace |
| `s_minindex` / `s_maxindex` | `int` | static | Index of topmost/bottommost polygon vertex |

## Key Functions

### R_DrawSpanletOpaque
- Signature: `void R_DrawSpanletOpaque(void)`
- Purpose: Rasterizes one affine spanlet, writing pixels only where palette index != 255 (transparent) and depth test passes; updates z-buffer.
- Inputs: `s_spanletvars` (global state)
- Outputs/Return: Writes to `pdest` (framebuffer) and `pz` (z-buffer)
- Side effects: Modifies framebuffer and z-buffer; advances all spanlet state pointers/accumulators
- Calls: None
- Notes: Pixel 255 is the transparent color sentinel; z-buffer written on pass.

### R_DrawSpanletTurbulentStipple33 / R_DrawSpanletTurbulentStipple66
- Signature: `void R_DrawSpanletTurbulentStipple33/66(void)`
- Purpose: Stipple-transparent turbulent (water warp) spans; 33% skips odd rows+cols, 66% inverts parity. Steps every 2 pixels in the kept rows to achieve ~50% coverage per row.
- Notes: Uses `r_turb_turb` sine table for UV warping; no alpha blend lookup, raw pixel write.

### R_DrawSpanletTurbulentBlended66 / R_DrawSpanletTurbulentBlended33
- Signature: `void R_DrawSpanletTurbulentBlended66/33(void)`
- Purpose: Full alpha-blended turbulent spans using `vid.alphamap` lookup table; 66 weights source heavily, 33 weights destination.
- Side effects: Reads and writes `pdest` for alpha compositing.

### R_DrawSpanlet33 / R_DrawSpanlet66
- Signature: `void R_DrawSpanlet33/66(void)`
- Purpose: Alpha-blended opaque-surface spans using `vid.alphamap`; skips palette index 255.
- Notes: 33 = 33% source / 66% dest; 66 = 66% source / 33% dest (alphamap index order differs).

### R_DrawSpanlet33Stipple / R_DrawSpanlet66Stipple
- Purpose: Stipple-based alpha faking for non-turbulent surfaces; uses `r_polydesc.stipple_parity` to checkerboard which pixels are written.

### R_DrawSpanletConstant33
- Purpose: Flat-shaded constant-color 33% blend using `r_polyblendcolor`; no texture lookup, no transparency sentinel check.

### R_ClipPolyFace
- Signature: `int R_ClipPolyFace(int nump, clipplane_t *pclipplane)`
- Purpose: Sutherland-Hodgman clip of a polygon (stored in `r_clip_verts`) against one plane; ping-pongs between the two clip vertex buffers.
- Inputs: Vertex count, clip plane
- Outputs/Return: New vertex count after clipping
- Side effects: Updates `clip_current`, writes `r_clip_verts`
- Calls: `DotProduct`, `memcpy`
- Notes: Interpolates all 5 components (xyz + st) linearly along clipped edges.

### R_PolygonDrawSpans
- Signature: `void R_PolygonDrawSpans(espan_t *pspan, qboolean iswater)`
- Purpose: Iterates the span list; for each span computes perspective-correct s/t in 16-pixel affine sub-spans, populates `s_spanletvars`, then dispatches `r_polydesc.drawspanlet()`.
- Inputs: Span list, water flag
- Side effects: Sets `r_turb_turb` offset for water animation; writes framebuffer/z-buffer via drawspanlet
- Calls: `r_polydesc.drawspanlet` (function pointer)
- Notes: Uses `DS_SPAN_LIST_END` sentinel to terminate span list; affine correction every 16 pixels.

### R_PolygonScanLeftEdge / R_PolygonScanRightEdge
- Purpose: Walk polygon vertices in opposite directions (CCW left, CW right) filling `s_polygon_spans` with u-start and pixel counts per scanline.
- Notes: Left edge traverses from `s_minindex` downward; right edge clamps to screen rect bounds.

### R_ClipAndDrawPoly
- Signature: `void R_ClipAndDrawPoly(float alpha, qboolean isturbulent, qboolean textured)`
- Purpose: Selects the appropriate `drawspanlet` function pointer based on alpha/turbulent/stipple flags, clips against all 4 frustum planes, projects vertices to screen, then calls `R_DrawPoly`.
- Calls: `R_ClipPolyFace` (×4), `TransformVector`, `VectorSubtract`, `R_DrawPoly`
- Notes: Entry point for external callers; the only function that performs frustum clipping.

### R_BuildPolygonFromSurface
- Signature: `void R_BuildPolygonFromSurface(msurface_t *fa)`
- Purpose: Populates `r_polydesc` and `r_clip_verts[0]` from a BSP `msurface_t`; resolves texture cache or warp image, computes s/t offsets including SURF_FLOWING scroll.
- Calls: `D_CacheSurface`, `DotProduct`, `VectorCopy`, `VectorSubtract`

### R_PolygonCalculateGradients
- Signature: `void R_PolygonCalculateGradients(void)`
- Purpose: Computes perspective-correct s/z, t/z, 1/z screen-space gradients from `r_polydesc` plane/axis vectors; sets global `d_sdivzstepu/v`, `d_tdivzstepu/v`, `d_zistepu/v` etc.
- Side effects: Writes many renderer globals (`sadjust`, `tadjust`, `bbextents`, `bbextentt`, `d_*`)

### R_DrawPoly *(static)*
- Signature: `static void R_DrawPoly(qboolean iswater)`
- Purpose: Internal rasterizer entry: finds y-extents, allocates span buffer on stack, calls gradient/edge/span pipeline.
- Notes: Must not be called directly from outside — no clipping performed.

### R_DrawAlphaSurfaces
- Signature: `void R_DrawAlphaSurfaces(void)`
- Purpose: End-of-frame pass: iterates `r_alpha_surfaces` linked list, builds and draws each with appropriate alpha (0.60 for TRANS66, 0.30 otherwise); clears the list.
- Calls: `R_BuildPolygonFromSurface`, `R_ClipAndDrawPoly`

### R_IMFlatShadedQuad
- Signature: `void R_IMFlatShadedQuad(vec3_t a,b,c,d, int color, float alpha)`
- Purpose: Immediate-mode flat-shaded quad; sets up `r_polydesc` and `r_clip_verts` directly, computes face normal via cross product, then calls `R_ClipAndDrawPoly` with `textured=false`.
- Calls: `CrossProduct`, `VectorNormalize`, `DotProduct`, `R_ClipAndDrawPoly`

## Control Flow Notes
- **Frame**: `R_DrawAlphaSurfaces` is called at end of frame after opaque geometry. Per-surface: `R_BuildPolygonFromSurface` → `R_ClipAndDrawPoly` → `R_ClipPolyFace` ×4 → project → `R_DrawPoly` → `R_PolygonCalculateGradients` → `R_PolygonScanLeftEdge/RightEdge` → `R_PolygonDrawSpans` → `drawspanlet` (function pointer).
- `r_alpha_surfaces` is a linked list populated earlier in the frame (in BSP traversal) and consumed here.

## External Dependencies
- `r_local.h` — renderer globals (`d_sdivzstepu`, `cacheblock`, `cachewidth`, `d_viewbuffer`, `d_pzbuffer`, `xscale`, `ycenter`, etc.)
- `vid.alphamap` — 256×256 palette alpha blend lookup table (defined in vid system)
- `r_turb_turb`, `sintable` — turbulence sine table (defined in `r_warp.c` or similar)
- `D_CacheSurface` — surface lightmap cache (defined in `r_surf.c`)
- `TransformVector` — view-space transform (defined in `r_main.c`)
- `view_clipplanes` — frustum planes (defined in `r_main.c`)
- `sw_stipplealpha` — cvar controlling stipple vs. blend mode (defined elsewhere)
- `r_newrefdef`, `r_refdef`, `r_origin`, `currentmodel`, `r_worldmodel` — global renderer state
