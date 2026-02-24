# ref_gl/gl_mesh.c

## File Purpose
Renders MD2 alias (triangle) models in the OpenGL renderer. Handles per-frame vertex interpolation, lighting/shading setup, frustum culling, and optional planar shadow projection for all non-BSP entities.

## Core Responsibilities
- Interpolate vertex positions between two animation frames (`GL_LerpVerts`)
- Cull alias models against the view frustum using an OBB derived from frame bounds (`R_CullAliasModel`)
- Compute and apply per-entity shading color for all shell/effect flags, fullbright, glow, IR goggles, and monochrome modes
- Draw interpolated geometry via GL commands list, with optional vertex array fast path (`GL_DrawAliasFrameLerp`)
- Render a flattened ground shadow blob (`GL_DrawAliasShadow`)
- Handle left-hand weapon mirroring via projection matrix flip

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `vec4_t` | typedef | `float[4]`; padded vertex for SIMD-aligned vertex array upload |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `r_avertexnormals` | `float[162][3]` | global | Precalculated unit normals for MD2 quantized normal indices |
| `s_lerped` | `vec4_t[MAX_VERTS]` | static | Interpolated vertex positions written by `GL_LerpVerts`, read by draw calls |
| `shadevector` | `vec3_t` | global | Direction used to project planar shadows onto the floor |
| `shadelight` | `float[3]` | global | RGB light color applied to the current entity |
| `r_avertexnormal_dots` | `float[16][256]` | global | Precomputed dot products of normals vs. 16 quantized yaw angles |
| `shadedots` | `float *` | global | Points into `r_avertexnormal_dots` row for current entity's yaw |

## Key Functions

### GL_LerpVerts
- **Signature:** `void GL_LerpVerts(int nverts, dtrivertx_t *v, dtrivertx_t *ov, dtrivertx_t *verts, float *lerp, float move[3], float frontv[3], float backv[3])`
- **Purpose:** Linearly interpolates all vertices between current and old frame, storing results into `s_lerped`. For shell-flagged entities, adds a normal-offset (`POWERSUIT_SCALE`) to inflate the mesh outward.
- **Inputs:** Vertex counts, current/old frame vertex arrays, interpolation scale vectors `frontv`/`backv`, translation `move`
- **Outputs/Return:** Writes directly into `lerp` (aliased to `s_lerped`)
- **Side effects:** Populates `s_lerped` global buffer
- **Calls:** Reads `r_avertexnormals`, reads `currententity->flags`
- **Notes:** Shell path and non-shell path are branched at the top to avoid per-vertex flag checks

### GL_DrawAliasFrameLerp
- **Signature:** `void GL_DrawAliasFrameLerp(dmdl_t *paliashdr, float backlerp)`
- **Purpose:** Core draw call. Computes interpolation vectors, calls `GL_LerpVerts`, then emits GL geometry using the model's pre-baked GL commands list (triangle strips/fans). Supports a vertex array fast path via `gl_vertex_arrays` cvar and `qglLockArraysEXT`.
- **Inputs:** MD2 header pointer, `backlerp` blend factor toward old frame
- **Outputs/Return:** void
- **Side effects:** Issues OpenGL draw calls; temporarily disables `GL_TEXTURE_2D` for shell entities
- **Calls:** `GL_LerpVerts`, `AngleVectors`, `VectorSubtract`, `VectorAdd`, `DotProduct`, `qglBegin/End`, `qglVertex3fv`, `qglTexCoord2f`, `qglColor4f`, `qglArrayElement`, `qglLockArraysEXT`, `qglUnlockArraysEXT`
- **Notes:** Non-vertex-array path does not support `RF_SHELL_DOUBLE`/`RF_SHELL_HALF_DAM` color (uses only RGB shell flags); vertex array path does

### GL_DrawAliasShadow
- **Signature:** `void GL_DrawAliasShadow(dmdl_t *paliashdr, int posenum)`
- **Purpose:** Projects the current frame's already-lerped verts onto the ground plane to draw a flat shadow blob.
- **Inputs:** MD2 header, frame index (unused; uses `s_lerped` directly via `lightspot` height)
- **Outputs/Return:** void
- **Side effects:** OpenGL draw calls; reads `lightspot` (extern), reads `s_lerped`
- **Calls:** `qglBegin/End`, `qglVertex3fv`, `memcpy`
- **Notes:** `posenum` parameter is effectively unused; shadow is derived from already-computed `s_lerped`

### R_CullAliasModel
- **Signature:** `static qboolean R_CullAliasModel(vec3_t bbox[8], entity_t *e)`
- **Purpose:** Builds a rotated OBB from the union of current and old frame AABB, then tests all 8 corners against the 4 frustum planes. Returns `true` if entirely outside.
- **Inputs:** Output bbox array (8 corners), entity pointer
- **Outputs/Return:** `qboolean`; writes world-space OBB corners into `bbox`
- **Side effects:** Clamps out-of-range `e->frame`/`e->oldframe` to 0 with a console warning
- **Calls:** `AngleVectors`, `DotProduct`, `VectorCopy`, `VectorAdd`, `ri.Con_Printf`
- **Notes:** Yaw sign is negated before `AngleVectors` to match Quake's coordinate convention

### R_DrawAliasModel
- **Signature:** `void R_DrawAliasModel(entity_t *e)`
- **Purpose:** Top-level alias model entry point. Culls, computes shading, sets GL state, selects skin, dispatches `GL_DrawAliasFrameLerp`, and optionally draws a shadow.
- **Inputs:** Entity to render
- **Outputs/Return:** void
- **Side effects:** Modifies `shadelight`, `shadedots`, `shadevector`, `c_alias_polys`; pushes/pops GL matrix; may modify `r_lightlevel->value` for weapon model lighting feedback to server
- **Calls:** `R_CullAliasModel`, `R_LightPoint`, `VectorNormalize`, `R_RotateForEntity`, `GL_Bind`, `GL_TexEnv`, `GL_DrawAliasFrameLerp`, `GL_DrawAliasShadow`, `MYgluPerspective`, `qglDepthRange`, `qglCullFace`, various `qgl*`

## Control Flow Notes
Called once per entity during the entity rendering pass (`R_DrawEntitiesOnList` in `gl_rmain.c`). Executes entirely within a single frame's render loop. `s_lerped` is a scratch buffer valid only for the duration of one entity's draw call.

## External Dependencies
- **Includes:** `gl_local.h` (pulls in all GL types, cvars, entity/model globals)
- **Includes (data):** `anorms.h`, `anormtab.h`
- **Defined elsewhere:** `currententity`, `currentmodel`, `r_newrefdef`, `frustum`, `lightspot`, `c_alias_polys`, `gldepthmin/max`, `r_lefthand`, `gl_shadows`, `gl_vertex_arrays`, `r_lerpmodels`, `gl_monolightmap`, `r_lightlevel`, `R_LightPoint`, `R_RotateForEntity`, `GL_Bind`, `GL_TexEnv`, `MYgluPerspective`, `qglLockArraysEXT`, `qglUnlockArraysEXT`
