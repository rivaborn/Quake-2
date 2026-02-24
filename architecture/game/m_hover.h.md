# game/m_hover.h

## File Purpose
Auto-generated header defining animation frame index constants and model scale for the Hover monster (a floating drone enemy) in Quake 2. It maps symbolic frame names to sequential integer indices consumed by the animation system in `m_hover.c`.

## Core Responsibilities
- Define all animation frame indices for the Hover monster model
- Provide the `MODEL_SCALE` constant used when registering or rendering the model
- Serve as the sole authoritative frame-index reference for `m_hover.c`

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions
None. This file contains only preprocessor `#define` directives.

## Control Flow Notes
Included exclusively by `game/m_hover.c`. The integer constants are used to set `self->s.frame` during AI state callbacks (stand, walk, attack, pain, death), driving the model animation each server frame. Not involved in init/shutdown directly; the constants are referenced passively at runtime.

## External Dependencies
- No includes.
- No external symbols; purely self-contained macro definitions.

---

**Animation sequence summary (205 frames total, indices 0–204):**

| Sequence | Frames | Index Range | Count |
|---|---|---|---|
| `stand` | stand01–30 | 0–29 | 30 |
| `forwrd` (forward) | forwrd01–35 | 30–64 | 35 |
| `stop1` | stop101–109 | 65–73 | 9 |
| `stop2` | stop201–208 | 74–81 | 8 |
| `takeof` (takeoff) | takeof01–30 | 82–111 | 30 |
| `land` | land01 | 112 | 1 |
| `pain1` | pain101–128 | 113–140 | 28 |
| `pain2` | pain201–212 | 141–152 | 12 |
| `pain3` | pain301–309 | 153–161 | 9 |
| `death1` | death101–111 | 162–172 | 11 |
| `backwd` (backward) | backwd01–24 | 173–196 | 24 |
| `attak1` (attack) | attak101–108 | 197–204 | 8 |

`MODEL_SCALE` is `1.000000`, indicating no scaling applied to the raw model geometry.
