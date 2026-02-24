# client/anorms.h

## File Purpose
A raw data table of 162 pre-computed unit normal vectors distributed approximately uniformly across the surface of a sphere. These are the Quake/id Software "anorms" (alias normals) used to represent lighting normals for alias (MD2) models in a compact, quantized form.

## Core Responsibilities
- Provides the 162-entry icosphere normal lookup table used by alias model lighting calculations
- Encodes each 3D normal as a `{x, y, z}` float triple, all unit-length (magnitude ≈ 1.0)
- Allows the engine to store a normal index (1 byte) in model data rather than 12 bytes of floats
- Shared across client rendering code and potentially software/GL renderers that include this header

## Key Types / Data Structures
None. The file contains only raw brace-enclosed float triplets — no type declarations.

## Global / File-Static State
None declared in this file. The file is intended to be `#include`d inside an array initializer or similar declaration in the including translation unit. The including file supplies the variable name, type, and storage class.

## Key Functions
None. This is a pure data file with no functions.

## Control Flow Notes
Not directly part of any init/frame/render cycle. The table is included as a static array initializer in files such as `cl_fx.c`, `r_alias.c`, or equivalent alias model lighting modules. At runtime, a byte-sized normal index stored per-vertex in MD2 model frames is used to index into this array, retrieving the pre-baked normal for diffuse lighting dot-product calculations. No runtime code lives here.

## External Dependencies
- No `#include` directives present
- No external symbols referenced
- Consumed by: any `.c` file that declares an array and then `#include`s this file (e.g., `float r_avertexnormals[NUMVERTEXNORMALS][3] = { #include "anorms.h" }`)

## Notes
- 162 entries correspond to the vertices of a subdivided icosahedron — the same table used in Quake 1 and carried forward into Quake 2
- All vectors are unit-length floating-point; `{0,0,1}` and `{0,0,-1}` (poles) and `{1,0,0}`, `{-1,0,0}` appear explicitly confirming normalization
- The file deliberately has no header guards or type declarations, making it an "inline data include" pattern — a common id Software idiom of the era
