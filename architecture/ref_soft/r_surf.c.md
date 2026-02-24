# ref_soft/r_surf.c

## File Purpose
Implements software-renderer surface caching and rasterization for the Quake 2 soft reference renderer. It manages a linear surface cache (surfcache), resolves animated textures, applies bilinear lightmap blending per mip level, and writes lit 8-bit paletted pixels into cache blocks.

## Core Responsibilities
- Resolving animated texture frames via `R_TextureAnimation`
- Dispatching per-mip-level surface block rasterizers (`R_DrawSurfaceBlock8_mip0–3`)
- Blending lightmap values across 16×16 (mip0) down to 2×2 (mip3) texel blocks
- Managing a linear bump-pointer surface cache (`D_SCAlloc`, `D_FlushCaches`, `R_InitCaches`)
- Cache validity checking (dlight, lightadj, animated texture changes) in `D_CacheSurface`
- Detecting surface cache thrashing via `r_cache_thrash`

## Key Types / Data Structures
| Name | Kind | Purpose |
|---|---|---|
| `drawsurf_t` | struct (extern) | Aggregates surface rasterization params: image, mip level, dimensions, lightadj, output buffer ptr |
| `surfcache_t` | struct (extern) | Node in the surface cache free-list; holds cached pixel data, owner backpointer, light adjustments |
| `msurface_t` | struct (extern) | BSP surface; holds extents, texinfo, lightmap styles, dlight frame, cachespots array |
| `mtexinfo_t` | struct (extern) | Texture info with animation chain (`next`, `numframes`, `image`) |

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `r_drawsurf` | `drawsurf_t` | global | Shared parameter block for current surface draw call |
| `lightleft`, `lightright`, `lightleftstep`, `lightrightstep` | `int` | global | Per-row light interpolation endpoints; shared with ASM variants |
| `lightdelta`, `lightdeltastep` | `int` | global | Vertical light delta; shared with ASM |
| `blocksize`, `blockdivshift`, `blockdivmask` | `int`/`unsigned` | global | Mip-derived block geometry; used by ASM |
| `prowdestbase`, `pbasesource` | `void*`/`uchar*` | global | Current column dest and source pointers for ASM |
| `surfrowbytes` | `int` | global | Row stride in bytes; used by ASM files |
| `r_lightptr` | `unsigned*` | global | Pointer into `blocklights` for current column |
| `r_stepback` | `int` | global | Texture wrap-around step in texels |
| `r_lightwidth` | `int` | global | Width of lightmap in blocks |
| `r_numhblocks`, `r_numvblocks` | `int` | global | Horizontal/vertical block counts for this surface |
| `r_source`, `r_sourcemax` | `uchar*` | global | Texture pixel base and wrap sentinel |
| `surfmiptable` | `void(*[4])(void)` | static | Dispatch table mapping mip level → block drawer |
| `r_cache_thrash` | `qboolean` | global | Set when surface cache is thrashing (rover wrapping) |
| `sc_size`, `sc_rover`, `sc_base` | `int`/`surfcache_t*` | global | Surface cache size, bump pointer, and base |
| `surfscale` | `float` | global | `1/(1<<miplevel)`; stored in cache entry |
| `blocklights` | `unsigned[1024]` | extern | Lightmap accumulation buffer (built by `R_BuildLightMap`) |

## Key Functions

### R_TextureAnimation
- **Signature:** `image_t *R_TextureAnimation(mtexinfo_t *tex)`
- **Purpose:** Resolves the correct animation frame for a surface's texture.
- **Inputs:** `tex` — base texinfo; uses `currententity->frame` globally.
- **Outputs/Return:** Pointer to the active `image_t`.
- **Side effects:** None.
- **Calls:** None.
- **Notes:** Returns `tex->image` immediately if no animation chain.

### R_DrawSurface
- **Signature:** `void R_DrawSurface(void)`
- **Purpose:** Iterates horizontal 16/8/4/2-texel-wide columns of a surface, sets up per-column light and source pointers, and calls the mip-appropriate block rasterizer.
- **Inputs:** Reads `r_drawsurf`, `blocklights`, texture mip pixels.
- **Outputs/Return:** Writes lit pixels into `r_drawsurf.surfdat` (the cache block).
- **Side effects:** Writes globals `r_lightptr`, `prowdestbase`, `pbasesource`, `surfrowbytes`, `r_source`, `r_sourcemax`, `r_stepback`, `r_numhblocks`, `r_numvblocks`, `r_lightwidth`, `blocksize`, `blockdivshift`, `blockdivmask`.
- **Calls:** `surfmiptable[r_drawsurf.surfmip]()` (one of the four block drawers).
- **Notes:** Texture S/T offsets are modulo-wrapped using `<< 16` bias to keep values positive.

