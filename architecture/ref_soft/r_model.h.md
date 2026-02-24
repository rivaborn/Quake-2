# ref_soft/r_model.h

## File Purpose
Defines the in-memory model representation structures for the software renderer (`ref_soft`). It covers brush (BSP), sprite, and alias (MD2) model types, along with the public API for model loading, caching, and BSP spatial queries.

## Core Responsibilities
- Declare in-memory BSP geometry types (`mvertex_t`, `medge_t`, `mplane_t`, `mtexinfo_t`, `msurface_t`, `mnode_t`, `mleaf_t`)
- Define the unified `model_t` container for all model types
- Expose the model management API (`Mod_Init`, `Mod_ForName`, `Mod_Free`, etc.)
- Define surface flags controlling rendering behavior (sky, turbulent water, background, flow)
- Expose BSP traversal utilities (`Mod_PointInLeaf`, `Mod_ClusterPVS`)

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `mvertex_t` | struct | Single world-space vertex position |
| `mplane_t` | struct | BSP plane with normal, distance, type/signbits for fast side classification |
| `medge_t` | struct | BSP edge referencing two vertex indices; carries a cached edge offset for rasterizer |
| `mtexinfo_t` | struct | Texture projection vectors, mip adjust, image pointer, animation chain |
| `msurface_t` | struct | Renderable BSP face; holds lighting, texture, cache spots, and alpha surface linkage |
| `mnode_t` | struct | BSP interior node with plane, children, surface range, and visibility frame |
| `mleaf_t` | struct | BSP leaf with PVS cluster/area, mark surfaces, and contents |
| `modtype_t` | enum | Discriminates model kinds: `mod_bad`, `mod_brush`, `mod_sprite`, `mod_alias` |
| `model_t` | struct | Unified model record holding all BSP arrays, alias/sprite skin pointers, and clip bounds |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `registration_sequence` | `int` | global (extern) | Monotonic counter used to mark/evict stale cached models across map loads |

## Key Functions

### Mod_Init
- Signature: `void Mod_Init(void)`
- Purpose: Initializes the model subsystem (likely clears the model pool).
- Inputs: None
- Outputs/Return: None
- Side effects: Resets model cache state.
- Calls: Not inferable from this file.
- Notes: Called once at renderer startup.

### Mod_ForName
- Signature: `model_t *Mod_ForName(char *name, qboolean crash)`
- Purpose: Loads or retrieves a cached model by filename.
- Inputs: `name` — asset path; `crash` — if true, fatal error on missing asset.
- Outputs/Return: Pointer to loaded `model_t`, or `NULL` if not found and `crash` is false.
- Side effects: May allocate and populate model data; updates `registration_sequence`.
- Calls: Not inferable from this file.
- Notes: Primary entry point for model acquisition by the rest of the renderer.

### Mod_Extradata
- Signature: `void *Mod_Extradata(model_t *mod)`
- Purpose: Returns a pointer to alias/sprite extra data, loading from disk if evicted from cache.
- Inputs: Loaded `model_t *`.
- Outputs/Return: `void *` to extra data block.
- Side effects: Potential disk I/O and allocation on cache miss.

### Mod_PointInLeaf
- Signature: `mleaf_t *Mod_PointInLeaf(float *p, model_t *model)`
- Purpose: Descends the BSP tree to find the leaf containing world point `p`.
- Inputs: 3-float world position; brush `model_t`.
- Outputs/Return: Pointer to the containing `mleaf_t`.
- Side effects: None.
- Notes: Used for PVS determination and audio/physics leaf queries.

### Mod_ClusterPVS
- Signature: `byte *Mod_ClusterPVVS(int cluster, model_t *model)`
- Purpose: Returns the decompressed (or raw) PVS bitset for a given cluster.
- Inputs: Cluster index; brush model.
- Outputs/Return: Pointer to PVS byte array.
- Side effects: May decompress vis data into a static buffer.

### Notes
- `Mod_ClearAll`, `Mod_TouchModel`, `Mod_Modellist_f`, `Mod_FreeAll`, `Mod_Free` are lifecycle/utility helpers for cache management and console listing; trivial signatures with no non-obvious semantics.

## Control Flow Notes
This header is consumed at renderer init (`Mod_Init`) and throughout the frame when surfaces, models, and vis data are accessed. `Mod_PointInLeaf` and `Mod_ClusterPVS` are called early in each frame to determine what is visible. `Mod_ForName` is called during map/entity loading, not per-frame.

## External Dependencies
- `qcommon/qfiles.h` — `dmodel_t`, `dvis_t`, `MIPLEVELS`, `MAXLIGHTMAPS`, `MAX_MD2SKINS`, `MAX_QPATH`
- `ref_soft/r_local.h` (or equivalent) — `image_t`, `vec3_t`, `byte`, `qboolean`
- Assembly constraint: comments note `mvertex_t` and `mplane_t` layout is mirrored in `asm_draw.h`/`asm_i386.h` — struct layout must not change without updating those files.
- All function bodies defined elsewhere (in `ref_soft/r_model.c`).
