# ctf/g_ctf.c

## File Purpose
Core implementation of the ThreeWave Capture the Flag (CTF) game mode for Quake 2. Handles all CTF-specific gameplay logic including flag mechanics, team assignment, the grappling hook weapon, tech powerups, match/election systems, and the in-game admin/join menus.

## Core Responsibilities
- Flag pickup, capture, drop, and auto-return logic
- Team assignment, skin assignment, and spawn point selection
- Grappling hook weapon simulation (fire, pull, cable draw, reset)
- Tech powerup spawning, pickup, drop, and effect application
- Match lifecycle management (SETUP → PREGAME → GAME → POST)
- Election/voting system for admin, map changes, and match requests
- CTF HUD stat population (`SetCTFStats`) and scoreboard formatting
- Ghost code system for reconnection score restoration
- In-game player menus (join, admin, settings, credits)

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `match_t` | enum | Match state machine: NONE, SETUP, PREGAME, GAME, POST |
| `elect_t` | enum | Election type: NONE, MATCH, ADMIN, MAP |
| `ctfgame_t` | struct | Global CTF game state: scores, match state, election state, ghost codes |
| `admin_settings_t` | struct | Transient admin settings menu state (match lengths, dmflags toggles) |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `ctfgame` | `ctfgame_t` | global | Authoritative CTF match/election/score state |
| `ctf` | `cvar_t *` | global | CTF mode enabled cvar |
| `competition` | `cvar_t *` | global | Competition/match mode level |
| `matchlock` | `cvar_t *` | global | Prevents joining during active match |
| `matchtime` | `cvar_t *` | global | Match duration in minutes |
| `flag1_item` / `flag2_item` | `gitem_t *` | static | Cached item pointers for team flags |
| `ctf_statusbar` | `char *` | global | HUD layout string for CTF overlay |
| `tnames[]` | `char *[]` | static | Tech powerup classname list |
| `loc_names[]` | anonymous struct array | static | Classname-to-priority table for team-say location reporting |
| `joinmenu` / `adminmenu` / `creditsmenu` | `pmenu_t[]` | static (file) | In-game menu definitions |

## Key Functions

### CTFInit
- Signature: `void CTFInit(void)`
- Purpose: Registers all CTF-related cvars at game startup.
- Inputs: None
- Outputs/Return: None
- Side effects: Allocates cvar handles into global pointers.
- Calls: `gi.cvar`
- Notes: Must be called before any CTF logic runs.

### CTFSpawn
- Signature: `void CTFSpawn(void)`
- Purpose: Resets CTF game state for a new map/level.
- Inputs: None
- Outputs/Return: None
- Side effects: Zeros `ctfgame`, caches flag item pointers, spawns techs, sets MATCH_SETUP if competition > 1.
- Calls: `FindItemByClassname`, `CTFSetupTechSpawn`

### CTFPickup_Flag
- Signature: `qboolean CTFPickup_Flag(edict_t *ent, edict_t *other)`
- Purpose: Handles all flag touch events: capture, return, and pickup.
- Inputs: `ent` = flag entity, `other` = touching player
- Outputs/Return: `true` if flag is picked up and should be removed from world; `false` otherwise.
- Side effects: Updates `ctfgame.team1/team2`, awards score bonuses, plays sounds, calls `CTFResetFlags` on capture.
- Calls: `CTFResetFlag`, `Drop_Item`, `gi.bprintf`, `gi.sound`
- Notes: Returns false both for captures (flag is reset) and for touching your own at-base flag (no-op).

### CTFFragBonuses
- Signature: `void CTFFragBonuses(edict_t *targ, edict_t *inflictor, edict_t *attacker)`
- Purpose: Evaluates and awards defensive/offensive bonuses on a frag (carrier kill, flag defense, carrier escort).
- Inputs: Targ/inflictor/attacker entities
- Outputs/Return: None
- Side effects: Modifies `resp.score`, ghost stats; prints bonus messages.
- Calls: `CTFOtherTeam`, `loc_CanSee`, `G_Find`, `gi.cprintf`, `gi.bprintf`
- Notes: Bonuses are mutually exclusive, checked in priority order.

### CTFGrapplePull
- Signature: `void CTFGrapplePull(edict_t *self)`
- Purpose: Per-frame think for an active grapple hook: pulls owner toward hook, damages latched enemies, draws cable.
- Inputs: `self` = grapple projectile entity
- Outputs/Return: None
- Side effects: Modifies owner velocity, applies damage, transitions grapple state to HANG, calls `CTFGrappleDrawCable`.
- Calls: `CTFResetGrapple`, `T_Damage`, `SV_AddGravity`, `CTFGrappleDrawCable`, `CheckTeamDamage`

