# ref_soft/asm_draw.h

## File Purpose
A pure-offset header that exposes byte offsets and constants for C structs shared between the software renderer's C code and its x86 assembly routines. It acts as the assembly-visible "ABI contract" so that `.s`/`.asm` files can access struct fields by numeric offset rather than C member syntax.

## Core Responsibilities
- Define `NEAR_CLIP` and `CYCLE` constants for use in both C and assembly
- Publish byte offsets for `espan_t`, `sspan_t`, `edge_t`, `surf_t`, `clipplane_t` fields
- Publish byte offsets for `medge_t`, `mvertex_t`, `refdef_t`, `mtriangle_t` fields
- Provide struct size constants (`*_size`) so assemblers can stride through arrays
- Provide shift/bit constants (`SURF_T_SHIFT`, `mtri_shift`) for fast array indexing in assembly
- Serve as the single synchronization point between C struct layout and hand-written ASM

## Key Types / Data Structures
None — this file defines no types; it only documents field offsets of types defined elsewhere.

## Global / File-Static State
None.

## Key Functions
None — this is a pure `#define` header with no functions.

**Notes:**
- Every constant in this file has a matching C declaration in another header; the file header comments call out each pairing explicitly (e.g., `espan_t` → `r_shared.h`, `surf_t` → `r_shared.h`, `clipplane_t` → `r_local.h`, `medge_t`/`mvertex_t` → `model.h`, `refdef_t` → `render.h`).
- `SURF_T_SHIFT 6` implies `surf_t` is 64 bytes (2^6), allowing `surf_t` array indexing via left-shift in ASM instead of multiply.
- `mtri_shift 4` and `mtri_size 16` serve the same purpose for `mtriangle_t`; the comment explicitly warns that `d_polysa.s` must be updated if this changes.

## Control Flow Notes
Not part of any runtime flow. Included at compile/assemble time by both C files and assembly sources in `ref_soft/` and `linux/` to ensure both sides agree on memory layout.

## External Dependencies
- **Defined elsewhere** (structs whose layouts this file mirrors):
  - `espan_t`, `edge_t`, `surf_t` → `r_shared.h`
  - `sspan_t` → `d_local.h`
  - `clipplane_t` → `r_local.h`
  - `medge_t`, `mvertex_t`, `mtriangle_t` → `model.h` (or `r_model.h`)
  - `refdef_t` → `render.h`
- No `#include` directives; this file is a standalone offset table.
- Consumed by: `ref_soft/r_aclipa.asm`, `ref_soft/r_edgea.asm`, `ref_soft/r_polysa.asm`, `linux/d_polysa.s`, `linux/r_aclipa.s`, etc.
