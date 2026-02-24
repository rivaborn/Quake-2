# ref_gl/warpsin.h

## File Purpose
A raw data header containing a precomputed sine wave lookup table scaled by 8, used to drive texture coordinate warping for liquid/warp surfaces in the OpenGL renderer. It is intended to be included directly inside an array initializer, not as a standalone declaration.

## Core Responsibilities
- Provides 256 precomputed float values representing one full cycle of `8 * sin(x)` for x in [0, 2π)
- Eliminates runtime `sin()` calls for warp surface texture animation
- Encodes both positive and negative half-cycles, forming a complete sine period

## Key Types / Data Structures
None.

## Global / File-Static State
None. This file contains only raw comma-separated float literals — no declarations or definitions.

## Key Functions
None.

## Control Flow Notes
This file is `#include`-d inside an array initializer in `ref_gl/gl_warp.c`, likely as:

```c
float warpsin[] = {
#include "warpsin.h"
};
```

At runtime, the array is indexed using a time-based offset (typically `(time * SPEED + texcoord) & 255`) to animate warp surfaces such as water, slime, and lava. It fits into the **per-frame render path** for warp surfaces — consulted during surface texture coordinate generation, not during init or shutdown.

## External Dependencies
- No includes of its own
- Consumed by: `ref_gl/gl_warp.c` (defined elsewhere)

**Notes:**
- 256 entries total — designed for power-of-two masked indexing (`& 255`)
- Amplitude is 8 (range: −8 to +8), matching the warp displacement scale used in `gl_warp.c`
- Entry at index 128 is `9.79717e-16` (floating-point zero artifact) rather than exactly `0.0`, confirming values were generated programmatically via `sin()`
- No include guards — safe only because the file is raw data, not a header with declarations
