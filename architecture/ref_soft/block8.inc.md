# ref_soft/block8.inc

## File Purpose
x86 assembly include file providing an unrolled, hand-optimized inner loop for block-scaling texture fetch and 16-bit pixel output. It is `#include`d (or assembled directly) into a larger software renderer routine that samples 8-bit paletted texels and writes 16-bit color values to the framebuffer.

## Core Responsibilities
- Read two 8-bit texel indices per iteration from a source texture surface (via `esi` and `esi+ebx`)
- Use the high byte of the fixed-point V coordinate (`dh`) to form a 2D palette/translation lookup index
- Translate each 8-bit palette index into a 16-bit color word via a self-patching lookup table address (`12345678h` placeholder)
- Advance the fixed-point texture coordinate accumulator (`edx += ebp`)
- Write two 16-bit pixels at a time to the destination framebuffer (`edi`)
- Provide four entry points (`LEnter16_16`, `LEnter8_16`, `LEnter4_16`, `LEnter2_16`) for partially-unrolled loop dispatch based on remaining pixel count (16, 8, 4, 2 pixels)

## Key Types / Data Structures
None (assembly include; no C types defined here).

## Global / File-Static State
None declared here; all state is in CPU registers or memory patched at runtime.

## Key Functions

### LEnter16_16
- **Signature:** Assembly label (no C signature); entry point for 16-pixel block
- **Purpose:** Processes 8 pairs of texels (16 pixels total), each pair fetched, palette-translated, and written as two 16-bit words
- **Inputs:** `esi` = texel source pointer; `ebx` = texture row stride; `edx` = fixed-point V coordinate; `ebp` = V step; `edi` = framebuffer destination
- **Outputs/Return:** Writes 16 × 2-byte pixels to `[edi]`; advances `edi` by 4 per pair (8 iterations → +32 bytes total); falls through to `LEnter8_16`
- **Side effects:** Modifies `eax`, `ecx`, `edx`, `esi`, `edi`
- **Calls:** None (pure register/memory ops)
- **Notes:** `12345678h` is a self-modifying address placeholder; the containing C/asm code patches `LBPatch0`–`LBPatch7` at runtime with the actual 16-bit palette table address.

### LEnter8_16
- **Signature:** Assembly label; entry point for 8-pixel block
- **Purpose:** Processes 4 pairs of texels (8 pixels), falls through to `LEnter4_16`
- **Inputs/Outputs:** Same register convention as above
- **Notes:** Patches `LBPatch8`–`LBPatch11`

### LEnter4_16
- **Signature:** Assembly label; entry point for 4-pixel block
- **Purpose:** Processes 2 pairs of texels (4 pixels), falls through to `LEnter2_16`
- **Notes:** Patches `LBPatch12`–`LBPatch13`

### LEnter2_16
- **Signature:** Assembly label; entry point for 2-pixel block
- **Purpose:** Processes 1 pair of texels (2 pixels) — minimum granularity
- **Notes:** Patches `LBPatch14`–`LBPatch15`

## Control Flow Notes
This file is an include fragment, not a standalone translation unit. The calling routine selects an entry point based on block width (number of pixels remaining), then falls through the cascading unrolled sections. This is a classic Duff's Device-style dispatch. It fits into the **per-scanline inner loop** of the software rasterizer's texture block-copy path for 16-bit output mode.

## External Dependencies
- No includes; depends entirely on register state established by the enclosing routine
- `12345678h` addresses are **runtime-patched** by an external C or asm function that writes the actual palette translation table address into the instruction stream at `LBPatch0`–`LBPatch15`
- Companion file `block8.inc` / `block16.h` likely handles the 8-bit framebuffer variant