### R_DrawSurfaceBlock8_mip0–3
- **Signature:** `void R_DrawSurfaceBlock8_mipN(void)`
- **Purpose:** Rasterizes one column of N×N texel blocks with bilinear light interpolation; indexes `vid.colormap` with `(light & 0xFF00) + texel`.
- **Inputs:** Globals set by `R_DrawSurface`.
- **Outputs/Return:** Writes to `prowdestbase` (8-bit pixel destination).
- **Side effects:** Advances `psource` with texture wrap via `r_stepback`.
- **Calls:** None.
- **Notes:** C fallbacks only; compiled under `#if !id386`. Block size is 16/8/4/2 for mip 0/1/2/3 respectively. The `#if !id386` block is replaced by assembly in `r_surf8.asm` on x86.

### R_InitCaches
- **Signature:** `void R_InitCaches(void)`
- **Purpose:** Allocates the surface cache heap; size scales with resolution above 320×240 baseline.
- **Inputs:** `sw_surfcacheoverride->value`, `vid.width/height`.
- **Outputs/Return:** Initializes `sc_base`, `sc_rover`, `sc_size`.
- **Side effects:** `malloc`; prints cache size to console via `ri.Con_Printf`.
- **Calls:** `ri.Con_Printf`, `malloc`.

### D_FlushCaches
- **Signature:** `void D_FlushCaches(void)`
- **Purpose:** Invalidates all surface cache entries by NULLing owner backpointers; resets rover to base.
- **Inputs:** `sc_base`.
- **Side effects:** Modifies `*c->owner` for all live entries; resets `sc_rover`.

### D_SCAlloc
- **Signature:** `surfcache_t *D_SCAlloc(int width, int size)`
- **Purpose:** Bump-allocates a surfcache block, coalescing rover neighbors if needed; splits leftover fragments > 256 bytes.
- **Inputs:** `width` (0–256), `size` (1–0x10000).
- **Outputs/Return:** Pointer to allocated `surfcache_t`; `owner` is NULL on return (caller must set).
- **Side effects:** Updates `sc_rover`; sets `r_cache_thrash` and `d_roverwrapped` on wrap detection; calls `ri.Sys_Error` on invalid params or OOM.
- **Calls:** `ri.Sys_Error`.
- **Notes:** Uses a `(surfcache_t*)0->data[size]` offsetof trick to compute true allocation size.

### D_CacheSurface
- **Signature:** `surfcache_t *D_CacheSurface(msurface_t *surface, int miplevel)`
- **Purpose:** Main entry point: checks cache validity, allocates if stale, builds lightmap, rasterizes surface, returns cache pointer.
- **Inputs:** BSP `surface`, integer `miplevel` (0–3).
- **Outputs/Return:** Valid `surfcache_t *` with current lit pixels.
- **Side effects:** Writes `r_drawsurf`, increments `c_surf`; calls `R_BuildLightMap` and `R_DrawSurface`.
- **Calls:** `R_TextureAnimation`, `D_SCAlloc`, `R_BuildLightMap`, `R_DrawSurface`.
- **Notes:** Cache hit requires: no dlight this frame, matching image pointer, matching all 4 `lightadj` values.

## Control Flow Notes
Called during the BSP surface rendering pass. `D_CacheSurface` is the entry point per visible surface per frame; it is called from `r_bsp.c` / `r_rsurf` draw path. `R_InitCaches` runs at renderer init; `D_FlushCaches` runs on mode change or level load. The block drawers are invoked only inside `R_DrawSurface`, which itself is only called from `D_CacheSurface`.

## External Dependencies
- `r_local.h` — pulls in all soft renderer types and globals
- `vid.colormap` — 8-bit palette lighting table (256 grades × 256 colors)
- `blocklights[1024]` — filled by `R_BuildLightMap` (defined in `r_light.c`)
- `d_roverwrapped`, `d_initial_rover` — cache thrash tracking (defined in `r_misc.c` or `r_main.c`)
- `currententity` — used by `R_TextureAnimation` (global set by caller)
- `r_framecount`, `r_newrefdef` — frame counter and ref def (defined in `r_main.c`)
- `c_surf` — debug surface count (defined elsewhere)
- `sw_surfcacheoverride` — cvar (registered elsewhere)
- `ri.Con_Printf`, `ri.Sys_Error` — renderer import table
