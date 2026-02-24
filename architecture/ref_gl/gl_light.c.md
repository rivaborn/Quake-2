# ref_gl/gl_light.c

## File Purpose
Implements all lighting calculations for the OpenGL renderer, covering dynamic light rendering (flashblend halos), BSP surface light marking, lightmap sampling for entities, and lightmap texture construction from static and dynamic light sources.

## Core Responsibilities
- Render dynamic lights as additive blended billboard halos (`gl_flashblend` mode)
- Mark BSP surfaces affected by dynamic lights each frame (`R_MarkLights`/`R_PushDlights`)
- Sample world lightmap data at a point for entity lighting (`R_LightPoint`)
- Accumulate dynamic light contributions into the `s_blocklights` buffer
- Build final RGBA lightmap texels from combined static + dynamic light data
- Handle monochrome lightmap modes (L, I, C, A) for alternate rendering paths

## Key Types / Data Structures
None locally defined; uses engine types from `gl_local.h`.

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `r_dlightframecount` | `int` | global | Frame stamp for dynamic light marking; prevents redundant marks |
| `pointcolor` | `vec3_t` | file-static (extern linkage) | Result color from `RecursiveLightPoint` |
| `lightplane` | `cplane_t *` | file-static (extern linkage) | BSP plane hit during light sampling; used as shadow plane |
| `lightspot` | `vec3_t` | file-static (extern linkage) | World-space impact point from light sampling |
| `s_blocklights` | `float[34*34*3]` | static | Floating-point accumulation buffer for one surface's lightmap texels |

## Key Functions

### R_RenderDlight
- **Signature:** `void R_RenderDlight(dlight_t *light)`
- **Purpose:** Draws a single dynamic light as a GL_TRIANGLE_FAN additive halo billboard in view space.
- **Inputs:** `light` — pointer to dlight with origin, intensity, color.
- **Outputs/Return:** void
- **Side effects:** Issues immediate-mode GL draw calls; modifies GL blend/color state (caller manages surrounding state).
- **Calls:** `qglBegin`, `qglColor3f`, `qglVertex3fv`, `qglEnd`, `VectorSubtract`, `cos`, `sin`
- **Notes:** The "view inside dlight" blend path is `#if 0`-disabled. Fan has 17 outer vertices forming a circle using `vpn`/`vright`/`vup` view vectors.

### R_RenderDlights
- **Signature:** `void R_RenderDlights(void)`
- **Purpose:** Iterates all scene dlights and renders each as a flashblend halo; only active when `gl_flashblend` is enabled.
- **Inputs:** None (reads `r_newrefdef.dlights`)
- **Outputs/Return:** void
- **Side effects:** Sets `r_dlightframecount`; modifies GL depth mask, blend, texture, shade model state.
- **Calls:** `R_RenderDlight`, various `qgl*` state calls

### R_MarkLights
- **Signature:** `void R_MarkLights(dlight_t *light, int bit, mnode_t *node)`
- **Purpose:** Recursively traverses the BSP tree and stamps `dlightbits` on surfaces within the light's radius.
- **Inputs:** `light` — dlight; `bit` — bitmask for this light index; `node` — current BSP node.
- **Outputs/Return:** void; mutates `surf->dlightbits` and `surf->dlightframe`.
- **Side effects:** Writes to world surface structs.
- **Calls:** `DotProduct`, `R_MarkLights` (recursive)
- **Notes:** Uses `DLIGHT_CUTOFF` (64) to cull early. Leaf nodes (`contents != -1`) terminate recursion.

### R_PushDlights
- **Signature:** `void R_PushDlights(void)`
- **Purpose:** Entry point called each frame to mark all dlight-affected surfaces; skipped when `gl_flashblend` is on.
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** Sets `r_dlightframecount`; calls `R_MarkLights` for every dlight from world root node.
- **Calls:** `R_MarkLights`

