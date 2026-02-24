# game/g_cmds.c

## File Purpose
Implements all client-issued game commands (chat, inventory, cheats, wave, kill, etc.) dispatched through the central `ClientCommand` entry point. Bridges player input from the network layer to game-state mutations and UI feedback.

## Core Responsibilities
- Dispatch client commands via `ClientCommand` to appropriate handlers
- Implement cheat commands: `give`, `god`, `notarget`, `noclip`
- Handle inventory navigation, use, and drop
- Handle weapon cycling (next/prev/last)
- Implement chat (`say`/`say_team`) with flood protection
- Provide player listing utilities (`players`, `playerlist`)
- Determine team membership for team-based deathmatch modes

## Key Types / Data Structures
None unique to this file; relies on types defined in `g_local.h`.

## Global / File-Static State
None declared in this file. Reads globals `dmflags`, `sv_cheats`, `deathmatch`, `maxclients`, `dedicated`, `flood_msgs`, `flood_persecond`, `flood_waitdelay`, `level`, `game`, `g_edicts`, `itemlist`, `meansOfDeath`.

## Key Functions

### ClientCommand
- **Signature:** `void ClientCommand(edict_t *ent)`
- **Purpose:** Central dispatch for all commands issued by a connected client.
- **Inputs:** `ent` — the player entity issuing the command.
- **Outputs/Return:** void
- **Side effects:** Calls any number of sub-handlers; unrecognized commands fall through to `Cmd_Say_f`.
- **Calls:** `gi.argv`, `Q_stricmp`, and all `Cmd_*` / `Select*` functions in this file.
- **Notes:** Commands that modify game state (`use`, `drop`, `give`, cheats, etc.) are blocked during intermission; `players`, `say`, `score`, `help` are always permitted.

### Cmd_Give_f
- **Signature:** `void Cmd_Give_f(edict_t *ent)`
- **Purpose:** Cheat — grants the player items, weapons, ammo, armor, or all of the above.
- **Inputs:** Command args via `gi.args()`/`gi.argv()`.
- **Outputs/Return:** void
- **Side effects:** Mutates `ent->client->pers.inventory`, `ent->health`; may spawn/free temporary entities via `G_Spawn`/`G_FreeEdict`.
- **Calls:** `FindItem`, `Add_Ammo`, `SpawnItem`, `Touch_Item`, `G_Spawn`, `G_FreeEdict`, `gi.cprintf`.
- **Notes:** Blocked in deathmatch unless `sv_cheats` is set.

### Cmd_Say_f
- **Signature:** `void Cmd_Say_f(edict_t *ent, qboolean team, qboolean arg0)`
- **Purpose:** Broadcasts a chat message to all clients, or to teammates only when `team` is true.
- **Inputs:** `ent` — sender; `team` — restrict to same team; `arg0` — include `argv(0)` (for unrecognized-command-as-chat fallback).
- **Outputs/Return:** void
- **Side effects:** Calls `gi.cprintf` on all eligible clients; updates `cl->flood_when` ring buffer and `cl->flood_locktill`; prints to dedicated server console.
- **Calls:** `OnSameTeam`, `gi.argc`, `gi.argv`, `gi.args`, `gi.cprintf`, `Com_sprintf`.
- **Notes:** Hard-caps message length at 150 chars. Flood protection uses a sliding window (`flood_msgs` slots over `flood_persecond` seconds); violators are locked out for `flood_waitdelay` seconds.

### Cmd_Wave_f
- **Signature:** `void Cmd_Wave_f(edict_t *ent)`
- **Purpose:** Triggers a taunt/wave animation on the player model.
- **Inputs:** `gi.argv(1)` — integer selecting animation (0–4).
- **Outputs/Return:** void
- **Side effects:** Sets `ent->s.frame`, `ent->client->anim_end`, `ent->client->anim_priority`.
- **Calls:** `gi.argv`, `gi.cprintf`.
- **Notes:** Blocked when ducked or when a higher-priority animation is active.

### Cmd_Kill_f
- **Signature:** `void Cmd_Kill_f(edict_t *ent)`
- **Purpose:** Allows a player to suicide, with a 5-second rate limit.
- **Side effects:** Clears `FL_GODMODE`, sets `health = 0`, sets `meansOfDeath = MOD_SUICIDE`, calls `player_die`.

### OnSameTeam / ClientTeam
- **Notes:** `ClientTeam` extracts the model or skin portion of the `skin` userinfo key. `OnSameTeam` compares both strings; returns `false` when neither `DF_MODELTEAMS` nor `DF_SKINTEAMS` is set.

### SelectNextItem / SelectPrevItem / ValidateSelectedItem
- **Notes:** Wrap-around inventory scan filtered by `itflags`; defer to `ChaseNext`/`ChasePrev` when in chase-cam mode. `ValidateSelectedItem` resets selection if current slot is empty.

## Control Flow Notes
`ClientCommand` is called by the server layer once per client command packet. It is not part of the per-frame think loop. Cheat and game-state commands are gated on `level.intermissiontime`; social commands (`say`, `score`, `help`) are always available.

## External Dependencies
- **Includes:** `g_local.h`, `m_player.h`
- **Defined elsewhere:** `gi` (game import struct), `itemlist`, `g_edicts`, `game`, `level`, `meansOfDeath`, `dmflags`, `sv_cheats`, `deathmatch`, `maxclients`, `dedicated`, `flood_msgs`, `flood_persecond`, `flood_waitdelay`, `FindItem`, `Add_Ammo`, `SpawnItem`, `Touch_Item`, `G_Spawn`, `G_FreeEdict`, `player_die`, `ChaseNext`, `ChasePrev`, `Cmd_Score_f`, `Cmd_Help_f`, all `FRAME_*` constants from `m_player.h`.
