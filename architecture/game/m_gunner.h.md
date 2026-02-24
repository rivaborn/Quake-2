# game/m_gunner.h

## File Purpose
Auto-generated header defining animation frame index constants and model scale for the Gunner enemy type. It maps human-readable frame names to sequential integer indices used by the animation system to drive the Gunner's skeletal mesh playback.

## Core Responsibilities
- Define integer constants for every animation frame across all Gunner state sequences (stand, walk, run, attack, pain, death, duck)
- Provide the `MODEL_SCALE` constant for the Gunner's world-space scaling factor
- Serve as the sole source of frame indexing truth consumed by `game/m_gunner.c`

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions
None. This is a pure constants header; it contains no functions.

## Control Flow Notes
Included by `game/m_gunner.c` at compile time. The frame constants are referenced in `mmove_t` animation sequence tables (e.g., `gunner_move_stand`, `gunner_move_run`, etc.) which are stepped through each server frame by the monster AI tick. The numeric values map directly to MD2 frame indices within the Gunner's `.md2` model file.

Animation sequence groupings inferable from the constants:

| Sequence | Frame Range | Indices |
|---|---|---|
| stand | stand01–stand70 | 0–69 |
| walk | walk01–walk24 | 70–93 |
| run | run01–run08 | 94–101 |
| runs (run strafe?) | runs01–runs06 | 102–107 |
| attak1 | attak101–attak121 | 108–128 |
| attak2 | attak201–attak230 | 129–158 |
| pain1 | pain101–pain118 | 159–176 |
| pain2 | pain201–pain208 | 177–184 |
| pain3 | pain301–pain305 | 185–189 |
| death | death01–death11 | 190–200 |
| duck | duck01–duck08 | 201–208 |

## External Dependencies
- No includes; self-contained preprocessor definitions
- Consumed by: `game/m_gunner.c` (defined elsewhere)
- The numeric frame indices must match the actual frame ordering baked into the Gunner MD2 model asset (`baseq2/models/gunner/tris.md2`)
