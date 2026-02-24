# game/m_gladiator.h

## File Purpose
Auto-generated header defining animation frame index constants and model scale for the Gladiator monster. Maps symbolic frame names to sequential integer indices corresponding to frames in the Gladiator's MD2 model file.

## Core Responsibilities
- Enumerates all animation frame indices for the Gladiator monster model
- Provides a `MODEL_SCALE` constant for world-space scaling of the model
- Serves as the bridge between the animation logic in `m_gladiator.c` and the underlying MD2 frame data

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions
None. This is a constants-only header.

**Notes:**
- All definitions are preprocessor `#define` macros, not typed constants.
- Frame groups present: `stand` (0–6), `walk` (7–22), `run` (23–28), `melee` (29–45), `attack` (46–54), `pain` (55–60), `death` (61–82), `painup` (83–89). Total: 90 frames.

## Control Flow Notes
Included by `m_gladiator.c`. Frame constants are referenced when constructing `mmove_t` animation sequence structs (first/last frame ranges) that drive the monster's AI state transitions each server frame.

## External Dependencies
- No includes.
- All symbols are self-contained `#define` constants.
- Consumed exclusively by `game/m_gladiator.c` (and potentially `ctf/m_gladiator.c` if present).
