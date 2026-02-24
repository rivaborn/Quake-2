# ref_soft/r_alias.c

## File Purpose
Implements alias (MD2) model rendering for the software rasterizer. Handles model transformation, bounding box culling, frame interpolation (lerping), lighting setup, skin binding, and per-vertex projection before dispatching triangles to the software span-fill rasterizer.

## Core Responsibilities
- Frustum/clip-plane bounding box rejection testing for alias models
- World-to-view transform matrix construction for each entity
- Frame interpolation: computing lerp coefficients and blending old/new frame vertices
- Per-vertex lighting calculation using precomputed vertex normals
- Skin setup and texture coordinate preparation
- Power suit shell effect vertex displacement
- Triangle dispatch to clipped or unclipped software rasterizer paths
- Left-hand weapon model mirroring (negated X scale)

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `aedge_t` | struct | Index pair defining one edge of a bounding box (12 edges total) |
| `aliasbatchedtransformdata_t` | struct | Batches vertex pointers (old frame, new frame, destination) for `R_AliasTransformFinalVerts` |
| `affinetridesc_t` | typedef (extern) | Skin pointer, dimensions passed to the span rasterizer |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `r_amodels_drawn` | `int` | global | Counter of alias models rendered this frame |
| `r_affinetridesc` | `affinetridesc_t` | global | Skin descriptor passed to the polygon rasterizer |
| `r_plightvec` | `vec3_t` | global | Light direction rotated into model-local space |
| `r_lerped` | `vec3_t[1024]` | global | Lerped vertex positions (declared but not used in this file) |
| `r_lerp_frontv`, `r_lerp_backv`, `r_lerp_move` | `vec3_t` | global | Lerp scale and translation vectors used in `R_AliasTransformFinalVerts` |
| `r_ambientlight` | `int` | global | Scaled ambient light level for per-vertex lighting |
| `r_shadelight` | `float` | global | Shade light intensity for per-vertex lighting |
| `r_aliasblendcolor` | `int` | global | Shell color index for constant-color span drawing |
| `r_thisframe`, `r_lastframe` | `daliasframe_t *` | global | Pointers into MD2 data for current and previous frames |
| `s_pmdl` | `dmdl_t *` | global | Pointer to the current MD2 model header |
| `aliastransform` | `float[3][4]` | global | Combined world→view transform used per-vertex |
| `aliasworldtransform`, `aliasoldworldtransform` | `float[3][4]` | global | Per-entity world transforms for bbox testing |
| `s_ziscale` | `float` | static | Z inverse scale; increased for `RF_DEPTHHACK` (weapon depth hack) |
| `s_alias_forward/right/up` | `vec3_t` | static | Entity orientation vectors, set in `R_AliasSetUpTransform` |
| `r_avertexnormals` | `float[162][3]` | global | Quake normal table (162 precomputed normals from `anorms.h`) |
| `aliasbatchedtransformdata` | `aliasbatchedtransformdata_t` | global | Scratch batch struct for vertex transform dispatch |

## Key Functions

### R_AliasCheckFrameBBox
- **Signature:** `unsigned long R_AliasCheckFrameBBox(daliasframe_t *frame, float worldxf[3][4])`
- **Purpose:** Clips a single frame's axis-aligned bounding box against the view frustum.
- **Inputs:** Frame data (scale/translate), world transform matrix.
- **Outputs/Return:** Clip code: `BBOX_TRIVIAL_ACCEPT`, `BBOX_TRIVIAL_REJECT`, `BBOX_MUST_CLIP_XY`, `BBOX_MUST_CLIP_Z`.
- **Side effects:** None.
- **Calls:** `R_AliasTransformVector`, `DotProduct`.
- **Notes:** Tests all 8 corners against 4 `view_clipplanes`; aggregate AND/OR clipping logic.

### R_AliasCheckBBox
- **Signature:** `qboolean R_AliasCheckBBox(void)`
- **Purpose:** Checks visibility of the current entity using both frames (for lerping).
- **Inputs:** Implicit — `currententity`, `r_thisframe`, `r_lastframe`, transform matrices.
- **Outputs/Return:** Composite clip code.
- **Calls:** `R_AliasCheckFrameBBox`.
- **Notes:** For non-lerping entities, only tests the current frame.

