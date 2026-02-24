# linux/qasm.h

## File Purpose
Assembly-language include header for the Linux x86 soft renderer. It declares external symbols (via `.extern` directives) visible to GNU assembler (`.s`) files and defines byte-offset constants for C structures so assembly code can access struct fields without a C compiler.

## Core Responsibilities
- Conditionally define the `C()` macro to mangle symbol names for ELF vs. non-ELF (leading underscore) ABI conventions.
- Detect i386 architecture and set the `id386` compile-time flag.
- Emit `.extern` directives for all C-side globals accessed by the software renderer and sound mixer assembly routines.
- Define `#define` byte-offset constants for every struct field accessed from assembly (plane_t, hull_t, edge_t, surf_t, span types, sound channel types, refdef_t, etc.).
- Gate software-renderer `.extern` declarations behind `#ifndef GLQUAKE` so they are excluded from GL builds.
- Define `TRANSPARENT_COLOR` (palette index 255) shared between C and assembly.

## Key Types / Data Structures
None. This file only defines numeric constants mirroring C struct layouts; no new types are declared here.

## Global / File-Static State
None. Header only; all listed symbols are external references to globals defined in C translation units.

## Key Functions
None. This is a pure header/include file containing no function definitions.

## Control Flow Notes
Included at the top of Linux assembly source files (`linux/d_polysa.s`, `linux/r_*.s`, `linux/snd_mixa.s`, etc.). It is not part of any runtime call graph; it is consumed entirely at assemble time. The `C()` macro and `.extern` directives are resolved by the GNU assembler before any code is emitted.

## External Dependencies
- **Notable includes:** None — this file includes nothing itself.
- **External symbols used but not defined here:**
  - Software renderer globals: `d_zistepu`, `d_pzbuffer`, `r_turb_*`, `edge_p`, `surface_p`, `surfaces`, `span_p`, `r_apverts`, `aliastransform`, etc. — defined in `ref_soft/r_*.c` and `ref_soft/d_*.c`.
  - Sound mixer globals: `snd_scaletable`, `paintbuffer`, `snd_linear_count`, `snd_p`, `snd_vol`, `snd_out` — defined in `client/snd_mix.c`.
  - View/render globals: `vright`, `vup`, `vpn`, `BOPS_Error` — defined in client/renderer C files.
  - Floating-point constants (`float_point5`, `Float2ToThe31nd`, `fp_64k`, etc.) and span-rasterizer temporaries (`advancetable`, `reciprocal_table`, `entryvec_table`) — defined in assembly data segments in `ref_soft/*.asm` / `linux/r_*.s`.

### Notes
- All struct-offset `#define`s carry explicit warnings ("must be kept the same as in ...") tying them to their C counterparts: `model.h`, `r_local.h`, `r_shared.h`, `d_local.h`, `sound.h`, `bspfile.h`. Any struct layout change in C must be manually mirrored here — there is no compile-time enforcement.
- `d_pzbuffer` and several other symbols appear twice in the `.extern` list (duplicates are harmless to the assembler but indicate copy-paste accumulation over time).
- The `NEAR_CLIP` (0.01) and `CYCLE` (128) defines duplicate constants from `r_local.h` for use in assembly without a C include.
