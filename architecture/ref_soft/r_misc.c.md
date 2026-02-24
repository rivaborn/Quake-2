# ref_soft/r_misc.c

## File Purpose
Miscellaneous setup and utility routines for the software renderer. Handles per-frame view parameter computation, frustum setup, mip-map scaling, and PCX screenshot output. Acts as the orchestration layer that prepares render state before geometry submission begins each frame.

## Core Responsibilities
- Compute and cache view-dependent parameters (scales, centers, clip rect) into `r_refdef` each frame
- Build frustum clip planes from screen edge normals and transform them into view space
- Set up per-scanline lookup tables (`d_scantable`, `zspantable`) for the rasterizer
- Manage mip-map bias and scaling via cvars `sw_mipcap`/`sw_mipscale`
- Apply self-modifying x86 code patches for optimized surface/alias rendering paths
- Write PCX-format screenshots to disk

## Key Types / Data Structures
None locally defined; uses engine types from `r_local.h`.

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `sw_mipcap` | `cvar_t *` | global | Max mip level cap |
| `sw_mipscale` | `cvar_t *` | global | Mip distance scale multiplier |
| `d_initial_rover` | `surfcache_t *` | global | Saved surface cache rover at frame start |
| `d_roverwrapped` | `qboolean` | global | Whether cache rover wrapped this frame |
| `d_minmip` | `int` | global | Resolved minimum mip level for this frame |
| `d_scalemip` | `float[3]` | global | Per-mip distance thresholds (basemip × sw_mipscale) |
| `basemip` | `float[3]` | static | Fixed base mip threshold ratios |
| `d_vrectx/y` | `int` | global | Viewport rect origin for particle clamp |
| `d_vrectright_particle` / `d_vrectbottom_particle` | `int` | global | Particle clip bounds (inset by max pixel size) |
| `d_pix_min/max/shift` | `int` | global | Particle pixel size range and shift for current resolution |
| `d_scantable` | `int[MAXHEIGHT]` | global | Row → pixel offset in color buffer |
| `zspantable` | `short*[MAXHEIGHT]` | global | Row → pointer into z-buffer |
| `alias_colormap` | `unsigned char *` | global | Pointer to current colormap (set from `vid.colormap`) |

## Key Functions

### D_Patch
- **Signature:** `void D_Patch(void)`
- **Purpose:** Applies self-modifying code patches to the inline x86 affine texturing and surface-fill routines.
- **Inputs:** None (reads `vid.colormap`, `colormap` global)
- **Outputs/Return:** void
- **Side effects:** Makes code memory pages writable; writes to `colormap`; calls `R_Surf8Patch`, `D_Aff8Patch`
- **Calls:** `Sys_MakeCodeWriteable`, `R_Surf8Patch`, `D_Aff8Patch`
- **Notes:** Guarded by `#if id386`; one-time code-write protection via static `protectset8` flag.

---

### D_ViewChanged
- **Signature:** `void D_ViewChanged(void)`
- **Purpose:** Recomputes per-scanline tables and particle-size parameters after the viewport changes; optionally clears z/color buffers for gallery mode.
- **Inputs:** Reads `r_refdef`, `vid`, `r_screenwidth`, `d_pzbuffer`, `r_newrefdef`
- **Outputs/Return:** void
- **Side effects:** Writes `d_scantable[]`, `zspantable[]`, `d_pix_*`, `d_vrect*`, `alias_colormap`; calls `Draw_Fill` and `memset` on `d_pzbuffer` in `RDF_NOWORLDMODEL` mode; calls `D_Patch`
- **Calls:** `Draw_Fill`, `D_Patch`
- **Notes:** Called at the end of `R_ViewChanged`.

---

### R_ViewChanged
- **Signature:** `void R_ViewChanged(vrect_t *vr)`
- **Purpose:** Recomputes all view projection constants (FOV, scale, center, screen edges, alias UV scales) from the current viewport rect and FOV angles.
- **Inputs:** `vr` — new viewport rectangle; reads `r_newrefdef` for FOV
- **Outputs/Return:** void
- **Side effects:** Writes extensively to `r_refdef`; sets `xscale`, `yscale`, `xcenter`, `ycenter`, `screenedge[]`, and alias-scaled variants; calls `D_ViewChanged`
- **Calls:** `VectorNormalize`, `D_ViewChanged`
- **Notes:** Double semicolon on FOV line is a benign typo. `yscale = xscale` (square pixels assumed).

---

