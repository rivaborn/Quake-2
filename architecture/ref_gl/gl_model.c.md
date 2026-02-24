# ref_gl/gl_model.c

## File Purpose
Handles all model loading, caching, and registration for the GL renderer. It parses and converts BSP brush models, MD2 alias models, and sprite models from on-disk formats into renderer-internal structures, and manages the model cache lifecycle tied to map registration sequences.

## Core Responsibilities
- Load and cache brush (BSP), alias (MD2), and sprite models from disk
- Convert on-disk binary formats to host endianness during load
- Manage a fixed-size model cache (`mod_known`) with name-based deduplication
- Build GPU-ready surface data: lightmaps, polygons, texture extents
- Provide PVS/cluster visibility queries (`Mod_PointInLeaf`, `Mod_ClusterPVS`)
- Implement the `R_BeginRegistration` / `R_EndRegistration` lifecycle to evict unused models and images

## Key Types / Data Structures
None defined here; all types are from `gl_local.h` / `gl_model.h`.

| Name | Kind | Purpose |
|------|------|---------|
| `model_t` | struct | Top-level model container (name, type, geometry arrays, extradata) |
| `mleaf_t` / `mnode_t` | struct | BSP tree leaf/node for spatial queries |
| `msurface_t` | struct | Rendered surface with lightmap, texinfo, polygon chain |
| `mtexinfo_t` | struct | Texture projection vectors, animation chain, image pointer |
| `dmdl_t` | struct | On-disk MD2 alias model header |
| `dsprite_t` | struct | On-disk sprite model header/frames |

## Global / File-Static State
| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `loadmodel` | `model_t *` | global | Points to the model currently being loaded |
| `modfilelen` | `int` | global | Byte size of the last file loaded via `FS_LoadFile` |
| `mod_novis` | `byte[MAX_MAP_LEAFS/8]` | global | All-ones bitmask returned when no vis data exists |
| `mod_known` | `model_t[MAX_MOD_KNOWN]` | global | Flat model cache, max 512 entries |
| `mod_numknown` | `int` | global | Count of used slots in `mod_known` |
| `mod_inline` | `model_t[MAX_MOD_KNOWN]` | global | Inline submodels copied from the world BSP |
| `registration_sequence` | `int` | global | Monotonically incremented each map load; drives model eviction |
| `mod_base` | `byte *` | static (file) | Base pointer into the raw BSP buffer during brush model load |

## Key Functions

### Mod_PointInLeaf
- **Signature:** `mleaf_t *Mod_PointInLeaf(vec3_t p, model_t *model)`
- **Purpose:** Walks the BSP tree to find the leaf containing point `p`.
- **Inputs:** World-space point, model with a valid node tree.
- **Outputs/Return:** Pointer to the containing `mleaf_t`.
- **Side effects:** None.
- **Calls:** `DotProduct` (macro), `ri.Sys_Error`.
- **Notes:** Terminates when `node->contents != -1`; `NULL` return is unreachable.

### Mod_ClusterPVS
- **Signature:** `byte *Mod_ClusterPVS(int cluster, model_t *model)`
- **Purpose:** Returns the decompressed PVS bitset for a given cluster.
- **Inputs:** Cluster index (-1 for none), model with vis lump.
- **Outputs/Return:** Pointer to static decompressed bitset, or `mod_novis`.
- **Side effects:** Overwrites the static buffer inside `Mod_DecompressVis`.
- **Calls:** `Mod_DecompressVis`.

### Mod_ForName
- **Signature:** `model_t *Mod_ForName(char *name, qboolean crash)`
- **Purpose:** Main model load/cache entry point; returns cached model or loads from disk.
- **Inputs:** Asset path string; `crash` triggers fatal error on missing file.
- **Outputs/Return:** Pointer to loaded `model_t`, or `NULL` if not found and `crash==false`.
- **Side effects:** Allocates hunk memory; sets `loadmodel`; calls type-specific loaders; calls `ri.FS_LoadFile` / `ri.FS_FreeFile`.
- **Calls:** `Mod_LoadAliasModel`, `Mod_LoadSpriteModel`, `Mod_LoadBrushModel`, `Hunk_Begin`, `Hunk_End`, `ri.FS_LoadFile`, `ri.FS_FreeFile`, `ri.Sys_Error`.
- **Notes:** Inline models (`name[0]=='*'`) are returned directly from `mod_inline` without file I/O.

