# ref_gl/gl_rsurf.c

## File Purpose
Implements surface-level rendering for the OpenGL renderer, covering BSP world traversal, brush model drawing, lightmap allocation/upload, and alpha/translucent surface handling. It manages both single-texture and multitexture (SGIS) paths for lightmapped world geometry.

## Core Responsibilities
- Traverse the BSP tree recursively to determine visible surfaces each frame
- Render opaque brush model and world surfaces with or without multitexture
- Manage lightmap atlas allocation, building, and dynamic updates
- Queue and draw translucent/alpha surfaces in back-to-front order
- Handle texture animation and scrolling (flowing) surfaces
- Mark visible leaves/nodes via PVS (Potentially Visible Set)
- Build GL polygon geometry from BSP surface edge data at load time

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `gllightmapstate_t` | struct | Tracks current lightmap atlas state: format, active texture index, per-lightmap surface chains, column allocation, and the CPU-side lightmap buffer |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `modelorg` | `vec3_t` | static | View origin relative to the model being rendered; used for BSP plane side tests |
| `r_alpha_surfaces` | `msurface_t *` | global | Linked list (via `texturechain`) of translucent surfaces to draw last, back-to-front |
| `gl_lms` | `gllightmapstate_t` | static | Singleton lightmap atlas state for the current frame/build pass |
| `c_visible_lightmaps` | `int` | global | Per-frame counter of active lightmap textures (perf stat) |
| `c_visible_textures` | `int` | global | Per-frame counter of visible unique textures (perf stat) |

## Key Functions

### R_TextureAnimation
- Signature: `image_t *R_TextureAnimation(mtexinfo_t *tex)`
- Purpose: Resolves animated texture to the correct frame image based on `currententity->frame`.
- Inputs: Base texture info pointer.
- Outputs/Return: Pointer to the active `image_t` for the current frame.
- Side effects: None.
- Calls: None directly.
- Notes: Walks the `tex->next` chain `frame % numframes` steps.

### R_RecursiveWorldNode
- Signature: `void R_RecursiveWorldNode(mnode_t *node)`
- Purpose: Front-to-back BSP traversal; marks leaf surfaces visible and dispatches opaque/translucent/sky surfaces to appropriate render chains.
- Inputs: BSP node pointer.
- Outputs/Return: None.
- Side effects: Sets `surf->visframe`; appends to `r_alpha_surfaces` and `image->texturechain`; calls `GL_RenderLightmappedPoly` directly for SGIS multitexture path.
- Calls: `R_CullBox`, `R_AddSkySurface`, `GL_RenderLightmappedPoly`, `R_TextureAnimation`.
- Notes: Skips nodes where `visframe != r_visframecount`; area portal visibility tested at leaf nodes.

### R_MarkLeaves
- Signature: `void R_MarkLeaves(void)`
- Purpose: Updates `visframe` on all leaves and their ancestor nodes visible from the current cluster via PVS. Supports combining two clusters for solid-water boundaries.
- Inputs: None (reads `r_viewcluster`, `r_viewcluster2` globals).
- Outputs/Return: None.
- Side effects: Increments `r_visframecount`; updates `node->visframe` on visible nodes/leaves; updates `r_oldviewcluster`.
- Calls: `Mod_ClusterPVS`.

### R_DrawWorld
- Signature: `void R_DrawWorld(void)`
- Purpose: Top-level world render entry point. Configures multitexture state, runs `R_RecursiveWorldNode`, then finalizes texture chains, lightmaps, sky, and debug outlines.
- Inputs: None.
- Outputs/Return: None.
- Side effects: Resets `gl_lms.lightmap_surfaces`; calls `R_ClearSkyBox`/`R_DrawSkyBox`; calls `DrawTextureChains`, `R_BlendLightmaps`, `R_DrawTriangleOutlines`.
- Calls: `R_RecursiveWorldNode`, `DrawTextureChains`, `R_BlendLightmaps`, `R_DrawSkyBox`, `R_ClearSkyBox`, `R_DrawTriangleOutlines`.

