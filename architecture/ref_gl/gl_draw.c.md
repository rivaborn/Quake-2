# ref_gl/gl_draw.c

## File Purpose
Implements all 2D screen-space drawing primitives for the OpenGL renderer. Handles console characters, HUD pictures, screen fills, fade overlays, and raw cinematic frame blitting.

## Core Responsibilities
- Initialize and cache the console character texture (`conchars.pcx`)
- Draw individual 8×8 console/HUD characters from a 16×16 glyph atlas
- Load and render 2D pictures (PCX files, with scrap atlas support)
- Tile a texture to fill letterbox/background regions
- Fill screen rectangles with a solid palette color
- Draw a full-screen semi-transparent black fade overlay
- Blit and scale raw 8-bit cinematic frames (with optional paletted-texture path)

## Key Types / Data Structures
None (uses types defined in `gl_local.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `draw_chars` | `image_t *` | global | Cached texture handle for console character atlas |

## Key Functions

### Draw_InitLocal
- **Signature:** `void Draw_InitLocal(void)`
- **Purpose:** Loads the console character texture and sets it to nearest-neighbor filtering to prevent blurry text.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** Binds `draw_chars` global; sets GL texture filter state.
- **Calls:** `GL_FindImage`, `GL_Bind`, `qglTexParameterf`
- **Notes:** Must be called once during renderer init before any `Draw_Char` calls.

### Draw_Char
- **Signature:** `void Draw_Char(int x, int y, int num)`
- **Purpose:** Renders a single 8×8 character from the 256-glyph atlas using UV indexing.
- **Inputs:** Screen pixel position `(x, y)`, ASCII character code `num` (masked to 8-bit)
- **Outputs/Return:** None
- **Side effects:** Issues GL draw call; binds `draw_chars` texture.
- **Calls:** `GL_Bind`, `qglBegin/End`, `qglTexCoord2f`, `qglVertex2f`
- **Notes:** Space (char 32) and off-screen characters (`y <= -8`) are skipped. Atlas layout: row = `num >> 4`, col = `num & 15`; each cell is 1/16 of the texture (`0.0625`).

### Draw_FindPic
- **Signature:** `image_t *Draw_FindPic(char *name)`
- **Purpose:** Resolves a picture name to a cached `image_t`, prepending `pics/` and `.pcx` for relative paths.
- **Inputs:** Picture name string (relative or absolute with leading `/`)
- **Outputs/Return:** Pointer to `image_t`, or `NULL` if not found.
- **Calls:** `GL_FindImage`, `Com_sprintf`

### Draw_GetPicSize
- **Signature:** `void Draw_GetPicSize(int *w, int *h, char *pic)`
- **Purpose:** Returns pixel dimensions of a named picture; writes `-1,-1` if not found.
- **Calls:** `Draw_FindPic`

### Draw_StretchPic
- **Signature:** `void Draw_StretchPic(int x, int y, int w, int h, char *pic)`
- **Purpose:** Renders a picture scaled to an arbitrary rectangle.
- **Side effects:** May flush scrap atlas (`Scrap_Upload`); conditionally disables `GL_ALPHA_TEST` on MCD/Rendition hardware for non-alpha images.
- **Calls:** `Draw_FindPic`, `Scrap_Upload`, `GL_Bind`, `qglBegin/End`

### Draw_Pic
- **Signature:** `void Draw_Pic(int x, int y, char *pic)`
- **Purpose:** Renders a picture at native size using image's stored UV extents (`sl/sh/tl/th`).
- **Side effects:** Same MCD/Rendition alpha test workaround as `Draw_StretchPic`.
- **Calls:** `Draw_FindPic`, `Scrap_Upload`, `GL_Bind`, `qglBegin/End`

### Draw_TileClear
- **Signature:** `void Draw_TileClear(int x, int y, int w, int h, char *pic)`
- **Purpose:** Tiles a 64×64 texture across a screen rectangle (used for letterbox borders).
- **Side effects:** UV coordinates are computed as `pixel / 64.0` to produce tiling without repeat-mode changes.
- **Calls:** `Draw_FindPic`, `GL_Bind`, `qglBegin/End`

### Draw_Fill
- **Signature:** `void Draw_Fill(int x, int y, int w, int h, int c)`
- **Purpose:** Fills a pixel rectangle with a solid color looked up from `d_8to24table`.
- **Inputs:** Rectangle bounds, palette index `c` (0–255)
- **Side effects:** Disables/re-enables `GL_TEXTURE_2D`; calls `ri.Sys_Error` on out-of-range index.
- **Calls:** `qglDisable/Enable`, `qglColor3f`, `qglBegin/End`

### Draw_FadeScreen
- **Signature:** `void Draw_FadeScreen(void)`
- **Purpose:** Overlays a full-screen black quad at 80% opacity (used for menu/cinematic darkening).
- **Side effects:** Enables blend, disables texture, draws full `vid.width × vid.height` quad, restores state.
- **Calls:** `qglEnable/Disable`, `qglColor4f`, `qglBegin/End`

### Draw_StretchRaw
- **Signature:** `void Draw_StretchRaw(int x, int y, int w, int h, int cols, int rows, byte *data)`
- **Purpose:** Uploads and renders a raw 8-bit indexed cinematic frame, scaling down to 256×256 max.
- **Inputs:** Target rect, source dimensions, raw palette-indexed pixel buffer
- **Side effects:** Calls `qglTexImage2D` to upload a new texture each frame (no caching); uses either 32-bit RGBA path via `r_rawpalette` or `GL_COLOR_INDEX8_EXT` paletted path if `qglColorTableEXT` is available.
- **Calls:** `GL_Bind(0)`, `qglTexImage2D`, `qglTexParameterf`, `qglBegin/End`
- **Notes:** Source rows > 256 are downsampled via fixed-point stepping; `t` UV coordinate adjusts for partial texture fill.

## Control Flow Notes
All functions are called during the 2D overlay phase of the frame, after 3D world rendering completes. `Draw_InitLocal` is called once at renderer startup. The remaining functions are invoked by the client HUD/console/menu systems each frame.

## External Dependencies
- **Includes:** `gl_local.h` (pulls in all GL types, `image_t`, `gl_config`, `vid`, `d_8to24table`)
- **Defined elsewhere:** `scrap_dirty`, `Scrap_Upload` (`gl_image.c`); `r_rawpalette` (`gl_rmisc.c`); `GL_FindImage`, `GL_Bind` (`gl_image.c`); `gl_config`, `gl_tex_solid_format` (`gl_rmain.c`); `qglColorTableEXT`, all `qgl*` wrappers (`qgl_*.c`); `ri` (renderer import struct); `d_8to24table` (palette table)
