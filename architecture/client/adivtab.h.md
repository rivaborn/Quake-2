# client/adivtab.h

## File Purpose
A precomputed lookup table of integer division quotient/remainder pairs for all combinations of numerator in [-15...16] and denominator in [-15...16]. It exists to replace costly integer division operations with a direct table lookup in the software renderer's inner loops.

## Core Responsibilities
- Provide all 32×32 = 1024 precomputed `{quotient, remainder}` pairs for integer division across the signed range [-15, 16].
- Eliminate runtime division in performance-critical rendering code paths.
- Handle the division-by-zero case (denominator = 0) gracefully by storing `{0, 0}`.

## Key Types / Data Structures
None. The file is raw aggregate initializer data, intended to be embedded inside an array declaration in the including translation unit.

## Global / File-Static State
None. The file contains no declarations — only struct initializer list entries.

## Key Functions
None. This is a pure data file with no functions.

## Control Flow Notes
This file is `#include`d into a C array definition in the software renderer (likely `ref_soft/` or the `client/` alias copy). During initialization the surrounding array is populated once; at render time, aliased polygon/span rasterization code indexes into the table using `numerator` and `denominator` offsets (both shifted by 15 to convert to zero-based indices) to recover a quotient and remainder without executing a hardware divide instruction. This was a significant optimization on late-1990s x86 hardware where integer division was expensive.

## External Dependencies
- No includes of its own.
- Depends entirely on the enclosing file to declare the array type (typically a struct with two `int` fields, `quotient` and `remainder`, or equivalent) before `#include`-ing this file.
- Defined elsewhere: the struct/array type into which these initializers are inserted.