### R_AliasSetUpTransform
- **Signature:** `void R_AliasSetUpTransform(void)`
- **Purpose:** Builds `aliastransform` (view-space), `aliasworldtransform`, and `aliasoldworldtransform` from entity angles and origin.
- **Side effects:** Writes global transform matrices; reads `currententity`, `vright/vup/vpn`, `r_origin`.
- **Calls:** `AngleVectors`, `VectorCopy`, `VectorInverse`, `R_ConcatTransforms`.
- **Notes:** Contains a known bug — column assignment loop overwrites `[i][0]` three times instead of `[i][0..2]`.

### R_AliasTransformFinalVerts
- **Signature:** `void R_AliasTransformFinalVerts(int numpoints, finalvert_t *fv, dtrivertx_t *oldv, dtrivertx_t *newv)`
- **Purpose:** Per-vertex lerp, power suit displacement, transform to view space, lighting, projection, and clip-flag assignment.
- **Side effects:** Writes `finalvert_t` output array.
- **Calls:** `R_AliasProjectAndClipTestFinalVert` (C path); inline x87 FPU asm (i386 path).
- **Notes:** Dual implementation: `#if id386` uses hand-written x87 inline assembly for performance; `#else` uses portable C.

### R_AliasPreparePoints
- **Signature:** `void R_AliasPreparePoints(void)`
- **Purpose:** Allocates cache-aligned `finalvert_t` stack buffer, transforms all vertices, then iterates triangles dispatching to `R_DrawTriangle` or `R_AliasClipTriangle`.
- **Side effects:** Sets `iractive` global; reads model ST/triangle arrays.
- **Calls:** `R_AliasTransformFinalVerts`, `R_DrawTriangle`, `R_AliasClipTriangle`.
- **Notes:** Left-hand weapon reverses vertex winding order (pfv[2],pfv[1],pfv[0]).

### R_AliasSetupLighting
- **Signature:** `void R_AliasSetupLighting(void)`
- **Purpose:** Samples world light at entity origin, applies entity flags (fullbright, minlight, glow), clamps, and rotates light vector into model space.
- **Side effects:** Sets `r_ambientlight`, `r_shadelight`, `r_plightvec`; writes `r_lightlevel->value` for weapon models.
- **Calls:** `R_LightPoint`, `DotProduct`, `sin`.

### R_AliasDrawModel
- **Signature:** `void R_AliasDrawModel(void)`
- **Purpose:** Top-level entry point — orchestrates the full alias model render pipeline for `currententity`.
- **Side effects:** Increments `r_amodels_drawn`; sets `d_pdrawspans` function pointer; flips `aliasxscale` sign for left-hand weapons.
- **Calls:** `R_AliasSetupFrames`, `R_AliasSetUpTransform`, `R_AliasCheckBBox`, `R_AliasSetupSkin`, `R_AliasSetupLighting`, `R_AliasSetUpLerpData`, `R_AliasPreparePoints`.

### Notes (trivial helpers)
- `R_AliasTransformVector`: 3×4 matrix-vector multiply, used for bbox corner transforms.
- `R_AliasProjectAndClipTestFinalVert`: Perspective divide + 2D clip flag set for a single vertex.
- `R_AliasSetupSkin`: Resolves skin image, sets `r_affinetridesc` fields, calls `R_PolysetUpdateTables`.
- `R_AliasSetupFrames`: Validates and resolves `currententity->frame`/`oldframe` into `r_thisframe`/`r_lastframe`.
- `R_AliasSetUpLerpData`: Computes `r_lerp_move`, `r_lerp_frontv`, `r_lerp_backv` from entity origins and frame scale/translate.

## Control Flow Notes
Called from the software renderer's entity draw path per frame. `R_AliasDrawModel` is the sole external entry point. Flow: setup frames → build transforms → bbox cull → setup skin → setup lighting → setup lerp → transform+project all verts → rasterize triangles. Shutdown is implicit (no persistent allocations; all buffers are stack or pre-existing globals).

## External Dependencies
- **Includes:** `r_local.h` (all soft-renderer types and globals)
- **Defined elsewhere:** `currententity`, `currentmodel`, `r_origin`, `vright`, `vup`, `vpn`, `view_clipplanes`, `r_refdef`, `aliasxscale`, `aliasyscale`, `aliasxcenter`, `aliasycenter`, `r_newrefdef`, `r_lefthand`, `r_lerpmodels`, `r_lightlevel`, `d_pdrawspans`, `aliastriangleparms`
- **Calls external:** `R_LightPoint`, `R_ConcatTransforms`, `AngleVectors`, `R_DrawTriangle`, `R_AliasClipTriangle`, `R_PolysetUpdateTables`, `R_PolysetDrawSpans8_*`, `ri.Con_Printf`