### Mod_LoadBrushModel
- **Signature:** `void Mod_LoadBrushModel(model_t *mod, void *buffer)`
- **Purpose:** Parses a BSP file, loading all lumps and building submodel entries in `mod_inline`.
- **Inputs:** Target model slot, raw file buffer.
- **Outputs/Return:** Void; populates `loadmodel` in-place.
- **Side effects:** Allocates hunk data for all BSP lumps; populates `mod_inline[0..n]`; calls lightmap builders.
- **Calls:** All `Mod_Load*` lump helpers, `GL_BeginBuildingLightmaps`, `GL_EndBuildingLightmaps`, `ri.Sys_Error`.
- **Notes:** Enforces `loadmodel == mod_known` (world must be first model loaded).

### Mod_LoadAliasModel
- **Signature:** `void Mod_LoadAliasModel(model_t *mod, void *buffer)`
- **Purpose:** Loads an MD2 model: byte-swaps header, copies ST verts/triangles/frames/GL commands, registers skins.
- **Side effects:** Hunk-allocates the full model data block; calls `GL_FindImage` per skin.
- **Calls:** `Hunk_Alloc`, `GL_FindImage`, `ri.Sys_Error`.
- **Notes:** Hard-codes `mod->mins/maxs` to ±32; vertex data is 8-bit and not byte-swapped.

### R_BeginRegistration / R_EndRegistration
- **Signatures:** `void R_BeginRegistration(char *model)` / `void R_EndRegistration(void)`
- **Purpose:** Begin: increments `registration_sequence`, optionally flushes old world, loads new world BSP. End: frees all models not touched during the registration pass, then calls `GL_FreeUnusedImages`.
- **Side effects:** May free and reload the world model; evicts stale cache entries.
- **Calls:** `Mod_Free`, `Mod_ForName`, `GL_FreeUnusedImages`, `ri.Cvar_Get`.

### Notes (minor helpers)
- `Mod_LoadLighting/Visibility/Vertexes/Edges/Texinfo/Faces/Nodes/Leafs/Marksurfaces/Surfedges/Planes/Submodels`: each reads one BSP lump, byte-swaps fields, hunk-allocates output, and stores pointer+count into `loadmodel`.
- `CalcSurfaceExtents`: computes lightmap `texturemins[]` and `extents[]` for a surface by projecting all edge vertices through `texinfo->vecs`.
- `RadiusFromBounds`: returns the bounding sphere radius from AABB corners.
- `Mod_SetParent`: recursive post-pass that fills `node->parent` for the entire BSP tree.

## Control Flow Notes
- **Init:** `Mod_Init` zeroes `mod_novis` to all-visible. Called once at renderer startup.
- **Map load:** `R_BeginRegistration` → `Mod_ForName` → `Mod_LoadBrushModel` (and sub-loaders) → `GL_BeginBuildingLightmaps` / `GL_EndBuildingLightmaps`.
- **Per-entity model load:** `R_RegisterModel` → `Mod_ForName` (cached hit or disk load) → re-registers images against current sequence.
- **Map unload:** `R_EndRegistration` sweeps `mod_known`, freeing any model whose `registration_sequence` is stale.
- **Frame:** `Mod_PointInLeaf` and `Mod_ClusterPVS` are called per-frame during visibility determination in `gl_rmain.c`.

## External Dependencies
- **Includes:** `gl_local.h` (pulls in all renderer types, `ri` import table, math macros)
- **Defined elsewhere:**
  - `ri` — renderer import struct (`Sys_Error`, `Con_Printf`, `FS_LoadFile`, `Cvar_Get`)
  - `r_worldmodel`, `r_viewcluster`, `r_oldviewcluster`, `currentmodel` — globals in `gl_rmain.c`
  - `r_notexture` — fallback image, `gl_image.c`
  - `GL_FindImage`, `GL_FreeUnusedImages` — `gl_image.c`
  - `GL_BuildPolygonFromSurface`, `GL_SubdivideSurface` — `gl_warp.c` / `gl_rsurf.c`
  - `GL_BeginBuildingLightmaps`, `GL_CreateSurfaceLightmap`, `GL_EndBuildingLightmaps` — `gl_light.c`
  - `Hunk_Begin`, `Hunk_Alloc`, `Hunk_End`, `Hunk_Free` — engine memory allocator
