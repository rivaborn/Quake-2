# game/g_items.c

## File Purpose
Defines all collectable items in the game (weapons, ammo, armor, health, powerups, keys) and implements the complete lifecycle of item pickup, use, drop, respawn, and world placement. It is the authoritative item registry for the game module.

## Core Responsibilities
- Declares and populates the global `itemlist[]` item registry
- Implements pickup callbacks for every item category (armor, health, ammo, powerups, keys, weapons)
- Implements use callbacks for timed powerups (Quad, Breather, Envirosuit, Invulnerability, Silencer, Power Armor)
- Implements drop logic for weapons, ammo, and general items
- Manages item respawn scheduling via `SetRespawn` / `DoRespawn`
- Handles item world placement (`droptofloor`, `SpawnItem`, `PrecacheItem`)
- Provides lookup utilities (`FindItem`, `FindItemByClassname`, `GetItemByIndex`)

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `gitem_t` | struct (defined in `g_local.h`) | Describes a single item: classname, callbacks, models, sounds, flags, quantity |
| `gitem_armor_t` | struct | Armor-specific stats: base/max count, normal/energy protection, armor type tag |
| `itemlist[]` | `gitem_t[]` | Master registry of every item; index 0 is a sentinel null entry |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `itemlist[]` | `gitem_t[]` | global | Master item table; indexed by `ITEM_INDEX` macro throughout the game |
| `jacketarmor_info` | `gitem_armor_t` | global | Stats for jacket armor |
| `combatarmor_info` | `gitem_armor_t` | global | Stats for combat armor |
| `bodyarmor_info` | `gitem_armor_t` | global | Stats for body armor |
| `jacket_armor_index` | `int` | static | Cached item index for jacket armor; set in `SetItemNames` |
| `combat_armor_index` | `int` | static | Cached item index for combat armor |
| `body_armor_index` | `int` | static | Cached item index for body armor |
| `power_screen_index` | `int` | static | Cached item index for power screen |
| `power_shield_index` | `int` | static | Cached item index for power shield |
| `quad_drop_timeout_hack` | `int` | static | Carries remaining quad duration when a dropped quad is immediately re-used |

## Key Functions

### Touch_Item
- **Signature:** `void Touch_Item(edict_t *ent, edict_t *other, cplane_t *plane, csurface_t *surf)`
- **Purpose:** Collision callback executed when a client entity overlaps an item; orchestrates the full pickup sequence.
- **Inputs:** Item entity, touching entity, collision plane/surface (unused).
- **Outputs/Return:** void
- **Side effects:** Modifies client inventory, HUD stats, plays sounds, fires item targets, frees or sets respawn on item entity.
- **Calls:** `ent->item->pickup`, `G_UseTargets`, `gi.imageindex`, `gi.soundindex`, `gi.sound`, `G_FreeEdict`
- **Notes:** Dead players (health < 1) and non-clients are rejected. Targets are fired exactly once via `ITEM_TARGETS_USED` spawnflag. Coop `IT_STAY_COOP` items are not freed after pickup.

### Drop_Item
- **Signature:** `edict_t *Drop_Item(edict_t *ent, gitem_t *item)`
- **Purpose:** Spawns a physically tossed copy of an item projected from the dropper's view angles.
- **Inputs:** Dropping entity, item definition.
- **Outputs/Return:** Pointer to the newly spawned dropped entity.
- **Side effects:** Allocates a new edict; sets `drop_temp_touch` for 1 second to prevent self-pickup, then transitions to `Touch_Item`; in DM, freed after 29 seconds.
- **Calls:** `G_Spawn`, `AngleVectors`, `G_ProjectSource`, `gi.trace`, `gi.linkentity`

### Pickup_Armor
- **Signature:** `qboolean Pickup_Armor(edict_t *ent, edict_t *other)`
- **Purpose:** Handles armor pickup with blending logic: shards add flat, better armor replaces with salvage calculation, equal/worse armor is clamped to old max.
- **Inputs:** Armor item entity, picking-up client entity.
- **Outputs/Return:** `true` if armor was taken, `false` if already at max with inferior armor.
- **Side effects:** Modifies `other->client->pers.inventory`; schedules respawn in DM.
- **Calls:** `ArmorIndex`

### Pickup_Ammo
- **Signature:** `qboolean Pickup_Ammo(edict_t *ent, edict_t *other)`
- **Purpose:** Adds ammo to inventory; auto-selects weapon if player had none of this ammo type.
- **Inputs:** Ammo entity, client entity.
- **Outputs/Return:** `true` if any ammo was added.
- **Side effects:** May set `other->client->newweapon`; schedules 30-second DM respawn.
- **Calls:** `Add_Ammo`, `FindItem`, `SetRespawn`

### SpawnItem
- **Signature:** `void SpawnItem(edict_t *ent, gitem_t *item)`
- **Purpose:** Entry point called by entity spawn functions; precaches assets, applies DM filter rules, defers `droptofloor` by 2 frames.
- **Inputs:** Entity being spawned, item definition.
- **Side effects:** May free entity (DM rules); sets `ent->think = droptofloor`, modifies `level.power_cubes` for coop power cubes, nulls `item->drop` for `IT_STAY_COOP` items in coop.
- **Calls:** `PrecacheItem`, `G_FreeEdict`, `gi.dprintf`, `gi.modelindex`

### PrecacheItem
- **Signature:** `void PrecacheItem(gitem_t *it)`
- **Purpose:** Registers all models, sounds, and images associated with an item (and its ammo type) with the server.
- **Calls:** `gi.soundindex`, `gi.modelindex`, `gi.imageindex`, `FindItem`, recursively `PrecacheItem`

### Use_Quad
- **Signature:** `void Use_Quad(edict_t *ent, gitem_t *item)`
- **Purpose:** Activates Quad Damage; stacks duration if already active; consumes `quad_drop_timeout_hack` if set.
- **Side effects:** Modifies `ent->client->quad_framenum`; plays sound.

### InitItems / SetItemNames
- `InitItems`: Sets `game.num_items` from `itemlist` array size. Called at game init.
- `SetItemNames`: Sends all item names as config strings; resolves and caches the five armor/power-armor indices. Called by worldspawn.

## Control Flow Notes
- **Init:** `InitItems` → `SetItemNames` (worldspawn) → `SpawnItem` per map entity → `droptofloor` (deferred 2 frames).
- **Frame:** `Touch_Item` fires on collision; `DoRespawn` fires via `think` after `SetRespawn` delay; `MegaHealth_think` ticks health drain per second.
- **Player action:** Use/drop commands invoke `Use_*` / `Drop_*` callbacks stored in `gitem_t`.

## External Dependencies
- **Includes:** `g_local.h` (pulls in all game types, `gi` import table, cvars, macros)
- **Defined elsewhere:** `gi` (game import struct), `game`, `level`, `itemlist` (self), `skill`, `deathmatch`, `coop`, `dmflags` (cvars), `G_Spawn`, `G_FreeEdict`, `G_UseTargets`, `ValidateSelectedItem`, `ArmorIndex` (defined here), all `Weapon_*` functions (in `p_weapon.c` / `g_weapon.c`)
