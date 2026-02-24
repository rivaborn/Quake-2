# game/g_spawn.c

## File Purpose
This file implements the entity spawning subsystem for the Quake 2 game module. It parses the map's entity lump (text-format key/value pairs), maps classnames to spawn functions via a dispatch table, and initializes the world entity with all required precached assets and configstrings.

## Core Responsibilities
- Maintain the `spawns[]` dispatch table mapping classname strings to `SP_*` spawn functions
- Parse raw entity text from the BSP into `edict_t` structs via `ED_ParseEdict` / `ED_ParseField`
- Dispatch `ED_CallSpawn` to invoke the correct spawn function per entity
- Filter entities by skill level and deathmatch flags during map load
- Chain team-slave entities together via `G_FindTeams`
- Initialize the world entity (`SP_worldspawn`) with all sound/model precaches, configstrings, and light style tables
- Define HUD statusbar layout strings for singleplayer and deathmatch

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `spawn_t` | struct | Maps a classname string to its `SP_*` function pointer |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `spawns[]` | `spawn_t[]` | file-static (global linkage) | Full dispatch table of all spawnables |
| `single_statusbar` | `char *` | global | HUD layout string for singleplayer |
| `dm_statusbar` | `char *` | global | HUD layout string for deathmatch |

## Key Functions

### ED_CallSpawn
- **Signature:** `void ED_CallSpawn(edict_t *ent)`
- **Purpose:** Resolves `ent->classname` to a spawn function and calls it; checks item list first, then `spawns[]` table.
- **Inputs:** Initialized `edict_t` with `classname` set.
- **Outputs/Return:** void; entity is fully initialized after call.
- **Side effects:** Calls `SpawnItem` or a `SP_*` function, which mutates the edict. Prints a warning via `gi.dprintf` if no match found.
- **Calls:** `SpawnItem`, `s->spawn`, `gi.dprintf`
- **Notes:** Item classnames take priority over the `spawns[]` table.

### ED_NewString
- **Signature:** `char *ED_NewString(char *string)`
- **Purpose:** Allocates a level-tagged copy of a string, translating `\n` escape sequences.
- **Inputs:** Raw string from entity lump.
- **Outputs/Return:** Heap-allocated string (TAG_LEVEL lifetime).
- **Side effects:** Allocates via `gi.TagMalloc`.
- **Calls:** `gi.TagMalloc`, `strlen`

### ED_ParseField
- **Signature:** `void ED_ParseField(char *key, char *value, edict_t *ent)`
- **Purpose:** Looks up `key` in the `fields[]` table and writes the typed value into the edict (or `st` spawntemp) at the appropriate byte offset.
- **Inputs:** Key/value strings, target edict.
- **Outputs/Return:** void; writes directly into edict memory via pointer arithmetic.
- **Side effects:** May call `ED_NewString` for string fields; writes to global `st` for spawntemp fields.
- **Calls:** `ED_NewString`, `sscanf`, `atoi`, `atof`, `gi.dprintf`
- **Notes:** `FFL_NOSPAWN` fields are skipped. `F_ANGLEHACK` encodes a yaw-only angle into a full vector.

### ED_ParseEdict
- **Signature:** `char *ED_ParseEdict(char *data, edict_t *ent)`
- **Purpose:** Tokenizes one `{ key value ... }` block from the entity lump and populates an edict.
- **Inputs:** Pointer into entity text, empty target edict.
- **Outputs/Return:** Updated `data` pointer past the parsed block.
- **Side effects:** Zeros `st` at entry; zeros edict if block was empty. Calls `ED_ParseField` for each pair.
- **Calls:** `COM_Parse`, `ED_ParseField`, `gi.error`
- **Notes:** Keys prefixed with `_` are silently discarded (editor utility comments).

### G_FindTeams
- **Signature:** `void G_FindTeams(void)`
- **Purpose:** Scans all live edicts and links entities sharing a `team` string into a singly-linked chain via `teamchain`/`teammaster`; marks slaves with `FL_TEAMSLAVE`.
- **Inputs:** `g_edicts`, `globals.num_edicts`.
- **Outputs/Return:** void.
- **Side effects:** Mutates `teamchain`, `teammaster`, and `flags` fields on edicts. Prints team counts via `gi.dprintf`.

### SpawnEntities
- **Signature:** `void SpawnEntities(char *mapname, char *entities, char *spawnpoint)`
- **Purpose:** Top-level map initialization: resets all level state, parses the full entity lump, filters by skill/deathmatch, calls `ED_CallSpawn` for each entity, then runs `G_FindTeams` and `PlayerTrail_Init`.
- **Inputs:** Map name string, raw entity lump text, spawn point name.
- **Outputs/Return:** void.
- **Side effects:** Frees TAG_LEVEL memory, zeroes `level` and all `g_edicts`, sets client pointers, forces `skill` cvar to integer, calls `SaveClientData`. Contains a hardcoded map hack for the "command" map.
- **Calls:** `SaveClientData`, `gi.FreeTags`, `COM_Parse`, `G_Spawn`, `ED_ParseEdict`, `ED_CallSpawn`, `G_FreeEdict`, `G_FindTeams`, `PlayerTrail_Init`, `gi.cvar_forceset`

### SP_worldspawn
- **Signature:** `void SP_worldspawn(edict_t *ent)`
- **Purpose:** Initializes the world entity and precaches all globally required sounds, models, images; sets configstrings for sky, music, gravity, HUD statusbar, and all 64 light animation styles.
- **Inputs:** World edict (`g_edicts[0]`).
- **Outputs/Return:** void.
- **Side effects:** Calls `InitBodyQue`, `SetItemNames`, `PrecacheItem`; sets `sm_meat_index`, `snd_fry`; issues many `gi.configstring`, `gi.soundindex`, `gi.modelindex`, `gi.imageindex` calls; sets `sv_gravity` cvar.
- **Calls:** `InitBodyQue`, `SetItemNames`, `PrecacheItem`, `FindItem`, `gi.configstring`, `gi.soundindex`, `gi.modelindex`, `gi.imageindex`, `gi.cvar_set`

## Control Flow Notes
`SpawnEntities` is the engine-called entry point at map load time (init phase). It drives the entire entity instantiation pipeline: parse → filter → spawn → team-link → trail init. `SP_worldspawn` is always the first entity spawned (index 0). No per-frame logic exists in this file.

## External Dependencies
- **Includes:** `g_local.h` (pulls in `edict_t`, `gitem_t`, `field_t`, `spawn_temp_t st`, `fields[]`, `itemlist`, `level`, `game`, `g_edicts`, `globals`, cvars)
- **Defined elsewhere:** `COM_Parse`, `SpawnItem`, `G_Spawn`, `G_FreeEdict`, `SaveClientData`, `InitBodyQue`, `SetItemNames`, `PrecacheItem`, `FindItem`, `PlayerTrail_Init`, `Q_stricmp`, `gi` (game import struct), all `SP_*` functions
