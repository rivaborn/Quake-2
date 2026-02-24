# ref_soft/d_if.inc

## File Purpose
x86 assembly include file that defines struct field offsets and constants mirroring C structures from `d_iface.h` and related headers. It allows assembly routines to access C struct members by byte offset without redefining types in ASM syntax.

## Core Responsibilities
- Define byte offsets for `particle_t`, `finalvert_t`, `stvert_t`, `trivertx_t`, and `affinetridesc_t` fields
- Define shared engine constants (`TURB_TEX_SIZE`, `CYCLE`, `MAXHEIGHT`, `CACHE_SIZE`, `ALIAS_ONSEAM`)
- Serve as the ASM-side contract that must stay synchronized with multiple C headers

## Key Types / Data Structures

None (this file defines offsets *into* C structures, not types themselves).

| Struct Mirrored | Source Header | Purpose |
|---|---|---|
| `particle_t` | `d_iface.h` | Particle position, color, velocity, lifetime offsets |
| `finalvert_t` | `d_iface.h` | Transformed alias model vertex offsets |
| `stvert_t` | `modelgen.h` | Skin texture coordinate vertex offsets |
| `trivertx_t` | `modelgen.h` | Compressed alias model vertex + normal index offsets |
| `affinetridesc_t` | `d_iface.h` | Affine triangle descriptor offsets for software rasterizer |

## Global / File-Static State

None.

## Key Functions

None. This is a pure data/constants include file; it contains no executable code or function definitions.

## Control Flow Notes
This file is `#include`-equivalent for MASM/NASM assembly sources. It is consumed by ASM rasterizer files (e.g., `d_polysa.s`, `r_polysa.asm`, `r_aclipa.asm`) that perform inner-loop alias model rendering in hand-written x86 assembly. It has no runtime control flow of its own.

The comment at `fv_v equ 0` explicitly warns that `d_polysa.s` pushes the address of that field directly — a fragile ABI dependency that would silently break if the offset changed.

## External Dependencies
- Must remain byte-for-byte consistent with:
  - `d_iface.h` — `particle_t`, `finalvert_t`, `affinetridesc_t`
  - `r_shared.h` — `ALIAS_ONSEAM`, `MAXHEIGHT`
  - `modelgen.h` — `stvert_t`, `trivertx_t`
  - `quakedef.h` — `CACHE_SIZE`
- No symbols are defined here; all are `equ` (assembler constants resolved at assemble time)

## Notes
- `PARTICLE_Z_CLIP equ 8.0` — floating-point literal used as a near-clip threshold for particles
- `fv_shift equ 5` encodes that `fv_size` (32 bytes) is a power-of-two stride, enabling ASM to use shift instead of multiply for array indexing
- The repeated `; !!! if this is changed...` comments indicate this file was a known synchronization hazard in the original id Software codebase
