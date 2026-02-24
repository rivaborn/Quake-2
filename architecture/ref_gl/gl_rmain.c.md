# ref_gl/gl_rmain.c

## File Purpose
Central orchestration file for the OpenGL renderer (`ref_gl`). It owns the per-frame render pipeline, manages all renderer cvars, implements the `GetRefAPI` export entry point, and handles renderer initialization and shutdown.

## Core Responsibilities
- Exports `GetRefAPI`, the DLL entry point that binds the renderer to the engine
- Drives the full 3D render pipeline: setup → world → entities → dlights → particles → alpha surfaces → screen blend
- Manages frustum setup and entity-level culling (`R_CullBox`)
- Dispatches entity rendering by model type (alias, brush, sprite, beam, null)
- Draws sprite models, beam entities, and particles directly
- Initializes/registers ~50 renderer cvars and console commands
- Handles mode-setting, GL extension detection, and stereo initialization

## Key Types / Data Structures
| Name | Kind | Purpose |
|------|------|---------|
| `viddef_t` | struct (extern) | Video dimensions (`vid.width`, `vid.height`) |
| `refimport_t` | struct | Engine callbacks imported into renderer |
| `refexport_t` | struct | Renderer functions exported to engine |
| `glconfig_t` | struct | Static GL capability/renderer identification |
| `glstate_t` | struct | Dynamic GL state (camera sep, stereo, prev_mode) |
| `refdef_t` | struct | Per-frame view definition (angles, org, FOV, entities, particles) |
| `cplane_t` | struct | Frustum plane with normal, dist, signbits |

## Global / File-Static State
| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `vid` | `viddef_t` | global | Current video dimensions |
| `ri` | `refimport_t` | global | Engine import table |
| `r_worldmodel` | `model_t *` | global | Loaded BSP world model |
| `gldepthmin/max` | `float` | global | Depth range bounds (ztrick alternates these) |
| `gl_config` | `glconfig_t` | global | GL vendor/renderer caps |
| `gl_state` | `glstate_t` | global | Mutable GL state |
| `frustum[4]` | `cplane_t[]` | global | View frustum planes |
| `r_visframecount` | `int` | global | PVS epoch counter |
| `r_framecount` | `int` | global | Dlight push-check epoch |
| `c_brush_polys`, `c_alias_polys` | `int` | global | Per-frame polygon counters for `r_speeds` |
| `v_blend[4]` | `float[]` | global | Screen blend color/alpha |
| `vup`, `vpn`, `vright`, `r_origin` | `vec3_t` | global | View basis vectors and eye position |
| `r_world_matrix[16]` | `float[]` | global | Captured GL modelview matrix |
| `r_newrefdef` | `refdef_t` | global | Current frame's view definition |
| `r_viewcluster`, `r_viewcluster2`, `r_oldviewcluster`, `r_oldviewcluster2` | `int` | global | PVS cluster tracking (dual for water transitions) |
| `r_rawpalette[256]` | `unsigned` | global | Expanded 32-bit cinematic palette |
| ~50 `cvar_t *` | `cvar_t *` | global | All renderer/GL cvars |

## Key Functions

### GetRefAPI
- **Signature:** `refexport_t GetRefAPI(refimport_t rimp)`
- **Purpose:** DLL entry point; stores import table and fills export struct with all renderer function pointers.
- **Inputs:** `rimp` — engine-provided callbacks
- **Outputs/Return:** Populated `refexport_t`
- **Side effects:** Sets global `ri`; calls `Swap_Init()`
- **Calls:** `Swap_Init`
- **Notes:** Must be the first function called by the engine after loading the renderer DLL.

### R_Init
- **Signature:** `int R_Init(void *hinstance, void *hWnd)`
- **Purpose:** Full renderer initialization: palette, cvars, QGL, OS GL context, mode, extension detection, image/model/particle subsystems.
- **Inputs:** Platform window handles
- **Outputs/Return:** 0 on success, -1 on failure
- **Side effects:** Allocates GL context, registers cvars and commands, initializes images/models
- **Calls:** `Draw_GetPalette`, `R_Register`, `QGL_Init`, `GLimp_Init`, `R_SetMode`, `GL_SetDefaultState`, `GL_InitImages`, `Mod_Init`, `R_InitParticleTexture`, `Draw_InitLocal`

### R_RenderFrame
- **Signature:** `void R_RenderFrame(refdef_t *fd)`
- **Purpose:** Public per-frame 3D render entry point called by engine each frame.
- **Inputs:** `fd` — current view definition
- **Side effects:** Drives full render pipeline, updates `r_lightlevel` cvar, switches to 2D mode
- **Calls:** `R_RenderView`, `R_SetLightLevel`, `R_SetGL2D`

