# game/m_boss2.h

## File Purpose
Auto-generated header defining animation frame index constants and the model scale for the Boss2 monster model. It maps symbolic frame names to sequential integer indices used by the animation system to reference specific frames within the monster's 3D model.

## Core Responsibilities
- Defines `#define` constants for all Boss2 animation frame indices (stand, walk, attack, pain, death)
- Defines the `MODEL_SCALE` constant for the Boss2 model
- Serves as the sole source of truth for Boss2 frame numbering, consumed by `game/m_boss2.c`

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions
None. This is a pure constants header — no functions, no variables.

## Control Flow Notes
This file participates passively in animation control flow. `game/m_boss2.c` uses these constants when constructing `mmove_t` animation sequences (e.g., `FRAME_stand30` through `FRAME_stand49` define the stand loop range). The engine advances `entity->s.frame` each tick; logic in `m_boss2.c` compares the current frame against these constants to trigger callbacks and transitions.

Notable frame layout (by index range):

| Range | Indices | Animation |
|---|---|---|
| stand30–stand49 | 0–19 | Stand loop (first segment) |
| stand1–stand29 | 21–49 | Stand loop (second segment) |
| walk1–walk20 | 50–69 | Walk cycle |
| attack1–attack40 | 70–109 | Attack sequence |
| pain2–pain23 | 110–131 | Pain reaction |
| death2–death50 | 132–180 | Death sequence |

- Stand frames are non-contiguous by name but contiguous by index (stand30 starts at 0, stand1 resumes at 21), which is a quirk of how ModelGen exported this model.
- No `pain1` or `death1` frame is present — the sequences start at index 2, consistent with other boss models sharing a common animation set offset.
- Total frame count: 181 frames (indices 0–180).

## External Dependencies
- No includes.
- Consumed by: `game/m_boss2.c` (inferred from naming convention).
- `MODEL_SCALE` value of `1.000000` indicates the Boss2 model uses native scale with no resize applied.
