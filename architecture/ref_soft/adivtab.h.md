# ref_soft/adivtab.h

## File Purpose
A precomputed lookup table of integer division results (quotient and remainder pairs) for all combinations of numerator in [-15...16] and denominator in [-15...16]. It eliminates runtime integer division in the software renderer's inner loops.

## Core Responsibilities
- Stores 32×32 = 1024 `{quotient, remainder}` pairs as raw brace-initializer data
- Provides O(1) division results for small signed integers used in texture/span rasterization
- Intended to be `#include`d directly into a struct/array initializer, not used as a standalone header

## Key Types / Data Structures
None. The file contains only raw aggregate initializer data (`{int, int}` pairs). The consuming array type is defined in the including translation unit.

## Global / File-Static State
None. This file defines no variables, functions, or macros — it is pure data.

## Key Functions
None.

## Control Flow Notes
This file is not self-contained. It is `#include`d into another source file (expected: `ref_soft/r_alias.c` or similar software rasterizer code) inside an array initializer declaration. The including file defines the element type (a struct with quotient and remainder fields) and the array variable. At runtime, the renderer indexes into the resulting array using `(numerator + 15) * 32 + (denominator + 15)` or equivalent offset arithmetic to retrieve precomputed `n/d` and `n%d` without executing a division instruction.

## External Dependencies
- No `#include` directives
- No external symbols referenced
- Depends entirely on the including translation unit for type context and array declaration