### R_SetupFrame
- **Signature:** `void R_SetupFrame(void)`
- **Purpose:** Master per-frame setup: increments frame counter, builds view matrix, determines leaf/cluster, selects warp vs. normal render target, invokes `R_ViewChanged`, sets up frustum, and resets all frame counters.
- **Inputs:** Reads `r_newrefdef`, `r_fullbright`, `sw_waterwarp`, cvars
- **Outputs/Return:** void
- **Side effects:** Writes `r_framecount`, `modelorg`, `r_origin`, `vpn/vright/vup`, `r_viewleaf`, `r_viewcluster`, `r_dowarp`, `d_viewbuffer`, `r_screenwidth`, all `c_*`/`r_*` counters, `d_roverwrapped`, `d_initial_rover`, `d_minmip`, `d_scalemip[]`
- **Calls:** `D_FlushCaches`, `VectorCopy`, `AngleVectors`, `Mod_PointInLeaf`, `R_ViewChanged`, `R_TransformFrustum`, `R_SetUpFrustumIndexes`
- **Notes:** Entry point called once per rendered frame by the high-level renderer.

---

### R_TransformFrustum
- **Signature:** `void R_TransformFrustum(void)`
- **Purpose:** Rotates the four screen-edge clip plane normals into world space using the current view basis.
- **Side effects:** Writes `view_clipplanes[0..3].normal` and `.dist`
- **Calls:** `DotProduct`, `VectorCopy`

---

### R_SetUpFrustumIndexes
- **Signature:** `void R_SetUpFrustumIndexes(void)`
- **Purpose:** Precomputes per-plane AABB corner index pairs for fast frustum-vs-box tests.
- **Side effects:** Writes `r_frustum_indexes[]`, `pfrustum_indexes[]`

---

### R_TransformPlane
- **Signature:** `void R_TransformPlane(mplane_t *p, float *normal, float *dist)`
- **Purpose:** Transforms a BSP plane into view space for clipping.
- **Calls:** `DotProduct`, `TransformVector`
- **Notes:** TODO comment acknowledges rotating entities are unsupported.

---

### TransformVector
- **Signature:** `void TransformVector(vec3_t in, vec3_t out)`
- **Purpose:** Projects a vector onto the view basis (right/up/forward).
- **Notes:** C version under `!id386`; hand-rolled x87 FPU assembly version for Win32 x86.

---

### WritePCXfile
- **Signature:** `void WritePCXfile(char *filename, byte *data, int width, int height, int rowbytes, byte *palette)`
- **Purpose:** RLE-encodes a paletted 8-bit frame buffer to a PCX file on disk.
- **Side effects:** `malloc`/`free` of PCX work buffer; file I/O via `fopen`/`fwrite`/`fclose`
- **Notes:** RLE only escapes bytes with top two bits set (`0xc0` mask).

---

### R_ScreenShot_f
- **Signature:** `void R_ScreenShot_f(void)`
- **Purpose:** Console command handler — finds next available `quakeNN.pcx` slot, converts 32-bit palette to 24-bit, writes screenshot.
- **Calls:** `Com_sprintf`, `Sys_Mkdir`, `fopen`, `fclose`, `WritePCXfile`, `ri.Con_Printf`

---

### Notes
- `R_PrintTimes`, `R_PrintDSpeeds`, `R_PrintAliasStats` are trivial debug-stats printers that call `ri.Con_Printf` with cached timing/counter globals.
- `R_SurfacePatch` is a no-op stub on non-x86 platforms.

## Control Flow Notes
`R_SetupFrame` is the primary entry point, called once per frame by `R_RenderFrame`. It chains: `R_ViewChanged` → `D_ViewChanged` → `D_Patch`. Frustum setup follows immediately after. All downstream rasterization reads the tables and constants populated here.

## External Dependencies
- `r_local.h` — all renderer types, globals, and macros
- `Sys_MakeCodeWriteable`, `Sys_Milliseconds`, `Sys_Mkdir` — platform HAL
- `D_FlushCaches`, `Draw_Fill` — surface cache and draw subsystems
- `Mod_PointInLeaf` — BSP model subsystem
- `AngleVectors`, `VectorNormalize`, `DotProduct`, `VectorCopy` — math library (defined elsewhere)
- `ri` (refimport_t) — engine callbacks: `Con_Printf`, `FS_Gamedir`
- `d_pzbuffer`, `sc_rover`, `r_warpbuffer`, `colormap` — defined in other ref_soft translation units
