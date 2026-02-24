# ref_gl/gl_warp.c

## File Purpose
Implements sky box rendering and water/turbulent surface warping for the OpenGL renderer. It handles subdivision of warp surfaces at load time and per-frame animated rendering of water polygons and the six-sided sky box.

## Core Responsibilities
- Subdivide warp surfaces (water, lava, slime, sky) into 64-unit grid polygons at model load time
- Render water/turbulent polygons with animated sinusoidal UV distortion each frame
- Clip sky polygons against six frustum planes and accumulate per-face UV extents
- Draw the six-sided sky box using accumulated min/max UV extents with optional rotation
- Load and bind sky cube-face textures from `env/` directory (TGA or PCX)

## Key Types / Data Structures
None (uses types from `gl_local.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `skyname` | `char[MAX_QPATH]` | global | Current sky set name |
| `skyrotate` | `float` | global | Sky rotation speed (degrees/sec) |
| `skyaxis` | `vec3_t` | global | Axis of sky rotation |
| `sky_images[6]` | `image_t*[6]` | global | Loaded textures for six sky faces |
| `warpface` | `msurface_t*` | global | Current surface being subdivided (used as implicit parameter) |
| `r_turbsin[]` | `float[]` | global | 256-entry sin LUT included from `warpsin.h` |
| `skymins[2][6]`, `skymaxs[2][6]` | `float` | global | Per-face UV extent accumulators for sky box |
| `sky_min`, `sky_max` | `float` | global | UV clamp values to avoid bilinear seam |
| `c_sky` | `int` | global | Sky polygon counter (stat/debug) |
| `skyclip[6]` | `vec3_t[6]` | global | Clip plane normals for sky polygon clipping |
| `st_to_vec[6][3]`, `vec_to_st[6][3]` | `int` | global | Axis-to-ST and ST-to-axis remapping tables |
| `skytexorder[6]` | `int[6]` | global | Texture index order for face rendering |

## Key Functions

### GL_SubdivideSurface
- Signature: `void GL_SubdivideSurface(msurface_t *fa)`
- Purpose: Entry point called at model load time to recursively subdivide a warp surface into `glpoly_t` chains stored on the surface.
- Inputs: `fa` — the surface to subdivide.
- Outputs/Return: None; populates `fa->polys`.
- Side effects: Sets global `warpface = fa`; allocates `glpoly_t` nodes from Hunk.
- Calls: `SubdividePolygon`, reads `loadmodel->surfedges/edges/vertexes`.
- Notes: Converts BSP edge list back to raw vertex array before recursing.

### SubdividePolygon
- Signature: `void SubdividePolygon(int numverts, float *verts)`
- Purpose: Recursively splits a polygon along the nearest 64-unit axial boundary; emits a fan-centered `glpoly_t` leaf when no axis needs splitting.
- Inputs: Vertex count and flat float array (xyz triples).
- Outputs/Return: None; allocates and links `glpoly_t` onto `warpface->polys`.
- Side effects: Hunk allocation; writes UV coords using `warpface->texinfo->vecs`.
- Calls: `BoundPoly`, `SubdividePolygon` (recursive), `Hunk_Alloc`.
- Notes: Crashes via `ri.Sys_Error` if `numverts > 60`. Appends centroid vertex at index 0 and duplicates first vertex at end to close the fan.

### EmitWaterPolys
- Signature: `void EmitWaterPolys(msurface_t *fa)`
- Purpose: Renders animated water/turbulence surface by distorting UVs with a sin LUT each frame.
- Inputs: `fa` — surface with pre-subdivided `polys` chain.
- Outputs/Return: None.
- Side effects: Issues `qglBegin/qglEnd` GL_TRIANGLE_FAN draw calls; reads `r_newrefdef.time`.
- Calls: `qglBegin`, `qglTexCoord2f`, `qglVertex3fv`, `qglEnd`; uses `Q_ftol` on x86.
- Notes: Applies scroll offset for `SURF_FLOWING` surfaces. Uses `TURBSCALE = 256/(2π)` to index the 256-entry LUT.

### ClipSkyPolygon
- Signature: `void ClipSkyPolygon(int nump, vec3_t vecs, int stage)`
- Purpose: Recursively clips a sky polygon against six axis-aligned half-spaces, then calls `DrawSkyPolygon` on the fully-clipped result.
- Inputs: Vertex count, vertex array, clip stage index (0–6).
- Outputs/Return: None.
- Side effects: Calls `DrawSkyPolygon` at stage 6 which updates `skymins/skymaxs`.
- Calls: `DotProduct`, `DrawSkyPolygon`, `ClipSkyPolygon` (recursive).
- Notes: Errors if `nump > MAX_CLIP_VERTS-2` (62).

### R_AddSkySurface
- Signature: `void R_AddSkySurface(msurface_t *fa)`
- Purpose: Transforms a sky surface's vertices to view-relative space and feeds them into the clip pipeline.
- Inputs: `fa` — sky surface.
- Side effects: Updates `skymins/skymaxs` via `ClipSkyPolygon` → `DrawSkyPolygon`.
- Calls: `VectorSubtract`, `ClipSkyPolygon`.

### R_ClearSkyBox
- Signature: `void R_ClearSkyBox(void)`
- Purpose: Resets per-face UV extent accumulators before processing a new frame's sky surfaces.
- Side effects: Writes to `skymins`, `skymaxs`.

### R_DrawSkyBox
- Signature: `void R_DrawSkyBox(void)`
- Purpose: Draws the six sky cube faces using accumulated UV extents; supports time-based rotation.
- Side effects: Pushes/pops GL matrix; calls `GL_Bind`, `qglBegin/qglEnd`, `MakeSkyVec`. Mutates `skymins/skymaxs` when rotating (forces full face draw).
- Calls: `qglPushMatrix`, `qglTranslatef`, `qglRotatef`, `GL_Bind`, `MakeSkyVec`, `qglBegin/qglEnd/qglPopMatrix`.

### R_SetSky
- Signature: `void R_SetSky(char *name, float rotate, vec3_t axis)`
- Purpose: Sets the active sky by name; loads six face textures from `env/`.
- Inputs: Sky name, rotation speed, rotation axis.
- Side effects: Writes `skyname`, `skyrotate`, `skyaxis`, `sky_images[]`, `sky_min/sky_max`; temporarily increments `gl_picmip->value` for mip-reduction.
- Calls: `GL_FindImage`, `Com_sprintf`.
- Notes: Falls back to `r_notexture` if a face image is missing. Uses PCX if paletted texture extension is active, otherwise TGA.

## Control Flow Notes
- **Load time**: `GL_SubdivideSurface` is called once per warp surface when a BSP model is loaded.
- **Frame — sky**: `R_ClearSkyBox` resets extents; `R_AddSkySurface` is called per visible sky surface during BSP traversal; `R_DrawSkyBox` is called once at end of scene rendering.
- **Frame — water**: `EmitWaterPolys` is called per visible warp surface during surface rendering.
- `R_SetSky` is called in response to the `sky` map command/worldspawn key.

## External Dependencies
- `gl_local.h` — renderer types (`msurface_t`, `glpoly_t`, `image_t`, `r_newrefdef`, `r_origin`, GL wrappers)
- `warpsin.h` — 256-entry float sin table included inline
- `loadmodel` — extern `model_t*` set by the model loader
- `Hunk_Alloc`, `ri.Sys_Error` — engine memory/error services
- `GL_Bind`, `GL_FindImage`, `GL_TexEnv` — defined in other `ref_gl` files
- `gl_skymip`, `gl_picmip`, `gl_ext_palettedtexture` — cvars defined elsewhere
