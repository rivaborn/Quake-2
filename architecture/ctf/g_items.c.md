# ctf/g_items.c

## File Purpose
Implements the complete item system for the CTF game module, covering pickup, use, drop, respawn, and world-placement logic for all item categories: armor, weapons, ammo, powerups, keys, health, CTF flags, and CTF tech items. It also defines the master `itemlist[]` table that enumerates every item in the game.

## Core Responsibilities
- Define and expose the global `itemlist[]` item registry for all game items
- Handle pickup callbacks for each item category (armor, ammo, health, powerup, key, power armor)
- Handle use callbacks for timed powerups (Quad, Breather, Envirosuit, Invulnerability, Silencer, Power Armor)
- Handle drop logic for ammo, general items, and power armor
- Manage item respawning via `SetRespawn`/`DoRespawn`
- Spawn items into the world via `SpawnItem`/`droptofloor`, including CTF flag routing
- Precache all assets (models, sounds, images) required by each item via `PrecacheItem`
- Provide item lookup utilities (`GetItemByIndex`, `FindItem`, `FindItemByClassname`)

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `gitem_t` | struct (defined in `game.h`) | Describes a single item: classname, callbacks, models, sounds, flags, ammo type, etc. |
| `gitem_armor_t` | struct | Armor-specific stats: base/max count, normal/energy protection, armor type tag |
| `itemlist[]` | `gitem_t[]` | Master array of all game items; index 0 is reserved/null |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `jacketarmor_info` | `gitem_armor_t` | global | Stats for jacket armor |
| `combatarmor_info` | `gitem_armor_t` | global | Stats for combat armor |
| `bodyarmor_info` | `gitem_armor_t` | global | Stats for body armor |
| `jacket_armor_index` | `int` | static | Cached itemlist index for jacket armor |
| `combat_armor_index` | `int` | static | Cached itemlist index for combat armor |
| `body_armor_index` | `int` | static | Cached itemlist index for body armor |
| `power_screen_index` | `int` | static | Cached itemlist index for power screen |
| `power_shield_index` | `int` | static | Cached itemlist index for power shield |
| `quad_drop_timeout_hack` | `static int` | static | Carries remaining Quad time when a dropped Quad is immediately re-used |
| `itemlist[]` | `gitem_t[]` | global | Master item definition table |

## Key Functions

### GetItemByIndex
- **Signature:** `gitem_t *GetItemByIndex(int index)`
- **Purpose:** Safe index-to-item lookup into `itemlist[]`.
- **Inputs:** Integer index.
- **Outputs/Return:** Pointer to `gitem_t`, or `NULL` if out of range.
- **Side effects:** None.
- **Calls:** None.
- **Notes:** Index 0 is always invalid (reserved null slot).

### FindItem / FindItemByClassname
- **Signature:** `gitem_t *FindItem(char *pickup_name)` / `gitem_t *FindItemByClassname(char *classname)`
- **Purpose:** Linear search of `itemlist[]` by display name or classname.
- **Inputs:** String name.
- **Outputs/Return:** Matching `gitem_t *` or `NULL`.
- **Side effects:** None.
- **Calls:** `Q_stricmp`.

### DoRespawn / SetRespawn
- **Signature:** `void DoRespawn(edict_t *ent)` / `void SetRespawn(edict_t *ent, float delay)`
- **Purpose:** `SetRespawn` hides an item and schedules `DoRespawn`; `DoRespawn` re-shows it. In CTF with `DF_WEAPONS_STAY`, only the team master weapon respawns.
- **Side effects:** Modifies `svflags`, `solid`, `nextthink`, `think`; calls `gi.linkentity`; sets `EV_ITEM_RESPAWN` event.

### Touch_Item
- **Signature:** `void Touch_Item(edict_t *ent, edict_t *other, cplane_t *plane, csurface_t *surf)`
- **Purpose:** Central pickup trigger. Calls item's pickup callback, awards HUD feedback, plays sounds, fires targets, and frees or respawns the entity.
- **Inputs:** Touching entity pair and collision info.
- **Side effects:** Updates client inventory/stats/HUD, plays sounds via `gi.sound`, calls `G_UseTargets`, may call `G_FreeEdict`.
- **Calls:** `ent->item->pickup`, `CTFMatchSetup`, `gi.imageindex`, `gi.sound`, `G_UseTargets`, `G_FreeEdict`.
- **Notes:** Blocked during CTF match setup phase. Targets only fired once (`ITEM_TARGETS_USED` flag).

