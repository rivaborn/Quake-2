# ctf/g_local.h

## File Purpose
Central local header for the CTF (Capture the Flag) game module, defining all game-side types, structures, constants, and function prototypes. It is the CTF variant of the base game's `game/g_local.h`, extended with CTF-specific fields (grapple, CTF team state, tech timers, menus) and includes `g_ctf.h` at the bottom.

## Core Responsibilities
- Defines the full `edict_s` and `gclient_s` structures (gated by `GAME_INCLUDE`)
- Declares all game-module globals (`game`, `level`, `gi`, `g_edicts`, cvars)
- Provides all cross-file function prototypes for the game DLL subsystems
- Enumerates constants for damage, movement, AI, items, weapons, armor, and MOD codes
- Extends base `client_respawn_t` and `gclient_s` with CTF-specific fields
- Defines field offset macros (`FOFS`, `STOFS`, etc.) used by the save/load system

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `edict_s` | struct | Full server entity; contains state, physics, AI callbacks, item, moveinfo, monsterinfo |
| `gclient_s` | struct | Full client state: persistent data, respawn data, weapon/view/CTF state |
| `client_persistant_t` | struct | Data surviving level changes: inventory, weapon, score, health |
| `client_respawn_t` | struct | Data surviving DM respawns; adds CTF team, state, ghost, vote, admin flags |
| `game_locals_t` | struct | Game-wide persistent state (clients array, serverflags, item count) |
| `level_locals_t` | struct | Per-level transient state (framenum, time, intermission, entity tracking) |
| `spawn_temp_t` | struct | Temporary fields parsed from entity string, not kept in `edict_t` |
| `moveinfo_t` | struct | Mover physics state (doors, platforms): speed, distance, callbacks |
| `monsterinfo_t` | struct | Monster AI state: current move, flags, attack callbacks, power armor |
| `mmove_t` | struct | Monster animation sequence: frame range, per-frame callbacks |
| `mframe_t` | struct | Single monster animation frame: AI func, distance, think func |
| `gitem_t` | struct | Item definition: classname, callbacks, model, icon, ammo, flags |
| `gitem_armor_t` | struct | Armor stats: counts, normal/energy protection values |
| `damage_t` | enum | `DAMAGE_NO`, `DAMAGE_YES`, `DAMAGE_AIM` — entity damage acceptance |
| `weaponstate_t` | enum | `WEAPON_READY/ACTIVATING/DROPPING/FIRING` |
| `ammo_t` | enum | Ammo type identifiers |
| `movetype_t` | enum | Entity movement modes (NONE, WALK, FLY, TOSS, BOUNCE, etc.) |
| `fieldtype_t` | enum | Field types for save/load serialization |
| `field_t` | struct | Name/offset/type/flags descriptor for entity field save system |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `game` | `game_locals_t` | global (extern) | Persistent game state across levels |
| `level` | `level_locals_t` | global (extern) | Current level transient state |
| `gi` | `game_import_t` | global (extern) | Engine import table (server→game calls) |
| `globals` | `game_export_t` | global (extern) | Game export table (game→server calls) |
| `st` | `spawn_temp_t` | global (extern) | Temporary spawn fields during entity parsing |
| `g_edicts` | `edict_t *` | global (extern) | Entity array; `world == &g_edicts[0]` |
| `meansOfDeath` | `int` | global (extern) | Current kill MOD code for damage attribution |
| `is_quad` | `qboolean` | global (extern) | CTF: whether quad damage is active |
| `sm_meat_index` | `int` | global (extern) | Model index for meat/gib |
| `snd_fry` | `int` | global (extern) | Sound index for frying sound |
| `jacket_armor_index` | `int` | global (extern) | Item index for jacket armor |
| `combat_armor_index` | `int` | global (extern) | Item index for combat armor |
| `body_armor_index` | `int` | global (extern) | Item index for body armor |
| Various `cvar_t *` | `cvar_t *` | global (extern) | CVars: `deathmatch`, `skill`, `fraglimit`, `capturelimit`, `instantweap`, `sv_gravity`, etc. |

## Key Functions

All declarations are prototypes only; no implementations are in this header. Key subsystem entry points declared:

### T_Damage
- Signature: `void T_Damage(edict_t *targ, edict_t *inflictor, edict_t *attacker, vec3_t dir, vec3_t point, vec3_t normal, int damage, int knockback, int dflags, int mod)`
- Purpose: Central damage application; routes through armor, power armor, godmode, knockback
- Inputs: Target, inflictor, attacker entities; direction/point/normal vectors; damage amount, knockback, damage flags, means-of-death
- Outputs/Return: void; modifies target health, may kill entity
- Side effects: Updates `meansOfDeath`, triggers pain/die callbacks, emits blood effects
- Calls: Defined in `g_combat.c`

### T_RadiusDamage
- Signature: `void T_RadiusDamage(edict_t *inflictor, edict_t *attacker, float damage, edict_t *ignore, float radius, int mod)`
- Purpose: Splash damage to all entities within radius
- Calls: Defined in `g_combat.c`; internally calls `T_Damage`

### G_RunEntity
- Signature: `void G_RunEntity(edict_t *ent)`
- Purpose: Per-frame physics/think dispatch for one entity; routes by movetype
- Defined in `g_phys.c`

### ClientEndServerFrame / ClientBeginServerFrame
- Signatures: `void ClientEndServerFrame(edict_t *ent)` / `void ClientBeginServerFrame(edict_t *ent)`
- Purpose: Per-frame client update bookends (view, HUD, input processing)
- Defined in `p_view.c` and `g_client.c`

### Notes
- `G_Spawn`, `G_FreeEdict`, `G_InitEdict` manage entity lifecycle
- `G_UseTargets`, `G_PickTarget`, `G_Find` handle the entity targeting graph
- `Weapon_Generic` drives the player weapon state machine
- `AI_SetSightClient`, `ai_stand/move/walk/run/charge` are the monster AI tick functions
- `monster_fire_*` family provides typed monster projectile emission

## Control Flow Notes

This header is included by virtually every `.c` file in the `ctf/` game module. It does not contain executable code. During init, `game_locals_t` and `level_locals_t` are populated by `G_InitGame` and map load functions. Each server frame calls `G_RunFrame`, which iterates `g_edicts` via `G_RunEntity` and dispatches `ClientBeginServerFrame`/`ClientEndServerFrame` per connected client. The `edict_s.think`, `touch`, `use`, `pain`, and `die` callbacks embedded in `edict_s` drive all entity behavior.

## External Dependencies

- `q_shared.h` — math types, `vec3_t`, `qboolean`, string utilities
- `game.h` — `game_import_t`, `game_export_t`, `entity_state_t`, `player_state_t`, `pmove_state_t`, short `gclient_t`/`edict_t` stubs (overridden by `GAME_INCLUDE`)
- `p_menu.h` — CTF in-game menu types (`pmenuhnd_t`)
- `g_ctf.h` — CTF-specific declarations (included at bottom to avoid circular deps)
- `link_t`, `cplane_t`, `csurface_t`, `solid_t` — defined in `q_shared.h` / `qcommon.h`
