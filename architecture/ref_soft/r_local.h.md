# ref_soft/r_local.h

## File Purpose
Central internal header for the Quake 2 software renderer (`ref_soft`). It aggregates all shared types, constants, global variable declarations, and function prototypes used across the software rasterization subsystem. Acts as the "glue" header that every `.c` file in `ref_soft` includes.

## Core Responsibilities
- Define image, video, and rendering state types used throughout the software renderer
- Declare all renderer-global variables (frame counters, edge lists, surface caches, view state)
- Declare the full public API surface for the software renderer (Draw_*, R_*, D_*, SWimp_*)
- Define rasterizer constants (viewport limits, clip planes, turb sizes, mip levels)
- Declare cvars controlling software renderer behavior (`sw_*`, `r_*`)
- Provide the driver/implementation boundary via `SWimp_*` function declarations

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `imagetype_t` | enum | Classifies image resources (skin, sprite, wall, pic, sky) |
| `image_t` | struct | Loaded image with name, type, dimensions, transparency flag, mip level pixel arrays |
| `viddef_t` | struct | Video framebuffer descriptor: pixel buffer, colormap, alphamap, dimensions |
| `rserr_t` | enum | Mode-set result codes (ok, invalid fullscreen/mode, unknown) |
| `oldrefdef_t` | struct | Legacy view definition: viewport rects, FOV, view origin/angles, ambient light |
| `finalvert_t` | struct | Transformed alias model vertex with screen u/v/s/t, light, z-inverse, clip flags |
| `affinetridesc_t` | struct | Descriptor for affine-mapped triangle rasterization (skin, triangles, verts) |
| `drawsurf_t` | struct | Parameters for surface texture generation pass |
| `surfcache_t` | struct | Cached lit surface tile; linked list with LRU-style owner pointer |
| `surf_t` | struct | Active surface entry in the BSP edge/span pipeline |
| `edge_t` | struct | Scan-converted BSP edge with u/u_step, prev/next, surface refs |
| `clipplane_t` | struct | View frustum clip plane with normal, dist, and left/right edge flags |
| `espan_t` | struct | Horizontal span (u, v, count) for rasterizer |
| `polydesc_t` | struct | Polygon draw descriptor for R_POLY.C and sprite setup |
| `bedge_t` | struct | Clipped bmodel edge between two `mvertex_t` points |
| `alight_t` | struct | Alias model lighting: ambient, shade intensity, light vector |
| `emitpoint_t` | struct | Projected polygon vertex (u, v, s, t, zi) |
| `aliastriangleparms_t` | struct | Three `finalvert_t` pointers passed to triangle rasterizer |
| `swstate_t` | struct | Persistent SW renderer state: fullscreen flag, prev mode, gamma table, palette |
| `vrect_t` | struct | Integer rectangle with linked-list pointer |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `vid` | `viddef_t` | global | Active video framebuffer and colormap |
| `r_refdef` | `oldrefdef_t` | global | Current frame's viewport and view parameters |
| `r_newrefdef` | `refdef_t` | global | New-style refdef passed from client each frame |
| `r_drawsurf` | `drawsurf_t` | global | Current surface being texture-generated |
| `sc_rover` / `sc_base` | `surfcache_t*` | global | Surface cache allocation rover and base pointer |
| `d_viewbuffer` | `pixel_t*` | global | Active pixel output buffer |
| `d_pzbuffer` | `short*` | global | Z-buffer for depth testing |
| `surfaces`, `surface_p`, `surf_max` | `surf_t*` | global | Surface pool for BSP surface stack |
| `r_edges`, `edge_p`, `edge_max` | `edge_t*` | global | Edge pool for scan-line edge list |
| `newedges[MAXHEIGHT]` / `removeedges[MAXHEIGHT]` | `edge_t*[]` | global | Per-scanline edge insertion and removal lists |
| `edge_head/tail/aftertail` | `edge_t` | global | Sentinel nodes for active edge list |
| `view_clipplanes[4]` | `clipplane_t` | global | View frustum clip planes |
| `aliastriangleparms` | `aliastriangleparms_t` | global | Current alias triangle vertex pointers |
| `sw_state` | `swstate_t` | global | Persistent software renderer mode/palette state |
| `ri` | `refimport_t` | global | Engine import function table |
| `d_8to24table[256]` | `unsigned[]` | global | 8-bit to 32-bit palette lookup |
| `r_framecount` | `int` | global | Frame sequence counter |
| `r_visframecount` | `int` | global | Visibility frame counter |
| `r_worldmodel` | `model_t*` | global | Currently loaded world BSP model |
| `currententity` / `currentmodel` | pointers | global | Entity and model being rendered this pass |
| `colormap` | `void*` | global | Active lighting colormap |
| `r_notexture_mip` | `image_t*` | global | Fallback texture |

