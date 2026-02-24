# ref_gl/gl_model.h

## File Purpose
Defines the in-memory data structures for all model types (brush, sprite, alias) used by the GL renderer. Bridges on-disk BSP/mesh formats with renderer-ready representations, and declares the model management and hunk allocator API.

## Core Responsibilities
- Define in-memory brush model geometry types (vertices, edges, surfaces, nodes, leaves)
- Define the unified `model_t` container for all model types
- Declare surface flags and BSP traversal side constants
- Declare the model lifecycle API (`Mod_Init`, `Mod_ForName`, `Mod_Free`, etc.)
- Declare the hunk (zone) allocator API used for model data

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `mvertex_t` | struct | Single 3D vertex position in memory |
| `mmodel_t` | struct | Submodel entry (bounding box, headnode, face range) |
| `medge_t` | struct | BSP edge with two vertex indices and a cached edge offset |
| `mtexinfo_t` | struct | Texture projection vectors, flags, animation chain, bound image |
| `glpoly_t` | struct | GL-ready polygon strip with `VERTEXSIZE=7` floats per vert (xyz, s1t1, s2t2) |
| `msurface_t` | struct | Renderable BSP face: plane, edges, lightmap coords, dynamic light state, poly list |
| `mnode_t` | struct | BSP interior node: plane, children, surface range, vis/cull data |
| `mleaf_t` | struct | BSP leaf: cluster/area, mark surfaces, vis frame |
| `modtype_t` | enum | Model kind: `mod_bad`, `mod_brush`, `mod_sprite`, `mod_alias` |
| `model_t` | struct | Unified model record holding all subtype data, registration sequence, and extradata |

## Global / File-Static State
None.

## Key Functions

### Mod_Init
- Signature: `void Mod_Init(void)`
- Purpose: Initialize the model subsystem.
- Inputs: None
- Outputs/Return: None
- Side effects: Not inferable from this file.
- Calls: Not inferable from this file.
- Notes: Called once at renderer startup.

### Mod_ForName
- Signature: `model_t *Mod_ForName(char *name, qboolean crash)`
- Purpose: Load or retrieve a cached model by filename.
- Inputs: `name` — asset path; `crash` — if true, fatal error on missing model.
- Outputs/Return: Pointer to loaded `model_t`, or NULL if not found and `crash` is false.
- Side effects: May load from disk and populate hunk memory.
- Calls: Not inferable from this file.
- Notes: Primary entry point for all model loading in the GL renderer.

### Mod_PointInLeaf
- Signature: `mleaf_t *Mod_PointInLeaf(float *p, model_t *model)`
- Purpose: Descend the BSP tree to find the leaf containing point `p`.
- Inputs: World-space point, brush model.
- Outputs/Return: Pointer to the containing `mleaf_t`.
- Side effects: None.
- Calls: Not inferable from this file.

### Mod_ClusterPVS
- Signature: `byte *Mod_ClusterPVS(int cluster, model_t *model)`
- Purpose: Return the decompressed PVS bitset for a given cluster.
- Inputs: Cluster index, brush model.
- Outputs/Return: Pointer to PVS byte array.
- Side effects: Not inferable from this file.
- Notes: Used by the renderer for visibility culling.

### Hunk_Begin / Hunk_Alloc / Hunk_End / Hunk_Free
- Signature: `void *Hunk_Begin(int maxsize)` / `void *Hunk_Alloc(int size)` / `int Hunk_End(void)` / `void Hunk_Free(void *base)`
- Purpose: Linear block allocator for model data; reserves a max-size block, bump-allocates within it, then trims on `Hunk_End`. `Hunk_Free` releases the whole block.
- Notes: Used exclusively for per-model extradata; not a general heap.

## Control Flow Notes
This header is consumed by `gl_model.c` (implementation) and other GL renderer files (`gl_rmain.c`, `gl_rsurf.c`, etc.). Models are loaded during map/asset registration, referenced each frame during BSP traversal and surface rendering, and freed on map change via `Mod_FreeAll` / `Mod_ClearAll`.

## External Dependencies
- `gl_local.h` (implicit) — provides `image_t`, `cplane_t`, `dvis_t`, `MAX_QPATH`, `MAX_MD2SKINS`, `MAXLIGHTMAPS`, `vec3_t`, `qboolean`
- `cplane_t` — defined in `qcommon/qfiles.h` or shared headers
- `dvis_t` — on-disk vis structure, defined in `qcommon/qfiles.h`
- `image_t` — defined in `ref_gl/gl_local.h`
