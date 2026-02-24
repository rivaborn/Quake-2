# ctf/q_shared.c

## File Purpose
Shared utility library for the CTF game module, providing math, string, byte-order, and info-string primitives used across client, server, and game code. This is a near-identical copy of `game/q_shared.c` scoped to the CTF mod.

## Core Responsibilities
- 3D vector and matrix math (normalize, cross product, rotation, bounds)
- Angle/rotation utilities (AngleVectors, LerpAngle, anglemod)
- AABB plane-side classification (BoxOnPlaneSide, with x86 asm fast path)
- Byte-order detection and endian-swap initialization
- String utilities (case-insensitive compare, sprintf wrapper, token parser)
- File path manipulation (strip extension, file base, default extension)
- Info-string key/value encoding and parsing

## Key Types / Data Structures
None defined in this file (all types come from `q_shared.h`).

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `vec3_origin` | `vec3_t` | global | Canonical zero vector `{0,0,0}` |
| `bigendien` | `qboolean` | global | True if host is big-endian |
| `_BigShort` … `_LittleFloat` | function pointers | global | Dispatch table for endian conversion, set by `Swap_Init` |
| `com_token` | `char[MAX_TOKEN_CHARS]` | file-static (effectively global) | Scratch buffer returned by `COM_Parse` |
| `paged_total` | `int` | global | Accumulator used by `Com_PageInMemory` |
| `i`, `corners[2]` | `int`, `vec3_t[2]` | global (file scope leak) | Orphaned declarations between `anglemod` and `BoxOnPlaneSide2` — likely a copy/paste artifact |

## Key Functions

### RotatePointAroundVector
- Signature: `void RotatePointAroundVector(vec3_t dst, const vec3_t dir, const vec3_t point, float degrees)`
- Purpose: Rotates `point` around arbitrary axis `dir` by `degrees`.
- Inputs: Axis direction, source point, rotation angle in degrees.
- Outputs/Return: Result written to `dst`.
- Side effects: None.
- Calls: `PerpendicularVector`, `CrossProduct`, `R_ConcatRotations`.
- Notes: Wrapped in `#pragma optimize("", off/on)` for MSVC fp correctness.

### AngleVectors
- Signature: `void AngleVectors(vec3_t angles, vec3_t forward, vec3_t right, vec3_t up)`
- Purpose: Decomposes a Euler angle triple (pitch/yaw/roll) into orthonormal basis vectors.
- Inputs: `angles` in degrees; any of `forward`/`right`/`up` may be NULL.
- Outputs/Return: Writes to non-NULL output vectors.
- Side effects: Uses `static` locals `sr,sp,sy,cr,cp,cy` — not thread-safe.
- Calls: `sin`, `cos`.

### BoxOnPlaneSide
- Signature: `int BoxOnPlaneSide(vec3_t emins, vec3_t emaxs, struct cplane_s *p)`
- Purpose: Classifies an AABB relative to a plane; returns 1 (front), 2 (back), or 3 (spanning).
- Inputs: Box min/max corners, plane with `type`, `signbits`, `normal`, `dist`.
- Outputs/Return: Bitmask int.
- Side effects: None (C path); x86 asm path uses static `bops_initialized` and `Ljmptab[8]` jump table.
- Calls: Nothing (inline arithmetic).
- Notes: `#if id386` selects hand-written x86 FPU assembly; C fallback covers all other targets. `BoxOnPlaneSide2` is a slower general reference version defined above it.

### Swap_Init
- Signature: `void Swap_Init(void)`
- Purpose: Detects host endianness and assigns the six endian-conversion function pointers.
- Inputs: None.
- Outputs/Return: Sets `bigendien` and `_Big*`/`_Little*` globals.
- Side effects: Global function-pointer table mutation.
- Calls: None (pointer assignments only).

### COM_Parse
- Signature: `char *COM_Parse(char **data_p)`
- Purpose: Extracts one whitespace/comment-delimited token from a string, advancing the pointer.
- Inputs: Pointer-to-pointer into source text.
- Outputs/Return: Pointer to static `com_token` buffer; advances `*data_p`.
- Side effects: Overwrites `com_token` static buffer — not reentrant.
- Calls: None.
- Notes: Handles `//` line comments and double-quoted strings; silently truncates tokens exceeding `MAX_TOKEN_CHARS`.

### Info_SetValueForKey / Info_ValueForKey / Info_RemoveKey
- Purpose: Manage `\key\value\key\value` formatted info strings used for player/server metadata.
- Notes: `Info_ValueForKey` uses a two-slot static buffer for value returns to allow one comparison without clobber. `Info_Validate` rejects strings containing `"` or `;`.

## Control Flow Notes
This file is a pure utility library with no frame or init hooks of its own. `Swap_Init` must be called once at engine startup before any `BigShort`/`LittleFloat` etc. calls are valid. All other functions are stateless helpers callable at any time.

## External Dependencies
- Notable includes: `q_shared.h` (all type and macro definitions)
- `Com_Printf` — defined elsewhere (engine common layer); used for error/warning output in string utilities
- `sin`, `cos`, `sqrt`, `fabs`, `vsprintf`, `strcasecmp`/`_stricmp` — C runtime
- `VectorNormalize`, `DotProduct` — macros or functions declared in `q_shared.h`
- `R_ConcatRotations` — defined in this same file (self-call)
- `ProjectPointOnPlane`, `PerpendicularVector` — also defined in this file
