# client/asm_i386.h

## File Purpose
A header file providing symbolic byte-offset constants for several engine C structures, enabling x86 assembly routines to access struct fields by offset rather than by name. It serves as the contract between C struct layouts and hand-written assembly code.

## Core Responsibilities
- Define byte-offset macros for `plane_t`, `hull_t`, `dnode_t`, `sfxcache_t`, `channel_t`, and `portable_samplepair_t` structs
- Provide a `C()` macro to handle ELF vs. non-ELF symbol naming conventions (underscore prefix)
- Document and enforce the structural contract between C headers and assembly files
- Define the `TRANSPARENT_COLOR` constant shared with `d_iface.h`

## Key Types / Data Structures
None — this file only defines preprocessor constants mirroring existing C structs.

## Global / File-Static State
None.

## Key Functions
None — this is a pure macro/constant header.

## Control Flow Notes
Not part of any runtime control flow. Included by x86 assembly (`.s`/`.asm`) files and any C files that need to reference the same offset constants. The correctness of this file is a compile-time/link-time invariant: if the corresponding C structs change size or field order without matching updates here, assembly routines will silently read/write wrong memory locations.

## External Dependencies
- **Notable includes:** None — self-contained.
- **External symbols used but not defined here:**
  - `plane_t` — defined in `model.h` (and referenced in BSP/collision code)
  - `hull_t` — defined in `model.h`
  - `dnode_t` — defined in `bspfile.h`
  - `sfxcache_t` — defined in `sound.h`
  - `channel_t` — defined in `sound.h`
  - `portable_samplepair_t` — defined in `sound.h`
  - `TRANSPARENT_COLOR` — must match `d_iface.h`

## Notes
- The `C(label)` macro resolves the ELF vs. COFF/PE symbol naming difference: ELF platforms export symbols without a leading underscore; older toolchains (MSVC, DJGPP) prepend `_`. This allows a single assembly source to target both.
- Every struct block carries an explicit `_size` constant (e.g., `pl_size 20`, `ch_size 52`) used for stride calculations in array indexing loops in assembly.
- The file comment on `hu_` offsets explicitly warns that `SV_HullPointContents` contains a hard-coded array stride that must be updated if `hull_t` changes — a rare but critical cross-file coupling.
