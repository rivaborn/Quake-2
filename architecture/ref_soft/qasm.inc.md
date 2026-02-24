# ref_soft/qasm.inc

## File Purpose
This is an x86 assembly include file for the Quake 2 software renderer. It declares external C symbols visible to assembly routines and defines byte-offset constants for C structs, enabling assembly code to directly access struct fields without going through C headers.

## Core Responsibilities
- Declares `externdef` references to all C global variables used by the software renderer's assembly routines
- Defines struct field byte offsets as assembler `equ` constants, mirroring C struct layouts
- Guards renderer-specific externs under `ifndef GLQUAKE` so the file is reusable in non-GL contexts
- Provides constants (`TRANSPARENT_COLOR`, `NEAR_CLIP`, `CYCLE`) shared between C and assembly
- Acts as the single synchronization point between C data layout and hand-written assembly

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `plane_t` offsets (`pl_*`) | struct mirror | BSP plane: normal (vec3), dist, type, signbits |
| `hull_t` offsets (`hu_*`) | struct mirror | BSP hull: clipnodes, planes, clip bounds |
| `dnode_t` offsets (`nd_*`) | struct mirror | BSP node on-disk layout |
| `sfxcache_t` offsets (`sfxc_*`) | struct mirror | Decoded sound sample cache |
| `channel_t` offsets (`ch_*`) | struct mirror | Active sound channel state |
| `portable_samplepair_t` offsets (`psp_*`) | struct mirror | Stereo audio sample pair |
| `espan_t` offsets | struct mirror | Horizontal edge span for rasterization |
| `sspan_t` offsets | struct mirror | Screen span (no pnext, smaller than espan_t) |
| `spanpackage_t` offsets | struct mirror | Per-span rasterization parameter bundle |
| `edge_t` offsets (`et_*`) | struct mirror | Active edge table entry |
| `surf_t` offsets (`st_*`) | struct mirror | Active surface table entry |
| `clipplane_t` offsets (`cp_*`) | struct mirror | View-frustum clip plane |
| `medge_t` offsets (`me_*`) | struct mirror | Model edge: vertex indices + cache offset |
| `mvertex_t` offsets (`mv_*`) | struct mirror | Model vertex position |
| `refdef_t` offsets (`rd_*`) | struct mirror | Renderer frame definition / view parameters |
| `mtriangle_t` offsets (`mtri_*`) | struct mirror | Model triangle: face-front flag + vertex indices |

## Global / File-Static State

None. This file only declares externs and constants; no storage is defined here.

## Key Functions

None. This is a pure include/header file containing only `equ` constant definitions and `externdef` declarations.

## Control Flow Notes

Included at the top of every `.asm` / `.s` assembly source file in `ref_soft/` and `linux/`. It has no runtime presence — all content is resolved at assemble time. The `id386 equ 1` flag gates x86-specific assembly paths in consuming files.

## External Dependencies

- **Mirrors (must stay in sync with):**
  - `d_iface.h` — `TRANSPARENT_COLOR`
  - `model.h` — `plane_t`, `hull_t`, `medge_t`, `mvertex_t`, `mtriangle_t`
  - `bspfile.h` — `dnode_t`
  - `sound.h` — `sfxcache_t`, `channel_t`, `portable_samplepair_t`
  - `r_local.h` — `NEAR_CLIP`, `CYCLE`, `clipplane_t`
  - `r_shared.h` — `espan_t`, `edge_t`, `surf_t`
  - `d_local.h` — `sspan_t`
  - `d_polyset.c` — `spanpackage_t`
  - `render.h` — `refdef_t`
- All symbols declared via `externdef` are **defined elsewhere** in C translation units (`r_edge.c`, `r_surf.c`, `snd_dma.c`, `snd_mix.c`, etc.)
