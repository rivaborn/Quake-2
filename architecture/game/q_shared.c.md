# game/q_shared.c

## File Purpose
Shared utility library included by both game and engine modules, providing math primitives, string utilities, byte-order handling, token parsing, and info-string manipulation. This is a self-contained "standard library" layer for the Quake 2 codebase, compiled into the game DLL directly.

## Core Responsibilities
- 3D vector and matrix math (normalize, cross product, dot product, rotation, bounds)
- Angle conversion and interpolation utilities
- Platform-portable byte-order (endianness) initialization and swap functions
- BSP plane-side classification for AABB vs. plane (`BoxOnPlaneSide`)
- String utilities: case-insensitive compare, path manipulation, `va()` formatting
- Token parser (`COM_Parse`) for config/script text streams
- Info-string key/value encoding, lookup, mutation, and validation

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `cplane_s` | struct (extern) | BSP plane with normal, dist, type, signbits; used by `BoxOnPlaneSide` |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `vec3_origin` | `vec3_t` | global | Shared zero-vector constant |
| `bigendien` | `qboolean` | global | Set by `Swap_Init`; true if big-endian host |
| `_BigShort` … `_LittleFloat` | function pointers (6×) | global | Dispatch to swap or no-op based on endianness |
| `com_token` | `char[MAX_TOKEN_CHARS]` | file-static (effectively global) | Reused buffer returned by `COM_Parse` |
| `paged_total` | `int` | global | Accumulator for `Com_PageInMemory` touch loop |
| `i`, `corners[2]` | `int`, `vec3_t[2]` | global (file scope leak) | Orphaned globals outside any function — likely a copy-paste artifact |

## Key Functions

### RotatePointAroundVector
- Signature: `void RotatePointAroundVector(vec3_t dst, const vec3_t dir, const vec3_t point, float degrees)`
- Purpose: Rotates `point` around arbitrary axis `dir` by `degrees` using a change-of-basis + Z-rotation + inverse-basis matrix chain.
- Inputs: Destination vector, rotation axis (normalized), point to rotate, angle in degrees.
- Outputs/Return: Result written to `dst`.
- Side effects: None.
- Calls: `PerpendicularVector`, `CrossProduct`, `R_ConcatRotations`
- Notes: Wrapped in `#pragma optimize("", off/on)` on MSVC to avoid FP codegen bugs.

### AngleVectors
- Signature: `void AngleVectors(vec3_t angles, vec3_t forward, vec3_t right, vec3_t up)`
- Purpose: Decomposes a Euler angle triple (pitch/yaw/roll) into orthonormal basis vectors.
- Inputs: `angles` in degrees; any of `forward`/`right`/`up` may be NULL.
- Outputs/Return: Writes to non-NULL output vectors.
- Side effects: Uses `static` sin/cos locals (MSVC FP bug workaround).
- Calls: `sin`, `cos`

### BoxOnPlaneSide
- Signature: `int BoxOnPlaneSide(vec3_t emins, vec3_t emaxs, struct cplane_s *p)`
- Purpose: Classifies an AABB against a BSP plane; returns 1 (front), 2 (back), or 3 (spanning).
- Inputs: Box min/max corners, plane pointer with `type`, `signbits`, `normal`, `dist`.
- Outputs/Return: Integer side mask.
- Side effects: None.
- Calls: Nothing (pure arithmetic).
- Notes: On x86 Windows (`id386`), replaced with a `__declspec(naked)` x87 FPU assembly version using a self-initializing jump table (`Ljmptab`). On all other platforms, uses an 8-case `switch` on `p->signbits` to select min/max corner per axis.

### Swap_Init
- Signature: `void Swap_Init(void)`
- Purpose: Detects host endianness and wires the `_BigShort`/`_LittleShort`/etc. function pointers.
- Inputs: None.
- Outputs/Return: None.
- Side effects: Sets `bigendien` and 6 global function pointers.
- Calls: None (runtime type probe via union trick).

### COM_Parse
- Signature: `char *COM_Parse(char **data_p)`
- Purpose: Extracts one whitespace-delimited or quoted token from a text stream, advancing the pointer.
- Inputs: Pointer-to-pointer into a null-terminated string.
- Outputs/Return: Pointer to static `com_token` buffer; `*data_p` advanced past token.
- Side effects: Overwrites `com_token`.
- Notes: Skips `//` line comments; handles quoted strings; silently discards tokens exceeding `MAX_TOKEN_CHARS`.

### Info_SetValueForKey / Info_ValueForKey / Info_RemoveKey
- Purpose: Manage `\key\value\key\value` encoded info strings used for player/server metadata.
- Notes: `Info_ValueForKey` uses a double-buffer (`value[2]`) so two calls can be compared safely. `Info_Validate` rejects strings containing `"` or `;`.

### VectorNormalize / VectorNormalize2
- Signature: `vec_t VectorNormalize(vec3_t v)` / `vec_t VectorNormalize2(vec3_t v, vec3_t out)`
- Purpose: Normalizes a vector in-place or to a separate output; returns original length.
- Notes: In-place version used heavily throughout the engine; `sqrt` is forward-declared as `double sqrt(double)`.

**Notes on trivial helpers:** `_DotProduct`, `_VectorSubtract`, `_VectorAdd`, `_VectorCopy` are non-inline fallbacks for macro equivalents. `VectorMA`, `CrossProduct`, `VectorScale`, `VectorInverse`, `VectorLength`, `ClearBounds`, `AddPointToBounds`, `VectorCompare`, `Q_fabs`, `LerpAngle`, `anglemod`, `Q_log2` are all self-contained single-operation utilities.

## Control Flow Notes
This file has no frame-loop participation. It is a pure utility module initialized once via `Swap_Init` (called at engine startup from `Qcommon_Init`). All other functions are stateless helpers called on demand throughout game logic, renderer, and common layers.

## External Dependencies
- **Includes:** `q_shared.h` (defines `vec3_t`, `cplane_s`, `MAX_TOKEN_CHARS`, `MAX_INFO_STRING`, `MAX_INFO_KEY`, `qboolean`, macros like `DotProduct`, `VectorNormalize`)
- **External symbols used:** `Com_Printf` (defined in `qcommon/common.c`), `PerpendicularVector` (defined in this file, called recursively by `RotatePointAroundVector`), `R_ConcatRotations` (defined in this file)
- `Q_ftol`: x86 MSVC-only naked ASM; not available on non-MSVC targets
- `sqrt`, `sin`, `cos`, `fabs`, `memcpy`, `memset`, `strcmp`, `strncpy`, `strcpy`, `strcat`, `strlen`, `strstr`, `vsprintf`: standard C library
