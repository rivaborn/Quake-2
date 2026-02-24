# game/m_float.h

## File Purpose
Auto-generated header file produced by the ModelGen tool, defining symbolic frame index constants for the Floater monster's 3D model animations. It maps human-readable animation frame names to sequential integer indices used by the game's animation system.

## Core Responsibilities
- Defines all animation frame indices for the Floater monster (`float` model)
- Provides the `MODEL_SCALE` constant for this monster's mesh scaling
- Serves as the compile-time interface between the monster logic (`m_float.c`) and the model animation data

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions
None. This file contains only preprocessor `#define` macros.

**Notes:**
- All frame constants follow the pattern `FRAME_<animname><framenum>`, mapping to sequential integers 0–247.
- Animation sets defined: `actvat` (0–30), `attak1` (31–44), `attak2` (45–69), `attak3` (70–103), `death` (104–116), `pain1` (117–123), `pain2` (124–131), `pain3` (132–143), `stand1` (144–195), `stand2` (196–247).

## Control Flow Notes
Not part of any runtime control flow. Included by `m_float.c` to allow animation state machine functions to reference frame boundaries by name (e.g., `FRAME_stand101` through `FRAME_stand152`) rather than raw integers. The `MODEL_SCALE` constant (1.0) is used during entity spawn to scale the model's bounding geometry.

## External Dependencies
- No includes.
- Consumed entirely by `game/m_float.c` (defined elsewhere).
