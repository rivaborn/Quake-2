# ctf/p_client.c

## File Purpose
Implements the CTF-variant player client lifecycle for Quake 2, covering connection, spawning, death, respawning, per-frame input processing, and disconnection. It is the CTF-modified fork of `game/p_client.c`, adding grapple, flag, tech, and team-assignment hooks throughout.

## Core Responsibilities
- Manage player connection/disconnection and userinfo parsing
- Select and validate spawn points (deathmatch, coop, CTF, single-player)
- Initialize and reset persistent and per-respawn client state
- Handle player death: obituaries, gibbing, animation, weapon toss, CTF flag/tech drops
- Drive per-client-frame physics via `gi.Pmove`, touch resolution, and weapon firing
- Drive per-server-frame logic: weapon animation ticks and dead-player respawn gating
- Maintain a body queue for corpse entities after respawn

## Key Types / Data Structures
None defined here; relies on types from `g_local.h`.

| Name | Kind | Purpose |
|---|---|---|
| `pmove_t` | struct (external) | Player movement state passed to `gi.Pmove` |
| `client_persistant_t` | struct (external) | Survives death/level changes (health, inventory, weapon) |
| `client_respawn_t` | struct (external) | Per-life data reset each spawn (score, cmd_angles, CTF team) |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `pm_passent` | `edict_t *` | global | Passed to `PM_trace` so pmove can exclude the moving player from traces |

## Key Functions

### InitClientPersistant
- **Signature:** `void InitClientPersistant(gclient_t *client)`
- **Purpose:** Zero and populate persistent client data; grants Blaster, Grapple (CTF addition), and ammo caps.
- **Inputs:** `client` — target gclient
- **Outputs/Return:** void
- **Side effects:** Modifies `client->pers`; calls `FindItem`, `ITEM_INDEX`
- **Calls:** `FindItem`, `ITEM_INDEX`, `memset`
- **Notes:** CTF adds unconditional Grapple grant; called on first connect and after each death in DM.

### InitClientResp
- **Signature:** `void InitClientResp(gclient_t *client)`
- **Purpose:** Zero per-life respawn struct while preserving CTF team and id_state; assigns team if unset.
- **Inputs:** `client`
- **Side effects:** May call `CTFAssignTeam`
- **Calls:** `memset`, `CTFAssignTeam`

### PutClientInServer
- **Signature:** `void PutClientInServer(edict_t *ent)`
- **Purpose:** Full entity setup for a spawning or respawning player: selects spawn point, resets client/entity fields, runs pmove origin, sets model/skin, calls `CTFStartClient`.
- **Inputs:** `ent` — player edict
- **Side effects:** Writes `client->ps`, `ent->s`, calls `KillBox`, `gi.linkentity`, `ChangeWeapon`
- **Calls:** `SelectSpawnPoint`, `InitClientPersistant`, `ClientUserinfoChanged`, `FetchClientEntData`, `KillBox`, `CTFStartClient`, `ChangeWeapon`, `gi.linkentity`
- **Notes:** Early-returns if `CTFStartClient` handles placement (team-join menu path).

### ClientThink
- **Signature:** `void ClientThink(edict_t *ent, usercmd_t *ucmd)`
- **Purpose:** Per-client-frame driver: runs pmove, syncs entity state, fires weapons, updates grapple, chase-cam followers, and CTF menu.
- **Inputs:** `ent`, `ucmd` — current user command
- **Side effects:** Mutates `ent->s.origin/velocity`, `client->ps`, calls `gi.Pmove`, `gi.linkentity`, `G_TouchTriggers`, `CTFGrapplePull`, `CTFApplyRegeneration`, `UpdateChaseCam`, `PMenu_Do_Update`
- **Calls:** `gi.Pmove`, `PM_trace`, `G_TouchTriggers`, `Think_Weapon`, `PlayerNoise`, `CTFGrapplePull`, `CTFApplyRegeneration`, `UpdateChaseCam`, `PMenu_Do_Update`
- **Notes:** Chase-target clients skip pmove entirely and only record angles.

