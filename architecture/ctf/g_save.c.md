# ctf/g_save.c

## File Purpose
Implements the CTF game module's save/load system, handling serialization of game state, level state, entities, and clients to binary files. It also contains `InitGame`, the entry point called when the game DLL is first loaded.

## Core Responsibilities
- Register entity field descriptors for spawn-time parsing (`fields[]`) and savegame pointer fixup (`savefields[]`, `levelfields[]`, `clientfields[]`)
- Initialize all game CVars, entity/client pools, and CTF subsystem on game start
- Serialize/deserialize the game-global state (`WriteGame`/`ReadGame`) including all client structs
- Serialize/deserialize per-level state (`WriteLevel`/`ReadLevel`) including all live edicts and `level_locals_t`
- Perform pointer swizzling: convert pointers to integer indices before write, restore them after read

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `field_t` | struct | Describes a serializable field: name, byte offset, type tag, flags |
| `edict_t` | struct | Game entity (defined in `g_local.h`) |
| `gclient_t` | struct | Per-client persistent state |
| `level_locals_t` | struct | Level-scope globals (time, sight/sound entities, etc.) |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `fields[]` | `field_t[]` | global | Spawn-time key/value field descriptors for entity parsing |
| `savefields[]` | `field_t[]` | global | Pointer fields in `edict_t` requiring swizzle on save/load |
| `levelfields[]` | `field_t[]` | global | Pointer fields in `level_locals_t` requiring swizzle |
| `clientfields[]` | `field_t[]` | global | Pointer fields in `gclient_t` requiring swizzle |

## Key Functions

### InitGame
- Signature: `void InitGame(void)`
- Purpose: First-time DLL initialization; registers CVars, allocates entity/client arrays, forces deathmatch mode, calls `CTFInit()`.
- Inputs: None (reads CVars from engine via `gi.cvar`)
- Outputs/Return: void
- Side effects: Allocates `g_edicts` and `game.clients` via `gi.TagMalloc`; sets `globals.edicts`, `globals.max_edicts`, `globals.num_edicts`; calls `InitItems()` and `CTFInit()`
- Calls: `gi.cvar`, `gi.cvar_set`, `gi.TagMalloc`, `gi.dprintf`, `InitItems`, `Com_sprintf`, `CTFInit`
- Notes: CTF-specific — forces `deathmatch=1`, disables `coop`. Called once per game session.

### WriteField1 / ReadField / WriteField2
- `WriteField1`: Converts pointer fields in a temp copy to serializable integers (string length, edict index, client index, item index) before block write.
- `WriteField2`: Writes the variable-length string data that `WriteField1` measured.
- `ReadField`: Restores pointer fields after block read — allocates level/game-tagged memory for strings, resolves edict/client/item indices back to pointers.

### WriteGame
- Signature: `void WriteGame(char *filename, qboolean autosave)`
- Purpose: Writes cross-level game state (game struct + all client structs) to a file.
- Inputs: `filename` — output path; `autosave` — if false, calls `SaveClientData()` first
- Outputs/Return: void
- Side effects: File I/O; sets/clears `game.autosaved`; writes compile-date stamp for version check
- Calls: `SaveClientData`, `fopen`, `fwrite`, `WriteClient`, `fclose`, `gi.error`

### ReadGame
- Signature: `void ReadGame(char *filename)`
- Purpose: Restores game state from a save file; frees all TAG_GAME memory first.
- Inputs: `filename` — save file path
- Side effects: Frees TAG_GAME memory, re-allocates `g_edicts` and `game.clients`
- Calls: `gi.FreeTags`, `fopen`, `fread`, `gi.TagMalloc`, `ReadClient`, `fclose`, `gi.error`
- Notes: Validates compile-date stamp; errors out on version mismatch.

### WriteLevel / ReadLevel
- `WriteLevel`: Serializes `sizeof(edict_t)`, a function pointer sentinel (`InitGame`), `level_locals_t`, and all in-use edicts with their indices.
- `ReadLevel`: Deserializes the same; validates struct size and function pointer base address; wipes entity array first; re-links all entities via `gi.linkentity`; marks clients unconnected; re-arms `target_crosslevel_target` entities.
- Notes: `ReadLevel` assumes `SpawnEntities` has already run to establish baselines. Sentinel `-1` marks end of edict list.

## Control Flow Notes
- `InitGame` is the DLL entry point — called once at game start or save load before any frames run.
- `WriteGame`/`ReadGame` are called by the server on level transitions and explicit saves.
- `WriteLevel`/`ReadLevel` are called on level save/restore; `ReadLevel` is called after `SpawnEntities` has already populated the world.

## External Dependencies
- `g_local.h` — `edict_t`, `gclient_t`, `level_locals_t`, `game`, `level`, `g_edicts`, `globals`, `itemlist`, field macros (`FOFS`, `STOFS`, `LLOFS`, `CLOFS`)
- `gi` interface — `gi.cvar`, `gi.TagMalloc`, `gi.FreeTags`, `gi.linkentity`, `gi.error`, `gi.dprintf`
- `SaveClientData`, `InitItems`, `CTFInit` — defined elsewhere in the CTF game module
- `maxclients`, `deathmatch`, `coop`, `maxentities` — CVars, registered here and used globally
