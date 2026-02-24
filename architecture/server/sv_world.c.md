# server/sv_world.c

## File Purpose
Implements server-side world spatial query functions, including entity area management via a binary space partition tree, entity linking/unlinking, point-content tests, and swept-volume trace (collision) queries against both world geometry and entities.

## Core Responsibilities
- Build and maintain a 2D axis-aligned BSP area tree for fast entity spatial lookup
- Link/unlink entities into the area tree when they move or change state
- Encode entity bounding box dimensions into `entity_state.solid` for client prediction
- Track which BSP PVS clusters and areas each entity occupies
- Enumerate candidate entities within an AABB region (`SV_AreaEdicts`)
- Perform swept-volume collision traces (`SV_Trace`) against world and entities
- Compute point contents merging world BSP and entity hulls

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `areanode_t` | struct | Binary tree node partitioning world space; stores axis, split distance, and linked lists of trigger/solid edicts |
| `moveclip_t` | struct | Transient trace context holding move bounds, size variants for monsters, pass-entity, content mask, and accumulating `trace_t` result |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `sv_areanodes` | `areanode_t[32]` | global | Pre-allocated flat pool for area tree nodes |
| `sv_numareanodes` | `int` | global | Count of allocated nodes in pool |
| `area_mins`, `area_maxs` | `float *` | global | Query AABB for current `SV_AreaEdicts_r` traversal |
| `area_list` | `edict_t **` | global | Output list pointer for area query |
| `area_count`, `area_maxcount` | `int` | global | Current fill count and cap for area query |
| `area_type` | `int` | global | Selects solid vs. trigger list during area traversal |

## Key Functions

### SV_CreateAreaNode
- **Signature:** `areanode_t *SV_CreateAreaNode(int depth, vec3_t mins, vec3_t maxs)`
- **Purpose:** Recursively constructs a uniform 2D (X/Y) BSP area tree to depth 4, producing up to 32 nodes.
- **Inputs:** Recursion depth; world AABB bounds.
- **Outputs/Return:** Pointer to root `areanode_t`.
- **Side effects:** Allocates from `sv_areanodes[]`, increments `sv_numareanodes`.
- **Calls:** `ClearLink`, `VectorSubtract`, `VectorCopy`, self.
- **Notes:** Splits on whichever of X or Y is longer; leaves have `axis == -1`.

### SV_ClearWorld
- **Signature:** `void SV_ClearWorld(void)`
- **Purpose:** Resets area node pool and rebuilds tree from `sv.models[1]` (world model) bounds.
- **Side effects:** Zeros `sv_areanodes`, resets `sv_numareanodes`, calls `SV_CreateAreaNode`.

### SV_LinkEdict
- **Signature:** `void SV_LinkEdict(edict_t *ent)`
- **Purpose:** Inserts an entity into the area tree; updates `s.solid` encoding, absolute bounds, PVS cluster list, and area numbers.
- **Inputs:** Entity pointer.
- **Side effects:** Modifies `ent->absmin/absmax`, `ent->s.solid`, `ent->num_clusters`, `ent->clusternums`, `ent->areanum/areanum2`, `ent->linkcount`; mutates doubly-linked area lists.
- **Calls:** `SV_UnlinkEdict`, `VectorSubtract/Add/Copy`, `CM_BoxLeafnums`, `CM_LeafCluster`, `CM_LeafArea`, `Com_DPrintf`, `InsertLinkBefore`.
- **Notes:** Absolute bounds are expanded by 1 unit on all sides for epsilon safety. Rotating BSP entities use a sphere-expanded AABB. Entities touching >2 areas emit a debug warning during map load only.

### SV_UnlinkEdict
- **Signature:** `void SV_UnlinkEdict(edict_t *ent)`
- **Purpose:** Removes entity from its area linked list; no-ops if not linked.
- **Side effects:** Nulls `ent->area.prev/next`.

### SV_AreaEdicts
- **Signature:** `int SV_AreaEdicts(vec3_t mins, vec3_t maxs, edict_t **list, int maxcount, int areatype)`
- **Purpose:** Collects all entities whose AABB overlaps the query box into `list`.
- **Inputs:** Query AABB, output buffer, max count, type flag (`AREA_SOLID` or `AREA_TRIGGER`).
- **Outputs/Return:** Count of matching entities.
- **Side effects:** Writes global query state; calls recursive `SV_AreaEdicts_r`.

### SV_AreaEdicts_r
- **Signature:** `void SV_AreaEdicts_r(areanode_t *node)`
- **Purpose:** Recursive DFS over area tree; AABB-tests entities at each node and appends matches to `area_list`.
- **Notes:** Skips `SOLID_NOT` entities; truncates with warning on overflow.

### SV_PointContents
- **Signature:** `int SV_PointContents(vec3_t p)`
- **Purpose:** Returns content flags at point `p`, OR-ing world BSP contents with contents from any solid entity whose hull contains the point.
- **Calls:** `CM_PointContents`, `SV_AreaEdicts`, `SV_HullForEntity`, `CM_TransformedPointContents`.

### SV_HullForEntity
- **Signature:** `int SV_HullForEntity(edict_t *ent)`
- **Purpose:** Returns the headnode index suitable for clipping against the given entity.
- **Outputs/Return:** BSP model headnode (for `SOLID_BSP`) or synthesized box headnode.
- **Calls:** `CM_HeadnodeForBox`; fatal error if BSP model missing.

### SV_Trace
- **Signature:** `trace_t SV_Trace(vec3_t start, vec3_t mins, vec3_t maxs, vec3_t end, edict_t *passedict, int contentmask)`
- **Purpose:** Primary collision trace entry point; sweeps a box volume from `start` to `end` against world then entities.
- **Inputs:** Move endpoints, box half-extents, entity to ignore, content filter mask.
- **Outputs/Return:** `trace_t` with fraction, normal, hit entity.
- **Calls:** `CM_BoxTrace`, `SV_TraceBounds`, `SV_ClipMoveToEntities`.
- **Notes:** Short-circuits if world blocks entirely (fraction == 0). Null mins/maxs default to `vec3_origin`.

### SV_ClipMoveToEntities
- **Signature:** `void SV_ClipMoveToEntities(moveclip_t *clip)`
- **Purpose:** Iterates candidate entities from area query; clips move against each, updating `clip->trace` to closest hit.
- **Notes:** Skips own missiles and owners; uses enlarged `mins2/maxs2` for monster entities; handles `startsolid` merging carefully.

## Control Flow Notes
Called during the server frame from movement and physics code. `SV_ClearWorld` is called at map load (`sv_init`). `SV_LinkEdict`/`SV_UnlinkEdict` are invoked whenever entity positions change (exposed to game DLL via `gi.linkentity`/`gi.unlinkentity`). `SV_Trace` is the primary physics collision API used by both the server (`pmove`, projectile movement) and exposed as `gi.trace` to the game DLL.

## External Dependencies
- **Includes:** `server.h` (pulls in `qcommon.h`, `game.h`, entity/server types)
- **Defined elsewhere:** `CM_BoxLeafnums`, `CM_LeafCluster`, `CM_LeafArea`, `CM_PointContents`, `CM_TransformedPointContents`, `CM_BoxTrace`, `CM_TransformedBoxTrace`, `CM_HeadnodeForBox` (collision model, `qcommon/cmodel.c`); `ge->edicts` (game export struct); `sv.models[]`, `sv.state` (server state globals); `Com_DPrintf`, `Com_Printf`, `Com_Error`; `vec3_origin`; `link_t` list primitives.
