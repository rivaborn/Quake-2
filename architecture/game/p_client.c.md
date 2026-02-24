# game/p_client.c

## File Purpose
Manages the full lifecycle of player clients in the Quake 2 game module: connection, spawning, respawning, disconnection, death, and per-frame processing. It also handles spawn point selection, body queue management, and cooperative/deathmatch-specific hacks for broken maps.

## Core Responsibilities
- Connect, begin, disconnect, and per-frame update callbacks for player entities
- Select appropriate spawn points (singleplayer, deathmatch, coop)
- Initialize and restore persistent and per-respawn client data
- Handle player death, gibbing, obituary messages, and weapon tossing
- Manage the body queue (recycled corpse entities)
- Run `pmove` physics integration per client frame
- Patch broken coop spawn points on specific stock maps

## Key Types / Data Structures
None defined here; uses types from `g_local.h` and `m_player.h`.

| Name | Kind | Purpose |
|---|---|---|
| `pmove_t` | struct (external) | Player movement state passed to `gi.Pmove` |
| `client_persistant_t` | struct (external) | Data surviving death/level changes |
| `client_respawn_t` | struct (external) | Per-respawn transient state |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `pm_passent` | `edict_t *` | global | Passed to `PM_trace` as the entity to ignore during player movement traces |

## Key Functions

### PutClientInServer
- **Signature:** `void PutClientInServer(edict_t *ent)`
- **Purpose:** Core spawn routine — resets client/entity state and places the player at a spawn point.
- **Inputs:** Player edict
- **Outputs/Return:** None
- **Side effects:** Modifies `ent`, `client->pers`, `client->resp`, `client->ps`; calls `gi.linkentity`
- **Calls:** `SelectSpawnPoint`, `InitClientPersistant`, `ClientUserinfoChanged`, `FetchClientEntData`, `KillBox`, `ChangeWeapon`, `gi.linkentity`, `gi.modelindex`
- **Notes:** Handles deathmatch (wipe + reinit), coop (restore from `coop_respawn`), and singleplayer separately. Spectators are set `MOVETYPE_NOCLIP`/`SOLID_NOT`.

### ClientThink
- **Signature:** `void ClientThink(edict_t *ent, usercmd_t *ucmd)`
- **Purpose:** Per-client-frame tick: runs `pmove`, processes buttons, fires weapons, updates chase cam.
- **Inputs:** Player edict, user command from network
- **Outputs/Return:** None
- **Side effects:** Updates `ent->s.origin`, `ent->velocity`, `client->ps`, triggers touch callbacks, may set `level.exitintermission`
- **Calls:** `gi.Pmove`, `PM_trace`, `G_TouchTriggers`, `Think_Weapon`, `PlayerNoise`, `GetChaseTarget`, `ChaseNext`, `UpdateChaseCam`, `gi.linkentity`, `gi.sound`
- **Notes:** Skips movement for spectators following a chase target. Dead players get fixed view angles toward `killer_yaw`.

### ClientBeginServerFrame
- **Signature:** `void ClientBeginServerFrame(edict_t *ent)`
- **Purpose:** Called once per server frame before other entities; handles respawn input, weapon ticking, spectator transitions, and player trail.
- **Inputs:** Player edict
- **Outputs/Return:** None
- **Side effects:** May call `respawn` or `spectator_respawn`; calls `Think_Weapon`; appends to player trail
- **Calls:** `spectator_respawn`, `Think_Weapon`, `respawn`, `visible`, `PlayerTrail_LastSpot`, `PlayerTrail_Add`

### player_die
- **Signature:** `void player_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- **Purpose:** Handles player death: sets dead state, triggers gib or death animation, clears inventory and powerups.
- **Inputs:** Dying player, inflictor, attacker, damage amount, hit point
- **Calls:** `LookAtKiller`, `ClientObituary`, `TossClientWeapon`, `Cmd_Help_f`, `ThrowGib`, `ThrowClientHead`, `gi.sound`, `gi.linkentity`
- **Notes:** Gib threshold is health < −40. Rotates through 3 death animations via a `static int i`.

### ClientConnect
- **Signature:** `qboolean ClientConnect(edict_t *ent, char *userinfo)`
- **Purpose:** Gate function called when a client attempts to join; enforces IP ban, password, and spectator limits.
- **Inputs:** Player edict, userinfo string
- **Outputs/Return:** `true` if allowed, `false` with `rejmsg` set if rejected
- **Calls:** `SV_FilterPacket`, `Info_ValueForKey`, `Info_SetValueForKey`, `InitClientResp`, `InitClientPersistant`, `ClientUserinfoChanged`

### SelectSpawnPoint
- **Signature:** `void SelectSpawnPoint(edict_t *ent, vec3_t origin, vec3_t angles)`
- **Purpose:** Determines the best spawn location depending on game mode.
- **Calls:** `SelectDeathmatchSpawnPoint`, `SelectCoopSpawnPoint`, `G_Find`, `gi.error`

### ClientObituary
- **Signature:** `void ClientObituary(edict_t *self, edict_t *inflictor, edict_t *attacker)`
- **Purpose:** Prints kill/death message and updates DM scores based on `meansOfDeath`.
- **Calls:** `gi.bprintf`, `IsFemale`, `IsNeutral`
- **Notes:** Uses gender-aware pronoun selection for self-kills.

### CopyToBodyQue
- **Signature:** `void CopyToBodyQue(edict_t *ent)`
- **Purpose:** Transfers a dying player's visual state to a recycled body entity in the queue.
- **Side effects:** Modifies pre-allocated body edicts; calls `gi.unlinkentity`/`gi.linkentity`

### PM_trace
- **Signature:** `trace_t PM_trace(vec3_t start, vec3_t mins, vec3_t maxs, vec3_t end)`
- **Purpose:** Trace callback passed to `pmove`; selects `MASK_PLAYERSOLID` or `MASK_DEADSOLID` based on health.
- **Notes:** Uses global `pm_passent` as the ignored entity.

## Control Flow Notes
- **Init:** `ClientConnect` → `ClientBegin` → `PutClientInServer`
- **Per-frame:** `ClientBeginServerFrame` (server tick, once), `ClientThink` (client tick, multiple per server frame)
- **Death:** `player_die` → `LookAtKiller` + `ClientObituary` + `TossClientWeapon`; respawn triggered in `ClientBeginServerFrame` on button press
- **Disconnect:** `ClientDisconnect` clears entity and configstring

## External Dependencies
- `g_local.h`, `m_player.h` — game-local types, frame constants (`FRAME_death*`, `FRAME_crdeath*`)
- External symbols: `G_Find`, `G_Spawn`, `G_FreeEdict`, `G_InitEdict`, `KillBox`, `Drop_Item`, `FindItem`, `FindItemByClassname`, `ThrowGib`, `ThrowClientHead`, `ChangeWeapon`, `Think_Weapon`, `PlayerNoise`, `PlayerTrail_*`, `GetChaseTarget`, `ChaseNext`, `UpdateChaseCam`, `ClientEndServerFrame`, `MoveClientToIntermission`, `Cmd_Help_f`, `SV_FilterPacket`, `gi.*` (engine interface), `meansOfDeath` (global from `g_combat.c`), `itemlist`, `g_edicts`, `game`, `level`
