# game/m_tank.h

## File Purpose
Auto-generated header defining animation frame index constants for the Tank monster model in Quake 2. It maps symbolic frame names to sequential integer indices used by the animation system in `game/m_tank.c`.

## Core Responsibilities
- Exposes all frame index constants for the Tank's animation sequences: stand, walk, attack (4 variants), pain (3 variants), death, and reclining
- Defines the model scale constant used when registering or sizing the Tank model
- Serves as the single source of truth for frame numbering, preventing magic numbers in the Tank AI logic

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions
None. This file contains only preprocessor `#define` constants.

**Notes:**
- All symbols are plain `#define` macros — no functions, structs, or variables are declared.
- Frame numbering is zero-based and contiguous (0–293), reflecting the raw frame layout of the Tank's MD2 model file.

## Control Flow Notes
This header is included by `game/m_tank.c`. The constants it defines are used to index into animation sequence tables (arrays of `mframe_t`) and to set `s.frame` on the entity during state transitions driven by the AI. It plays no direct role in init/frame/update logic itself — it is purely a data reference layer consumed at compile time.

## External Dependencies
- No includes.
- No external symbols referenced.

## Animation Sequence Summary

| Sequence | Frame Names | Index Range | Count |
|---|---|---|---|
| Stand | `FRAME_stand01`–`FRAME_stand30` | 0–29 | 30 |
| Walk | `FRAME_walk01`–`FRAME_walk25` | 30–54 | 25 |
| Attack 1 | `FRAME_attak101`–`FRAME_attak122` | 55–76 | 22 |
| Attack 2 | `FRAME_attak201`–`FRAME_attak238` | 77–114 | 38 |
| Attack 3 | `FRAME_attak301`–`FRAME_attak353` | 115–167 | 53 |
| Attack 4 | `FRAME_attak401`–`FRAME_attak429` | 168–196 | 29 |
| Pain 1 | `FRAME_pain101`–`FRAME_pain104` | 197–200 | 4 |
| Pain 2 | `FRAME_pain201`–`FRAME_pain205` | 201–205 | 5 |
| Pain 3 | `FRAME_pain301`–`FRAME_pain316` | 206–221 | 16 |
| Death | `FRAME_death101`–`FRAME_death132` | 222–253 | 32 |
| Reclining | `FRAME_recln101`–`FRAME_recln140` | 254–293 | 40 |

`MODEL_SCALE` is `1.000000`, indicating the Tank model is used at native export scale with no runtime scaling applied.
