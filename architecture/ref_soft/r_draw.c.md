# ref_soft/r_draw.c

## File Purpose
Implements 2D screen drawing routines for the software renderer. Handles UI elements including characters, pics, tiles, solid fills, and screen fade effects by writing directly to the software framebuffer (`vid.buffer`).

## Core Responsibilities
- Load and cache the console character font (`conchars`)
- Draw individual 8×8 console/HUD characters with transparency support
- Draw named PCX images (pics) with optional transparency, at 1:1 or stretched scale
- Tile a 64×64 image across a rectangular screen region
- Fill screen rectangles with a solid palette index color
- Apply a dithered screen fade effect (darkens every other pixel)

## Key Types / Data Structures
| Name | Kind | Purpose |
|------|------|---------|
| `image_t` | struct (defined in `r_local.h`) | Holds image pixel data, dimensions, transparency flag, and mip levels |

## Global / File-Static State
| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `draw_chars` | `image_t *` | global | Pointer to the loaded console character sheet (`conchars`) |

## Key Functions

### Draw_InitLocal
- Signature: `void Draw_InitLocal(void)`
- Purpose: Initializes the 2D draw subsystem by loading the console character image.
- Inputs: None
- Outputs/Return: None
- Side effects: Sets `draw_chars` global.
- Calls: `Draw_FindPic`
- Notes: Must be called before any `Draw_Char` invocations.

### Draw_FindPic
- Signature: `image_t *Draw_FindPic(char *name)`
- Purpose: Resolves a short pic name to a full `pics/<name>.pcx` path and returns the cached image.
- Inputs: `name` — bare pic name or absolute path (leading `/` or `\` bypasses prefix).
- Outputs/Return: `image_t *` or NULL on failure.
- Side effects: May load and cache the image via `R_FindImage`.
- Calls: `Com_sprintf`, `R_FindImage`

### Draw_Char
- Signature: `void Draw_Char(int x, int y, int num)`
- Purpose: Blits one 8×8 character from the `conchars` sheet to the framebuffer with transparency; supports top-edge clipping for scrolling console.
- Inputs: `x`, `y` — screen position; `num` — ASCII/extended character index (0–255).
- Outputs/Return: None
- Side effects: Writes to `vid.buffer`.
- Calls: None (direct pointer arithmetic)
- Notes: Space characters (32, 160) are skipped. Pixel stride in `conchars` is 128 bytes per row; each glyph row is 8 pixels wide. `TRANSPARENT_COLOR` pixels are not written.

### Draw_StretchPicImplementation
- Signature: `void Draw_StretchPicImplementation(int x, int y, int w, int h, image_t *pic)`
- Purpose: Stretches an `image_t` to an arbitrary rectangle using fixed-point scaling; shared implementation for `Draw_StretchPic` and `Draw_StretchRaw`.
- Inputs: Target rect `(x,y,w,h)`, source `pic`.
- Outputs/Return: None
- Side effects: Writes to `vid.buffer`; calls `ri.Sys_Error` on out-of-bounds coordinates.
- Calls: `memcpy`, `ri.Sys_Error`
- Notes: Uses 16.16 fixed-point horizontal stepping. Vertical scaling via integer division per row. No transparency handling.

### Draw_StretchRaw
- Signature: `void Draw_StretchRaw(int x, int y, int w, int h, int cols, int rows, byte *data)`
- Purpose: Stretches a raw pixel buffer (e.g., cinematic frame) to a screen rect without going through the image cache.
- Inputs: Raw pixel pointer `data`, source dimensions `cols`/`rows`, target rect.
- Outputs/Return: None
- Side effects: Writes to `vid.buffer` via `Draw_StretchPicImplementation`.
- Calls: `Draw_StretchPicImplementation`

### Draw_Pic
- Signature: `void Draw_Pic(int x, int y, char *name)`
- Purpose: Draws a named pic at 1:1 scale; handles both opaque (memcpy) and transparent paths with 8-pixel loop unrolling.
- Inputs: Screen position, pic name.
- Outputs/Return: None
- Side effects: Writes to `vid.buffer`; logs error via `ri.Con_Printf` if pic not found.
- Calls: `Draw_FindPic`, `memcpy`, `ri.Con_Printf`
- Notes: Silently clips/skips on bad coordinates rather than erroring.

### Draw_TileClear
- Signature: `void Draw_TileClear(int x, int y, int w, int h, char *name)`
- Purpose: Tiles a 64×64 pic across a screen rectangle (used to fill letterbox borders around the viewport).
- Inputs: Rect, tile pic name.
- Side effects: Writes to `vid.buffer`; clips rect to screen bounds internally.
- Calls: `Draw_FindPic`, `ri.Con_Printf`
- Notes: Row index into tile is `(screen_y + i) & 63`; column index is `j & 63`.

### Draw_Fill
- Signature: `void Draw_Fill(int x, int y, int w, int h, int c)`
- Purpose: Fills a screen rectangle with palette index `c`.
- Side effects: Writes to `vid.buffer`; clips to screen bounds.

### Draw_FadeScreen
- Signature: `void Draw_FadeScreen(void)`
- Purpose: Darkens the screen by zeroing pixels in a checkerboard/dither pattern (every other pixel per row).
- Side effects: Destructively modifies `vid.buffer` in-place.
- Notes: Uses `(y & 1) << 1` to alternate the zeroed column phase per row, producing a 50% dither.

## Control Flow Notes
`Draw_InitLocal` is called during renderer initialization. All other functions are called during the 2D overlay phase of the frame, after 3D scene rendering is complete. `Draw_StretchRaw` is called from the cinematic playback path. `Draw_FadeScreen` is called before drawing menus that require a darkened background.

## External Dependencies
- `r_local.h` — renderer globals, `image_t`, `vid`, `TRANSPARENT_COLOR`
- `R_FindImage` — image loading/caching (defined in `r_image.c`)
- `ri.Sys_Error`, `ri.Con_Printf` — engine callbacks (defined elsewhere in engine)
- `Com_sprintf` — defined in `qcommon`
- `vid.buffer`, `vid.rowbytes`, `vid.width`, `vid.height` — framebuffer state (defined elsewhere)
