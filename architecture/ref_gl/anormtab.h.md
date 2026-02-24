# ref_gl/anormtab.h

## File Purpose
This header contains a precomputed 2D lookup table of floating-point scalar values used to approximate per-normal lighting dot products for alias model (MD2) rendering in the GL renderer. Each row corresponds to a discrete light pitch angle, and each column corresponds to one of the 162 precalculated vertex normals (plus padding to 256 entries) used by Quake 2's alias model format.

## Core Responsibilities
- Provide a static, compile-time data table for normal-to-light dot product approximation
- Map (light pitch index × normal index) → scalar intensity multiplier
- Eliminate per-frame trigonometric computation for alias model lighting
- Pad each row to 256 entries (remaining entries filled with `1.00`) to allow power-of-2 indexing

## Key Types / Data Structures
None. The file contains only raw data intended to be embedded in an array initializer.

## Global / File-Static State
None. This file is a fragment (no declarations), included directly into a variable definition elsewhere.

## Key Functions
None. This is a pure data file with no functions.

## Control Flow Notes
This file is `#include`d inside an array initializer in `ref_gl/gl_rmain.c` (or similar), where it is wrapped in a declaration such as:
```c
float r_avertexnormal_dots[SHADEDOT_QUANT][256] = { ... };
```
It is accessed during alias model rendering to look up the dot-product approximation between a precomputed vertex normal and the current light direction, keyed by the quantized light pitch angle. This avoids computing `dot(normal, light_dir)` at runtime per vertex.

## External Dependencies
- No includes.
- Intended to be used by `ref_gl/gl_rmain.c` or equivalent, which defines the enclosing array variable and the `SHADEDOT_QUANT` constant (16 rows visible here, corresponding to 16 discrete pitch quantization steps).
- Parallel structure to `client/anorms.h`, which defines the actual 3D unit normal vectors for the 162 standard Quake 2 alias model normals. This table precomputes the lighting result for each (normal, pitch) pair.

## Control Flow Notes
- Used during the **render** phase only; no involvement in init, update, or shutdown.
- Indexed as `shadedots[normal_index]` where `shadedots` is a pointer to the appropriate row, selected by quantizing the current light yaw/pitch angle before the draw call.
- The trailing `1.00` padding entries (indices 162–255) act as neutral multipliers if any code accidentally indexes beyond the 162 valid normals.