## Key Functions

No function bodies are defined here; this is a header. All entries below are declarations.

### SWimp_* (platform implementation boundary)
- Signature: Various — `SWimp_BeginFrame`, `SWimp_EndFrame`, `SWimp_Init`, `SWimp_SetPalette`, `SWimp_Shutdown`, `SWimp_SetMode`, `SWimp_AppActivate`
- Purpose: Platform abstraction layer; implemented per-OS (win32, linux, etc.)
- Notes: Clean separation between renderer logic and windowing/display system.

### R_Init / R_Shutdown
- Signature: `qboolean R_Init(void *hInstance, void *wndProc)` / `void R_Shutdown(void)`
- Purpose: Renderer initialization and teardown; called by the client vid system.

### R_RenderFrame
- Signature: `void R_RenderFrame(refdef_t *fd)`
- Purpose: Main per-frame render entry point; drives world, entity, particle, and overlay rendering.

### R_BeginRegistration / R_RegisterModel / R_EndRegistration
- Purpose: Map load lifecycle — clear old assets, register models, finalize.

### D_CacheSurface
- Signature: `surfcache_t *D_CacheSurface(msurface_t *surface, int miplevel)`
- Purpose: Retrieve or generate a cached lit surface at the given mip level.

### R_ScanEdges
- Signature: `void R_ScanEdges(void)`
- Purpose: Core software rasterizer — walks the active edge list per scanline to generate spans.

### R_EmitEdge / R_ClipEdge
- Purpose: Project and clip BSP edges into the screen-space edge list.

### Draw_* functions
- Purpose: 2D overlay drawing API (pics, chars, fills, fade, stretch) matching the `refimport_t` draw interface.

## Control Flow Notes
- **Init**: `R_Init` → `R_Register` (cvars), `R_InitImages`, `R_InitCaches`, `Draw_InitLocal`, `SWimp_Init`
- **Per-frame**: `R_RenderFrame` → `R_SetupFrame` → `R_RenderWorld` → `R_ScanEdges` → `D_DrawSurfaces` → entity/particle passes → `SWimp_EndFrame`
- **Map load**: `R_BeginRegistration` → `R_NewMap` → asset registration → `R_EndRegistration`
- **Shutdown**: `R_Shutdown` → `R_ShutdownImages` → `SWimp_Shutdown`

## External Dependencies
- `../client/ref.h` — `refdef_t`, `refimport_t`, `entity_t`, `cvar_t`
- `r_model.h` — `model_t`, `msurface_t`, `mvertex_t`, `mplane_t`, `mnode_t`, `mleaf_t`, `medge_t`, `mtexinfo_t`
- `qcommon/qfiles.h` (transitively) — `dtriangle_t`, `fixed16_t`, `fixed8_t`
- `asm_draw.h` — must stay in sync with `clipplane_t`, `edge_t`, `espan_t`, `oldrefdef_t` (noted inline)
- `d_ifacea.h` — must stay in sync with `finalvert_t`, `MAXHEIGHT`, `TURB_TEX_SIZE`, `CYCLE`
