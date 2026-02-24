# ref_soft/r_main.c

## File Purpose
Central orchestration file for the Quake 2 software renderer (`ref_soft`). It owns the renderer's global state, implements the per-frame render pipeline, and exposes the `GetRefAPI` entry point that the engine uses to bind all renderer functions at runtime.

## Core Responsibilities
- Declare and initialize all global renderer state (view vectors, screen geometry, frame counters, cvars)
- Register/unregister cvars and console commands on init/shutdown
- Drive the full frame render sequence: setup → PVS marking → edge drawing → entity drawing → particles → palette
- Manage video mode changes and z-buffer/surface-cache lifecycle via `R_BeginFrame` / `R_InitGraphics`
- Build the `refexport_t` vtable returned to the engine via `GetRefAPI`
- Handle palette loading, gamma correction, and cinematic palette switching
- Cull and dispatch brush-model entities through the BSP edge system
- Draw alias/sprite/beam entities in two passes (opaque then translucent)

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `viddef_t` | struct (extern) | Video width/height, buffer pointer, row bytes, colormap |
| `refimport_t` | struct (extern) | Engine callbacks (Cvar_Get, Sys_Error, Con_Printf, etc.) |
| `refexport_t` | struct (extern) | Renderer function vtable returned to engine |
| `refdef_t` | struct (extern) | Per-frame scene descriptor (view origin, angles, entities, particles) |
| `oldrefdef_t` | struct (extern) | Legacy internal refdef holding xOrigin/yOrigin and view vectors |
| `swstate_t` | struct (extern) | Software renderer state: gamma table, current palette, previous mode |
| `alight_t` | struct (extern) | Ambient lighting descriptor (ambient, shadelight, lightvec) |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `vid` | `viddef_t` | global | Video surface descriptor shared with driver |
| `ri` | `refimport_t` | global | Engine import table |
| `d_8to24table` | `unsigned[256]` | global | 8-bit palette → 32-bit RGBA lookup |
| `r_worldmodel` | `model_t *` | global | Currently loaded world BSP model |
| `r_newrefdef` | `refdef_t` | global | Current frame's scene parameters |
| `sw_state` | `swstate_t` | global | Gamma table and active palette |
| `r_framecount` | `int` | global | Monotonic frame counter (starts at 1) |
| `r_visframecount` | `int` | global | PVS update counter |
| `r_viewcluster` / `r_oldviewcluster` | `int` | global | Current and previous BSP cluster for PVS |
| `vup/vpn/vright` | `vec3_t` | global | Current view axes (modified during bmodel rendering) |
| `base_vup/base_vpn/base_vright` | `vec3_t` | global | Saved world-space view axes |
| `r_refdef` | `oldrefdef_t` | global | Internal screen-space projection parameters |
| `r_dowarp` | `qboolean` | global | Flag: apply underwater warp this frame |
| `d_pzbuffer` | `short *` | global (cond.) | Z-buffer allocation |
| `auxedges` | `edge_t *` (implied) | global | Heap-allocated edge array when stack is too small |

## Key Functions

### GetRefAPI
- **Signature:** `refexport_t GetRefAPI(refimport_t rimp)`
- **Purpose:** DLL entry point; stores engine import table and fills the export vtable.
- **Inputs:** `rimp` — engine callback struct.
- **Outputs/Return:** Fully populated `refexport_t`.
- **Side effects:** Writes `ri` global; calls `Swap_Init()`.
- **Calls:** `Swap_Init`
- **Notes:** Only external linkage entry point for the renderer DLL.

---

### R_Init
- **Signature:** `qboolean R_Init(void *hInstance, void *wndProc)`
- **Purpose:** Full renderer initialization: images, models, draw layer, textures, turb tables, clip plane flags, cvar registration, palette, and window creation.
- **Inputs:** Platform window handles.
- **Outputs/Return:** `true` on success (never returns false in this code).
- **Side effects:** Allocates image/model systems; registers cvars and commands; calls `SWimp_Init`; opens window via `R_BeginFrame(0)`.
- **Calls:** `R_InitImages`, `Mod_Init`, `Draw_InitLocal`, `R_InitTextures`, `R_InitTurb`, `R_Register`, `Draw_GetPalette`, `SWimp_Init`, `R_BeginFrame`