### RecursiveLightPoint
- **Signature:** `int RecursiveLightPoint(mnode_t *node, vec3_t start, vec3_t end)`
- **Purpose:** Casts a vertical ray down the BSP tree to find the lightmap value at a point; writes result to `pointcolor`.
- **Inputs:** BSP node, ray start/end (typically `p` to `p - 2048` Z).
- **Outputs/Return:** `-1` = no hit, `0` = unlit surface, `1` = lit surface with `pointcolor` set.
- **Side effects:** Writes `pointcolor`, `lightspot`, `lightplane`.
- **Calls:** `DotProduct`, `VectorCopy`, `RecursiveLightPoint` (recursive)
- **Notes:** Skips SURF_DRAWTURB and SURF_DRAWSKY (no lightmaps). Applies `gl_modulate` and `lightstyles` scaling across all `MAXLIGHTMAPS` layers.

### R_LightPoint
- **Signature:** `void R_LightPoint(vec3_t p, vec3_t color)`
- **Purpose:** Computes the total light color at a world point for entity illumination, combining static lightmap sample and all active dlights.
- **Inputs:** `p` — world position; `color` — output RGB.
- **Outputs/Return:** void; fills `color`.
- **Side effects:** Reads `currententity->origin`; applies `gl_modulate` scaling to final result.
- **Calls:** `RecursiveLightPoint`, `VectorSubtract`, `VectorLength`, `VectorMA`, `VectorScale`

### R_AddDynamicLights
- **Signature:** `void R_AddDynamicLights(msurface_t *surf)`
- **Purpose:** Accumulates dynamic light contributions into `s_blocklights` for a surface whose `dlightbits` is set.
- **Inputs:** `surf` — the surface being lit.
- **Outputs/Return:** void; modifies `s_blocklights`.
- **Side effects:** Writes `s_blocklights`.
- **Calls:** `DotProduct`, `Q_ftol`
- **Notes:** Uses Chebyshev-like distance approximation (`sd + td>>1`) rather than true Euclidean distance for performance.

### R_BuildLightMap
- **Signature:** `void R_BuildLightMap(msurface_t *surf, byte *dest, int stride)`
- **Purpose:** Combines all static lightmap layers and dynamic lights into a final RGBA texture row for upload.
- **Inputs:** `surf` — surface; `dest` — destination texture buffer; `stride` — row pitch adjustment.
- **Outputs/Return:** void; writes RGBA bytes to `dest`.
- **Side effects:** Reads/writes `s_blocklights`; calls `R_AddDynamicLights`; calls `ri.Sys_Error` on bad input.
- **Calls:** `R_AddDynamicLights`, `R_SetCacheState` (indirectly via caller), `memset`, `Q_ftol`, `ri.Sys_Error`
- **Notes:** Supports monolightmap modes via `gl_monolightmap->string[0]` switch ('0'=color, 'L'/'I'=luminance, 'C'=fake color, 'A'=alpha-only).

### R_SetCacheState
- **Signature:** `void R_SetCacheState(msurface_t *surf)`
- **Purpose:** Snapshots current lightstyle values into `surf->cached_light[]` to detect changes requiring lightmap rebuild.
- **Calls:** None beyond array access.

## Control Flow Notes
- **Per-frame (non-flashblend):** `R_PushDlights` is called before BSP rendering to mark surfaces; `R_BuildLightMap` is called per surface when its lightmap is stale or `dlightframe` matches `r_framecount`.
- **Per-frame (flashblend):** `R_RenderDlights` is called during the 3D scene pass after geometry; dlight marking is skipped entirely.
- `R_LightPoint` is called per entity during `gl_rmain.c`'s entity setup phase.

## External Dependencies
- **Includes:** `gl_local.h` (pulls in all GL, engine math, and renderer state)
- **Defined elsewhere:** `r_framecount`, `r_newrefdef`, `r_worldmodel`, `r_origin`, `vpn`, `vright`, `vup`, `currententity`, `gl_flashblend`, `gl_modulate`, `gl_monolightmap` (cvars/globals from `gl_rmain.c`); `Q_ftol` (platform math); all `qgl*` function pointers; `ri` (renderer import table)