### ClientBeginServerFrame
- **Signature:** `void ClientBeginServerFrame(edict_t *ent)`
- **Purpose:** Pre-entity server frame hook: ticks weapon animation if no ucmd did so, gates dead-player respawn on button/force-respawn/CTF match state.
- **Calls:** `Think_Weapon`, `respawn`, `CTFMatchOn`, `PlayerTrail_Add`, `visible`

### player_die
- **Signature:** `void player_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- **Purpose:** Handles all death consequences: obituary, CTF telefrag scoring fix, gib/animation selection, flag and tech drops, grapple reset, weapon toss.
- **Calls:** `LookAtKiller`, `ClientObituary`, `CTFFragBonuses`, `TossClientWeapon`, `CTFPlayerResetGrapple`, `CTFDeadDropFlag`, `CTFDeadDropTech`, `ThrowGib`, `ThrowClientHead`, `Cmd_Help_f`, `gi.sound`, `gi.linkentity`
- **Notes:** CTF adds `modelindex3` clear (flag model), grapple reset, and flag/tech drop before the standard death path.

### ClientConnect / ClientDisconnect
- **Signature:** `qboolean ClientConnect(edict_t *ent, char *userinfo)` / `void ClientDisconnect(edict_t *ent)`
- **Purpose:** Gate entry (password check, init), and clean exit (drop flag/tech, clear entity, blank configstring).
- **Calls:** `ClientConnect`: `InitClientResp`, `InitClientPersistant`, `ClientUserinfoChanged`. `ClientDisconnect`: `CTFDeadDropFlag`, `CTFDeadDropTech`, `gi.unlinkentity`, `gi.configstring`.

### SelectSpawnPoint
- **Signature:** `void SelectSpawnPoint(edict_t *ent, vec3_t origin, vec3_t angles)`
- **Purpose:** Dispatch to CTF/DM/coop/SP spawn selection, copy chosen spot's origin+angles out.
- **Calls:** `SelectCTFSpawnPoint`, `SelectDeathmatchSpawnPoint`, `SelectCoopSpawnPoint`, `G_Find`, `gi.error`

### Notes (trivial helpers)
- `PlayersRangeFromSpot` — distance to nearest live player from a spot.
- `SelectRandomDeathmatchSpawnPoint` / `SelectFarthestDeathmatchSpawnPoint` — spawn heuristics avoiding the two closest occupied spots.
- `PM_trace` — thin wrapper forwarding pmove traces to `gi.trace` with live/dead mask selection.
- `SP_FixCoopSpots` / `SP_CreateCoopSpots` — map-specific coop spawn fixup hacks.
- `CopyToBodyQue` / `InitBodyQue` / `body_die` — rotating corpse entity pool management.
- `ClientObituary` — formats and broadcasts kill/death messages; adjusts scores.
- `IsFemale` — checks skin userinfo prefix for gender-specific obituary strings.

## Control Flow Notes
- **Connect:** `ClientConnect` → `ClientBegin` → `ClientBeginDeathmatch` or direct → `PutClientInServer`
- **Per client frame:** `ClientThink` (pmove + weapon fire + CTF hooks)
- **Per server frame:** `ClientBeginServerFrame` (weapon tick, respawn gate) then `ClientEndServerFrame` (defined elsewhere)
- **Death:** `player_die` → optional `respawn` → `PutClientInServer`

## External Dependencies
- **Includes:** `g_local.h`, `m_player.h` (frame constants)
- **Defined elsewhere:** `CTFStartClient`, `CTFFragBonuses`, `CTFPlayerResetGrapple`, `CTFDeadDropFlag`, `CTFDeadDropTech`, `CTFGrapplePull`, `CTFApplyRegeneration`, `CTFAssignTeam`, `CTFAssignSkin`, `CTFMatchOn`, `SelectCTFSpawnPoint`, `UpdateChaseCam`, `PMenu_Do_Update`, `Think_Weapon`, `ChangeWeapon`, `Drop_Item`, `ThrowGib`, `ThrowClientHead`, `PlayerTrail_Add`, `G_Find`, `G_Spawn`, `G_FreeEdict`, `G_InitEdict`, `KillBox`, `ClientEndServerFrame`, `MoveClientToIntermission`, `gi.*` (engine import table)
