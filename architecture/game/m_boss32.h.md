# game/m_boss32.h

## File Purpose
Auto-generated header defining animation frame index constants for the Boss3 "rider" monster model. Maps named animation frames to sequential integer indices consumed by the game's animation system.

## Core Responsibilities
- Enumerate all animation frames for the boss3/rider model as preprocessor constants
- Provide a `MODEL_SCALE` constant for this model's world-space scaling factor
- Serve as the sole interface between the monster logic in `m_boss32.c` and the underlying MD2 model frame data

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions
None. This is a pure constants header; it contains no functions, variables, or type definitions.

## Control Flow Notes
Included by `game/m_boss32.c`. Frame constants are referenced when building `mmove_t` animation sequence descriptors (first/last frame pairs) that drive the monster's per-think animation stepping. The engine advances the entity's `s.frame` field through these ranges each server frame.

Animation groups present:

| Group prefix | Frame range | Count | Notes |
|---|---|---|---|
| `attak1xx` | 0–17 | 18 | Attack sequence 1 |
| `attak2xx` | 18–30 | 13 | Attack sequence 2 |
| `death[1]xx` | 31–80 | 50 | Primary death |
| `pain1xx` | 81–83 | 3 | Pain set 1 |
| `pain2xx` | 84–86 | 3 | Pain set 2 |
| `pain3xx` | 87–111 | 25 | Pain set 3 (long) |
| `standxx` | 112–162 | 51 | Idle stand |
| `walkxx` | 163–187 | 25 | Walk cycle |
| `activexx` | 188–200 | 13 | Activation/alert |
| `attak3xx` | 201–208 | 8 | Attack sequence 3 |
| `attak4xx` | 209–234 | 26 | Attack sequence 4 |
| `attak5xx` | 235–250 | 16 | Attack sequence 5 |
| `death2xx` | 251–345 | 95 | Secondary death (very long) |
| `death3xx` | 346–365 | 20 | Tertiary death |
| `jumpxx` | 366–378 | 13 | Jump |
| `pain4xx` | 379–382 | 4 | Pain set 4 |
| `pain5xx` | 383–386 | 4 | Pain set 5 |
| `pain6xx` | 387–413 | 27 | Pain set 6 (long) |
| `stand2xx` | 414–473 | 60 | Secondary stand |
| `walk2xx` | 474–490 | 17 | Secondary walk cycle |

Total frames: **491** (indices 0–490).

## External Dependencies
- No includes. Standalone constant definitions only.
- Consumed exclusively by `game/m_boss32.c` (and its CTF counterpart `ctf/m_boss32.c` if present).
- Frame indices must match the compiled MD2 model at `baseq2/models/monsters/boss3/rider`.
