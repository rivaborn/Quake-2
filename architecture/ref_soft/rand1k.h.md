# ref_soft/rand1k.h

## File Purpose
A raw data header containing 1,024 pre-generated random byte values in the range 0–255. It is intended to be `#include`-d directly into an array initializer within the software renderer, providing a fixed-seed lookup table for pseudo-random effects.

## Core Responsibilities
- Supply a statically embedded table of 1,024 random bytes (range 0–255) for use by the software renderer.
- Eliminate runtime random number generation overhead by providing a precomputed lookup table.
- Enable deterministic, repeatable pseudo-random access patterns for visual effects (e.g., particle noise, dithering, surface variation).

## Key Types / Data Structures
None.

## Global / File-Static State
None. (All state lives in whichever translation unit `#include`s this file into an array declaration.)

## Key Functions
None. This file contains no function definitions.

## Control Flow Notes
This file is not a standalone compilation unit. It is `#include`-d inside an array initializer expression in a `.c` file within the software renderer (`ref_soft/`). At that usage site the bytes become a `static` or global `unsigned char` (or `int`) array. Callers index into the table — typically masked with `& 0x3FF` (1023) or a similar bitmask — to retrieve pseudo-random values during rendering without calling `rand()`. Not inferable which specific `.c` files consume it without inspecting those files directly.

## External Dependencies
- No `#include` directives.
- No external symbols.
- Depends entirely on the including file to provide the surrounding array declaration and type context.
