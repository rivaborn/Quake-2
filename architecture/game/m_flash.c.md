# game/m_flash.c

## File Purpose
Defines a shared lookup table of 3D offset vectors for every monster muzzle-flash attachment point in the game. It is compiled into both the game DLL and the client executable so both can independently resolve flash positions relative to a monster's model origin.

## Core Responsibilities
- Provides `monster_flash_offset[]`, indexed by `MZ2_*` constants defined elsewhere
- Maps each named flash type (e.g. `MZ2_TANK_BLASTER_1`) to a model-space `(x, y, z)` offset
- Covers all stock Q2 monsters: Tank, Infantry, Soldier, Gunner, Chick, Flyer, Medic, Gladiator, Hover, Actor, Supertank, Boss2, Makron, Jorg
- Extends into Rogue expansion monsters: Carrier, Turret, Stalker, Daedalus, Widow, Widow2
- Index 0 is intentionally unused (sentinel/padding entry)
- Some entries contain inline correction notes (e.g. Chick rocket sign fix, Widow2 beamer X-coordinate adjustments with commented originals)

## Key Types / Data Structures
None. The file contains only data.

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `monster_flash_offset` | `vec3_t[]` | global | Table of 211 3D offsets (indices 0–210), each giving the model-local position of a monster's muzzle-flash attachment point, indexed by `MZ2_*` constant |

## Key Functions
None. This file contains no functions.

## Control Flow Notes
Pure data file with no runtime logic. Both consumers access it by direct array indexing:
- **Game DLL** (`g_monster.c`, weapon files): indexes the table during attack actions to compute world-space shot origin.
- **Client** (`cl_fx.c` / `cl_newfx.c`): indexes the table when handling `svc_muzzleflash2` network messages to position the visual muzzle-flash effect.
No init, frame, or shutdown involvement.

## External Dependencies
- `q_shared.h` — provides `vec3_t` typedef; this is the only include
- `MZ2_*` constants — defined in `q_shared.h` (or `game.h`); used externally to index into this table; not referenced inside this file itself
- `vec3_t` compound-literal initialization relies on C aggregate initializer syntax; the three-float comma-separated rows are not tagged — positional correspondence to `{x, y, z}` is implicit
