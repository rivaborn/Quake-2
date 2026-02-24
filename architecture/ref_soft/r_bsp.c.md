# ref_soft/r_bsp.c

## File Purpose
Implements BSP tree traversal for the software renderer, handling both world geometry rendering and submodel (bmodel) polygon clipping. It walks the BSP tree to determine visible surfaces, backface-culls polygons, and clips bmodel polygons against BSP node planes before submission to the rasterizer.

## Core Responsibilities
- Traverse the world BSP tree recursively, frustum-culling nodes and marking visible surfaces
- Render world surfaces in front-to-back order using per-leaf render keys
- Compute rotation matrices from entity Euler angles for submodel transforms
- Transform and clip bmodel polygons against BSP planes (`R_RecursiveClipBPoly`)
- Dispatch clipped bmodel faces to `R_RenderBmodelFace` or `R_RenderFace`
- Maintain `r_currentkey`/`r_currentbkey` for painter's-algorithm ordering

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `solidstate_t` | enum | `touchessolid`, `drawnode`, `nodrawnode` — declared but not used in this file |
| `bedge_t` | struct (external) | Clipped bmodel edge: two vertex pointers + linked-list `pnext` |
| `mvertex_t` | struct (external) | Single 3D vertex with `position` field |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `insubmodel` | `qboolean` | global | Flags whether currently rendering a submodel |
| `currententity` | `entity_t *` | global | Entity being rendered this pass |
| `modelorg` | `vec3_t` | global | Viewpoint relative to current entity's model space |
| `r_entorigin` | `vec3_t` | global | Current entity origin in world coordinates |
| `entity_rotation` | `float[3][3]` | global | Rotation matrix built from entity Euler angles |
| `r_currentbkey` | `int` | global | Render-order key for bmodel surfaces |
| `pbverts` | `mvertex_t *` | static | Scratch vertex pool for bmodel clipping |
| `pbedges` | `bedge_t *` | static | Scratch edge pool for bmodel clipping |
| `numbverts`, `numbedges` | `int` | static | Counts into scratch pools |
| `pfrontenter`, `pfrontexit` | `mvertex_t *` | static | Entry/exit vertices at a BSP clip plane crossing |
| `makeclippededge` | `qboolean` | static | Set when a clip-plane closing edge must be generated |
| `c_drawnode` | `int` | global | Debug counter: nodes visited during world traversal |

## Key Functions

### R_EntityRotate
- **Signature:** `void R_EntityRotate(vec3_t vec)`
- **Purpose:** Transforms a vector into entity-local space using `entity_rotation`.
- **Inputs:** `vec` — vector to rotate in-place.
- **Outputs/Return:** Modifies `vec` in-place.
- **Side effects:** None beyond modifying the argument.
- **Calls:** `VectorCopy`, `DotProduct`

### R_RotateBmodel
- **Signature:** `void R_RotateBmodel(void)`
- **Purpose:** Builds `entity_rotation` from `currententity->angles` (yaw/pitch/roll), then rotates `modelorg`, `vpn`, `vright`, `vup`, and recalculates the frustum into entity space.
- **Inputs:** `currententity->angles`, global view vectors.
- **Outputs/Return:** Updates `entity_rotation`, `modelorg`, view vectors.
- **Side effects:** Calls `R_TransformFrustum`, modifying frustum planes.
- **Calls:** `R_ConcatRotations`, `R_EntityRotate`, `R_TransformFrustum`
- **Notes:** Uses three explicit sin/cos evaluations; TODO comments note potential for LUT caching.

### R_RecursiveClipBPoly
- **Signature:** `void R_RecursiveClipBPoly(bedge_t *pedges, mnode_t *pnode, msurface_t *psurf)`
- **Purpose:** Clips a bmodel polygon's edge list against one BSP node plane, partitions edges to front/back, then recurses or renders at leaves. Respects PVS (`visframe`) and area bits.
- **Inputs:** Edge list, current BSP node, surface to render.
- **Outputs/Return:** Void; triggers `R_RenderBmodelFace` at visible leaves.
- **Side effects:** Allocates into `pbverts`/`pbedges` scratch pools; sets `r_currentbkey`.
- **Calls:** `DotProduct`, `ri.Con_Printf`, `R_RenderBmodelFace`, self (recursive)
- **Notes:** Returns early on pool overflow. Closing edge on the clip plane is added in both winding directions for front and back lists.

### R_DrawSolidClippedSubmodelPolygons
- **Signature:** `void R_DrawSolidClippedSubmodelPolygons(model_t *pmodel, mnode_t *topnode)`
- **Purpose:** For bmodels spanning multiple leaves: backface-culls each surface, builds a `bedge_t` ring from the surface's `medge_t` list, then calls `R_RecursiveClipBPoly`. Transparent surfaces bypass clipping and go directly to `R_RenderBmodelFace`.
- **Inputs:** Model pointer, BSP topnode to clip against.
- **Side effects:** Uses file-static scratch buffers; reads `r_pcurrentvertbase`.
- **Calls:** `DotProduct`, `R_RecursiveClipBPoly`, `R_RenderBmodelFace`

### R_DrawSubmodelPolygons
- **Signature:** `void R_DrawSubmodelPolygons(model_t *pmodel, int clipflags, mnode_t *topnode)`
- **Purpose:** For bmodels entirely within one leaf: backface-culls and directly renders each surface via `R_RenderFace`.
- **Calls:** `DotProduct`, `R_RenderFace`

### R_RecursiveWorldNode
- **Signature:** `void R_RecursiveWorldNode(mnode_t *node, int clipflags)`
- **Purpose:** Core world BSP traversal. Frustum-culls nodes using accept/reject point pairs, marks surfaces as visible at leaves, and renders front-facing surfaces at interior nodes in front-to-back order. Increments `r_currentkey` per node for sorting.
- **Inputs:** BSP node, bitmask of active frustum planes.
- **Side effects:** Writes `surf->visframe`, `pleaf->key`; increments `r_currentkey`, `c_drawnode`; calls `R_RenderFace`.
- **Calls:** `DotProduct`, `R_RenderFace`, self (recursive)
- **Notes:** Axis-aligned plane types (`PLANE_X/Y/Z`) are fast-pathed. Area-bit visibility check gates leaf processing.

### R_RenderWorld
- **Signature:** `void R_RenderWorld(void)`
- **Purpose:** Entry point for world rendering. Resets `c_drawnode`, sets `currententity` to the world entity, syncs `modelorg` and `currentmodel`, then invokes `R_RecursiveWorldNode` with all four frustum planes active.
- **Calls:** `VectorCopy`, `R_RecursiveWorldNode`

## Control Flow Notes
- **Per-frame:** `R_RenderWorld` is called once per frame to traverse and render world geometry. Submodel rendering occurs separately, calling `R_RotateBmodel` followed by `R_DrawSolidClippedSubmodelPolygons` or `R_DrawSubmodelPolygons` depending on whether the model spans multiple leaves.
- World traversal feeds `r_currentkey` increments used downstream for surface sorting in the edge/span pipeline.

## External Dependencies
- **Includes:** `r_local.h` (brings in all soft-renderer types and globals)
- **Defined elsewhere:** `R_RenderFace`, `R_RenderBmodelFace`, `R_ConcatRotations`, `R_TransformFrustum`, `r_visframecount`, `r_framecount`, `r_currentkey`, `r_worldmodel`, `r_worldentity`, `r_origin`, `r_pcurrentvertbase`, `r_newrefdef`, `view_clipplanes`, `pfrustum_indexes`, `vpn`, `vright`, `vup`, `currentmodel`, `ri`