### R_DrawBrushModel
- Signature: `void R_DrawBrushModel(entity_t *e)`
- Purpose: Renders a non-world inline brush model entity with correct transform, culling, and dynamic light marking.
- Inputs: Entity pointer with origin/angles.
- Outputs/Return: None.
- Side effects: Modifies `currententity`, `currentmodel`, `modelorg`; pushes/pops GL matrix; applies angle negation workaround for Quake pitch/roll bug.
- Calls: `R_CullBox`, `R_RotateForEntity`, `R_DrawInlineBModel`, `GL_EnableMultitexture`.

### R_BlendLightmaps
- Signature: `void R_BlendLightmaps(void)`
- Purpose: Second-pass lightmap blending for the non-multitexture path. Renders static lightmaps, then dynamically rebuilds and uploads changed lightmap regions.
- Inputs: None.
- Outputs/Return: None.
- Side effects: Uploads lightmap textures via `qglTexSubImage2D`; calls `LM_UploadBlock`/`LM_InitBlock`; disables depth write during blend.
- Calls: `GL_Bind`, `DrawGLPolyChain`, `LM_InitBlock`, `LM_UploadBlock`, `LM_AllocBlock`, `R_BuildLightMap`.

### GL_RenderLightmappedPoly
- Signature: `static void GL_RenderLightmappedPoly(msurface_t *surf)`
- Purpose: Renders a single surface using SGIS multitexture (diffuse + lightmap in one pass). Handles dynamic lightmap updates inline.
- Inputs: Surface pointer.
- Outputs/Return: None.
- Side effects: May call `qglTexSubImage2D` to update lightmap; increments `c_brush_polys`.
- Calls: `R_TextureAnimation`, `R_BuildLightMap`, `R_SetCacheState`, `GL_MBind`.

### GL_BuildPolygonFromSurface
- Signature: `void GL_BuildPolygonFromSurface(msurface_t *fa)`
- Purpose: Constructs a `glpoly_t` from BSP edge/vertex data, computing both diffuse and lightmap UV coordinates. Called at map load time.
- Inputs: Surface pointer; reads `currentmodel` edge/vertex arrays.
- Outputs/Return: None (attaches poly to `fa->polys`).
- Side effects: `Hunk_Alloc` for poly memory.
- Calls: `Hunk_Alloc`, `DotProduct`, `VectorAdd`, `VectorCopy`.

### GL_CreateSurfaceLightmap / GL_BeginBuildingLightmaps / GL_EndBuildingLightmaps
- Load-time lightmap construction sequence: `Begin` initializes atlas state and allocates texture slots; `CreateSurface` packs each surface into the atlas; `End` uploads the final block.

## Control Flow Notes
- **Init**: `GL_BeginBuildingLightmaps` → `GL_CreateSurfaceLightmap` (per surface) → `GL_BuildPolygonFromSurface` → `GL_EndBuildingLightmaps`.
- **Frame**: `R_MarkLeaves` updates PVS → `R_DrawWorld` traverses BSP → surfaces dispatched to chains or rendered directly → `R_BlendLightmaps` (single-texture path) → `R_DrawAlphaSurfaces` (called externally) handles translucents last.

## External Dependencies
- Notable includes: `gl_local.h` (pulls in all GL types, cvars, model structs)
- External symbols used but not defined here: `R_BuildLightMap`, `R_SetCacheState` (defined in `gl_light.c`); `EmitWaterPolys`, `R_DrawSkyBox`, `R_ClearSkyBox`, `R_AddSkySurface` (warp/sky modules); `R_MarkLights` (dynamic light marking); `Mod_ClusterPVS` (model/vis module); `GL_Bind`, `GL_MBind`, `GL_EnableMultitexture`, `GL_TexEnv`, `GL_SelectTexture` (`gl_image`/`gl_rmain`); `qgl*` function pointers (GL dispatch layer); `r_worldmodel`, `r_framecount`, `r_visframecount`, `r_viewcluster`, `currententity`, `currentmodel`, `gl_state`, `r_newrefdef` (renderer globals).
