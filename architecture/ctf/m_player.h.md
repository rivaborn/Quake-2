# ctf/m_player.h

## File Purpose
Auto-generated header defining all animation frame index constants for the CTF player model. It maps symbolic frame names to sequential integer indices used by the animation system to reference frames within the player's `.md2` model file.

## Core Responsibilities
- Enumerate all player animation frames as preprocessor constants
- Define frame ranges for: idle stand, run, attack, pain, jump, gestures (flip, salute, taunt, wave, point), crouch states, and death sequences
- Provide `MODEL_SCALE` for world-space scaling of the player model

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions
None. This is a pure header of `#define` constants.

## Control Flow Notes
This file is passively included by animation and player code (e.g., `p_view.c`, `p_client.c`, `p_weapon.c`) that drives frame transitions. The integer values map directly into the `.md2` model's frame array at render time. The animation system uses these constants to set `s.frame` on the player entity, which the renderer consumes each frame.

Animation groups inferable from constant ranges:

| Group | Frame Range | Count |
|---|---|---|
| stand | 0–39 | 40 |
| run | 40–45 | 6 |
| attack | 46–53 | 8 |
| pain1/2/3 | 54–65 | 12 |
| jump | 66–71 | 6 |
| flip | 72–83 | 12 |
| salute | 84–94 | 11 |
| taunt | 95–111 | 17 |
| wave | 112–122 | 11 |
| point | 123–134 | 12 |
| crouch stand | 135–153 | 19 |
| crouch walk | 154–159 | 6 |
| crouch attack | 160–168 | 9 |
| crouch pain | 169–172 | 4 |
| crouch death | 173–177 | 5 |
| death1/2/3 | 178–197 | 20 |

## External Dependencies
- No includes.
- Consumed by: `ctf/p_view.c`, `ctf/p_client.c`, `ctf/p_weapon.c` (defined elsewhere).
- `MODEL_SCALE` may be read by model loading or collision code (defined elsewhere).
