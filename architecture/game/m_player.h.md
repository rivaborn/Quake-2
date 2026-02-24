# game/m_player.h

## File Purpose
Auto-generated header defining integer frame index constants for the player character's skeletal animation sequences. It maps symbolic animation frame names to their sequential integer indices as stored in the player model file.

## Core Responsibilities
- Enumerate all player model animation frames as preprocessor constants
- Provide a symbolic interface so game code can reference frames by name rather than magic integers
- Define the model scale constant for the player model

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions
None. This is a pure constants header with no functions.

## Control Flow Notes
Passively included by animation-driving code (primarily `game/p_view.c` and `game/p_weapon.c`). Frame constants are consumed whenever player animation state is set or advanced — e.g., assigning `client->anim_end = FRAME_run6` to bound a run cycle. No execution logic resides here.

## External Dependencies
- No includes
- No external symbols; all content is self-contained `#define` macros

---

**Notes on animation sequence layout (frame ranges):**

| Sequence group | First frame | Last frame | Count |
|---|---|---|---|
| `stand` (idle) | 0 | 39 | 40 |
| `run` | 40 | 45 | 6 |
| `attack` (upright) | 46 | 53 | 8 |
| `pain1/2/3` (upright) | 54 | 65 | 12 |
| `jump` | 66 | 71 | 6 |
| `flip` (gesture) | 72 | 83 | 12 |
| `salute` (gesture) | 84 | 94 | 11 |
| `taunt` (gesture) | 95 | 111 | 17 |
| `wave` (gesture) | 112 | 122 | 11 |
| `point` (gesture) | 123 | 134 | 12 |
| `crstnd` (crouch idle) | 135 | 153 | 19 |
| `crwalk` (crouch walk) | 154 | 159 | 6 |
| `crattak` (crouch attack) | 160 | 168 | 9 |
| `crpain` (crouch pain) | 169 | 172 | 4 |
| `crdeath` (crouch death) | 173 | 177 | 5 |
| `death1/2/3` (upright) | 178 | 197 | 20 |

`MODEL_SCALE 1.000000` indicates the player model uses a 1:1 world-unit scale with no additional rescaling applied at load time.
