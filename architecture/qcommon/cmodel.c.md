# qcommon/cmodel.c

## File Purpose
Implements the collision model (BSP-based) system for Quake 2. Loads BSP map lumps into collision-ready structures and provides spatial queries including point/box traces, leaf lookups, PVS/PHS decompression, and area portal connectivity flooding.

## Core Responsibilities
- Load and parse all collision-relevant BSP lumps from a `.bsp` file
- Maintain static arrays of planes, nodes, leafs, brushes, brush sides, and submodels
- Provide box/point trace queries against brushes via recursive BSP traversal
- Construct a synthetic "box hull" for AABB-vs-world queries
- Decompress run-length encoded PVS/PHS visibility bitsets per cluster
- Manage area portal open/closed state and flood-fill area connectivity
- Expose leaf, cluster, and area accessor functions to the rest of the engine

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `cnode_t` | struct | Collision BSP node: plane pointer + two child indices |
| `cbrushside_t` | struct | One side of a brush: plane pointer + surface reference |
| `cleaf_t` | struct | BSP leaf: contents flags, cluster/area id, leaf-brush range |
| `cbrush_t` | struct | Convex brush: contents, side range, per-frame checkcount |
| `carea_t` | struct | Area for portal connectivity: portal range, floodnum, floodvalid |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `map_planes` | `cplane_t[MAX_MAP_PLANES+6]` | global | All BSP planes; +6 reserved for box hull |
| `map_nodes` | `cnode_t[MAX_MAP_NODES+6]` | global | All BSP nodes; +6 for box hull |
| `map_leafs` | `cleaf_t[MAX_MAP_LEAFS]` | global | All BSP leafs |
| `map_brushes` | `cbrush_t[MAX_MAP_BRUSHES]` | global | All convex brushes |
| `map_brushsides` | `cbrushside_t[MAX_MAP_BRUSHSIDES]` | global | All brush sides |
| `map_cmodels` | `cmodel_t[MAX_MAP_MODELS]` | global | Submodels (index 0 = world) |
| `map_visibility` | `byte[MAX_MAP_VISIBILITY]` | global | Raw PVS/PHS data; aliased by `map_vis` |
| `map_areaportals` | `dareaportal_t[MAX_MAP_AREAPORTALS]` | global | Portal adjacency records |
| `portalopen` | `qboolean[MAX_MAP_AREAPORTALS]` | global | Runtime open/closed state per portal |
| `trace_trace` | `trace_t` | global (file) | Accumulates result during recursive trace |
| `trace_start/end/mins/maxs/extents` | `vec3_t` | global (file) | Trace parameters shared across recursion |
| `checkcount` | `int` | global | Monotonic counter to avoid re-testing brushes |
| `floodvalid` | `int` | global | Generation counter for area flood invalidation |
| `box_headnode`, `box_planes`, `box_brush`, `box_leaf` | mixed | global | Pointers into map arrays for synthetic AABB hull |
| `leaf_count/maxcount/list/mins/maxs/topnode` | mixed | global (file) | Thread-local-style state for `CM_BoxLeafnums_r` |

## Key Functions

### CM_LoadMap
- **Signature:** `cmodel_t *CM_LoadMap(char *name, qboolean clientload, unsigned *checksum)`
- **Purpose:** Main entry point to load a BSP file into all collision arrays. Returns pointer to world cmodel.
- **Inputs:** Map filename, client-load flag (skip re-flood if reusing), checksum output pointer.
- **Outputs/Return:** `&map_cmodels[0]` (world model).
- **Side effects:** Fills all `map_*` globals, calls `CM_InitBoxHull`, resets and re-floods area portals, sets `map_name`.
- **Calls:** `FS_LoadFile`, `Com_BlockChecksum`, all `CMod_Load*`, `CM_InitBoxHull`, `FloodAreaConnections`, `FS_FreeFile`.
- **Notes:** Short-circuits if same map already loaded and `flushmap` not set; handles empty name for cinematic-only servers.

