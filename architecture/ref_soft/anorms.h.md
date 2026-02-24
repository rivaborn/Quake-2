# ref_soft/anorms.h

## File Purpose
A raw data header containing 162 pre-computed unit normal vectors arranged on an icosahedron-derived sphere. These normals are used by the software renderer to approximate lighting on alias (MD2) models.

## Core Responsibilities
- Provides the Quake 2 standard normal lookup table (162 entries, matching the Quake MDL/MD2 normal encoding scheme)
- Each entry is a unit-length 3D vector `{x, y, z}` stored as float literals
- Intended to be included directly inside an array initializer or variable declaration in a `.c` file

## Key Types / Data Structures
None. The file contains only raw brace-enclosed float triplet initializers — no type declarations.

## Global / File-Static State
None declared in this file. State is created by whichever translation unit `#include`s this file inside an array definition.

## Key Functions
None. This is a pure data file with no functions.

## Control Flow Notes
This file is not self-contained — it is `#include`d inside an array declaration in another `.c` file (e.g., `r_alias.c` or `r_light.c`), typically as:

```c
float r_avertexnormals[NUMVERTEXNORMALS][3] = {
#include "anorms.h"
};
```

At runtime, the array is indexed using the 8-bit normal index packed into each MD2 vertex to look up a precomputed lighting value, avoiding per-frame normal computation. This is part of the alias model lighting path during the render frame.

## External Dependencies
- No `#include` directives
- No external symbols
- Depends entirely on the including `.c` file to provide the surrounding array declaration context