### R_RenderView
- **Signature:** `void R_RenderView(refdef_t *fd)`
- **Purpose:** Executes the complete 3D scene render in order.
- **Inputs:** `fd` copied into `r_newrefdef`
- **Side effects:** Modifies all frame-global state; issues all GL draw calls for the scene
- **Calls:** `R_PushDlights`, `R_SetupFrame`, `R_SetFrustum`, `R_SetupGL`, `R_MarkLeaves`, `R_DrawWorld`, `R_DrawEntitiesOnList`, `R_RenderDlights`, `R_DrawParticles`, `R_DrawAlphaSurfaces`, `R_Flash`

### R_BeginFrame
- **Signature:** `void R_BeginFrame(float camera_separation)`
- **Purpose:** Per-frame setup before any drawing: mode changes, logging, gamma, 2D matrix, draw buffer, texture mode updates, depth clear.
- **Side effects:** May trigger vid restart; calls `R_Clear`
- **Calls:** `GLimp_BeginFrame`, `GL_TextureMode`, `GL_UpdateSwapInterval`, `R_Clear`

### R_SetupFrame
- **Signature:** `void R_SetupFrame(void)`
- **Purpose:** Extracts view origin/angles, updates PVS clusters (with above/below water check), copies blend color, resets poly counters.
- **Calls:** `AngleVectors`, `Mod_PointInLeaf`

### R_SetupGL
- **Signature:** `void R_SetupGL(void)`
- **Purpose:** Configures GL viewport, projection matrix (via `MYgluPerspective`), modelview matrix from view angles, captures `r_world_matrix`, sets culling/blend/depth state.
- **Calls:** `MYgluPerspective`, `qglGetFloatv`

### R_DrawEntitiesOnList
- **Signature:** `void R_DrawEntitiesOnList(void)`
- **Purpose:** Two-pass entity dispatch: opaque first (depth writes on), then translucent (depth writes off).
- **Calls:** `R_DrawBeam`, `R_DrawNullModel`, `R_DrawAliasModel`, `R_DrawBrushModel`, `R_DrawSpriteModel`

### R_DrawParticles
- **Signature:** `void R_DrawParticles(void)`
- **Purpose:** Renders all particles, switching between `GL_EXT_point_parameters` GL_POINTS path and triangle-billboard fallback.
- **Calls:** `GL_DrawParticles`

### R_CullBox
- **Signature:** `qboolean R_CullBox(vec3_t mins, vec3_t maxs)`
- **Purpose:** Returns true if AABB is fully outside the 4-plane view frustum.
- **Calls:** `BOX_ON_PLANE_SIDE` (macro)

### R_SetFrustum
- **Signature:** `void R_SetFrustum(void)`
- **Purpose:** Builds 4 frustum planes by rotating VPN by FOV angles, then computes dist and signbits per plane.
- **Calls:** `RotatePointAroundVector`, `DotProduct`, `SignbitsForPlane`

### R_Clear
- **Signature:** `void R_Clear(void)`
- **Purpose:** Clears depth (and optionally color) buffer; implements ztrick by alternating depth range and compare function.
- **Side effects:** Writes `gldepthmin`/`gldepthmax`; issues `qglDepthRange`

### R_SetPalette
- **Signature:** `void R_SetPalette(const unsigned char *palette)`
- **Purpose:** Loads cinematic or default palette into `r_rawpalette` and uploads to GL texture palette.
- **Calls:** `GL_SetTexturePalette`

## Control Flow Notes
- **Init:** `GetRefAPI` → `R_Init` (one-time startup)
- **Per frame:** `R_BeginFrame` → `R_RenderFrame` (`R_RenderView` pipeline) → `GLimp_EndFrame`
- `R_RenderView` is the heart of the 3D pipeline; all scene subsystems are called from it in a fixed order.
- `R_SetGL2D` is called after 3D rendering to transition into 2D overlay mode for HUD/menus.

## External Dependencies
- `gl_local.h` — renderer-local types, macros, all qgl declarations
- `GLimp_*` — OS/platform GL implementation (context, mode, frame begin/end)
- `QGL_Init` / `QGL_Shutdown` — dynamic OpenGL function binding layer
- `R_DrawAliasModel`, `R_DrawBrushModel`, `R_DrawBeam`, `R_DrawWorld`, `R_MarkLeaves`, `R_PushDlights`, `R_RenderDlights`, `R_DrawAlphaSurfaces`, `R_LightPoint` — defined in other `ref_gl/` files
- `Mod_Init`, `Mod_FreeAll`, `Mod_PointInLeaf` — model subsystem (`gl_model.c`)
- `GL_InitImages`, `GL_ShutdownImages`, `GL_TextureMode` — image subsystem (`gl_image.c`)
- `d_8to24table` — global 8-to-32-bit color table, defined elsewhere
- `ri` (refimport) — all engine services (cvars, console, errors) accessed through this
