# game/m_insane.h

## File Purpose
Auto-generated header by ModelGen that defines frame index constants for the "insane" civilian/NPC monster model. It maps symbolic animation frame names to sequential integer indices used by the animation system in `game/m_insane.c`.

## Core Responsibilities
- Enumerate all animation frame indices for the insane monster model (frames 0–281)
- Define animation groups: standing, walking, crawling, pain (standing and crawling variants), death (standing and crawling variants), and a "cross" pose sequence
- Expose the model scale constant for use by the spawning/initialization code

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions
None. This is a constants-only header.

## Control Flow Notes
This file is passively included by `game/m_insane.c`. The integer constants are consumed at init time when `mmove_t` animation sequence structs are populated (first/last frame ranges), and at runtime when the AI frame-advance logic indexes into the model's frame array. Not part of any init/frame/shutdown flow directly.

## External Dependencies
- No includes
- `MODEL_SCALE` (1.0) consumed by `game/m_insane.c` during entity spawn to set render scale

---

**Notes:**
- 160 stand frames (0–159) is unusually large; this encodes the insane NPC's erratic idle behavior as a long looping sequence rather than branching AI states
- Walk frames are non-contiguous in name (walk27–walk39 precede walk1–walk26 in index order, indices 160–198); consumers must reference these constants rather than computing ranges arithmetically
- Animation groups: `stand` (0–159), `walk` (160–198), `st_pain` (199–209), `st_death` (210–226), `crawl` (227–235), `cr_pain` (236–244), `cr_death` (245–251), `cross` (252–281)
