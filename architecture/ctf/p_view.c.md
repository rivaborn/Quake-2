# ctf/p_view.c

## File Purpose
Handles per-frame player view computation for the CTF game module, including view angles, bob, roll, blend effects, falling damage, world environmental effects, and client-side state finalization at end of server frame.

## Core Responsibilities
- Compute view angle kick from damage, fall impact, velocity, and bob
- Compute gun offset and angles from bob and view delta
- Calculate full-screen color blend from environment, powerups, and damage
- Apply environmental hazard damage (drowning, lava, slime)
- Detect and apply falling damage (with CTF grapple immunity)
- Drive player animation state machine (stand/walk/duck/jump/pain/death)
- Finalize per-client `player_state_t` fields at end of server frame
- Propagate stats to chase-cam followers (CTF-specific)

## Key Types / Data Structures
None (operates on `edict_t` and `gclient_t` defined in `g_local.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `current_player` | `edict_t *` | static | Player entity being processed this frame |
| `current_client` | `gclient_t *` | static | Shorthand for `current_player->client` |
| `forward`, `right`, `up` | `vec3_t` | static | Player orientation basis vectors, set once per frame |
| `xyspeed` | `float` | global | Horizontal speed magnitude, shared with event/frame setters |
| `bobmove` | `float` | global | Bob cycle increment per frame |
| `bobcycle` | `int` | global | Integer bob cycle index; odd = right foot forward |
| `bobfracsin` | `float` | global | `sin(bobfrac * PI)`, drives bob amplitude |

## Key Functions

### ClientEndServerFrame
- Signature: `void ClientEndServerFrame(edict_t *ent)`
- Purpose: Master per-frame finalizer; sets module globals, then calls all sub-systems in order.
- Inputs: `ent` — the player entity.
- Outputs/Return: void; mutates `ent->client->ps`, `ent->s`, and module-level globals.
- Side effects: Sets `current_player`/`current_client`; writes pmove origin/velocity from entity state; calls `gi.unicast` for scoreboard; copies stats to chase followers.
- Calls: `P_WorldEffects`, `P_FallingDamage`, `P_DamageFeedback`, `SV_CalcViewOffset`, `SV_CalcGunOffset`, `SV_CalcBlend`, `G_SetStats`, `G_SetClientEvent`, `G_SetClientEffects`, `G_SetClientSound`, `G_SetClientFrame`, `PMenu_Do_Update`, `DeathmatchScoreboardMessage`, `AngleVectors`.
- Notes: Must run after `ClientThink`; pmove origin/velocity re-sync corrects "sinking into plats" lag.

### P_DamageFeedback
- Signature: `void P_DamageFeedback(edict_t *player)`
- Purpose: Converts accumulated frame damage into blend color, view kick, pain sound, and pain animation.
- Inputs: `player` — damaged entity; reads `damage_blood/armor/parmor/knockback` from client.
- Outputs/Return: void; writes `ps.stats[STAT_FLASHES]`, `damage_blend`, `damage_alpha`, `v_dmg_roll/pitch/time`, clears damage accumulators.
- Side effects: `gi.sound` for pain; sets `player->s.frame` and `client->anim_*` for pain animation.
- Calls: `VectorMA`, `VectorNormalize`, `VectorSubtract`, `DotProduct`, `gi.sound`, `gi.soundindex`, `va`.

### SV_CalcViewOffset
- Signature: `void SV_CalcViewOffset(edict_t *ent)`
- Purpose: Builds `ps.kick_angles` and `ps.viewoffset` from weapon kick, damage kick, fall, velocity, and bob.
- Inputs: `ent`; reads module globals `bobfracsin`, `bobcycle`, `xyspeed`, `forward`, `right`.
- Outputs/Return: void; writes `ps.kick_angles`, `ps.viewoffset`.
- Side effects: Clears damage kick state when ratio expires. Hard-clamps offset to ±14/±22/+30.
- Notes: Dead players get fixed angles facing killer yaw.

### SV_CalcBlend
- Signature: `void SV_CalcBlend(edict_t *ent)`
- Purpose: Composites all full-screen blend layers (liquid, powerups, damage, bonus) into `ps.blend`.
- Inputs: `ent`; queries `gi.pointcontents` at view origin.
- Side effects: `gi.sound` for powerup expiry warnings at 30 frames remaining; decays `damage_alpha` and `bonus_alpha`.
- Calls: `SV_AddBlend`, `gi.pointcontents`, `gi.sound`, `gi.soundindex`, `VectorAdd`.

### P_FallingDamage
- Signature: `void P_FallingDamage(edict_t *ent)`
- Purpose: Detects landing impact, sets fall camera kick, and applies falling damage.
- Inputs: `ent`; reads `oldvelocity`, `groundentity`, `waterlevel`.
- Side effects: Sets `ent->s.event` (footstep/fall/fallfar/fallshort), `fall_value/time`; calls `T_Damage`.
- Notes: CTF addition — skips damage within 2 frames of grapple release or while grappling above FLY state.

### P_WorldEffects
- Signature: `void P_WorldEffects(void)`
- Purpose: Handles water entry/exit sounds, drowning, lava/slime damage using `current_player`/`current_client`.
- Side effects: `T_Damage`, `gi.sound`, `PlayerNoise`; modifies `air_finished`, `dmg`, `flags`.

### G_SetClientFrame
- Signature: `void G_SetClientFrame(edict_t *ent)`
- Purpose: Advances or resets player animation frame based on duck/run/ground state.
- Notes: CTF modification — player on grapple skips jump frame and uses standing loop instead.

## Control Flow Notes
`ClientEndServerFrame` is the single entry point called by the server loop at frame end for each connected player. It initializes module globals once, then pipelines: world effects → falling damage → damage feedback → view offset → gun offset → blend → stats → events → effects → sound → frame animation.

## External Dependencies
- `g_local.h` — `edict_t`, `gclient_t`, all game cvars and constants
- `m_player.h` — player animation frame constants (`FRAME_*`, `ANIM_*`)
- External symbols: `sv_rollangle`, `sv_rollspeed`, `run_pitch`, `run_roll`, `bob_pitch`, `bob_roll`, `bob_up`, `gun_x/y/z`, `deathmatch`, `dmflags`, `maxclients` (cvars); `T_Damage`, `PlayerNoise`, `PowerArmorType`, `CTFEffects`, `G_SetStats`, `DeathmatchScoreboardMessage`, `PMenu_Do_Update` (game functions); `gi` (engine import struct); `world`, `g_edicts`, `level`, `game` (global state).
