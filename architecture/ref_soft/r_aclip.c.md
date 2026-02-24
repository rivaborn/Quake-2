# ref_soft/r_aclip.c

## File Purpose
Implements polygon clipping routines for Alias (MD2) model triangles in the software renderer. Clips projected screen-space vertices against the view frustum (Z-near plane) and screen-edge boundaries before rasterization.

## Core Responsibilities
- Clip individual edges against the near Z plane (`R_Alias_clip_z`)
- Clip individual edges against screen rectangle bounds (left/right/top/bottom)
- Run a Sutherland-Hodgman style polygon clipper (`R_AliasClip`) for a single clip plane at a time
- Orchestrate full multi-plane clipping of a triangle (`R_AliasClipTriangle`)
- Fan-triangulate clipped polygon output and submit to `R_DrawTriangle`

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `finalvert_t` | struct (defined elsewhere) | Screen-space projected vertex: `u`, `v` (screen coords), `s`, `t` (texcoords), `l` (light), `zi` (inverse-Z), `xyz[3]` (view-space), `flags` (clip flags) |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `fv` | `finalvert_t[2][8]` | static | Ping-pong clip buffers; holds up to 8 vertices per buffer during multi-plane clipping |

## Key Functions

### R_Alias_clip_z
- **Signature:** `void R_Alias_clip_z(finalvert_t *pfv0, finalvert_t *pfv1, finalvert_t *out)`
- **Purpose:** Linearly interpolates a new vertex at the near Z clip plane (`ALIAS_Z_CLIP_PLANE`) along the edge pfv0→pfv1, then projects it to screen space.
- **Inputs:** Two view-space vertices straddling the Z clip plane.
- **Outputs/Return:** Writes clipped vertex into `out`; `out->xyz[2]` is set to `ALIAS_Z_CLIP_PLANE`.
- **Side effects:** Calls `R_AliasProjectAndClipTestFinalVert` which writes screen-space `u`/`v`/`zi`/`flags` into `out`.
- **Calls:** `R_AliasProjectAndClipTestFinalVert`
- **Notes:** Only operates on `xyz`/`s`/`t`/`l`; screen fields are filled by the projection call.

### R_Alias_clip_left / _right / _top / _bottom
- **Signature:** `void R_Alias_clip_*(finalvert_t *pfv0, finalvert_t *pfv1, finalvert_t *out)`
- **Purpose:** Interpolate a clipped vertex at a screen-rectangle boundary. The vertex ordering (which endpoint to treat as base) is chosen by comparing `v` coordinates to maintain consistent winding.
- **Inputs:** Two screen-space vertices; one on each side of the clip edge.
- **Outputs/Return:** Writes interpolated `u`, `v`, `s`, `t`, `l`, `zi` into `out` (with +0.5 rounding).
- **Side effects:** None beyond writing `out`.
- **Calls:** None.
- **Notes:** Guarded by `#if !id386`; x86 platforms supply assembly replacements. The `+0.5` bias performs fixed-point rounding.

### R_AliasClip
- **Signature:** `int R_AliasClip(finalvert_t *in, finalvert_t *out, int flag, int count, void(*clip)(...))`
- **Purpose:** Sutherland-Hodgman single-plane clipper. Walks polygon edges, emitting clipped intersection vertices and keeping inside vertices.
- **Inputs:** Input vertex array, output array, clip flag bitmask, vertex count, edge-clip function pointer.
- **Outputs/Return:** Returns new vertex count in `out`; recomputes `flags` on newly generated vertices.
- **Side effects:** Updates `out[k].flags` by re-testing against all four screen edges after clipping.
- **Calls:** The passed-in `clip` function pointer.
- **Notes:** Both endpoints outside → skip; one outside → emit intersection; inside endpoint always emitted. Max output vertices bounded by input count + number of clipped intersections (8 max for a triangle after 5 planes).

### R_AliasClipTriangle
- **Signature:** `void R_AliasClipTriangle(finalvert_t *index0, finalvert_t *index1, finalvert_t *index2)`
- **Purpose:** Full pipeline: copies triangle into ping-pong buffers, clips sequentially against Z and four screen planes, clamps surviving vertices to screen rect, then fan-triangulates and submits to the rasterizer.
- **Inputs:** Three projected/flagged `finalvert_t` pointers for a triangle.
- **Outputs/Return:** void.
- **Side effects:** Writes `aliastriangleparms` global and calls `R_DrawTriangle()` for each output sub-triangle.
- **Calls:** `R_AliasClip` (×up to 5), `R_DrawTriangle`.
- **Notes:** Uses `pingpong` integer XOR'd with 1 to alternate between `fv[0]` and `fv[1]` after each clip pass. Early-returns if any clip stage produces 0 vertices.

## Control Flow Notes
Called during the alias model render pass (per-triangle). `R_AliasClipTriangle` is the entry point invoked for each triangle that has at least one clipped vertex; fully inside triangles bypass clipping and go directly to `R_DrawTriangle`. Output feeds the software rasterizer.

## External Dependencies
- `r_local.h` — pulls in `finalvert_t`, clip flag constants (`ALIAS_Z_CLIP`, `ALIAS_LEFT_CLIP`, etc.), `ALIAS_Z_CLIP_PLANE`, `r_refdef` (aliasvrect bounds), `aliastriangleparms`
- `R_AliasProjectAndClipTestFinalVert` — defined elsewhere (projects view-space xyz to screen)
- `R_DrawTriangle` — defined elsewhere (software rasterizer entry point)
- `aliastriangleparms` — global struct defined elsewhere; written here to pass triangle to rasterizer
