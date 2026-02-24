# game/p_view.c

## File Purpose
Computes all per-player view-state updates at the end of each server frame, including camera offsets, gun offsets, screen blends, bob/roll calculations, falling damage, world environmental effects, and player animation state.

## Core Responsibilities
- Calculate view bob, roll, and kick angles each frame
- Apply damage feedback (screen blend, view kick, pain animation/sound)
- Compute view and gun positional/angular offsets
- Determine screen color blend from environment, powerups, and damage
- Handle falling damage and fall-camera kick
- Process world environmental effects (drowning, lava, slime, water entry/exit)
- Set per-frame client effects, sounds, events, and animation frames
- Serve as the terminal per-player update pipeline via `ClientEndServerFrame`

## Key Types / Data Structures
None (operates on existing `edict_t` and `gclient_t` from `g_local.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `current_player` | `edict_t *` | static | Player entity being processed this frame |
| `current_client` | `gclient_t *` | static | Client record for `current_player` |
| `forward`, `right`, `up` | `vec3_t` | static | Basis vectors from player view angle; shared across all functions |
| `xyspeed` | `float` | global | Horizontal speed magnitude; used by bob and animation logic |
| `bobmove` | `float` | global | Bob cycle increment this frame |
| `bobcycle` | `int` | global | Integer bob cycle counter (odd = right foot forward) |
| `bobfracsin` | `float` | global | `sin(bobfrac * PI)`; drives view/gun sway amplitude |

## Key Functions

### ClientEndServerFrame
- Signature: `void ClientEndServerFrame(edict_t *ent)`
- Purpose: Master per-player end-of-frame update; orchestrates all view, effect, and animation subsystems.
- Inputs: `ent` — the player entity.
- Outputs/Return: void; mutates `ent->client->ps`, `ent->s`, and all client state fields.
- Side effects: Sets `current_player`/`current_client` globals; calls `AngleVectors` to populate `forward/right/up`; triggers sound, stats, unicast.
- Calls: `P_WorldEffects`, `P_FallingDamage`, `P_DamageFeedback`, `SV_CalcViewOffset`, `SV_CalcGunOffset`, `SV_CalcBlend`, `G_SetStats`, `G_SetSpectatorStats`, `G_CheckChaseStats`, `G_SetClientEvent`, `G_SetClientEffects`, `G_SetClientSound`, `G_SetClientFrame`, `DeathmatchScoreboardMessage`, `gi.unicast`.
- Notes: Short-circuits to only update stats during intermission. Syncs `pmove.origin/velocity` from entity state to account for server-pushed movement.

### P_DamageFeedback
- Signature: `void P_DamageFeedback(edict_t *player)`
- Purpose: Converts accumulated frame damage into screen blend color/alpha, view-angle kick, pain animation, and pain sound.
- Inputs: `player` — entity with damage accumulators (`damage_blood`, `damage_armor`, `damage_parmor`, `damage_knockback`).
- Outputs/Return: void; writes `ps.stats[STAT_FLASHES]`, `damage_blend`, `damage_alpha`, `v_dmg_roll/pitch/time`, `anim_priority/end`, `s.frame`.
- Side effects: `gi.sound` for pain; clears all damage accumulators.
- Calls: `gi.sound`, `gi.soundindex`, `va`, `VectorSubtract`, `VectorNormalize`, `DotProduct`, `VectorMA`, `VectorCopy`, `VectorClear`.
- Notes: Blend color is weighted average across blood (red), armor (white), power armor (green). Depends on `forward`/`right` being set prior by `ClientEndServerFrame`.

### SV_CalcViewOffset
- Signature: `void SV_CalcViewOffset(edict_t *ent)`
- Purpose: Builds `ps.kick_angles` and `ps.viewoffset` from weapon kick, damage kick, fall kick, velocity, and bob.
- Inputs: `ent`; reads global `bobfracsin`, `bobcycle`, `xyspeed`.
- Outputs/Return: void; writes `ps.kick_angles`, `ps.viewangles` (dead case), `ps.viewoffset`.
- Side effects: None beyond entity state mutation.
- Notes: View offset is hard-clamped to ±14 XY, −22/+30 Z to keep camera inside player bbox.

### SV_CalcGunOffset
- Signature: `void SV_CalcGunOffset(edict_t *ent)`
- Purpose: Computes `ps.gunangles` and `ps.gunoffset` from bob sway, view-angle delta, and `gun_x/y/z` cvars.
- Inputs: `ent`; reads `forward/right/up` globals.
- Outputs/Return: void; writes `ps.gunangles`, `ps.gunoffset`.

### SV_CalcBlend
- Signature: `void SV_CalcBlend(edict_t *ent)`
- Purpose: Accumulates full-screen color blend from water/lava/slime contents, active powerups (quad, invincible, enviro, breather), damage, and pickup bonus.
- Inputs: `ent`.
- Outputs/Return: void; writes `ps.blend[4]`, `ps.rdflags` (`RDF_UNDERWATER`); decays `damage_alpha` and `bonus_alpha`.
- Side effects: `gi.sound` for powerup expiry warnings at 30 frames remaining; `gi.pointcontents`.
- Notes: Uses alpha-compositing via `SV_AddBlend`.

### P_WorldEffects
- Signature: `void P_WorldEffects(void)`
- Purpose: Handles water entry/exit sounds, drowning damage, breather/envirosuit air management, and lava/slime sizzle damage.
- Inputs: Reads `current_player`/`current_client` globals.
- Outputs/Return: void; mutates `air_finished`, `dmg`, `watertype` flags, `FL_INWATER`.
- Side effects: `gi.sound`, `T_Damage`, `PlayerNoise`.
- Notes: Drowning damage ramps from 2 to 15 HP/sec; envirosuit reduces lava to 1/3 damage.

### P_FallingDamage
- Signature: `void P_FallingDamage(edict_t *ent)`
- Purpose: Detects landing impacts, applies fall damage, sets fall camera kick and footstep/fall events.
- Inputs: `ent`; compares `velocity[2]` vs `oldvelocity[2]`.
- Outputs/Return: void; sets `s.event`, `fall_value`, `fall_time`; calls `T_Damage`.
- Notes: Water depth attenuates delta by 0.25–0.5; fully submerged (level 3) is immune. Skipped in noclip or non-player models.

### G_SetClientFrame
- Signature: `void G_SetClientFrame(edict_t *ent)`
- Purpose: Advances or transitions player animation frames based on ground state, duck, run, and `anim_priority`.
- Notes: Uses `goto newanim` for transition logic; supports `ANIM_REVERSE` playback direction.

### SV_CalcRoll
- Signature: `float SV_CalcRoll(vec3_t angles, vec3_t velocity)`
- Purpose: Computes lateral roll based on sideways velocity component vs `sv_rollspeed` and `sv_rollangle` cvars.

- **Notes — trivial helpers:** `SV_AddBlend` performs alpha-over compositing. `G_SetClientEffects` sets `s.effects`/`s.renderfx` flags for powerups and godmode. `G_SetClientEvent` emits `EV_FOOTSTEP` on bob cycle transitions. `G_SetClientSound` selects looping ambient sound (railgun hum, BFG hum, fry, etc.).

## Control Flow Notes
`ClientEndServerFrame` is called once per player per server frame (from `p_client.c` or equivalent). It establishes the globals `current_player`, `current_client`, `forward/right/up`, `xyspeed`, and all bob variables, then sequentially invokes the view, blend, and animation subsystems. `P_WorldEffects` relies on those globals instead of taking parameters, tightly coupling it to this call order.

## External Dependencies
- **Includes:** `g_local.h`, `m_player.h` (animation frame constants)
- **Defined elsewhere:** `gi` (game import interface), `T_Damage`, `PlayerNoise`, `G_SetStats`, `G_SetSpectatorStats`, `G_CheckChaseStats`, `DeathmatchScoreboardMessage`, `PowerArmorType`, `AngleVectors`, `sv_rollangle`, `sv_rollspeed`, `run_pitch`, `run_roll`, `bob_pitch`, `bob_roll`, `bob_up`, `gun_x/y/z`, `deathmatch`, `dmflags`, `snd_fry`, `level`, `world`
