# ref_soft/r_rast.c

## File Purpose
Implements the software rasterizer's edge emission and clipping pipeline for the Quake 2 software renderer. It transforms world/model edges into screen-space rasterization edges, clips them against view frustum planes, and posts visible surfaces to the span-generation system. Also manages the skybox geometry construction and emission.

## Core Responsibilities
- Clip 3D edges against the view frustum (left, right, top, bottom planes) via `R_ClipEdge`
- Project clipped vertices to screen space and emit rasterization edges via `R_EmitEdge`
- Cache edge results per-frame to avoid redundant clipping work
- Post surface descriptors (`surf_t`) with 1/z gradient coefficients for the span renderer
- Initialize and emit the skybox as 6 fake BSP faces appended to `loadmodel`
- Handle translucent surfaces by deferring them to `r_alpha_surfaces` instead of the edge renderer
- Provide separate entry points for world faces (`R_RenderFace`) and brush model faces (`R_RenderBmodelFace`)

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `evert_t` | struct | Transient projected vertex: screen `u`, `v`, and ceiling-snapped `v` (scanline integer) |
| `clipplane_t` | struct (defined in r_local.h) | Frustum clip plane with normal, dist, flags for left/right edge, and linked `next` |
| `bedge_t` | struct (defined elsewhere) | Linked list of brush model edges, each holding two `mvertex_t*` |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `cacheoffset` | `unsigned int` | global | Byte offset of the freshly emitted edge into `r_edges`; written back to `medge_t.cachededgeoffset` |
| `c_faceclip` | `int` | global | Debug counter: faces that entered the clip pipeline |
| `entity_clipplanes` | `clipplane_t*` | global | Per-entity clip plane list pointer |
| `view_clipplanes[4]` | `clipplane_t[]` | global | Four frustum clip planes (left/right/top/bottom) |
| `world_clipplanes[16]` | `clipplane_t[]` | global | Additional world clip planes |
| `r_pedge` | `medge_t*` | global | Current BSP edge being processed; used by cache write-back |
| `r_leftclipped`, `r_rightclipped` | `qboolean` | global | Whether the current edge was clipped on left/right |
| `makeleftedge`, `makerightedge` | `qboolean` | static | Tracks whether synthetic left/right closure edges are needed |
| `r_nearzionly` | `qboolean` | global | When true, `R_EmitEdge` only updates `r_nearzi` (right-edge 1/z pass) |
| `sintable[1280]`, `intsintable[1280]`, `blanktable[1280]` | `int[]` | global | Lookup tables for trigonometric/scan operations |
| `r_leftenter`, `r_leftexit`, `r_rightenter`, `r_rightexit` | `mvertex_t` | global | Intersection points where edges cross the left/right clip planes |
| `r_emitted` | `int` | global | Set to 1 if at least one edge was emitted this face |
| `r_nearzi` | `float` | global | Maximum 1/z across all emitted edges; used for mipmap selection |
| `r_u1`, `r_v1`, `r_lzi1`, `r_ceilv1` | float/int | global | Cached projected endpoint from the last vertex (for shared-vertex optimization) |
| `r_lastvertvalid` | `qboolean` | global | Whether cached last-vertex values are reusable |
| `r_skyframe` | `int` | global | Frame number when skybox was last emitted; guards against re-emission |
| `r_skyfaces[6]`, `r_skyplanes[6]`, `r_skytexinfo[6]` | arrays | global | Skybox face/plane/texinfo data |
| `r_skyverts`, `r_skyedges`, `r_skysurfedges` | pointers | global | Pointers into `loadmodel` arrays for skybox geometry |

## Key Functions

### R_InitSkyBox
- **Signature:** `void R_InitSkyBox(void)`
- **Purpose:** Appends 6 faces, 8 vertices, 12 edges, and 24 surfedges for a unit skybox cube into `loadmodel`, then initializes planes, texinfos, and edge indices.
- **Inputs:** None (reads `loadmodel` extern)
- **Outputs/Return:** void; modifies `loadmodel->numsurfaces` etc. in-place
- **Side effects:** Extends `loadmodel` arrays; calls `ri.Sys_Error` on overflow
- **Calls:** `ri.Sys_Error`, `VectorCopy`, `memset`
- **Notes:** Must be called once during world load. Uses hardcoded `skybox_planes`, `box_vecs`, `box_verts`, `box_edges`, `box_surfedges` tables.

### R_EmitSkyBox
- **Signature:** `void R_EmitSkyBox(void)`
- **Purpose:** Repositions skybox geometry around `r_origin` and emits all 6 sky faces into the edge renderer for the current frame.
- **Inputs:** None (reads `r_origin`, `r_framecount`)
- **Outputs/Return:** void
- **Side effects:** Updates `r_skyverts`, `r_skyplanes`, `r_skytexinfo` positions; calls `R_RenderFace` 6×; temporarily overrides `r_currentkey`
- **Calls:** `R_RenderFace`, `DotProduct`
- **Notes:** Guarded by `r_skyframe == r_framecount` to emit once per frame. Skipped in submodels.

