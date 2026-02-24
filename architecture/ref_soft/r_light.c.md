# ref_soft/r_light.c

## File Purpose
Implements lighting calculations for the software renderer, covering dynamic light marking on BSP surfaces, static lightmap sampling, and the construction of the final per-surface light map used during rasterization.

## Core Responsibilities
- Recursively mark BSP surfaces affected by each dynamic light each frame
- Sample the static lightmap at a world-space point (used for entity lighting)
- Accumulate dynamic light contributions onto `blocklights[]`
- Combine static lightmaps and dynamic lights into the `blocklights[]` buffer in 8.8 fixed-point format
- Support negative (darkening) dynamic lights via PGM extension

## Key Types / Data Structures
None (operates on types defined in `r_local.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `r_dlightframecount` | `int` | global | Frame stamp used to avoid re-initializing `dlightbits` per surface more than once per frame |
| `pointcolor` | `vec3_t` | global (file) | Output color from `RecursiveLightPoint`, read by `R_LightPoint` |
| `lightplane` | `mplane_t *` | global (file) | The BSP plane where the light ray impacted; used as a shadow plane |
| `lightspot` | `vec3_t` | global (file) | World-space point of lightmap hit, companion to `lightplane` |
| `blocklights` | `unsigned[1024]` | global | Accumulation buffer for one surface's combined light values in 8.8 fixed-point |

## Key Functions

### R_MarkLights
- **Signature:** `void R_MarkLights(dlight_t *light, int bit, mnode_t *node)`
- **Purpose:** Recursively traverses the BSP tree and sets `dlightbits` on any surface within the light's radius.
- **Inputs:** Dynamic light descriptor, bitmask for this light's index, current BSP node.
- **Outputs/Return:** void
- **Side effects:** Writes `surf->dlightbits` and `surf->dlightframe` on affected surfaces.
- **Calls:** `DotProduct`, recursive `R_MarkLights`
- **Notes:** Handles negative-intensity lights (PGM extension) by taking absolute value of intensity for culling. Uses `r_dlightframecount` to lazily clear `dlightbits` only on first touch per frame.

### R_PushDlights
- **Signature:** `void R_PushDlights(model_t *model)`
- **Purpose:** Iterates all active dynamic lights in the current ref def and calls `R_MarkLights` for each, resetting `r_dlightframecount` first.
- **Inputs:** World model pointer.
- **Outputs/Return:** void
- **Side effects:** Sets `r_dlightframecount = r_framecount`; indirectly marks all affected surfaces.
- **Calls:** `R_MarkLights`

### RecursiveLightPoint
- **Signature:** `int RecursiveLightPoint(mnode_t *node, vec3_t start, vec3_t end)`
- **Purpose:** Casts a ray through the BSP tree from `start` to `end`, finds the first textured surface hit, and accumulates its lightmap value into `pointcolor`.
- **Inputs:** BSP node, ray start/end in world space.
- **Outputs/Return:** `1` on hit, `0` if surface has no samples, `-1` if no surface hit.
- **Side effects:** Writes `pointcolor`, `lightspot`, `lightplane`.
- **Calls:** `DotProduct`, `VectorCopy`, `VectorMA`, recursive `RecursiveLightPoint`
- **Notes:** Skips `SURF_DRAWTURB` and `SURF_DRAWSKY` surfaces (no lightmaps). Accumulates all active `MAXLIGHTMAPS` style layers scaled by `lightstyles[].rgb`.

### R_LightPoint
- **Signature:** `void R_LightPoint(vec3_t p, vec3_t color)`
- **Purpose:** Public entry point for entity lighting. Casts a downward ray 2048 units to sample the static lightmap, then adds contributions from all active dynamic lights.
- **Inputs:** World-space position `p`, output `color`.
- **Outputs/Return:** void (result via `color`)
- **Side effects:** Reads `r_worldmodel`, `r_newrefdef`, `currententity`.
- **Calls:** `RecursiveLightPoint`, `VectorCopy`, `VectorSubtract`, `VectorLength`, `VectorMA`
- **Notes:** Falls back to full-white if no lightdata exists.

### R_AddDynamicLights
- **Signature:** `void R_AddDynamicLights(void)`
- **Purpose:** For each dynamic light flagged on `r_drawsurf.surf`, projects the light onto the surface and accumulates or subtracts light intensity into `blocklights[]`.
- **Inputs:** Implicit: `r_drawsurf`, `r_newrefdef`.
- **Outputs/Return:** void
- **Side effects:** Modifies `blocklights[]`.
- **Calls:** `DotProduct`, `fabs`
- **Notes:** PGM negative-light support: subtracts from `blocklights` and clamps to `minlight` to prevent wrap-around on `unsigned` buffer.

### R_BuildLightMap
- **Signature:** `void R_BuildLightMap(void)`
- **Purpose:** Builds the final `blocklights[]` for the current draw surface by accumulating all static lightmap styles then dynamic lights, then converts to inverted 8.8 format for the software renderer's surface cache.
- **Inputs:** Implicit: `r_drawsurf`, `r_fullbright`, `r_worldmodel`.
- **Outputs/Return:** void
- **Side effects:** Writes `blocklights[]`.
- **Calls:** `R_AddDynamicLights`
- **Notes:** Inversion (`255*256 - t`) converts from additive light to the renderer's "darkness" scale. `VID_CBITS` controls the fixed-point shift. Clamps minimum to `1<<6` to avoid fully-black texels.

## Control Flow Notes
`R_PushDlights` is called once per frame before surface rendering. `R_BuildLightMap` is called per visible surface during the surface draw loop (`r_drawsurf`), and internally calls `R_AddDynamicLights` only if the surface was marked in the current frame. `R_LightPoint` is called per entity for model shading.

## External Dependencies
- `r_local.h` — all shared renderer types (`msurface_t`, `mnode_t`, `dlight_t`, `r_drawsurf`, `r_newrefdef`, `r_worldmodel`, `r_framecount`, `VID_CBITS`, `MAXLIGHTMAPS`)
- `currententity` — global entity pointer, defined in renderer core
- `r_fullbright`, `r_framecount` — defined elsewhere in the soft renderer
