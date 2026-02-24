# linux/block16.h

## File Purpose
An x86 AT&T-syntax assembly fragment (`#include`-able header) implementing an unrolled texture block-drawing inner loop for the 16-bit-per-pixel software renderer. It is `#include`d directly into an assembly source file, not compiled independently.

## Core Responsibilities
- Render 2 texels per iteration by performing two parallel palette lookups and writing two 16-bit pixels at once.
- Advance the texture coordinate accumulator (`edx`/`ebp`) for sub-texel precision stepping.
- Step the source texture pointer (`esi`) by two rows per iteration using the texture stride (`ebx`).
- Provide multiple entry points (`LEnter16_16`, `LEnter8_16`, `LEnter4_16`, `LEnter2_16`) so the caller can handle spans whose pixel count is not a multiple of 16 by jumping into the appropriate mid-loop position.
- Expose patch points (`LBPatch0`–`LBPatch15`) so the engine can self-modify the `0x12345678` placeholder addresses at runtime to point to the active 16-bit palette translation table.

## Key Types / Data Structures
None. (Pure assembly fragment; no C types.)

## Global / File-Static State
None. (All state is in CPU registers at the point of inclusion.)

## Key Functions
No C functions. The file defines the following assembly labels:

| Label | Role |
|---|---|
| `LEnter16_16` | Entry for 16-pixel-aligned span tail (8 iterations of 2-pixel body) |
| `LEnter8_16` | Entry skipping first 4 iterations (8-pixel tail) |
| `LEnter4_16` | Entry skipping first 6 iterations (4-pixel tail) |
| `LEnter2_16` | Entry for final 2-pixel tail |
| `LBPatch0`–`LBPatch15` | Self-modification patch sites for the palette table base address |

### Per-iteration body (repeated 8×)
- **Pattern:** Load two adjacent texture row bytes into `al`/`cl`; copy the fractional-step high byte into `ah`/`ch` to form 16-bit indices; look up each index in the 16-bit colour table via `0x12345678(,%eax,2)` / `0x12345678(,%ecx,2)`; write the resulting 16-bit words to `(%edi)` and `2(%edi)`; advance the destination pointer by 4 bytes.
- **Register contract:** `esi` = source texel pointer, `ebx` = texture row stride, `edx:dh` = fixed-point V accumulator, `ebp` = V step, `edi` = 16-bpp framebuffer destination.

## Control Flow Notes
This fragment is `#include`d inside a larger assembly routine (likely `linux/r_surf8.s` or equivalent) that handles span rasterisation. The caller sets up all registers, performs the aligned 16-pixel bulk loop, then falls through or jumps to one of the `LEnter*_16` labels to consume the remaining 2/4/8/16 pixels. After the last iteration the outer routine continues with its own epilogue. This file has no prologue or epilogue of its own.

## External Dependencies
- **Included by:** an assembly (`.s`) file in `linux/` that manages the outer scan-line loop and register setup.
- **Runtime patch target:** a 16-bit palette translation table whose address replaces `0x12345678` at load/init time — defined and patched elsewhere (likely `linux/vid_so.c` or the soft-renderer initialisation path).
- No C headers or external symbols are referenced directly.
