# game/m_flipper.h

## File Purpose
Auto-generated header defining animation frame index constants for the Flipper monster model (an aquatic creature). It maps named animation frames to sequential integer indices consumed by the animation system in `m_flipper.c`.

## Core Responsibilities
- Enumerates all animation frame indices for the Flipper monster model
- Groups frames by animation sequence via naming convention (`flpbit`, `flptal`, `flphor`, `flpver`, `flppn1`, `flppn2`, `flpdth`)
- Defines the model's scale factor for rendering
- Serves as the sole animation data contract between the model asset and game logic

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions
None. This is a pure constants header; it contains no functions.

## Control Flow Notes
Included by `m_flipper.c`. The `#define` constants are used as arguments to animation sequence table entries (e.g., `.firstframe`, `.lastframe` fields in `mmove_t` structs) that drive per-frame monster state during the game's entity think/update loop.

## External Dependencies
- No includes
- No external symbols; entirely self-contained preprocessor definitions

---

**Animation Sequence Summary** (160 frames total, indices 0–159):

| Prefix | Range | Count | Sequence |
|---|---|---|---|
| `flpbit` | 0–19 | 20 | Bite attack |
| `flptal` | 20–40 | 21 | Tail attack |
| `flphor` | 41–64 | 24 | Horizontal swim |
| `flpver` | 65–93 | 29 | Vertical swim |
| `flppn1` | 94–98 | 5 | Pain type 1 |
| `flppn2` | 99–103 | 5 | Pain type 2 |
| `flpdth` | 104–159 | 56 | Death |

`MODEL_SCALE` is `1.000000`, indicating no geometry scaling is applied at load time.
