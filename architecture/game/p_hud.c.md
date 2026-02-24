# game/p_hud.c

## File Purpose
Manages the player HUD (heads-up display), intermission sequencing, and deathmatch scoreboard for the Quake 2 game module. It computes per-frame player stats sent to the client renderer and handles transitioning players into intermission state between levels.

## Core Responsibilities
- Teleport all clients to the intermission camera point and freeze them
- Strip coop players of keys when crossing unit boundaries
- Build and transmit the deathmatch scoreboard layout string
- Respond to `score` and `help` console commands
- Populate `ps.stats[]` array each frame with HUD data (health, ammo, armor, timers, frags)
- Propagate stats from a chase-camera target to the spectating client
- Manage spectator-specific HUD layout flags

## Key Types / Data Structures
None (all types imported via `g_local.h`).

## Global / File-Static State
None.

## Key Functions

### MoveClientToIntermission
- **Signature:** `void MoveClientToIntermission(edict_t *ent)`
- **Purpose:** Freezes a single client at the intermission camera: sets position, view angle, clears weapon/effects/powerups, and sends the scoreboard layout if in DM/coop.
- **Inputs:** `ent` — a connected player entity
- **Outputs/Return:** void
- **Side effects:** Mutates `ent->client->ps`, `ent->s`, `ent->solid`, powerup frame counters. Calls `gi.unicast` to push the layout message.
- **Calls:** `DeathmatchScoreboardMessage`, `gi.unicast`
- **Notes:** Sets `pm_type = PM_FREEZE` to lock movement. Clears `RDF_UNDERWATER` blend flag.

### BeginIntermission
- **Signature:** `void BeginIntermission(edict_t *targ)`
- **Purpose:** Initiates level-end intermission: respawns dead clients, sets `level.intermissiontime`, strips coop keys, locates a camera entity, then moves all clients to it.
- **Inputs:** `targ` — the trigger/target entity carrying the `map` field for the next level
- **Outputs/Return:** void
- **Side effects:** Writes `level.intermissiontime`, `level.changemap`, `level.exitintermission`, `level.intermission_origin/angle`. Modifies inventory of all clients in coop. Calls `respawn` on dead clients.
- **Calls:** `respawn`, `G_Find`, `MoveClientToIntermission`
- **Notes:** If the map name contains `*` (unit transition) in non-coop, `exitintermission` is set to 1 to skip the intermission screen entirely. Randomly selects among up to four `info_player_intermission` spots.

### DeathmatchScoreboardMessage
- **Signature:** `void DeathmatchScoreboardMessage(edict_t *ent, edict_t *killer)`
- **Purpose:** Builds an insertion-sorted scoreboard layout string (up to 12 clients) and writes it as a `svc_layout` network message.
- **Inputs:** `ent` — the viewing player; `killer` — entity to tag with "tag2" (may be NULL)
- **Outputs/Return:** void
- **Side effects:** Calls `gi.WriteByte`, `gi.WriteString` — queues data into the network send buffer.
- **Calls:** `gi.imageindex`, `Com_sprintf`, `gi.WriteByte`, `gi.WriteString`
- **Notes:** Layout string is capped at 1024 bytes; entries are truncated if the cap is reached. Spectators are excluded from the sorted list.

### G_SetStats
- **Signature:** `void G_SetStats(edict_t *ent)`
- **Purpose:** Fills `ent->client->ps.stats[]` each frame with all HUD values: health, ammo, armor, powerup timers, selected item, layout flags, frags, and the help/weapon icon.
- **Inputs:** `ent` — a player entity
- **Outputs/Return:** void
- **Side effects:** May emit a sound and clear `FL_POWER_ARMOR` if cells reach zero. Calls `gi.imageindex` and `gi.soundindex` / `gi.sound`.
- **Calls:** `PowerArmorType`, `FindItem`, `ArmorIndex`, `GetItemByIndex`, `gi.imageindex`, `gi.soundindex`, `gi.sound`
- **Notes:** Power armor icon flashes against regular armor every 8 frames via `level.framenum & 8`. Timer priority order: quad → invincibility → enviro → breather.

### G_CheckChaseStats
- **Signature:** `void G_CheckChaseStats(edict_t *ent)`
- **Purpose:** After `G_SetStats` runs on a target, copies that target's stats to every spectator chasing it, then overlays spectator-specific fields.
- **Inputs:** `ent` — the player being observed
- **Outputs/Return:** void
- **Side effects:** Overwrites `cl->ps.stats` for each chasing spectator.
- **Calls:** `G_SetSpectatorStats`

### G_SetSpectatorStats
- **Signature:** `void G_SetSpectatorStats(edict_t *ent)`
- **Purpose:** Sets `STAT_SPECTATOR = 1`, recalculates layout flags independently of the chase target, and sets `STAT_CHASE` to the target's player-skin config string index.
- **Inputs:** `ent` — a spectator entity
- **Outputs/Return:** void
- **Side effects:** Calls `G_SetStats` if the spectator has no chase target.
- **Calls:** `G_SetStats`

## Control Flow Notes
`G_SetStats` and `G_CheckChaseStats` are called once per server frame per player (from `ClientEndServerFrame` in `p_view.c`). `BeginIntermission` is triggered by map exit targets during gameplay. `Cmd_Score_f` and `Cmd_Help_f` are registered command handlers dispatched from `ClientCommand`.

## External Dependencies
- `g_local.h` — pulls in all game types, `level`, `game`, `g_edicts`, cvars (`deathmatch`, `coop`, `skill`, `maxclients`), and the `gi` game import table
- `respawn`, `G_Find`, `PowerArmorType`, `ArmorIndex`, `GetItemByIndex`, `FindItem`, `DeathmatchScoreboard` — defined elsewhere in the game module
- `gi.unicast`, `gi.WriteByte`, `gi.WriteString`, `gi.imageindex`, `gi.soundindex`, `gi.sound` — engine import functions
