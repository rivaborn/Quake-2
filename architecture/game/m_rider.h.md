# game/m_rider.h

## File Purpose
Auto-generated header defining animation frame index constants for the "rider" monster model (boss3/rider). It maps symbolic frame names to sequential integer indices used by the animation system.

## Core Responsibilities
- Defines `FRAME_stand201` through `FRAME_stand260` as integer constants (0–59)
- Defines the model's scale factor via `MODEL_SCALE`
- Provides a symbolic interface so animation code avoids hardcoded frame numbers

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions
None. This is a pure header of preprocessor definitions.

## Control Flow Notes
Consumed passively at compile time by whichever `.c` file implements the boss3/rider monster logic (likely `game/m_boss3.c` or similar). Frame constants are referenced when setting `entity->s.frame` or constructing `mmove_t` animation sequence structs that drive the monster's state machine each server frame.

## External Dependencies
- No includes.
- No external symbols.
- Intended to be included by the rider/boss3 monster implementation file.

**Notes:**
- The file contains only a single animation sequence (`stand2`, frames 201–260), spanning 60 frames (indices 0–59). The naming offset (201 vs. 0) reflects the source model's internal frame numbering, while the macro values are the engine-side zero-based indices.
- `MODEL_SCALE 1.000000` indicates no scaling is applied relative to the base model geometry.
- Marked "Do NOT Modify" — regenerating via ModelGen would overwrite changes.
