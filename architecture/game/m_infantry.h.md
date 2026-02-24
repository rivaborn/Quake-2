# game/m_infantry.h

## File Purpose
Auto-generated header defining animation frame index constants for the Infantry monster model. It maps symbolic frame names to sequential integer indices used by the animation system to index into the model's keyframe array.

## Core Responsibilities
- Enumerate all animation frame indices for the Infantry monster (207 total frames)
- Provide human-readable names for frame ranges (stand, walk, run, pain, duck, death, block, attack)
- Define the model's scale factor constant
- Serve as the sole source of truth for Infantry frame numbering consumed by `game/m_infantry.c`

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions
None. This file is a pure `#define` header with no functions, structs, or variables.

**Notes:**
- `FRAME_gun02` (0) is the only non-sequential anomaly at the start — frame 0 is a gun pose, not a stand frame; `FRAME_stand01` begins at 1.
- `MODEL_SCALE` is defined as `1.000000`, indicating no scaling applied at load time.

## Control Flow Notes
This file has no runtime behavior. It is `#include`d by `game/m_infantry.c`, where animation sequence tables (`mmove_t`) reference these constants as `firstframe`/`lastframe` bounds. The animation system advances `s.frame` each tick, and these constants let the code express ranges like `FRAME_run01`–`FRAME_run08` symbolically rather than as magic integers.

## External Dependencies
- No includes.
- No external symbols.
- Consumed exclusively by `game/m_infantry.c` (and potentially `ctf/` equivalents).

---

**Animation frame inventory summary:**

| Animation group | Frame range | Count |
|---|---|---|
| `gun` | 0 | 1 |
| `stand` | 1–71 | 71 |
| `walk` | 72–91 | 20 |
| `run` | 92–99 | 8 |
| `pain1` | 100–109 | 10 |
| `pain2` | 110–119 | 10 |
| `duck` | 120–124 | 5 |
| `death1` | 125–144 | 20 |
| `death2` | 145–169 | 25 |
| `death3` | 170–178 | 9 |
| `block` | 179–183 | 5 |
| `attak1` | 184–198 | 15 |
| `attak2` | 199–206 | 8 |
