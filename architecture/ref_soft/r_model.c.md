# ref_soft/r_model.c

## File Purpose
Implements model loading, caching, and registration for the software renderer. Handles all three Quake 2 model types (brush/BSP, alias/MD2, sprite) and provides PVS/vis decompression utilities used during rendering.

## Core Responsibilities
- Load and cache brush, alias, and sprite models from disk
- Decompress BSP lump sub-data (vertexes, planes, nodes, leafs, faces, etc.) into renderer-side structs
- Convert 24-bit RGB lightmap data to 8-bit for the software renderer
- Provide PVS cluster visibility queries (`Mod_ClusterPVS`)
- Register/unregister models each map load, freeing stale assets
- Build leaf-to-vis and vis-to-leaf index tables for software renderer's visibility system
- Initialize and tear down inline submodels from the world BSP

## Key Types / Data Structures
| Name | Kind | Purpose |
|------|------|---------|
| `model_t` | struct | Central model record; holds type, geometry arrays, extradata pointer |
| `mleaf_t` | struct | BSP leaf node with cluster/area/marksurface info |
| `mnode_t` | struct | BSP interior node with plane and child pointers |
| `msurface_t` | struct | Renderable face with texinfo, extents, lightmap samples |
| `mtexinfo_t` | struct | Texture projection vectors, image pointer, animation chain |
| `dmdl_t` | struct | MD2 alias model header (on-disk and hunk-resident) |
| `dsprite_t` | struct | Sprite model header with per-frame image names |

## Global / File-Static State
| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `loadmodel` | `model_t *` | global | Points to model currently being loaded |
| `loadname` | `char[32]` | global | Name tag for hunk allocations |
| `mod_novis` | `byte[]` | global | All-visible sentinel returned when no PVS data exists |
| `mod_known` | `model_t[256]` | global | Flat cache of all loaded models |
| `mod_numknown` | `int` | global | Count of occupied `mod_known` slots |
| `mod_inline` | `model_t[256]` | global | Copies of BSP inline submodels (`*1`, `*2`, …) |
| `registration_sequence` | `int` | global | Monotone counter; stale models freed when sequence mismatches |
| `modfilelen` | `int` | global | Byte length of last file loaded via `FS_LoadFile` |
| `mod_base` | `byte *` | static/file | Base pointer into raw BSP buffer during lump parsing |
| `r_leaftovis` | `int[MAX_MAP_LEAFS]` | global | Maps leaf index → vis leaf index |
| `r_vistoleaf` | `int[MAX_MAP_LEAFS]` | global | Maps vis leaf index → leaf index |
| `r_numvisleafs` | `int` | global | Count of non-solid vis leaves |

## Key Functions

### Mod_ForName
- **Signature:** `model_t *Mod_ForName(char *name, qboolean crash)`
- **Purpose:** Primary model load entry point; returns cached model or loads from disk.
- **Inputs:** Model name string; `crash` flag to fatal-error on missing file.
- **Outputs/Return:** Pointer to populated `model_t` in `mod_known`, or `NULL`.
- **Side effects:** Allocates hunk memory; sets `loadmodel`; calls type-specific loader; frees file buffer.
- **Calls:** `ri.FS_LoadFile`, `Hunk_Begin/End`, `Mod_LoadAliasModel`, `Mod_LoadSpriteModel`, `Mod_LoadBrushModel`, `ri.FS_FreeFile`.
- **Notes:** Inline models (`*N`) bypass disk entirely and return from `mod_inline[]`. Unknown file magic is a fatal error.

### Mod_LoadBrushModel
- **Signature:** `void Mod_LoadBrushModel(model_t *mod, void *buffer)`
- **Purpose:** Parses all BSP lumps into renderer structs and populates `mod_inline[]` submodels.
- **Inputs:** Target `model_t`, raw BSP file buffer.
- **Outputs/Return:** void; populates `loadmodel` fields in place.
- **Side effects:** Large hunk allocation; byte-swaps entire header; calls all `Mod_Load*` sub-loaders; calls `R_NumberLeafs`, `R_InitSkyBox`.
- **Calls:** All `Mod_Load*` helpers, `R_NumberLeafs`, `R_InitSkyBox`.
- **Notes:** Enforces that a brush model is only loaded into `mod_known[0]` (world slot); asserts BSPVERSION.

