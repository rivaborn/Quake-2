# linux/d_ifacea.h

## File Purpose
Assembly-language interface header for the Linux software renderer. Defines byte offsets into C structures so that x86 assembly routines can access struct fields without relying on C's type system.

## Core Responsibilities
- Mirror field offsets of C structures from `d_iface.h`, `r_shared.h`, and `modelgen.h` for use in `.s` assembly files
- Define shared constants (`TURB_TEX_SIZE`, `CYCLE`, `MAXHEIGHT`, `CACHE_SIZE`) that must stay synchronized across C and asm
- Provide particle_t field offsets, distinguishing driver-usable fields from internal-only fields
- Provide finalvert_t, stvert_t, trivertx_t, and affinetridesc_t field offsets for alias model rendering assembly

## Key Types / Data Structures
None. This file only defines preprocessor constants; no types are declared here.

## Global / File-Static State
None.

## Key Functions
None. This is a pure header; no functions are declared or defined.

## Control Flow Notes
Consumed exclusively by Linux assembly files (e.g., `linux/d_polysa.s`, `linux/r_aclipa.s`, `linux/r_edgea.s`, `linux/r_scana.s`). These assembly routines use the `#define`d offsets to perform direct memory access on structs passed by pointer. No involvement in init/frame/shutdown logic directly; it enables the low-level rasterization hot paths called each frame during alias model and surface rendering.

## External Dependencies
- **Must stay in sync with** (no `#include` of these, purely a manual contract):
  - `d_iface.h` — `particle_t`, `finalvert_t`, `affinetridesc_t`, `TURB_TEX_SIZE`, `CYCLE`
  - `r_shared.h` — `ALIAS_ONSEAM`, `MAXHEIGHT`
  - `modelgen.h` — `stvert_t`, `trivertx_t`
  - `quakedef.h` — `CACHE_SIZE`
- No external symbols are referenced; this file is self-contained preprocessor definitions only.

**Notes:**
- `pt_color` at offset 12 and `pt_next` at offset 16 mark the boundary between driver-visible and engine-internal particle fields — assembly routines must not access fields at or beyond `pt_next`.
- `fv_v` at offset 0 has a special note: if moved, all `d_polysa.s` address pushes must be updated manually.
- `fv_shift = 5` encodes `fv_size = 32` as a power-of-two shift for efficient array indexing in asm.
