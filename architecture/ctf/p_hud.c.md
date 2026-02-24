# ctf/p_hud.c

## File Purpose
Implements the CTF variant HUD system, including intermission sequencing, deathmatch scoreboard rendering, help computer display, and per-frame player stat updates sent to the client. It is largely identical to `game/p_hud.c` but with CTF-specific hooks injected at key points.

## Core Responsibilities
- Teleport clients to intermission camera positions and freeze them
- Trigger and coordinate the intermission/end-of-level sequence
- Build and unicast the deathmatch scoreboard layout string
- Render the in-game help computer overlay
- Populate `player_state_t.stats[]` each frame for HUD rendering (health, ammo, armor, timers, frags, layouts)
- Delegate scoreboard and score calculation to CTF-specific functions when `ctf->value` is set

## Key Types / Data Structures
None (operates on existing engine types).

## Global / File-Static State
None.

## Key Functions

### MoveClientToIntermission
- Signature: `void MoveClientToIntermission(edict_t *ent)`
- Purpose: Teleports a single client to the intermission camera, freezes movement, strips effects, and sends the scoreboard layout.
- Inputs: `ent` — a connected client entity.
- Outputs/Return: void
- Side effects: Mutates `ent->client->ps`, `ent->s`, `ent->solid`, `ent->viewheight`; calls `gi.unicast`.
- Calls: `DeathmatchScoreboardMessage`, `gi.unicast`, `VectorCopy`
- Notes: Clears powerup timers (quad, invincible, breather, enviro) and grenade state.

### BeginIntermission
- Signature: `void BeginIntermission(edict_t *targ)`
- Purpose: Initiates the end-of-level intermission: calculates CTF scores, respawns dead clients, strips coop keys, picks a camera spot, and moves all clients.
- Inputs: `targ` — trigger/target entity whose `.map` field names the next level.
- Outputs/Return: void
- Side effects: Sets `level.intermissiontime`, `level.changemap`, `level.exitintermission`; may call `respawn()` on dead clients; calls `CTFCalcScores()` in CTF mode; calls `MoveClientToIntermission` for all clients.
- Calls: `CTFCalcScores`, `respawn`, `G_Find`, `MoveClientToIntermission`, `strstr`, `rand`
- Notes: Returns early if `level.intermissiontime` already set (idempotent). In non-DM single-player it sets `exitintermission = 1` immediately. Intermission spot selection randomly picks one of up to four `info_player_intermission` entities.

### DeathmatchScoreboardMessage
- Signature: `void DeathmatchScoreboardMessage(edict_t *ent, edict_t *killer)`
- Purpose: Builds a sorted scoreboard layout string and writes it to the network buffer via `svc_layout`.
- Inputs: `ent` — viewing client; `killer` — optional killer entity for dog-tag decoration.
- Outputs/Return: void
- Side effects: Writes to net message buffer (`gi.WriteByte`, `gi.WriteString`). Delegates entirely to `CTFScoreboardMessage` when `ctf->value` is set.
- Calls: `CTFScoreboardMessage`, `gi.imageindex`, `Com_sprintf`, `gi.WriteByte`, `gi.WriteString`
- Notes: Caps display at 12 clients. Layout string capped at 1024 bytes; entries are dropped if the buffer would overflow.

### G_SetStats
- Signature: `void G_SetStats(edict_t *ent)`
- Purpose: Populates all `ps.stats[]` slots for one client every frame so the client renderer can draw the HUD.
- Inputs: `ent` — client entity.
- Outputs/Return: void
- Side effects: Mutates `ent->client->ps.stats[]`; may clear `FL_POWER_ARMOR` and play a sound if cells run out; calls `SetCTFStats(ent)` at the end.
- Calls: `PowerArmorType`, `ArmorIndex`, `FindItem`, `GetItemByIndex`, `ITEM_INDEX`, `gi.imageindex`, `gi.soundindex`, `gi.sound`, `SetCTFStats`
- Notes: Power armor icon flashes with non-power armor at 4 Hz (`level.framenum & 8`). Timer priority order: quad → invincible → enviro → breather.

### Notes (minor functions)
- `DeathmatchScoreboard`: thin wrapper — calls `DeathmatchScoreboardMessage` then `gi.unicast`.
- `Cmd_Score_f`: toggles `showscores`; closes any open CTF `PMenu` first; resets `update_chase` on hide.
- `HelpComputer`: formats a static help layout string with kill/goal/secret counts and unicasts it.
- `Cmd_Help_f`: in DM mode redirects to `Cmd_Score_f`; otherwise toggles `showhelp` and calls `HelpComputer`.

## Control Flow Notes
- `BeginIntermission` is called from level-end trigger logic (elsewhere).
- `G_SetStats` is called every server frame from `ClientEndServerFrame` (in `p_view.c`) for each connected client.
- `Cmd_Score_f` / `Cmd_Help_f` are registered as client commands, called from `ClientCommand`.

## External Dependencies
- `g_local.h` — all game types, CVars (`deathmatch`, `coop`, `ctf`, `skill`), `level`, `game`, `g_edicts`, `itemlist`
- `CTFCalcScores`, `CTFScoreboardMessage`, `SetCTFStats`, `PMenu_Close` — defined in `g_ctf.c` / `p_menu.c`
- `PowerArmorType`, `ArmorIndex`, `FindItem`, `GetItemByIndex` — defined in `g_items.c`
- `G_Find`, `respawn` — defined in `g_utils.c` / `p_client.c`
- `gi` (game import struct) — provided by the engine at game init
