# linux/block8.h

## File Purpose
Inline x86 AT&T assembly fragment implementing an unrolled texture span-drawing loop for the software renderer's 8-bit color mode. It is `#include`d directly into a larger assembly routine and does not stand alone as a compilable translation unit.

## Core Responsibilities
- Sample two texels per iteration using bilinear-style row-strided addressing (`%esi` + `%ebx` offset)
- Apply a runtime-patched palette/colormap lookup via the `0x12345678` displacement (a sentinel patched at load time)
- Write two destination pixels per iteration to the output scanline buffer (`%edi`)
- Provide multiple entry points (`LEnter16_8`, `LEnter8_8`, `LEnter4_8`, `LEnter2_8`) for loop unrolling at 16, 8, 4, and 2 pixels remaining
- Advance the fixed-point texture coordinate accumulator (`%edx`/`%ebp`) by one step per pixel

## Key Types / Data Structures
None. (Pure assembly fragment; no C types defined.)

## Global / File-Static State
None directly declared here. The following registers carry state passed in by the including routine:

| Register | Role |
|---|---|
| `%esi` | Texture source pointer (current row) |
| `%ebx` | Texture row stride (bytes per row) |
| `%edx` | Fixed-point texture V coordinate (high byte = integer part) |
| `%ebp` | Fixed-point V step per pixel |
| `%edi` | Destination scanline write pointer |

## Key Functions
No C functions. Entry labels serve as jump targets within the enclosing assembly function:

| Label | Unrolled pixels handled from this point |
|---|---|
| `LEnter16_8` | 16 (4 explicit blocks + falls through) |
| `LEnter8_8` | 8 (2 explicit blocks + falls through) |
| `LEnter4_8` | 4 (1 block + falls through) |
| `LEnter2_8` | 2 (1 block, terminates fragment) |

Each two-pixel block follows this pattern:
1. Load texel from row 0 (`%esi`) into `%al`; load texel from row 1 (`%esi + %ebx`) into `%cl`
2. Copy high byte of `%edx` (integer V) into `%ah`/`%ch` to form colormap row index
3. Advance V accumulator (`%edx += %ebp`) twice (once per pixel)
4. Advance texture source by two rows (`%esi += 2*%ebx`)
5. Colormap lookup: `%al = colormap[%eax]` and `%cl = colormap[%ecx]` — addresses `0x12345678` are **runtime patches** (`LBPatch0`–`LBPatch15`)
6. Store two pixels to `(%edi)` and `1(%edi)`, advance `%edi` by 2

## Control Flow Notes
This fragment is `#include`d into the Linux software renderer's span-drawing path (likely `linux/d_polysa.s` or equivalent). The caller jumps to the appropriate `LEnterN_8` label based on the pixel count modulo 16, then falls through remaining blocks. It is part of the **per-frame, per-scanline render hot path**. There is no loop branch within this file; the enclosing file provides the outer loop.

## External Dependencies
- No `#include` directives (raw assembly fragment)
- `LBPatch0`–`LBPatch15`: labels consumed by an external self-patching mechanism that writes the real colormap base address over the `0x12345678` sentinels at startup or context switch
- Enclosing routine supplies all register state; this fragment has no prologue/epilogue
