# game/m_mutant.h

## File Purpose
Auto-generated header defining animation frame index constants and model scale for the Mutant monster. It maps symbolic frame names to sequential integer indices corresponding to frames in the Mutant's MD2 model file.

## Core Responsibilities
- Defines `#define` constants for every animation frame index across all Mutant animation sequences (attack, death, pain, run, stand, walk)
- Provides `MODEL_SCALE` for use when transforming model-space coordinates to world-space
- Serves as the single source of truth for frame numbering so `game/m_mutant.c` can reference frames by name rather than magic integers

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions
None. This is a pure constant-definition header with no functions.

**Notes:**
- All content is preprocessor `#define` macros; no runtime state or functions exist.

## Control Flow Notes
Included by `game/m_mutant.c`. The frame constants are used to index into `mmove_t` animation sequence descriptors (first/last frame fields), which the AI animation system steps through each game frame. Not part of any init/shutdown path directly.

## External Dependencies
- No includes.
- No external symbols referenced.
- Consumed by: `game/m_mutant.c` (inferred from naming convention).

## Animation Sequence Summary

| Sequence | First Constant | Last Constant | Frame Count |
|---|---|---|---|
| attack | `FRAME_attack01` (0) | `FRAME_attack15` (14) | 15 |
| death1 | `FRAME_death101` (15) | `FRAME_death109` (23) | 9 |
| death2 | `FRAME_death201` (24) | `FRAME_death210` (33) | 10 |
| pain1 | `FRAME_pain101` (34) | `FRAME_pain105` (38) | 5 |
| pain2 | `FRAME_pain201` (39) | `FRAME_pain206` (44) | 6 |
| pain3 | `FRAME_pain301` (45) | `FRAME_pain311` (55) | 11 |
| run | `FRAME_run03` (56) | `FRAME_run08` (61) | 6 |
| stand1 | `FRAME_stand101` (62) | `FRAME_stand164` (124) | 64 |
| walk | `FRAME_walk01` (126) | `FRAME_walk23` (148) | 23 |

Notable: the run sequence starts at `run03` (index 56), implying `run01`/`run02` are absent or shared with another sequence. `MODEL_SCALE` is `1.0`, so no scaling transformation is applied.
