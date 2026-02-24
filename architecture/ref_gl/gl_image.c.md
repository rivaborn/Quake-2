# ref_gl/gl_image.c

## File Purpose
Manages all OpenGL texture loading, uploading, and lifecycle for the GL renderer. Handles image decoding (PCX, TGA, WAL), GPU upload with mip generation, scrap atlas packing for small UI images, and texture registration/eviction.

## Core Responsibilities
- Load and decode PCX, TGA, and WAL image formats from disk
- Upload 8-bit and 32-bit image data to OpenGL (with optional mipmap generation)
- Scale textures to power-of-two dimensions, applying gamma and intensity correction
- Pack small HUD/pic images into a scrap atlas texture to reduce bind overhead
- Manage the `gltextures[]` pool: allocation, registration tracking, and free-on-reload
- Provide texture filter/format mode switching at runtime
- Initialize the 8-to-24-bit palette table and gamma/intensity LUTs

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `glmode_t` | struct | Maps a filter name string to GL min/mag filter enums |
| `gltmode_t` | struct | Maps a texture format name string to a GL internal format enum |
| `TargaHeader` | struct | Parsed TGA file header fields |
| `floodfill_t` | struct | FIFO queue entry (x,y) for BFS flood-fill algorithm |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `gltextures` | `image_t[MAX_GLTEXTURES]` | global | Master texture object pool |
| `numgltextures` | `int` | global | Count of allocated texture slots |
| `base_textureid` | `int` | global | Base GL texture name offset |
| `d_8to24table` | `unsigned[256]` | global | Palette: 8-bit index → 32-bit RGBA |
| `intensitytable` | `byte[256]` | static | Per-channel intensity scaling LUT |
| `gammatable` | `unsigned char[256]` | static | Per-channel gamma correction LUT |
| `intensity` | `cvar_t *` | global | Intensity scale cvar |
| `gl_solid_format` | `int` | global | Desired GL internal format for opaque textures (default 3) |
| `gl_alpha_format` | `int` | global | Desired GL internal format for alpha textures (default 4) |
| `gl_tex_solid_format` | `int` | global | Active solid format (overridable via cvar) |
| `gl_tex_alpha_format` | `int` | global | Active alpha format (overridable via cvar) |
| `gl_filter_min` | `int` | global | Current GL minification filter |
| `gl_filter_max` | `int` | global | Current GL magnification filter |
| `scrap_allocated` | `int[MAX_SCRAPS][BLOCK_WIDTH]` | global | Scrap atlas column-height skyline tracker |
| `scrap_texels` | `byte[MAX_SCRAPS][256*256]` | global | CPU-side scrap atlas pixel buffer |
| `scrap_dirty` | `qboolean` | global | Signals scrap needs re-upload |
| `upload_width/height` | `int` | global | Last uploaded texture dimensions (post-scale) |
| `uploaded_paletted` | `qboolean` | global | Whether last upload used paletted extension |

## Key Functions

### GL_Upload32
- **Signature:** `qboolean GL_Upload32(unsigned *data, int width, int height, qboolean mipmap)`
- **Purpose:** Scale, gamma-correct, and upload a 32-bit RGBA image to the currently bound GL texture object; optionally generate mipmaps manually.
- **Inputs:** Raw RGBA pixel data, source dimensions, mipmap flag
- **Outputs/Return:** `true` if texture has alpha channel
- **Side effects:** Writes `upload_width`, `upload_height`, `uploaded_paletted`; calls `qglTexImage2D` at each mip level; sets GL filter parameters
- **Calls:** `GL_ResampleTexture`, `GL_LightScaleTexture`, `GL_BuildPalettedTexture`, `GL_MipMap`, `qglTexImage2D`, `qglTexParameterf`
- **Notes:** Caps texture size at 256×256; respects `gl_picmip` and `gl_round_down` cvars; supports `GL_COLOR_INDEX8_EXT` paletted path when extension present

