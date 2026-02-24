# client/block8.h

## File Purpose
Inline x86 AT&T-syntax assembly fragment implementing a bilinear-scaled 8-bit texture block-copy loop body. It is `#include`d directly into a C or assembly file that provides the surrounding loop/function scaffold. Implements the inner loop of an 8-bit software renderer texture scaling routine using patchable lookup-table addresses.

## Core Responsibilities
- Fetch two source texels per iteration from a texture source pointer (`%esi`) with a row-stride offset (`%ebx`)
- Perform sub-texel interpolation by using the high byte of a fixed-point accumulator (`%dh`) as a table index
- Look up final 8-bit palette-mapped pixel values via patchable base addresses (`0x12345678` placeholders, `LBPatch*`)
- Write two pixels per iteration to the destination buffer (`%edi`), advancing it by 2 bytes
- Provide multiple entry points (`LEnter16_8`, `LEnter8_8`, `LEnter4_8`, `LEnter2_8`) for loop unrolling at different counts (16, 8, 4, 2 pixels)

## Key Types / Data Structures
None.

## Global / File-Static State
None. (Patch labels `LBPatch0`–`LBPatch15` are self-modifying code targets; the actual table addresses are written in at runtime by the surrounding C code.)

## Key Functions
This file contains no C functions. It is a raw assembly fragment with entry-point labels only.

### LEnter16_8 / LEnter8_8 / LEnter4_8 / LEnter2_8
- **Signature:** Assembly labels (no C prototype)
- **Purpose:** Fall-through entry points for an unrolled inner texel-fetch-and-write loop. `LEnter16_8` covers 8 pairs (16 pixels), falling through into `LEnter8_8` (4 pairs), `LEnter4_8` (2 pairs), `LEnter2_8` (1 pair), implementing Duff's-device-style partial unrolling.
- **Inputs (registers on entry):**
  - `%esi` — source texture pointer (current scanline position)
  - `%ebx` — texture row stride (bytes per row)
  - `%edx` — fixed-point V accumulator; `%dh` = fractional high byte used as interpolation index
  - `%ebp` — fixed-point V step (added to `%edx` each sub-step)
  - `%edi` — destination pixel buffer pointer
- **Outputs/Return:** Pixels written to `(%edi)` and `1(%edi)`; `%edi` advanced by 2 per pair; `%esi` advanced by `2*%ebx` per pair; `%edx` updated.
- **Side effects:** Writes to destination framebuffer region. Reads from two patchable lookup tables whose addresses are embedded as `0x12345678` placeholders at `LBPatch0`–`LBPatch15`.
- **Calls:** None (pure inline assembly fragment).
- **Notes:** The `0x12345678` immediates are runtime-patched by the enclosing C code to point to the actual bilinear interpolation lookup tables. The pattern is unrolled 8× from `LEnter16_8`, meaning full 16-pixel blocks share the maximum path length for throughput.

## Control Flow Notes
This fragment is `#include`d into the software renderer's span-drawing or surface-scaling path. The caller sets up registers, then jumps to the appropriate `LEnter*_8` label based on how many pixels remain in the current span, achieving partial-unroll dispatch. It does not loop internally — the outer loop and branch-back are in the including file.

## External Dependencies
- No `#include` directives (raw assembly fragment).
- Depends on caller-established register conventions (`%esi`, `%ebx`, `%edx`, `%ebp`, `%edi`).
- `LBPatch0`–`LBPatch15`: self-modification targets — addresses written by surrounding C/asm code (defined elsewhere).
- Designed for x86 (IA-32) with AT&T syntax; GAS assembler or inline `asm` context assumed.
