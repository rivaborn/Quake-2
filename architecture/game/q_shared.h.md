# game/q_shared.h

## File Purpose
The universal shared header included first by all Quake 2 program modules (client, server, game DLL, renderers). It defines the engine's foundational type system, math primitives, collision structures, network protocol constants, and cross-module interfaces that must remain ABI-compatible across all subsystems.

## Core Responsibilities
- Define primitive types (`byte`, `qboolean`, `vec_t`, `vec3_t`) and platform detection macros
- Declare math library functions and vector operation macros
- Define all collision detection types (`cplane_t`, `cmodel_t`, `trace_t`, `csurface_t`)
- Define player movement types (`pmove_t`, `pmove_state_t`, `usercmd_t`) for client-side prediction
- Define network protocol constants: entity/player state structures, config string indices, temp events, muzzle flash IDs
- Declare system-level utility interfaces (hunk allocator, file system search, byte-order swapping)
- Define the `cvar_t` structure and flag constants shared by all subsystems

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `qboolean` | typedef enum | Boolean type (`false`/`true`) used engine-wide |
| `vec3_t` | typedef (float[3]) | 3D vector, fundamental math primitive |
| `cplane_t` | struct | Collision plane with normal, dist, type, signbits; layout fixed for ASM |
| `cmodel_t` | struct | Collision model with bounds and BSP headnode |
| `csurface_t` | struct | Surface metadata (name, flags, value) for collision results |
| `mapsurface_t` | struct | Extended surface with full renderer name (32-char) alongside collision name |
| `trace_t` | struct | Result of a swept-box trace through the world |
| `pmtype_t` | enum | Player movement mode (NORMAL, SPECTATOR, DEAD, GIB, FREEZE) |
| `pmove_state_t` | struct | Bit-accurate network-synchronized movement state (short-quantized origin/velocity) |
| `usercmd_t` | struct | Per-frame client input sent to server |
| `pmove_t` | struct | Full player movement context with callbacks for world query |
| `entity_state_t` | struct | Per-entity network update data (origin, angles, model, effects, event) |
| `player_state_t` | struct | Per-player render state sent 10x/sec (view, gun, blend, stats) |
| `cvar_t` | struct | Console variable with name, string, latched string, flags, float value |
| `multicast_t` | enum | Routing scope for `gi.multicast()` (ALL/PHS/PVS, reliable variants) |
| `temp_event_t` | enum | One-shot world-space effect events (explosions, blood, beams, etc.) |
| `entity_event_t` | enum | Per-entity impulse events (footstep, fall, teleport, item respawn) |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `vec3_origin` | `vec3_t` | global (extern) | Shared zero vector constant |
| `curtime` | `int` | global (extern) | Millisecond timestamp from last `Sys_Milliseconds()` call |
| `monster_flash_offset` | `vec3_t[]` | global (extern) | Per-MZ2 muzzle flash position offsets for all monster types |
| `vidref_val` | `int` | global (extern) | Active renderer type identifier (GL=1, SOFT=2, OTHER=3) |

## Key Functions

### Vector math macros
- `DotProduct`, `VectorSubtract`, `VectorAdd`, `VectorCopy`, `VectorClear`, `VectorNegate`, `VectorSet` — inline comma-expression macros operating on `vec3_t`; no function call overhead.

### AngleVectors
- **Signature:** `void AngleVectors(vec3_t angles, vec3_t forward, vec3_t right, vec3_t up)`
- **Purpose:** Decomposes Euler angles into three orthogonal basis vectors.
- **Inputs:** Pitch/yaw/roll angles.
- **Outputs/Return:** Writes into `forward`, `right`, `up` (any may be NULL in implementations).
- **Side effects:** None.
- **Calls:** Not inferable from this file (declared only).
- **Notes:** Core to all directional aiming, camera, and physics calculations.

### BoxOnPlaneSide
- **Signature:** `int BoxOnPlaneSide(vec3_t emins, vec3_t emaxs, struct cplane_s *plane)`
- **Purpose:** Classifies an AABB relative to a plane: 1=front, 2=back, 3=spanning.
- **Inputs:** Box min/max corners, collision plane.
- **Outputs/Return:** int side classification.
- **Side effects:** None.
- **Notes:** The `BOX_ON_PLANE_SIDE` macro fast-paths axial planes (type < 3) before calling this function.

### VectorNormalize / VectorNormalize2
- **Signature:** `vec_t VectorNormalize(vec3_t v)` / `vec_t VectorNormalize2(vec3_t v, vec3_t out)`
- **Purpose:** Normalize a vector in-place or to a separate output; returns original length.
- **Notes:** Distinguished by whether source is modified.

### COM_Parse
- **Signature:** `char *COM_Parse(char **data_p)`
- **Purpose:** Tokenizer advancing a text pointer through whitespace/quoted strings; central to config and script parsing.
- **Inputs:** Pointer-to-pointer into source text.
- **Outputs/Return:** Pointer to static token buffer; advances `*data_p`.
- **Side effects:** Writes to internal static buffer.

### Info_* functions
- `Info_ValueForKey`, `Info_RemoveKey`, `Info_SetValueForKey`, `Info_Validate` — manipulate `\key\value\key\value` info strings used for userinfo/serverinfo cvars.

### Swap_Init / BigShort / LittleShort / etc.
- **Purpose:** Byte-order detection and swapping for cross-platform network/file data compatibility.
- **Notes:** `Swap_Init` selects function pointers at runtime based on detected endianness.

### Hunk_Begin / Hunk_Alloc / Hunk_End / Hunk_Free
- **Purpose:** Level-lifetime stack allocator for large contiguous memory blocks (models, etc.).
- **Notes:** Declared here for shared use; implemented in platform-specific sys code.

## Control Flow Notes
This file has no runtime control flow of its own. It is a pure declaration header. It is included before all other headers in every translation unit. The structures it defines (`pmove_state_t`, `entity_state_t`, `player_state_t`) are the wire-format types transmitted each network frame between server and client. `pmove_t` with its callback pointers is populated by the server (using world trace functions) and by the client (using local prediction), then passed to `Pmove()` each frame.

## External Dependencies
- **Standard C:** `<assert.h>`, `<math.h>`, `<stdio.h>`, `<stdarg.h>`, `<string.h>`, `<stdlib.h>`, `<time.h>`
- **Platform macros:** `id386`, `idaxp` guard x86/Alpha ASM paths
- `Q_ftol` — either an extern ASM fast float-to-long (x86/non-Linux) or a cast macro
- All declared functions are **defined elsewhere**: math functions in `game/q_shared.c`; system functions in platform-specific `sys_*.c`; hunk allocator in platform sys code