### GL_Upload8
- **Signature:** `qboolean GL_Upload8(byte *data, int width, int height, qboolean mipmap, qboolean is_sky)`
- **Purpose:** Convert an 8-bit paletted image via `d_8to24table`, handle transparent pixel color bleeding, then delegate to `GL_Upload32`.
- **Inputs:** 8-bit indexed pixel buffer, dimensions, mipmap flag, sky flag
- **Outputs/Return:** `true` if texture has alpha
- **Side effects:** Fast-path for sky: uploads raw indexed bytes directly via paletted extension
- **Calls:** `GL_Upload32`, `qglTexImage2D`, `qglTexParameterf`
- **Notes:** Transparent pixels (index 255) sample neighbors to avoid alpha fringe artifacts

### GL_LoadPic
- **Signature:** `image_t *GL_LoadPic(char *name, byte *pic, int width, int height, imagetype_t type, int bits)`
- **Purpose:** Allocate an `image_t` slot and upload image data; routes small 8-bit pics through the scrap atlas.
- **Inputs:** Name, decoded pixel buffer, dimensions, image type, bit depth
- **Outputs/Return:** Pointer to populated `image_t`
- **Side effects:** Modifies `gltextures[]`, `numgltextures`, scrap state; calls `R_FloodFillSkin` for skins
- **Calls:** `R_FloodFillSkin`, `Scrap_AllocBlock`, `GL_Bind`, `GL_Upload8`, `GL_Upload32`

### GL_FindImage
- **Signature:** `image_t *GL_FindImage(char *name, imagetype_t type)`
- **Purpose:** Primary texture lookup entry point — returns cached image or loads from disk by extension.
- **Inputs:** Filename (with .pcx/.wal/.tga extension), image type
- **Outputs/Return:** Pointer to `image_t`, or `NULL` on failure
- **Side effects:** Updates `registration_sequence` on cache hit; may call file I/O and GPU upload
- **Calls:** `LoadPCX`, `GL_LoadWal`, `LoadTGA`, `GL_LoadPic`

### GL_InitImages
- **Signature:** `void GL_InitImages(void)`
- **Purpose:** One-time renderer init: loads palette, 16-to-8 table, builds gamma and intensity LUTs.
- **Side effects:** Writes `gammatable`, `intensitytable`, `d_8to24table`, `gl_state.inverse_intensity`, `gl_state.d_16to8table`; sets `registration_sequence = 1`
- **Calls:** `Draw_GetPalette`, `ri.Cvar_Get`, `ri.FS_LoadFile`

### GL_FreeUnusedImages
- **Signature:** `void GL_FreeUnusedImages(void)`
- **Purpose:** Evict all textures not touched in the current registration sequence (except `r_notexture` and particle texture); called between map loads.
- **Side effects:** Calls `qglDeleteTextures`; zeroes freed `image_t` slots
- **Notes:** `it_pic` type images are never freed

- **Notes (minor helpers):** `GL_MipMap` halves in-place; `GL_ResampleTexture` does bilinear box-filter rescale; `GL_LightScaleTexture` applies gamma/intensity; `R_FloodFillSkin` BFS-fills background for clean mips; `Scrap_AllocBlock` uses skyline bin-packing.

## Control Flow Notes
- `GL_InitImages` is called at renderer startup; `GL_ShutdownImages` on teardown.
- `GL_FindImage` / `GL_LoadPic` are the per-asset entry points called by model, map, and HUD loaders throughout the frame setup phase.
- `GL_FreeUnusedImages` is called between map registration cycles.
- `Scrap_Upload` must be called (externally triggered via `scrap_dirty`) before scrap-backed images are rendered.
- Texture binding (`GL_Bind`, `GL_MBind`) is called per draw call in the render loop to minimize redundant state changes.

## External Dependencies
- `gl_local.h` — `image_t`, `gl_state`, `ri` (refimport_t), cvars, `registration_sequence`, `r_notexture`, `r_particletexture`
- `qglBindTexture`, `qglTexImage2D`, `qglTexParameterf`, `qglDeleteTextures`, `qglColorTableEXT`, `qglSelectTextureSGIS` — defined in platform GL wrapper
- `LittleShort`, `LittleLong`, `Q_stricmp` — defined in shared utilities
- `pcx_t`, `miptex_t` — defined in `qfiles.h`
- `TEXNUM_SCRAPS`, `TEXNUM_IMAGES`, `MAX_GLTEXTURES` — constants defined elsewhere