### R_EmitEdge *(non-x86 only)*
- **Signature:** `void R_EmitEdge(mvertex_t *pv0, mvertex_t *pv1)`
- **Purpose:** Projects both endpoints to screen space (1/z, u, v), constructs an `edge_t`, and inserts it into the `newedges`/`removeedges` scanline lists.
- **Inputs:** World-space vertices `pv0`, `pv1`
- **Outputs/Return:** void; appends to `edge_p`, inserts into `newedges[v]`, `removeedges[v2]`
- **Side effects:** Advances `edge_p`; updates `r_nearzi`, `r_emitted`, `r_u1/v1/lzi1/ceilv1`; may write `FULLY_CLIPPED_CACHED` to `cacheoffset` for horizontal edges
- **Calls:** `VectorSubtract`, `TransformVector`, `ceil`
- **Notes:** Reuses cached last-vertex via `r_lastvertvalid`. Horizontal edges (same scanline) are cached as fully clipped and discarded. Fixed-point `u` uses `0x100000` scale.

### R_ClipEdge *(non-x86 only)*
- **Signature:** `void R_ClipEdge(mvertex_t *pv0, mvertex_t *pv1, clipplane_t *clip)`
- **Purpose:** Recursively clips edge `(pv0,pv1)` against a linked list of frustum planes, then calls `R_EmitEdge` on the surviving segment.
- **Inputs:** `pv0`, `pv1` — edge endpoints; `clip` — head of clip plane chain (NULL = emit)
- **Outputs/Return:** void
- **Side effects:** May set `r_leftclipped`/`r_rightclipped` and write enter/exit clip vertices; sets `cacheoffset = 0x7FFFFFFF` on partial clips
- **Calls:** `DotProduct`, `R_EmitEdge`, self (recursive)
- **Notes:** Fully clipped edges write `FULLY_CLIPPED_CACHED` if not already left-clipped. The `continue` in the `do...while` loop relies on `clip = clip->next` in the condition.

### R_EmitCachedEdge
- **Signature:** `void R_EmitCachedEdge(void)`
- **Purpose:** Reuses an already-emitted `edge_t` for a new surface by patching its `surfs[]` slot.
- **Inputs:** `r_pedge->cachededgeoffset` (implicit global)
- **Outputs/Return:** void
- **Side effects:** Writes `surface_p - surfaces` into the cached edge's free `surfs[]` slot; updates `r_nearzi`; sets `r_emitted = 1`

### R_RenderFace
- **Signature:** `void R_RenderFace(msurface_t *fa, int clipflags)`
- **Purpose:** Main entry point to rasterize a world BSP face: builds clip plane chain, iterates surfedges clipping/emitting each, posts the surface descriptor with 1/z gradient.
- **Inputs:** `fa` — surface; `clipflags` — bitmask of active frustum planes (bits 0–3)
- **Outputs/Return:** void; advances `surface_p`
- **Side effects:** Increments `r_polycount`; defers translucent surfaces to `r_alpha_surfaces`; triggers `R_EmitSkyBox` for sky surfaces; increments `r_outofsurfaces`/`r_outofedges` on overflow
- **Calls:** `R_ClipEdge`, `R_EmitCachedEdge`, `R_EmitSkyBox`, `TransformVector`, `DotProduct`
- **Notes:** Uses per-frame edge caching keyed by `cachededgeoffset`; handles reversed edges (negative `lindex`) by swapping `v[0]`/`v[1]`.

### R_RenderBmodelFace
- **Signature:** `void R_RenderBmodelFace(bedge_t *pedges, msurface_t *psurf)`
- **Purpose:** Variant of `R_RenderFace` for inline brush models; iterates a `bedge_t` linked list instead of surfedges; always marks `insubmodel = true`.
- **Inputs:** `pedges` — linked edge list; `psurf` — surface descriptor
- **Outputs/Return:** void; advances `surface_p`
- **Side effects:** Same as `R_RenderFace` minus sky handling and edge caching (disabled for submodels)
- **Calls:** `R_ClipEdge`, `TransformVector`, `DotProduct`

## Control Flow Notes
This file sits between the BSP traversal (`r_bsp.c`) and the span generator (`r_edge.c` / `r_scan.c`). During the render frame, `R_RenderFace` / `R_RenderBmodelFace` are called for each visible BSP face. They feed projected, clipped edges into the global `newedges[]`/`removeedges[]` scanline tables that the span generator sweeps top-to-bottom. The 1/z plane equation stored on each `surf_t` is used during span generation for perspective-correct texturing.

## External Dependencies
- **Includes:** `r_local.h` (all shared renderer types, globals, macros), `<assert.h>`
- **Defined elsewhere:** `r_edges`, `edge_p`, `edge_max`, `newedges[]`, `removeedges[]`, `surface_p`, `surfaces`, `surf_max`, `r_framecount`, `r_currentkey`, `r_currentbkey`, `r_clipflags`, `r_alpha_surfaces`, `r_polycount`, `r_outofsurfaces`, `r_outofedges`, `insubmodel`, `currententity`, `currentmodel`, `r_pcurrentvertbase`, `modelorg`, `r_origin`, `r_refdef`, `xscale`, `yscale`, `xscaleinv`, `yscaleinv`, `xcenter`, `ycenter`, `loadmodel`, `TransformVector`, `R_RenderFace` (called from sky code above the `#if !id386` block, so the prototype is always available)
