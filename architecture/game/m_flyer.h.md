# game/m_flyer.h

## File Purpose
Auto-generated header defining animation frame index constants and action constants for the Flyer monster's 3D model. It maps human-readable frame names to sequential integer indices used by the animation system.

## Core Responsibilities
- Define named constants for every animation frame in the Flyer model
- Define action ID constants used to identify animation state categories
- Expose the model's scale factor for use by the renderer or physics system

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions
None. This is a pure constants header with no functions.

## Control Flow Notes
Passive data file. Included by `game/m_flyer.c`, which drives the Flyer AI and references these constants when setting `s.frame` on the entity to advance or switch animation sequences. Frame indices are written into the entity state each game tick; the renderer reads `s.frame` to select the correct model pose.

Animation sequences present:
| Sequence | Frame Range | Frames |
|---|---|---|
| `start` | 0–5 | 6 |
| `stop` | 6–12 | 7 |
| `stand` | 13–57 | 45 |
| `attak1` | 58–78 | 21 |
| `attak2` | 79–95 | 17 |
| `bankl` | 96–102 | 7 |
| `bankr` | 103–109 | 7 |
| `rollf` | 110–118 | 9 |
| `rollr` | 119–127 | 9 |
| `defens` | 128–133 | 6 |
| `pain1` | 134–142 | 9 |
| `pain2` | 143–146 | 4 |
| `pain3` | 147–150 | 4 |

## External Dependencies
- No includes.
- Consumed by: `game/m_flyer.c` (not inferable from this file alone, but standard pattern for all `m_*.h` headers).