### Drop_Item
- **Signature:** `edict_t *Drop_Item(edict_t *ent, gitem_t *item)`
- **Purpose:** Spawns a dropped item entity in front of the dropping entity, with toss velocity.
- **Side effects:** Calls `G_Spawn`, `gi.setmodel`, `gi.linkentity`; sets `drop_temp_touch` to prevent owner self-pickup for 1 second.
- **Calls:** `G_Spawn`, `AngleVectors`, `G_ProjectSource`, `gi.trace`, `gi.linkentity`.

### Pickup_Armor
- **Signature:** `qboolean Pickup_Armor(edict_t *ent, edict_t *other)`
- **Purpose:** Handles armor pickup with protection-ratio salvage math when replacing existing armor. Handles shards as a special case (+2 to current armor).
- **Calls:** `ArmorIndex`, `SetRespawn`.

### Add_Ammo / Pickup_Ammo
- **Purpose:** `Add_Ammo` is the core ammo-add primitive (respects per-type max). `Pickup_Ammo` wraps it, handles infinite-ammo DM flag, auto-selects weapon on first ammo pickup, and schedules respawn.
- **Calls:** `Add_Ammo`, `FindItem`, `SetRespawn`.

### Pickup_Health
- **Purpose:** Adds health; enforces a CTF-specific 250-cap for Mega Health. Sets up `MegaHealth_think` decay timer unless player has CTF Regeneration tech.
- **Calls:** `CTFHasRegeneration`, `SetRespawn`.

### SpawnItem
- **Signature:** `void SpawnItem(edict_t *ent, gitem_t *item)`
- **Purpose:** Entry point for map-spawned items. Precaches assets, filters dmflag-disabled items, handles coop power-cube bookkeeping, suppresses non-CTF flags, and schedules `droptofloor` (or `CTFFlagSetup` for flags).
- **Calls:** `PrecacheItem`, `G_FreeEdict`, `CTFFlagSetup`, `gi.modelindex`.

### InitItems / SetItemNames
- **Purpose:** `InitItems` sets `game.num_items` from `itemlist` size. `SetItemNames` registers all item names as config strings and caches armor/power-armor indices.
- **Calls:** `gi.configstring`, `FindItem`, `ITEM_INDEX`.

### Notes
- `PrecacheItem` parses space-separated precache strings and calls the appropriate `gi.soundindex`/`gi.modelindex`/`gi.imageindex` by file extension.
- `Use_Quad`, `Use_Breather`, `Use_Envirosuit`, `Use_Invulnerability`, `Use_Silencer` all decrement inventory and extend a frame-number deadline on the client struct.
- `droptofloor`, `drop_temp_touch`, `drop_make_touchable`, `Drop_General`, `Drop_Ammo`, `Drop_PowerArmor` are helpers summarized here rather than given full entries due to their straightforward nature.

## Control Flow Notes
- **Spawn phase:** `SpawnItem` → deferred `droptofloor` (2 frames later) plants items on the floor at level load.
- **Frame/touch:** Physics triggers `Touch_Item` each frame when a player overlaps an item trigger volume.
- **Respawn:** `SetRespawn` / `DoRespawn` operate on the think-function scheduler; items reappear after a timed delay.
- **`InitItems`** is called once at game init; **`SetItemNames`** is called by `worldspawn`.

## External Dependencies
- **Includes:** `g_local.h` (pulls in `game.h`, `q_shared.h`, entity/game definitions)
- **Defined elsewhere:**
  - `itemlist` referenced by `game.num_items` and `ITEM_INDEX` macro (defined in `game.h`)
  - `CTFMatchSetup`, `CTFHasRegeneration`, `CTFPickup_Flag`, `CTFDrop_Flag`, `CTFPickup_Tech`, `CTFDrop_Tech`, `CTFFlagSetup`, `CTFWeapon_Grapple` — CTF logic in `g_ctf.c`
  - `gi` game import struct (engine interface)
  - `deathmatch`, `coop`, `skill`, `dmflags`, `ctf` — cvars
  - `level`, `game` — global game/level state
  - `G_Spawn`, `G_FreeEdict`, `G_UseTargets`, `G_ProjectSource`, `ValidateSelectedItem` — entity utilities
