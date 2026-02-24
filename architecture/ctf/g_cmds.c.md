# ctf/g_cmds.c

## File Purpose
Handles all client-issued game commands for the CTF (Capture the Flag) mod, routing text commands to their corresponding handler functions. It extends the base Quake 2 command set with CTF-specific commands such as team selection, voting, ghosting, and admin controls.

## Core Responsibilities
- Parse and dispatch client commands via `ClientCommand`
- Implement cheat commands (give, god, notarget, noclip) gated behind `sv_cheats`
- Manage inventory navigation, use, and drop
- Implement player chat (`say`, `say_team`) with flood protection
- Provide weapon cycling and player animation (wave) commands
- Support CTF-specific player menu navigation (PMenu) and chase-cam redirection
- Determine team membership from userinfo skin/model strings

## Key Types / Data Structures
None (operates on types defined in `g_local.h` and `game.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `value[512]` (in `ClientTeam`) | `static char[]` | static (function-local) | Scratch buffer returned by `ClientTeam`; not re-entrant |

## Key Functions

### ClientTeam
- **Signature:** `char *ClientTeam(edict_t *ent)`
- **Purpose:** Extracts a player's team string from their `userinfo` skin field. Returns either the model prefix or skin suffix depending on `DF_MODELTEAMS`.
- **Inputs:** Player entity
- **Outputs/Return:** Pointer to a static buffer containing the team string
- **Side effects:** Writes to a function-static buffer — not re-entrant
- **Calls:** `Info_ValueForKey`, `strchr`
- **Notes:** Returns an empty string if `ent->client` is NULL.

### OnSameTeam
- **Signature:** `qboolean OnSameTeam(edict_t *ent1, edict_t *ent2)`
- **Purpose:** Returns true if two players share the same team based on skin/model flags.
- **Inputs:** Two player entities
- **Outputs/Return:** `qboolean`
- **Side effects:** None
- **Calls:** `ClientTeam`

### SelectNextItem / SelectPrevItem
- **Signature:** `void SelectNextItem(edict_t *ent, int itflags)` / `void SelectPrevItem(...)`
- **Purpose:** Cycles the player's selected inventory item forward or backward, filtered by item flags. In CTF, redirects to `PMenu_Next/Prev` if a menu is open, or `ChaseNext/ChasePrev` if in chase mode.
- **Inputs:** Player entity; `itflags` bitmask (`-1` = any, `IT_WEAPON`, `IT_POWERUP`)
- **Outputs/Return:** Modifies `cl->pers.selected_item`
- **Side effects:** May set `selected_item` to `-1` if no valid item found
- **Calls:** `PMenu_Next`, `PMenu_Prev`, `ChaseNext`, `ChasePrev`

### Cmd_Give_f
- **Signature:** `void Cmd_Give_f(edict_t *ent)`
- **Purpose:** Cheat command; grants items, weapons, ammo, armor, or all items to the client.
- **Inputs:** Client entity; reads `gi.args()` / `gi.argv()`
- **Outputs/Return:** Modifies `ent->client->pers.inventory`, `ent->health`
- **Side effects:** May spawn and immediately free temporary item entities via `G_Spawn` / `G_FreeEdict`
- **Calls:** `FindItem`, `Add_Ammo`, `G_Spawn`, `SpawnItem`, `Touch_Item`, `G_FreeEdict`
- **Notes:** Blocked in deathmatch unless `sv_cheats` is set.

### CheckFlood
- **Signature:** `qboolean CheckFlood(edict_t *ent)`
- **Purpose:** Enforces chat flood protection using a sliding-window timestamp ring buffer on the client.
- **Inputs:** Player entity
- **Outputs/Return:** `true` if the player is locked out from chatting
- **Side effects:** Updates `cl->flood_when[]`, `cl->flood_whenhead`, `cl->flood_locktill`
- **Calls:** `gi.cprintf`
- **Notes:** Controlled by `flood_msgs`, `flood_persecond`, `flood_waitdelay` cvars.

### Cmd_Say_f
- **Signature:** `void Cmd_Say_f(edict_t *ent, qboolean team, qboolean arg0)`
- **Purpose:** Broadcasts or team-casts a chat message with flood gating.
- **Inputs:** Sender entity; `team` flag restricts to teammates; `arg0` includes `argv(0)` in text
- **Side effects:** Calls `gi.cprintf` on all eligible recipients; passes through dedicated server console
- **Calls:** `CheckFlood`, `OnSameTeam`, `gi.cprintf`
- **Notes:** Message truncated to 150 characters to prevent abuse.

### ClientCommand
- **Signature:** `void ClientCommand(edict_t *ent)`
- **Purpose:** Engine-facing entry point; dispatches all client text commands to handlers.
- **Inputs:** Player entity (command read via `gi.argv(0)`)
- **Side effects:** Delegates to all `Cmd_*` and `CTF*` handlers; falls through to `Cmd_Say_f` for unknown commands
- **Notes:** `score`, `help`, `say`, `say_team`, `players` are processed even during intermission; all others are suppressed.

## Control Flow Notes
`ClientCommand` is the sole entry point called by the server engine when a client issues a text command. It runs within the server frame on demand (event-driven, not per-frame). Cheat commands check `deathmatch` and `sv_cheats` before executing. CTF-specific commands (`team`, `id`, `yes`, `no`, `ready`, `ghost`, `admin`, `warp`, `boot`, etc.) delegate directly to functions defined in `g_ctf.c`.

## External Dependencies
- **Includes:** `g_local.h`, `m_player.h`
- **Defined elsewhere:** `PMenu_Next/Prev/Close/Select`, `CTFOpenJoinMenu`, `CTFSay_Team`, `CTFTeam_f`, `CTFID_f`, `CTFVoteYes/No`, `CTFReady/NotReady`, `CTFGhost`, `CTFAdmin`, `CTFStats`, `CTFWarp`, `CTFBoot`, `CTFPlayerList`, `CTFObserver`, `CTFWhat_Tech`, `ChaseNext/ChasePrev`, `Add_Ammo`, `SpawnItem`, `Touch_Item`, `player_die`, `FindItem`, `G_Spawn`, `G_FreeEdict`, `itemlist`, `game`, `g_edicts`, `meansOfDeath`, `dmflags`, `sv_cheats`, `deathmatch`, `dedicated`, `ctf`, `flood_msgs`, `flood_persecond`, `flood_waitdelay`, `maxclients`
