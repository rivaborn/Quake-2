# ref_soft/block16.inc

## File Purpose
x86 assembly include fragment implementing a 16-bit-per-pixel texture block drawing loop for the software renderer. It is `#include`d or assembled inline into a larger span/block rasterizer, providing unrolled pixel-output iterations at multiple entry granularities (16, 8, 4, and 2 pixel block sizes).

## Core Responsibilities
- Reads 8-bit palette indices from a source texture span (via `esi` and `esi+ebx`)
- Expands palette indices into 16-bit RGB pixel values via a runtime-patched lookup table
- Writes two 16-bit pixels per iteration to the destination framebuffer (via `edi`)
- Advances the texture coordinate accumulator (`edx += ebp`) for sub-texel stepping
- Provides four fall-through entry points (`LEnter16_16`, `LEnter8_16`, `LEnter4_16`, `LEnter2_16`) enabling partial-block dispatch without branching

## Key Types / Data Structures
None. Pure assembly fragment; no C types defined here.

## Global / File-Static State
None declared in this file. Relies entirely on CPU register state and self-modifying memory patches established by surrounding code.

## Key Functions
No functions in the C sense. The file defines labeled assembly blocks:

### LEnter16_16
- Signature: Assembly label (fall-through entry)
- Purpose: Entry for a full 16-pixel block (8 two-pixel iterations unrolled)
- Inputs: `esi`=source texel ptr, `ebx`=texture row stride, `edx`=frac accumulator, `ebp`=frac step, `edi`=dest framebuffer ptr
- Outputs/Return: Writes 16 × 16-bit pixels to `[edi]`, advances `edi` by 32 bytes total
- Side effects: Modifies `eax`, `ecx`, `edx`, `esi`, `edi`
- Calls: None (pure register/memory ops)
- Notes: Falls through into `LEnter8_16`; implements 8 unrolled two-pixel write pairs

### LEnter8_16
- Signature: Assembly label (fall-through entry)
- Purpose: Entry for an 8-pixel block (4 two-pixel iterations)
- Inputs/Outputs: Same register convention as above
- Notes: Falls through into `LEnter4_16`

### LEnter4_16
- Signature: Assembly label (fall-through entry)
- Purpose: Entry for a 4-pixel block (2 two-pixel iterations)
- Notes: Falls through into `LEnter2_16`

### LEnter2_16
- Signature: Assembly label (fall-through entry)
- Purpose: Entry for the minimal 2-pixel block (1 two-pixel write)
- Notes: Terminal block; does not fall through further

**Notes on `LBPatch0`–`LBPatch15`:**
Each `LBPatch` label marks a **self-modifying patch site** — the address `12345678h` in the palette lookup `mov ax, [12345678h + eax*2]` is overwritten at runtime with the actual 16-bit palette table pointer. There are 16 such patch sites (two per two-pixel block, one for each of the two palette lookups).

## Control Flow Notes
This file is an `.inc` fragment assembled into a larger block-renderer translation unit (likely `ref_soft/r_scan.c` or an associated `.asm`). The caller sets up all registers, then jumps to one of the four entry labels depending on the residual pixel count for the current span. Each entry point falls through to the next smaller one, and execution exits off the bottom of `LEnter2_16` back into the caller's frame.

## External Dependencies
- No includes; this is a pure assembly fragment
- `12345678h` placeholder addresses are patched at load/init time by the surrounding C or assembly initializer with the address of the active 16-bit color palette lookup table
- Register ABI (`esi`, `edi`, `ebx`, `edx`, `ebp`) is a calling convention defined by the enclosing rasterizer, not within this file
