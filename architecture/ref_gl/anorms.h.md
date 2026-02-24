# ref_gl/anorms.h

## File Purpose
A raw data table of 162 pre-computed unit normal vectors, evenly distributed across the sphere using an icosahedron-based subdivision. Used by the alias model rendering system to convert compressed 8-bit normal indices (stored in MD2 model vertex data) back into 3D lighting normals.

## Core Responsibilities
- Provides the lookup table `r_avertexnormals` (or equivalent) mapping integer indices to unit normals
- Enables decompression of per-vertex normals from MD2's compact 1-byte representation
- Supplies normals for per-vertex diffuse lighting on alias (MD2) models in the GL renderer

## Key Types / Data Structures
None. This file contains only raw initializer data (brace-enclosed float triplets).

## Global / File-Static State
None declared in this file. The data is intended to be used as an initializer for an array declared in a `.c` file (typically `float r_avertexnormals[162][3]`).

## Key Functions
None. This is a pure data header with no functions.

## Control Flow Notes
This file is `#include`d directly into a `.c` source file (likely `gl_mesh.c` or `gl_rmain.c`) inside an array initializer block. It participates in the model rendering path:
- At render time, each MD2 vertex carries a 1-byte `lightnormalindex`
- The renderer indexes into the `r_avertexnormals` table using that index
- The resulting normal vector is dotted against the light direction to compute per-vertex intensity

## External Dependencies
- No `#include` directives — not a self-contained header
- Depends on the enclosing `.c` file to supply the array declaration context
- Identical or near-identical copies exist at `client/anorms.h` and `ref_soft/anorms.h`, shared across the soft and GL renderers and the client
