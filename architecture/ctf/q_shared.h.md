# ctf/q_shared.h

## File Purpose
The universal shared header for the CTF game module, included first by all translation units. It defines the engine-game protocol contract: fundamental types, math primitives, collision structures, network-communicated entity/player state, and all enumerated constants for effects, events, and game configuration.

## Core Responsibilities
- Define portable primitive types (`byte`, `qboolean`) and platform detection macros (`id386`, `idaxp`)
- Declare the math library: vector types, macros, and function prototypes
- Define collision detection structures (`cplane_t`, `cmodel_t`, `trace_t`, `pmove_t`)
- Declare the network protocol types: `entity_state_t`, `player_state_t`, `pmove_state_t`, `usercmd_t`
- Enumerate all effect flags (`EF_*`), render flags (`RF_*`), temp events (`TE_*`), muzzle flashes (`MZ_*`, `MZ2_*`)
- Define config string layout (`CS_*`) and deathmatch flags (`DF_*`)
- Declare system/utility interfaces: cvars, info strings, hunk allocator, byte-order functions

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `qboolean` | enum/typedef | Portable boolean (`false`/`true`) |
| `vec3_t` | typedef (float[3]) | 3D vector |
| `cplane_t` | struct | Collision plane: normal, dist, type, signbits |
| `cmodel_t` | struct | BSP submodel: bounds, origin, headnode |
| `csurface_t` | struct | Surface name, flags, value |
| `mapsurface_t` | struct | Extended surface with full resource name (ZOID CTF addition) |
| `trace_t` | struct | Result of a swept-box collision query |
| `pmove_state_t` | struct | Bit-accurate movement state sent server→client for prediction |
| `pmove_t` | struct | Full player move context including callbacks for world queries |
| `usercmd_t` | struct | Per-frame client input sent to server |
| `entity_state_t` | struct | Per-entity network update (origin, model, effects, event) |
| `player_state_t` | struct | Full player view state (pmove + angles, gun, blend, stats) |
| `cvar_t` | struct | Console variable: name, string, value, flags, linked list |
| `multicast_t` | enum | Destination scope for `gi.multicast()` |
| `pmtype_t` | enum | Player movement mode (normal, spectator, dead, gib, freeze) |
| `temp_event_t` | enum | Temporary effect events broadcast at world positions |
| `entity_event_t` | enum | Single-frame entity-relative impulse events |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `vec3_origin` | `vec3_t` | global (extern) | Shared zero vector constant |
| `curtime` | `int` | global (extern) | Millisecond timestamp from last `Sys_Milliseconds` call |
| `monster_flash_offset` | `vec3_t[]` | global (extern) | Per-`MZ2_*` muzzle flash position offsets |
| `vidref_val` | `int` | global (extern) | Active renderer type (`VIDREF_GL`/`VIDREF_SOFT`/`VIDREF_OTHER`) |

## Key Functions

No function bodies are defined in this header. All declarations are prototypes only.

### Notes
- **Math utilities declared**: `VectorMA`, `VectorNormalize`, `CrossProduct`, `AngleVectors`, `BoxOnPlaneSide`, `RotatePointAroundVector`, `R_ConcatRotations`, `R_ConcatTransforms`, `LerpAngle`, `anglemod` — implemented in `ctf/q_shared.c`.
- **String/path utilities declared**: `COM_SkipPath`, `COM_StripExtension`, `COM_Parse`, `Com_sprintf`, `Q_stricmp`, `Q_strncasecmp` — implemented in `ctf/q_shared.c`.
- **Byte-order functions declared**: `BigShort`, `LittleShort`, `BigLong`, `LittleLong`, `BigFloat`, `LittleFloat`, `Swap_Init` — implemented in platform layer.
- **System interface declared**: `Sys_Milliseconds`, `Sys_Mkdir`, `Sys_FindFirst/Next/Close`, `Hunk_Begin/Alloc/Free/End` — implemented in platform-specific code.
- **Info string functions declared**: `Info_ValueForKey`, `Info_RemoveKey`, `Info_SetValueForKey`, `Info_Validate`.
- `BOX_ON_PLANE_SIDE` macro provides inlined fast-path for axis-aligned planes before falling back to `BoxOnPlaneSide`.
- `Q_ftol` is a macro on Linux/SGI, an extern assembly routine on x86 Windows/IRIX.

## Control Flow Notes
This file has no runtime control flow of its own. It is a pure declaration/definition header included as the first dependency of every CTF module. The structures it defines (`pmove_state_t`, `entity_state_t`, `player_state_t`) represent the network protocol boundary — changes to them break prediction sync or require protocol version bumps. `pmove_t` is populated each frame by the server and passed to `Pmove()` in `qcommon/pmove.c`.

## External Dependencies
- **Standard library**: `<assert.h>`, `<math.h>`, `<stdio.h>`, `<stdarg.h>`, `<string.h>`, `<stdlib.h>`, `<time.h>`
- **Defined elsewhere**:
  - `vec3_origin` — `ctf/q_shared.c`
  - `monster_flash_offset` — `game/m_flash.c` (or CTF equivalent)
  - `curtime` — platform `sys_*.c`
  - `vidref_val` — renderer/video init code
  - All declared math, string, system, and byte-order functions — `ctf/q_shared.c` and platform layers
  - `struct edict_s` — forward-declared only; defined in `ctf/g_local.h`