---

### R_Shutdown
- **Signature:** `void R_Shutdown(void)`
- **Purpose:** Frees z-buffer, surface cache, colormap; unregisters commands; frees models and images; shuts down SW imp layer.
- **Side effects:** `free()` on `d_pzbuffer`, `sc_base`, `vid.colormap`; nulls all three.
- **Calls:** `D_FlushCaches`, `R_UnRegister`, `Mod_FreeAll`, `R_ShutdownImages`, `SWimp_Shutdown`

---

### R_RenderFrame
- **Signature:** `void R_RenderFrame(refdef_t *fd)`
- **Purpose:** Top-level per-frame render dispatch. Copies refdef, runs setup, PVS mark, dynamic lights, edge rasterization, entity passes, particles, alpha surfaces, palette blend, and optional warp.
- **Inputs:** `fd` — scene descriptor for this frame.
- **Side effects:** Updates `r_newrefdef`; writes timing globals; triggers screen warp if `r_dowarp`.
- **Calls:** `R_SetupFrame`, `R_MarkLeaves`, `R_PushDlights`, `R_EdgeDrawing`, `R_DrawEntitiesOnList`, `R_DrawParticles`, `R_DrawAlphaSurfaces`, `R_SetLightLevel`, `D_WarpScreen`, `R_CalcPalette`, `R_PrintAliasStats`, `R_PrintTimes`, `R_PrintDSpeeds`

---

### R_BeginFrame
- **Signature:** `void R_BeginFrame(float camera_separation)`
- **Purpose:** Per-frame setup: rebuilds gamma table if dirty, handles video mode changes (retrying on failure), calls `R_InitGraphics` on mode switch.
- **Side effects:** May reallocate z-buffer and surface cache; sets `sw_state.prev_mode`; calls `SWimp_SetMode`.
- **Calls:** `Draw_BuildGammaTable`, `R_GammaCorrectAndSetPalette`, `SWimp_SetMode`, `R_InitGraphics`

---

### R_MarkLeaves
- **Signature:** `void R_MarkLeaves(void)`
- **Purpose:** Walks world BSP and stamps `visframe` on all leaves/nodes visible from the current cluster using PVS bitfield.
- **Side effects:** Increments `r_visframecount`; sets `node->visframe` / `leaf->visframe`; updates `r_oldviewcluster`.
- **Calls:** `Mod_ClusterPVS`
- **Notes:** Short-circuits if cluster unchanged and `r_novis` is off; `sw_lockpvs` freezes the PVS.

---

### R_EdgeDrawing
- **Signature:** `void R_EdgeDrawing(void)`
- **Purpose:** Allocates edge/surface arrays (stack or heap), renders the world BSP, brush entities, then rasterizes via `R_ScanEdges`.
- **Side effects:** Sets `r_edges`, `surfaces`, `surf_max`; triggers timing probes.
- **Calls:** `R_BeginEdgeFrame`, `R_RenderWorld`, `R_DrawBEntitiesOnList`, `R_ScanEdges`, `R_SurfacePatch`, `Sys_Milliseconds`

---

### R_DrawEntitiesOnList
- **Signature:** `void R_DrawEntitiesOnList(void)`
- **Purpose:** Two-pass entity draw: opaque first, then translucent. Dispatches beams, sprites, and alias models.
- **Calls:** `R_DrawBeam`, `R_DrawSprite`, `R_AliasDrawModel`, `R_DrawNullModel`

---

### R_DrawBEntitiesOnList
- **Signature:** `void R_DrawBEntitiesOnList(void)`
- **Purpose:** Inserts brush-model entities into the edge pipeline with frustum culling and BSP top-node detection.
- **Calls:** `RotatedBBox`, `R_BmodelCheckBBox`, `R_FindTopnode`, `R_RotateBmodel`, `R_PushDlights`, `R_DrawSolidClippedSubmodelPolygons`, `R_DrawSubmodelPolygons`, `R_TransformFrustum`

---

