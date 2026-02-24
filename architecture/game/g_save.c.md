# game/g_save.c

## File Purpose
Implements the game DLL's serialization and deserialization system for save games and level transitions. Handles binary I/O of entity state, client state, level globals, and game globals by converting non-portable pointer types to portable indices before writing and restoring them on load.

## Core Responsibilities
- Define the `fields[]`, `levelfields[]`, and `clientfields[]` descriptor tables mapping field names to struct offsets and types
- Serialize and deserialize `edict_t`, `gclient_t`, and `level_locals_t` structures with pointer fixup
- Implement `WriteGame`/`ReadGame` for cross-level persistent state (client inventories, etc.)
- Implement `WriteLevel`/`ReadLevel` for per-level entity snapshots
- Convert pointer fields (edict refs, item refs, function pointers, mmove pointers) to portable integer indices before binary writes and restore them on read
- Host `InitGame`, the game DLL entry point called on new game or save load

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `field_t` | struct (defined in g_local.h) | Descriptor: field name, struct byte offset, type tag, flags (FFL_SPAWNTEMP, FFL_NOSPAWN) |
| `mmove_t` | struct | Monster move sequence; `mmove_reloc` used as a data-segment anchor for relative pointer encoding |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `mmove_reloc` | `mmove_t` | global | Relocation anchor: mmove pointers are stored as offsets relative to `&mmove_reloc` |
| `fields[]` | `field_t[]` | global | Master entity field descriptor table used for spawn, save, and load |
| `levelfields[]` | `field_t[]` | global | Field descriptors for `level_locals_t` pointer fields |
| `clientfields[]` | `field_t[]` | global | Field descriptors for `gclient_t` pointer fields (weapon items) |

## Key Functions

### InitGame
- **Signature:** `void InitGame(void)`
- **Purpose:** Game DLL initialization; registers all cvars, allocates entity and client arrays.
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** Allocates `g_edicts` and `game.clients` via `gi.TagMalloc`; sets `globals.edicts`, `globals.max_edicts`, `globals.num_edicts`; calls `InitItems()`
- **Calls:** `gi.cvar`, `gi.TagMalloc`, `InitItems`, `Com_sprintf`
- **Notes:** Also serves as the code-segment anchor for `F_FUNCTION` pointer encoding (`InitGame` address = base).

### WriteField1 / ReadField
- **Signature:** `void WriteField1(FILE *f, field_t *field, byte *base)` / `void ReadField(FILE *f, field_t *field, byte *base)`
- **Purpose:** Pre-write pass converts pointer fields in a struct copy to portable indices; `ReadField` reverses this after `fread`.
- **Inputs:** Open FILE, field descriptor, pointer to struct base
- **Outputs/Return:** void (mutates the struct copy in place for Write; mutates the live struct for Read)
- **Side effects:** None beyond struct mutation; `ReadField` calls `gi.TagMalloc` for `F_LSTRING` data
- **Notes:** `F_FUNCTION` encoded as byte offset from `InitGame`; `F_MMOVE` encoded as byte offset from `&mmove_reloc`; `F_EDICT` as index into `g_edicts`; `F_ITEM` as index into `itemlist`. `FFL_SPAWNTEMP` fields are silently skipped.

### WriteField2
- **Signature:** `void WriteField2(FILE *f, field_t *field, byte *base)`
- **Purpose:** Second write pass; writes variable-length string data that follows the fixed struct block.
- **Notes:** Only handles `F_LSTRING`; length was already serialized in the struct by `WriteField1`.

### WriteGame / ReadGame
- **Signature:** `void WriteGame(char *filename, qboolean autosave)` / `void ReadGame(char *filename)`
- **Purpose:** Write/read the persistent game state file (cross-level data + all client records).
- **Inputs:** Filename path; autosave flag
- **Side effects:** `WriteGame` calls `SaveClientData()` unless autosave; `ReadGame` calls `gi.FreeTags(TAG_GAME)`, reallocates entity and client arrays
- **Notes:** Version-checks via `__DATE__` string — saves are not portable across builds.

### WriteLevel / ReadLevel
- **Signature:** `void WriteLevel(char *filename)` / `void ReadLevel(char *filename)`
- **Purpose:** Write/read a complete level snapshot (level locals + all in-use edicts).
- **Side effects:** `ReadLevel` calls `gi.FreeTags(TAG_LEVEL)`, wipes `g_edicts`, re-links all entities via `gi.linkentity`, marks clients unconnected, fires deferred `target_crosslevel_target` think timers
- **Notes:** WriteLevel writes `sizeof(edict_t)` and `InitGame` address as compatibility sentinels; on non-Win32 the function pointer check is advisory only (prints offset, does not error).

### WriteEdict / ReadEdict / WriteLevelLocals / ReadLevelLocals
- Thin wrappers: copy struct, run `WriteField1`+`fwrite`+`WriteField2` (or `fread`+`ReadField`) over the appropriate field table.

## Control Flow Notes
- `InitGame` is the DLL entry point, called once per game session start or save load.
- `WriteGame`/`ReadGame` are called at level transitions and explicit saves (server-driven).
- `WriteLevel`/`ReadLevel` are called at level transitions; `ReadLevel` assumes `SpawnEntities` has already run to establish baseline state before overwriting with saved data.

## External Dependencies
- `g_local.h` — `edict_t`, `gclient_t`, `level_locals_t`, `game_locals_t`, field type enums, `FOFS`/`STOFS`/`LLOFS`/`CLOFS` offset macros
- `g_edicts`, `globals`, `game`, `level`, `itemlist`, `maxclients` — defined elsewhere in game DLL
- `gi` (game import interface) — `gi.cvar`, `gi.TagMalloc`, `gi.FreeTags`, `gi.linkentity`, `gi.error`, `gi.dprintf`
- `SaveClientData()`, `InitItems()` — defined elsewhere in game DLL
- Standard C: `fopen`, `fread`, `fwrite`, `fclose`, `memset`, `strcmp`, `strcpy`