### CTFFireGrapple
- Signature: `void CTFFireGrapple(edict_t *self, vec3_t start, vec3_t dir, int damage, int speed, int effect)`
- Purpose: Spawns the grapple hook projectile and fires it.
- Inputs: Firing entity, world-space start/direction, damage, speed, visual effect flags.
- Outputs/Return: None
- Side effects: Allocates a new `edict_t` via `G_Spawn`, links it, sets owner's `ctf_grapple` pointer.
- Calls: `G_Spawn`, `gi.linkentity`, `gi.trace`, `CTFGrappleTouch`

### SetCTFStats
- Signature: `void SetCTFStats(edict_t *ent)`
- Purpose: Populates all CTF-related HUD `ps.stats` slots for a given player each frame.
- Inputs: Player entity
- Outputs/Return: None
- Side effects: Writes to `ent->client->ps.stats[]`, updates ghost score/name.
- Calls: `CTFSetIDView`, `G_Find`, `gi.imageindex`
- Notes: Called every frame per player; handles blinking win headers and flag-state icons.

### CTFCheckRules
- Signature: `qboolean CTFCheckRules(void)`
- Purpose: Per-frame match state machine tick: handles election timeout, match phase transitions, countdown display, and capturelimit check.
- Inputs: None (reads `ctfgame`, `level`)
- Outputs/Return: `true` if the level should end (capturelimit hit).
- Side effects: Transitions `ctfgame.match`, calls `CTFStartMatch`/`CTFEndMatch`/`CTFResetAllPlayers`, updates `CONFIG_CTF_MATCH` configstring.
- Calls: `CTFStartMatch`, `CTFEndMatch`, `CTFResetAllPlayers`, `EndDMLevel`, `gi.configstring`

### CTFStartMatch / CTFEndMatch
- `CTFStartMatch`: Transitions to MATCH_GAME, zeros scores, assigns ghosts, force-kills all players for a simultaneous respawn.
- `CTFEndMatch`: Transitions to MATCH_POST, calculates final scores, broadcasts results, calls `EndDMLevel`.

### CTFSay_Team
- Signature: `void CTFSay_Team(edict_t *who, char *msg)`
- Purpose: Processes team-only chat with `%`-substitution tokens (location, armor, health, tech, weapon, visible players).
- Inputs: Sender, raw message string
- Outputs/Return: None
- Side effects: `gi.cprintf` to all same-team players.
- Calls: `CTFSay_Team_Location`, `CTFSay_Team_Armor`, `CTFSay_Team_Health`, `CTFSay_Team_Tech`, `CTFSay_Team_Weapon`, `CTFSay_Team_Sight`, `CheckFlood`

### CTFApplyResistance / CTFApplyStrength / CTFApplyHaste / CTFApplyRegeneration
- Tech powerup effect functions, each checking for item_tech1–4 in player inventory and modifying damage, speed, or health/armor regeneration accordingly.

## Control Flow Notes
- `CTFInit` is called once at game module load; `CTFSpawn` at each map start.
- `SetCTFStats` and `CTFCheckRules` are called every server frame (from `ClientEndServerFrame` and `G_RunFrame` respectively).
- `CTFPickup_Flag` is registered as the pickup callback on flag entities.
- `CTFGrapplePull` is the per-frame think on the grapple projectile entity while active.
- Match state drives player spawn behavior via `CTFStartClient` and `CTFMatchSetup`/`CTFMatchOn` queries from other modules.

## External Dependencies
- Notable includes: `g_local.h`, `m_player.h`
- External symbols used but not defined here:
  - `g_edicts`, `globals`, `game`, `level` — engine/game globals
  - `gi` — game import interface (all engine I/O)
  - `G_Find`, `G_Spawn`, `G_FreeEdict`, `Drop_Item`, `Touch_Item` — entity utilities
  - `PutClientInServer`, `respawn`, `player_die` — player lifecycle
  - `Weapon_Generic`, `P_ProjectSource`, `PlayerNoise` — weapon framework
  - `T_Damage`, `CheckTeamDamage`, `KillBox` — combat
  - `EndDMLevel`, `DoRespawn` — level transition
  - `PMenu_Open/Close/Update/UpdateEntry` — in-game menu system
  - `CheckFlood`, `ArmorIndex`, `PowerArmorType`, `GetItemByIndex` — utility
  - `SelectRandomDeathmatchSpawnPoint`, `SelectFarthestDeathmatchSpawnPoint`, `PlayersRangeFromSpot` — spawn selection
  - `capturelimit`, `dmflags`, `maxclients`, `instantweap` — cvars defined elsewhere
