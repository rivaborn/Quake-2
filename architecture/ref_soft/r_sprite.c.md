# ref_soft/r_sprite.c

## File Purpose
Renders a single sprite entity in the software renderer by constructing a view-aligned quadrilateral polygon in world space and submitting it to the polygon clipping/drawing pipeline. Sprites are always billboarded — fully parallel to the view plane.

## Core Responsibilities
- Validate and wrap the current entity's frame index against sprite frame count
- Fetch sprite frame metadata (dimensions, origin offsets) from model extradata
- Build four world-space vertices forming a billboard quad, UV-mapped to the sprite frame
- Configure the shared `r_polydesc` descriptor with texture data, axes, and offsets
- Dispatch to `R_ClipAndDrawPoly` with appropriate alpha for translucent or opaque sprites

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `dsprite_t` | struct (typedef) | Sprite model header; contains frame count and frame array |
| `dsprframe_t` | struct (typedef) | Per-frame data: width, height, origin_x/y |
| `polydesc_t` | struct (typedef) | Shared polygon descriptor consumed by the poly rasterizer |
| `vec5_t` | typedef | 5-float vector (x, y, z, s, t) used for clipped poly vertices |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `r_polydesc` | `polydesc_t` | global (extern) | Shared polygon descriptor written here, read by rasterizer |
| `r_clip_verts` | `vec5_t[2][MAXWORKINGVERTS+2]` | global (extern) | Clipping vertex buffers; `[0]` written as input quad |

## Key Functions

### R_DrawSprite
- **Signature:** `void R_DrawSprite(void)`
- **Purpose:** Constructs and submits a billboard sprite quad for the current entity using the software renderer's polygon pipeline.
- **Inputs:** Implicit — `currententity`, `currentmodel`, `r_entorigin`, `vup`, `vright`, `vpn`, `modelorg` (all globals)
- **Outputs/Return:** `void`
- **Side effects:** Writes `r_polydesc` fields (pixels, dimensions, axes, vertex count, offsets, stipple parity); writes 4 entries into `r_clip_verts[0]`; calls `R_ClipAndDrawPoly` which rasterizes to the framebuffer
- **Calls:** `VectorCopy`, `VectorScale`, `VectorInverse`, `R_ClipAndDrawPoly`
- **Notes:**
  - Frame index is wrapped via `%` rather than clamped (commented-out bounds-check at `#if 0` block)
  - The `vup` axis is **inverted** in `r_polydesc.vup` after being used to build `up`/`down` — sprite UV vertical axis runs opposite to world up
  - `stipple_parity` is forced to `1` around the draw call, then reset to `0`; this enables stippled transparency blending in the rasterizer for all sprites
  - `s_offset`/`t_offset` are set to half the frame dimensions, centering the texture sampling

## Control Flow Notes
Called from the entity rendering dispatch (likely `R_DrawEntitiesOnList` or equivalent in `r_main.c`) when the current entity's model type is `mod_sprite`. Executes entirely within a single frame's entity pass. No init or shutdown involvement.

## External Dependencies
- **Includes:** `r_local.h` (pulls in all soft-renderer types and globals)
- **Defined elsewhere:**
  - `r_polydesc` — defined in `r_poly.c` or `r_local`
  - `r_clip_verts` — defined in `r_poly.c` or clipping module
  - `R_ClipAndDrawPoly` — polygon clip + rasterize dispatch
  - `currententity`, `currentmodel`, `r_entorigin`, `vup`, `vright`, `vpn`, `modelorg` — renderer globals
