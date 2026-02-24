# game/g_local.h

## File Purpose
The primary internal header for the Quake 2 game module (game DLL). It defines all game-side types, constants, and the full ("fat") `edict_t` and `gclient_s` structures, as well as declaring every cross-file symbol used within the game module.

## Core Responsibilities
- Define `GAME_INCLUDE` to unlock full struct definitions from `game.h`
- Declare complete `edict_s` and `gclient_s` layouts (server only sees opaque stubs)
- Define all game-logic enumerations and constant sets (damage types, AI flags, move types, MOD codes, etc.)
- Declare global singletons (`game`, `level`, `gi`, `globals`, `st`) shared across all game source files
- Expose all cross-file function prototypes for every game subsystem
- Define field-offset macros (`FOFS`, `STOFS`, etc.) used by the save/load and spawn systems

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `edict_s` | struct | Full entity definition: server-visible state + all game-private fields (AI, physics, callbacks, links) |
| `gclient_s` | struct | Full client state: player_state + persistent data + per-frame weapon/damage/animation state |
| `client_persistant_t` | struct | Client data surviving level transitions (inventory, health, weapon) |
| `client_respawn_t` | struct | Client data surviving deathmatch respawns (score, enter frame) |
| `game_locals_t` | struct | Persistent game state saved to `.ssv` (clients array, serverflags, help messages) |
| `level_locals_t` | struct | Per-level state cleared on map load, saved to `.sav` (time, intermission, entity counts) |
| `spawn_temp_t` | struct | Transient entity spawn fields from map editor; discarded after spawning |
| `gitem_t` | struct | Item definition: pickup/use/drop callbacks, model, sound, flags, ammo linkage |
| `gitem_armor_t` | struct | Armor stats: base/max count, normal/energy protection factors |
| `moveinfo_t` | struct | Mover (door/platform) kinematic state: endpoints, speed, accel, callback |
| `mmove_t` | struct | Monster animation sequence: frame range, per-frame array, end callback |
| `mframe_t` | struct | Single monster animation frame: AI function, move distance, think function |
| `monsterinfo_t` | struct | Full monster AI state: current move, AI flags, attack state, behavior callbacks |
| `movetype_t` | enum | Entity physics mode (NONE, WALK, STEP, FLY, TOSS, BOUNCE, etc.) |
| `damage_t` | enum | Damage acceptance level (NO / YES / AIM) |
| `weaponstate_t` | enum | Weapon FSM states (READY, ACTIVATING, DROPPING, FIRING) |
| `ammo_t` | enum | Ammo type identifiers |
| `fieldtype_t` | enum | Save/load field type tags for reflection-based serialization |
| `field_t` | struct | Save/load field descriptor: name, byte offset, type, flags |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `game` | `game_locals_t` | global | Persistent game singleton |
| `level` | `level_locals_t` | global | Current level singleton |
| `gi` | `game_import_t` | global | Engine import table (engine → game calls) |
| `globals` | `game_export_t` | global | Game export table (game → engine calls) |
| `st` | `spawn_temp_t` | global | Temporary spawn fields during entity instantiation |
| `g_edicts` | `edict_t *` | global | Entity array base pointer |
| `meansOfDeath` | `int` | global | Last damage source code (MOD_*) for obituary text |
| `sm_meat_index` | `int` | global | Precached gib model index |
| `snd_fry` | `int` | global | Precached fry sound index |
| `jacket_armor_index` | `int` | global | Precached jacket armor item index |
| `combat_armor_index` | `int` | global | Precached combat armor item index |
| `body_armor_index` | `int` | global | Precached body armor item index |
| `maxentities`, `deathmatch`, `coop`, `dmflags`, `skill`, `fraglimit`, `timelimit`, `password`, etc. | `cvar_t *` | global | Game cvars, latched at init and read each frame |

## Key Functions
This file is a header only — it contains no function definitions. All entries below are **declarations** of functions implemented in other `.c` files.

### Notable subsystem groupings (by source file):
- **g_utils.c**: Entity lifecycle (`G_Spawn`, `G_FreeEdict`, `G_InitEdict`), spatial queries (`G_Find`, `findradius`, `G_PickTarget`), target firing (`G_UseTargets`)
- **g_combat.c**: `T_Damage`, `T_RadiusDamage`, `CanDamage`, `OnSameTeam`
- **g_monster.c**: Monster fire helpers (`monster_fire_*`), AI lifecycle (`walkmonster_start`, `flymonster_start`, `swimmonster_start`), `M_CheckAttack`
- **g_ai.c**: AI movement functions (`ai_stand`, `ai_walk`, `ai_run`, `ai_charge`), perception (`visible`, `infront`, `FoundTarget`)
- **g_weapon.c**: Projectile/hitscan fire functions (`fire_bullet`, `fire_rocket`, `fire_bfg`, etc.)
- **g_client.c / p_view.c**: `PutClientInServer`, `ClientBeginServerFrame`, `ClientEndServerFrame`, `respawn`
- **g_phys.c**: `G_RunEntity` — dispatches per-entity physics each frame
- **g_main.c**: `SaveClientData`, `FetchClientEntData`
- **m_move.c**: Monster movement (`M_walkmove`, `M_MoveToGoal`, `M_CheckBottom`)

## Control Flow Notes
This header is the spine of the game DLL frame loop:
- **Init**: `game_locals_t` and `level_locals_t` are initialized; `g_edicts` is allocated with `TAG_GAME`
- **Per-frame**: `level.current_entity` tracks the entity being processed; `G_RunEntity` dispatches physics; `ClientBeginServerFrame` / `ClientEndServerFrame` bracket player logic
- **Level change**: `level_locals_t` is cleared and reloaded; `client_persistant_t` survives via `SaveClientData` / `FetchClientEntData`
- **Shutdown**: `TAG_GAME` memory is freed; the DLL export table (`globals`) is the only engine-facing interface

## External Dependencies
- `q_shared.h` — shared math, string, and type primitives
- `game.h` — engine/game interface types (`game_import_t`, `game_export_t`, opaque `edict_t`/`gclient_t` stubs, `player_state_t`, `pmove_state_t`)
- `FOFS` / `STOFS` / `LLOFS` / `CLOFS` — zero-pointer offset macros depend on `edict_t`, `spawn_temp_t`, `level_locals_t`, `gclient_t` being fully defined here
- All `cvar_t *` globals defined and registered in `g_main.c`
- `fields[]` and `itemlist[]` arrays defined in `g_save.c` and `g_items.c` respectively