### CM_BoxTrace
- **Signature:** `trace_t CM_BoxTrace(vec3_t start, vec3_t end, vec3_t mins, vec3_t maxs, int headnode, int brushmask)`
- **Purpose:** Sweeps an AABB from `start` to `end` through the BSP, returning first solid intersection.
- **Inputs:** Start/end positions, box extents, root headnode, content mask.
- **Outputs/Return:** Filled `trace_t` with fraction, plane, surface, endpos.
- **Side effects:** Writes `trace_trace` and associated globals; increments `checkcount` and `c_traces`.
- **Calls:** `CM_BoxLeafnums_headnode`, `CM_TestInLeaf`, `CM_RecursiveHullCheck`.
- **Notes:** Handles three cases: position-test (start==end), point trace (zero-size box), and general swept box.

### CM_RecursiveHullCheck
- **Signature:** `void CM_RecursiveHullCheck(int num, float p1f, float p2f, vec3_t p1, vec3_t p2)`
- **Purpose:** Recursively descends BSP to find brush intersections for the current trace.
- **Side effects:** Updates `trace_trace` via `CM_TraceToLeaf`.
- **Calls:** `CM_TraceToLeaf`, itself recursively.
- **Notes:** Early-exits if `trace_trace.fraction <= p1f`; computes split fraction with `DIST_EPSILON` bias.

### CM_ClipBoxToBrush
- **Signature:** `void CM_ClipBoxToBrush(vec3_t mins, vec3_t maxs, vec3_t p1, vec3_t p2, trace_t *trace, cbrush_t *brush)`
- **Purpose:** Slab-intersection test of a moving AABB against all sides of a single brush.
- **Side effects:** Writes `trace->fraction`, `trace->plane`, `trace->surface`, `trace->contents` if closer hit found.

### CM_TransformedBoxTrace
- **Signature:** `trace_t CM_TransformedBoxTrace(vec3_t start, vec3_t end, vec3_t mins, vec3_t maxs, int headnode, int brushmask, vec3_t origin, vec3_t angles)`
- **Purpose:** Wraps `CM_BoxTrace` for rotated/translated entities by transforming trace into model-local space.
- **Notes:** Inverse-rotates hit plane normal back to world space. Marked `#pragma optimize("",off)` on MSVC.

### CM_InitBoxHull
- **Signature:** `void CM_InitBoxHull(void)`
- **Purpose:** Appends 6 nodes, 12 planes, 1 brush, and 1 leaf to the map arrays to represent a parameterizable AABB hull.
- **Side effects:** Sets `box_headnode`, `box_planes`, `box_brush`, `box_leaf`.

### FloodAreaConnections
- **Signature:** `void FloodAreaConnections(void)`
- **Purpose:** Flood-fills all areas reachable through open portals, assigning each connected group a shared `floodnum`.
- **Side effects:** Increments `floodvalid`; mutates `map_areas[*].floodnum/floodvalid`.

### CM_ClusterPVS / CM_ClusterPHS
- **Signature:** `byte *CM_ClusterPVS(int cluster)` / `byte *CM_ClusterPHS(int cluster)`
- **Purpose:** Decompress and return the PVS or PHS bitset for a given cluster into static row buffers.
- **Side effects:** Writes `pvsrow` / `phsrow`.

## Control Flow Notes
- `CM_LoadMap` is called during server map load (`SV_InitGame` / map change), before the game DLL and clients are initialized.
- Per-frame: `CM_BoxTrace` / `CM_TransformedBoxTrace` are the primary hot paths, called from server physics, player movement (`pmove`), and projectile code.
- `CM_SetAreaPortalState` is called by the game DLL when doors open/close, triggering `FloodAreaConnections`.
- `CM_ClusterPVS` / `CM_WriteAreaBits` are called each server frame during `SV_BuildClientFrame` to compute what each client can see.

## External Dependencies
- **Includes:** `qcommon.h` (pulls in `qfiles.h`, `qcommon.h` types, `cplane_t`, `trace_t`, `cmodel_t`, `dvis_t`, `mapsurface_t`, etc.)
- **Defined elsewhere:** `FS_LoadFile`, `FS_FreeFile`, `FS_Read`, `Com_Error`, `Com_BlockChecksum`, `Cvar_Get`, `Cvar_VariableValue`, `AngleVectors`, `BOX_ON_PLANE_SIDE`, `DotProduct`, `VectorCopy`, `VectorClear`, `VectorSubtract`, `VectorAdd`, `VectorNegate`