### Mod_LoadAliasModel
- **Signature:** `void Mod_LoadAliasModel(model_t *mod, void *buffer)`
- **Purpose:** Loads MD2 alias model, byte-swaps all fields, and registers skin images.
- **Inputs:** Target `model_t`, raw MD2 buffer.
- **Side effects:** Hunk allocation for full model header; calls `R_FindImage` per skin.
- **Calls:** `Hunk_Alloc`, `R_FindImage`.
- **Notes:** Validates version, vertex count, skin height against compile-time limits.

### Mod_LoadSpriteModel
- **Signature:** `void Mod_LoadSpriteModel(model_t *mod, void *buffer)`
- **Purpose:** Loads SP2 sprite, byte-swaps, registers per-frame images.
- **Inputs:** Target `model_t`, raw sprite buffer.
- **Side effects:** Hunk allocation; `R_FindImage` per frame.
- **Calls:** `Hunk_Alloc`, `R_FindImage`.

### Mod_ClusterPVS
- **Signature:** `byte *Mod_ClusterPVS(int cluster, model_t *model)`
- **Purpose:** Returns decompressed PVS bitset for a given cluster.
- **Outputs/Return:** Pointer to static decompressed buffer, or `mod_novis` sentinel.
- **Calls:** `Mod_DecompressVis`.

### R_BeginRegistration
- **Signature:** `void R_BeginRegistration(char *model)`
- **Purpose:** Starts a new map load; increments registration sequence, loads world BSP.
- **Side effects:** Bumps `registration_sequence`; calls `D_FlushCaches`, `Mod_Free`, `R_RegisterModel`, `R_NewMap`.

### R_EndRegistration
- **Signature:** `void R_EndRegistration(void)`
- **Purpose:** Frees all models not referenced in current registration sequence.
- **Side effects:** Calls `Hunk_Free` on stale models; calls `R_FreeUnusedImages`.

### R_RegisterModel
- **Signature:** `struct model_s *R_RegisterModel(char *name)`
- **Purpose:** Loads or re-validates a model and re-registers its images for the current sequence.
- **Calls:** `Mod_ForName`, `R_FindImage`.

### Mod_LoadLighting
- **Signature:** `void Mod_LoadLighting(lump_t *l)`
- **Purpose:** Converts 24-bit RGB lightmap lump to 8-bit by taking the brightest channel.
- **Notes:** Software-renderer-specific; GL renderer uses the full RGB data.

### CalcSurfaceExtents
- **Signature:** `void CalcSurfaceExtents(msurface_t *s)`
- **Purpose:** Computes `texturemins` and `extents` for lightmap allocation on each face.
- **Notes:** Enforces 256-texel max extent for non-warp surfaces; fatal error if exceeded.

## Control Flow Notes
Fits into **init/registration**: `R_BeginRegistration` → `Mod_ForName` → `Mod_LoadBrushModel` (and alias/sprite variants) at map load time. During `R_EndRegistration`, stale models are purged. The PVS helpers (`Mod_PointInLeaf`, `Mod_ClusterPVS`) are called each frame by the visibility culling path in the software renderer.

## External Dependencies
- **Includes:** `r_local.h` (pulls in all renderer types and `ri` import struct)
- **Defined elsewhere:** `r_worldmodel`, `r_oldviewcluster` (renderer globals), `R_FindImage`, `R_NewMap`, `R_InitSkyBox`, `D_FlushCaches`, `R_FreeUnusedImages`, `Hunk_Begin/End/Alloc/Free`, `Com_PageInMemory`, `ri.FS_LoadFile`, `ri.Sys_Error`, `ri.Cvar_Get`, `ri.Con_Printf`