### R_NewMap
- **Signature:** `void R_NewMap(void)`
- **Purpose:** Resets per-map state: view cluster, surface/edge array sizing and allocation.
- **Side effects:** `malloc` for `surfaces` and `auxedges` when counts exceed stack limits.

---

### R_CalcPalette
- **Signature:** `void R_CalcPalette(void)`
- **Purpose:** Blends the active palette with `r_newrefdef.blend` (damage/pickup flash) and applies gamma correction.
- **Calls:** `R_GammaCorrectAndSetPalette`

---

### Draw_GetPalette
- **Signature:** `void Draw_GetPalette(void)`
- **Purpose:** Loads `pics/colormap.pcx`, sets `vid.colormap`/`vid.alphamap`, and builds `d_8to24table`.
- **Calls:** `LoadPCX`, `ri.Sys_Error`, `free`

---

### R_GammaCorrectAndSetPalette / Draw_BuildGammaTable
- Apply the `vid_gamma` curve to a 256-entry palette and push it to the SW imp layer.

---

### R_DrawBeam
- Constructs 6 rotated quad segments between `e->oldorigin` and `e->origin` and rasterizes them via `R_IMFlatShadedQuad`.

---

**Notes on trivial helpers:**
- `R_InitTextures` — builds a 16×16 checkerboard mip chain into a static buffer.
- `R_InitTurb` — precomputes sine/integer-sine/blank tables for water warp.
- `R_Register` / `R_UnRegister` — register/remove all cvars and console commands.
- `R_BmodelCheckBBox` — 4-plane frustum test returning clip flags or `BMODEL_FULLY_CLIPPED`.
- `R_FindTopnode` — descends BSP to find the splitting node for a bounding box.
- `RotatedBBox` — computes AABB of an OBB by enumerating all 8 corners.
- `R_SetLightLevel` — samples light at view origin and writes `r_lightlevel->value`.
- `R_CinematicSetPalette` — clears framebuffer, flushes, then sets a cinematic 24-bit palette.

## Control Flow Notes

| Phase | Function |
|-------|----------|
| Init | `GetRefAPI` → `R_Init` → `R_BeginFrame(0)` |
| Map load | `R_NewMap` (called from engine via registered export) |
| Frame start | `R_BeginFrame` (mode change / gamma check) |
| Frame render | `R_RenderFrame`: setup → mark PVS → dlights → edge raster → entities → particles → palette |
| Frame end | `SWimp_EndFrame` (bound directly in `GetRefAPI`) |
| Shutdown | `R_Shutdown` |

## External Dependencies

- **Includes:** `r_local.h` (pulls in all `ref_soft` internals and `qcommon.h` transitively)
- **Defined elsewhere:**
  - `SWimp_*` — platform SW imp layer (`win32/rw_imp.c`, `linux/rw_*.c`, etc.)
  - `R_SetupFrame`, `R_TransformFrustum`, `R_BeginEdgeFrame`, `R_ScanEdges`, `R_SurfacePatch` — `r_edge.c` / `r_misc.c`
  - `R_RenderWorld`, `R_DrawSolidClippedSubmodelPolygons`, `R_DrawSubmodelPolygons` — `r_bsp.c`
  - `R_AliasDrawModel` — `r_alias.c`; `R_DrawSprite` — `r_sprite.c`; `R_DrawParticles` — `r_part.c`
  - `R_DrawAlphaSurfaces` — `r_rast.c`/`r_surf.c`; `R_IMFlatShadedQuad` — `r_draw.c`
  - `D_WarpScreen`, `D_FlushCaches` — `r_warp.c` / `r_misc.c`
  - `Mod_*` — `r_model.c`; `R_*Images` — `r_image.c`; `Draw_*` — `r_draw.c`
  - `R_LightPoint`, `R_PushDlights` — `r_light.c`
  - `Mod_ClusterPVS` — `r_model.c`
  - `sintable`, `intsintable`, `blanktable` — `r_local.h` / `r_vars`
  - `view_clipplanes`, `insubmodel`, `r_dlightframecount`, `modelorg`, `currententity`, `r_entorigin` — `r_local.h` globals defined in driver/edge files
