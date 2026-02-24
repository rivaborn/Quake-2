# client/block16.h

## File Purpose
An x86 AT&T-syntax assembly fragment (included as a header) implementing a hand-unrolled, bilinear-style block-drawing inner loop for 16-bit color mode. It processes pairs of 8-bit palette indices per iteration, looking them up in a 16-bit color translation table, and writes the resulting 16-bit pixels to the output framebuffer.

## Core Responsibilities
- Fetch two source texel indices per span step from a texture/span source (`%esi` + stride `%ebx`)
- Advance a fixed-point U/V coordinate accumulator (`%edx` += `%ebp`) for sub-texel stepping
- Perform palette/color-table lookups converting 8-bit indices to 16-bit RGB values via a patchable address (`0x12345678`)
- Write two 16-bit pixels at a time to the destination buffer (`%edi`), advancing by 4 bytes per block
- Provide multiple entry points (`LEnter16_16`, `LEnter8_16`, `LEnter4_16`, `LEnter2_16`) for power-of-two span lengths (16, 8, 4, 2 pixels), enabling a Duff's-device-style unrolled loop

## Key Types / Data Structures
None (pure assembly fragment; no C types defined).

## Global / File-Static State
None declared here. Relies entirely on caller-established register state and a runtime-patched lookup table address.

## Key Functions
Not applicable — this is an assembly code fragment, not a C translation unit. There are no C functions.

**Entry points (labels used as jump targets):**

| Label | Pixels processed from here to end |
|---|---|
| `LEnter16_16` | 16 pixels (8 block iterations) |
| `LEnter8_16` | 8 pixels (4 block iterations) |
| `LEnter4_16` | 4 pixels (2 block iterations) |
| `LEnter2_16` | 2 pixels (1 block iteration) |

**Per-iteration register convention (inferred):**

| Register | Role |
|---|---|
| `%esi` | Source texel pointer (advanced by `2×%ebx` each block) |
| `%ebx` | Source row stride / span step |
| `%edx:%dh` | Fixed-point stepper; `%dh` used as upper-byte index component |
| `%ebp` | Fixed-point increment added to `%edx` each step |
| `%edi` | Destination framebuffer pointer (16-bit pixels, +4 per block) |
| `%eax/%ecx` | Scratch: texel index pair assembled into table lookup keys |

## Control Flow Notes
This fragment is `#include`-d directly into an assembly or C file containing the surrounding span-rasterizer loop. The caller jumps into one of the `LEnter*_16` labels based on the pixel count modulo 16, then falls through the remaining blocks — a classic unrolled Duff's device pattern. The `LBPatch*` labels (0–15) mark instruction sites where the `0x12345678` placeholder address in each `movw` lookup is overwritten at runtime with the actual address of the 16-bit color translation table.

## External Dependencies
- **No includes** — this file is itself an included fragment.
- `0x12345678` lookup table address: patched at runtime by the surrounding rasterizer initialization code (defined elsewhere).
- Register state: fully set up by the calling span-draw routine (defined elsewhere).
