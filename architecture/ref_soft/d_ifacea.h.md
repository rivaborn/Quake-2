# ref_soft/d_ifacea.h

## File Purpose
Assembly-language interface header for the software renderer's inner-loop driver. Defines byte offsets into C structures so that hand-written x86 assembly routines can access struct fields without going through the C compiler.

## Core Responsibilities
- Mirror key constants from `d_iface.h`, `r_shared.h`, and `qcommon.h` for use in `.s`/`.asm` files
- Provide field byte offsets for `particle_t` so assembly renderers can read position and color
- Provide field byte offsets for `finalvert_t` (post-transform alias model vertices)
- Provide field byte offsets for `stvert_t` (alias model skin-texture coordinates)
- Provide field byte offsets for `trivertx_t` (compressed alias model vertex format)
- Provide field byte offsets for `affinetridesc_t` (per-triangle affine rasterisation descriptor)

## Key Types / Data Structures
None — this file declares no types. It only defines integer constants that describe the memory layout of types declared in the corresponding C headers.

## Global / File-Static State
None.

## Key Functions
None — header is constants only.

## Control Flow Notes
This file is `#include`d (or `.include`d) by assembly source files such as `linux/d_polysa.s`, `ref_soft/r_polysa.asm`, `ref_soft/r_aclipa.asm`, and similar. It has no runtime role; it is consumed entirely at assemble time.

The comment on `fv_v` (offset 0) explicitly warns that `d_polysa.s` pushes the **address** of that field directly, so any reordering of `finalvert_t` would silently break the assembly without a compile error — a critical coupling invariant.

## External Dependencies
- **Must stay in sync with** (manual contract, not enforced by the build):
  - `ref_soft/d_iface.h` — `particle_t`, `finalvert_t`, `affinetridesc_t`
  - `game/modelgen.h` or equivalent — `stvert_t`, `trivertx_t`
  - `r_shared.h` — `MAXHEIGHT`
  - `qcommon/qcommon.h` — `CACHE_SIZE`
- No external symbols are referenced; this is a pure constant-definition header.

## Notes
- `pt_size 44` and `fv_size 32` / `fv_shift 5` encode the struct sizes and the corresponding power-of-two shift, allowing assembly loops to advance pointers by multiplying an index rather than using an `imul`.
- `PARTICLE_Z_CLIP 8.0` is the only floating-point constant; it is a near-clip threshold used by assembly particle renderers.
- `TURB_TEX_SIZE`, `CYCLE`, `MAXHEIGHT`, and `CACHE_SIZE` are duplicated here verbatim from their authoritative C headers — any mismatch would cause silent misrenders or crashes with no linker-level diagnostic.
