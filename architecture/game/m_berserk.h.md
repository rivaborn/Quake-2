# game/m_berserk.h

## File Purpose
Auto-generated header defining animation frame index constants for the Berserk monster model. It maps symbolic frame names to sequential integer indices used by the animation system in `game/m_berserk.c`.

## Core Responsibilities
- Enumerate all animation frame indices for the Berserk monster (frames 0–243)
- Define the model scale constant for the Berserk entity
- Provide a stable symbolic interface so `m_berserk.c` can reference frames by name rather than raw integers

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions
None. This file contains only preprocessor `#define` macros.

## Control Flow Notes
Purely a compile-time constant header. Included by `m_berserk.c` (and potentially `ctf/m_berserk` equivalents). The integer values map directly to frame indices in the Berserk `.md2` model file; the animation system in `m_berserk.c` uses these constants to define `mmove_t` frame ranges for each animation state (stand, walk, run, attack, pain, death, etc.).

Animation groups inferable from naming:
| Group | Frames | Notes |
|---|---|---|
| `stand` / `standb` | 0–24 | Idle, two variants |
| `walkc` | 25–35 | Walk cycle |
| `run` | 36–41 | Run cycle |
| `att_a/b/c` | 42–109 | Three melee attack variants |
| `r_att` / `r_attb` | 110–145 | Ranged/rushing attack variants |
| `slam` | 146–168 | Ground slam attack |
| `duck` | 169–178 | Dodge/duck |
| `fall` | 179–198 | Falling |
| `painc` / `painb` | 199–222 | Two pain reactions |
| `death` / `deathc` | 223–243 | Two death sequences |

## External Dependencies
- No includes.
- `MODEL_SCALE 1.000000` — consumed by `m_berserk.c` when registering the model; value of `1.0` means no geometry rescaling is applied.
- All constants are consumed exclusively by `game/m_berserk.c` (defined elsewhere).
