# ctf/g_spawn.c

## File Purpose
CTF-variant entity spawning and map initialization module. It parses the textual entity definitions from a BSP map, dispatches each entity to its registered spawn function, and performs full level setup for the CTF game mode.

## Core Responsibilities
- Maintains a named dispatch table (`spawns[]`) mapping classname strings to spawn functions
- Resolves each parsed entity to either an item spawn or a named spawn function via `ED_CallSpawn`
- Parses raw entity string data (key/value pairs) into `edict_t` fields via `ED_ParseEdict` / `ED_ParseField`
- Filters entities by skill level and deathmatch flags during map load
- Chains team-slave entities together via `G_FindTeams`
- Initializes world-level configstrings (sky, gravity, CD track, statusbar, light styles) in `SP_worldspawn`
- CTF-specific: registers CTF team spawn points, banners, teleporters, and calls `CTFSpawn()` post-load
- Monsters and certain misc entities are compiled out (`#if 0`) for the CTF variant

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `spawn_t` | struct | Associates a classname string with its `SP_*` function pointer |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `spawns[]` | `spawn_t[]` | file-static (global linkage) | Master dispatch table; classname → spawn function |
| `single_statusbar` | `char *` | global | HUD layout string for single-player mode |
| `dm_statusbar` | `char *` | global | HUD layout string for standard deathmatch |

## Key Functions

### ED_CallSpawn
- **Signature:** `void ED_CallSpawn(edict_t *ent)`
- **Purpose:** Resolves and invokes the correct spawn function for an entity by classname.
- **Inputs:** Initialized `edict_t` with `classname` set.
- **Outputs/Return:** void
- **Side effects:** Calls `SpawnItem` or a `SP_*` function, fully initializing the entity in-world.
- **Calls:** `SpawnItem`, `s->spawn(ent)`, `gi.dprintf`
- **Notes:** Item list is checked first; falls back to `spawns[]` table; logs a warning if no match found.

### ED_NewString
- **Signature:** `char *ED_NewString(char *string)`
- **Purpose:** Allocates a level-tagged copy of a string, converting `\n` escape sequences.
- **Inputs:** Raw string from entity data.
- **Outputs/Return:** Newly allocated `char *` (TAG_LEVEL lifetime).
- **Side effects:** Allocates via `gi.TagMalloc`.
- **Calls:** `gi.TagMalloc`, `strlen`

### ED_ParseField
- **Signature:** `void ED_ParseField(char *key, char *value, edict_t *ent)`
- **Purpose:** Applies a single key/value pair to the correct field of an `edict_t` or the `st` spawn-temp struct.
- **Inputs:** Key and value strings, target entity.
- **Outputs/Return:** void
- **Side effects:** Writes directly into `edict_t` or `st` via the `fields[]` descriptor table using byte offsets.
- **Calls:** `ED_NewString`, `sscanf`, `atoi`, `atof`, `gi.dprintf`
- **Notes:** Dispatches on `field_t.type` (F_LSTRING, F_VECTOR, F_INT, F_FLOAT, F_ANGLEHACK, F_IGNORE). `FFL_SPAWNTEMP` fields redirect to the global `st`.

### ED_ParseEdict
- **Signature:** `char *ED_ParseEdict(char *data, edict_t *ent)`
- **Purpose:** Parses one `{ key value ... }` block from the entity lump into an `edict_t`.
- **Inputs:** Pointer into the entity string, target entity.
- **Outputs/Return:** Updated `data` pointer past the closing `}`.
- **Side effects:** Calls `ED_ParseField` for each pair; zeroes entity if no fields were parsed; zeroes `st` at entry.
- **Calls:** `COM_Parse`, `ED_ParseField`, `gi.error`
- **Notes:** Keys prefixed with `_` are silently skipped (editor utility comments).

### G_FindTeams
- **Signature:** `void G_FindTeams(void)`
- **Purpose:** Links all entities sharing a `team` string into a master/slave chain.
- **Inputs:** Global `g_edicts` array, `globals.num_edicts`.
- **Outputs/Return:** void
- **Side effects:** Sets `FL_TEAMSLAVE`, `teammaster`, and `teamchain` on affected edicts; prints team count.
- **Calls:** `gi.dprintf`

### SpawnEntities
- **Signature:** `void SpawnEntities(char *mapname, char *entities, char *spawnpoint)`
- **Purpose:** Full map initialization entry point — parses all entities, filters by skill/deathmatch, spawns them, and finalizes level state.
- **Inputs:** Map name, raw entity lump string, spawnpoint string.
- **Outputs/Return:** void
- **Side effects:** Frees TAG_LEVEL memory, zeroes `level` and `g_edicts`, calls `SaveClientData`, `G_Spawn`/`G_FreeEdict`, `ED_CallSpawn`, `G_FindTeams`, `PlayerTrail_Init`, `CTFSpawn`.
- **Calls:** `SaveClientData`, `gi.FreeTags`, `COM_Parse`, `G_Spawn`, `ED_ParseEdict`, `ED_CallSpawn`, `G_FreeEdict`, `G_FindTeams`, `PlayerTrail_Init`, `CTFSpawn`
- **Notes:** Contains a hardcoded map hack for the `"command"` map. Monsters are fully excluded from CTF (`#if 0` blocks).

### SP_worldspawn
- **Signature:** `void SP_worldspawn(edict_t *ent)`
- **Purpose:** Initializes the world entity, sends all level configstrings to the server, and precaches all global assets.
- **Inputs:** World `edict_t` (slot 0).
- **Outputs/Return:** void
- **Side effects:** Calls `gi.configstring` extensively (sky, gravity, CD track, statusbar, 64 light styles), precaches sounds and models via `gi.soundindex`/`gi.modelindex`/`gi.imageindex`, sets `sm_meat_index`. In CTF mode, uses `ctf_statusbar` and precaches CTF flag images.
- **Calls:** `InitBodyQue`, `SetItemNames`, `gi.configstring`, `gi.imageindex`, `gi.soundindex`, `gi.modelindex`, `gi.cvar_set`, `PrecacheItem`, `FindItem`

## Control Flow Notes
`SpawnEntities` is the engine-called entry point at map load time. It drives the entire init sequence: parse → filter → spawn each entity → link teams → `CTFSpawn`. `SP_worldspawn` is always the first entity spawned (slot 0) and handles all global precaching before other entities run.

## External Dependencies
- **Includes:** `g_local.h` (all game types, `fields[]`, `st`, `g_edicts`, `level`, `game`, cvars)
- **Defined elsewhere:** `itemlist`, `SpawnItem`, `G_Spawn`, `G_FreeEdict`, `SaveClientData`, `PlayerTrail_Init`, `CTFSpawn`, `CTF`-specific spawn functions (`SP_info_player_team1/2`, `SP_misc_ctf_banner`, `SP_trigger_teleport`, etc.), `ctf_statusbar`, `COM_Parse`, all `SP_*` functions listed as forward declarations, `gi` (game import), `sm_meat_index`
