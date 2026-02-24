# ref_gl/gl_local.h

## File Purpose
Central internal header for the Quake 2 OpenGL renderer (`ref_gl`). Defines all shared types, global state declarations, render CVars, and function prototypes used across the GL renderer subsystem. Acts as the single include point that binds together image management, model data, GL configuration, and the platform abstraction layer.

## Core Responsibilities
- Define `image_t` and `imagetype_t` for GPU texture management
- Declare all renderer-facing CVars (quality, extensions, lighting, particles)
- Expose the `glconfig_t` / `glstate_t` structs for hardware capability and runtime GL state
- Declare all cross-file render function prototypes (draw, model, world, sky, lighting)
- Define GL renderer identification bitmasks for hardware-specific workarounds
- Declare the `GLimp_*` platform abstraction interface
- Expose `refimport_t ri` for engine callback access

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `viddef_t` | struct | Holds display width/height as seen by the game |
| `imagetype_t` | enum | Classifies texture purpose: skin, sprite, wall, pic, sky |
| `image_t` | struct | Per-texture descriptor: GL texnum, dimensions, UV scrap coords, registration sequence, alpha/palette flags |
| `rserr_t` | enum | Renderer set-mode error codes (ok, invalid fullscreen/mode, unknown) |
| `glvert_t` | struct | Immediate-mode vertex: position (xyz), texcoord (st), color (rgb) |
| `glconfig_t` | struct | Static GL hardware capabilities: renderer ID bitmask, vendor/version/extension strings, CDS allowed flag |
| `glstate_t` | struct | Mutable GL runtime state: current textures, TMU, stereo, gamma tables, lightmap tex base, fullscreen flag |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `vid` | `viddef_t` | global | Current video dimensions |
| `gltextures[MAX_GLTEXTURES]` | `image_t[1024]` | global | All registered GL textures |
| `numgltextures` | `int` | global | Count of active textures |
| `r_notexture`, `r_particletexture` | `image_t *` | global | Fallback and particle textures |
| `currententity`, `currentmodel` | pointer | global | Entity/model being rendered this draw call |
| `r_visframecount`, `r_framecount` | `int` | global | PVS and frame counters for culling |
| `frustum[4]` | `cplane_t` | global | View frustum planes |
| `c_brush_polys`, `c_alias_polys` | `int` | global | Per-frame polygon counters (r_speeds) |
| `vup`, `vpn`, `vright`, `r_origin` | `vec3_t` | global | View basis vectors and eye position |
| `r_newrefdef` | `refdef_t` | global | Current frame render definition |
| `r_viewcluster`, `r_viewcluster2`, `r_oldviewcluster`, `r_oldviewcluster2` | `int` | global | PVS cluster tracking |
| `r_world_matrix[16]` | `float` | global | OpenGL world transform matrix |
| `d_8to24table[256]` | `unsigned` | global | Palette to 32-bit RGBA lookup |
| `gl_config` | `glconfig_t` | global | Static hardware config |
| `gl_state` | `glstate_t` | global | Mutable GL runtime state |
| `ri` | `refimport_t` | global | Engine import function table |
| `gldepthmin`, `gldepthmax` | `float` | global | Depth range values |
| `gl_lightmap_format`, `gl_solid_format`, etc. | `int` | global | Active GL internal texture formats |
| `registration_sequence` | `int` | global | Current asset registration epoch |

## Key Functions

All entries here are declarations only; implementations reside in other `ref_gl/*.c` files.

### GL_Bind / GL_MBind / GL_TexEnv / GL_EnableMultitexture / GL_SelectTexture
- **Purpose:** Core GL texture state management — bind textures to TMUs, set environment modes, toggle multitexture path.

### R_Init / R_Shutdown
- **Signature:** `int R_Init(void *hinstance, void *hWnd)` / `void R_Shutdown(void)`
- **Purpose:** Top-level renderer lifecycle: initialize GL context, CVars, images, models; tear down on exit.

### R_RenderView
- **Signature:** `void R_RenderView(refdef_t *fd)`
- **Purpose:** Main per-frame scene render entry point — sets up view, culls, draws world and entities.

### R_DrawAliasModel / R_DrawBrushModel / R_DrawSpriteModel / R_DrawBeam
- **Purpose:** Per-entity-type draw dispatch called during the render loop.

### R_LightPoint / R_PushDlights / R_RenderDlights / R_MarkLights
- **Purpose:** Dynamic lighting: sample light at a point, push/render dynamic lights, mark lit BSP nodes.

### R_MarkLeaves
- **Purpose:** Updates PVS visibility, marks BSP leaves/nodes visible for the current frame.

### GL_DrawParticles
- **Signature:** `void GL_DrawParticles(int n, const particle_t particles[], const unsigned colortable[768])`
- **Purpose:** Renders all active particles using GL extension emulation (point parameters or quads).

### GLimp_* (platform abstraction)
- **Purpose:** `GLimp_Init/Shutdown/SetMode/BeginFrame/EndFrame/AppActivate/EnableLogging/LogNewFrame` — platform-specific GL context and window management; implemented per-OS outside `ref_gl`.

### Draw_* / R_BeginFrame / R_SwapBuffers / R_SetPalette
- **Purpose:** 2D overlay drawing (pics, chars, fills, fades, stretch-raw cinematic), frame boundary management, and palette upload.

## Control Flow Notes
This header is included by every `ref_gl/*.c` translation unit. `R_Init` initializes the renderer at startup; each game frame calls `R_BeginFrame` → `R_RenderView` (world + entities + particles + alpha surfaces + sky + dynamic lights) → `R_SwapBuffers` via `GLimp_EndFrame`. `R_Shutdown` tears everything down. The `GLimp_*` layer decouples this file from OS-specific window and context code.

## External Dependencies
- `<GL/gl.h>`, `<GL/glu.h>` — OpenGL API
- `../client/ref.h` — `refdef_t`, `refimport_t`, `entity_t`, `particle_t`, `cvar_t`, `vec3_t`, etc.
- `qgl.h` — Quake GL function pointer wrappers
- `gl_model.h` — `model_t`, `msurface_t`, `mnode_t`, `glpoly_t`, `dlight_t`, `cplane_t`
- All `extern` globals and function bodies defined across `gl_rmain.c`, `gl_image.c`, `gl_rsurf.c`, `gl_draw.c`, `gl_light.c`, `gl_warp.c`, `gl_mesh.c`, `gl_rmisc.c`, and platform `GLimp` implementations
