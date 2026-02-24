# ctf/g_ctf.h

## File Purpose
Public interface header for the Quake 2 CTF (Capture The Flag) game module. Declares all shared types, constants, and function prototypes used across the CTF game logic, exposing the full CTF subsystem API to other translation units.

## Core Responsibilities
- Define HUD stat slot indices for CTF-specific UI elements
- Declare team, grapple state, and ghost record types
- Define all CTF gameplay tuning constants (bonuses, timeouts, radii, speeds)
- Expose function prototypes for flag logic, grapple weapon, tech items, match/voting system, and chase cam

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `ctfteam_t` | enum | Team membership: `CTF_NOTEAM`, `CTF_TEAM1`, `CTF_TEAM2` |
| `ctfgrapplestate_t` | enum | Grapple hook FSM states: `FLY`, `PULL`, `HANG` |
| `ghost_t` | struct | Per-player disconnect record storing netname, stats (kills/deaths/caps/basedef/carrierdef), ghost code, team, score, and a back-pointer to `edict_t` for reconnect recovery |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `ctf` | `cvar_t *` | global (extern) | Master cvar enabling/disabling CTF mode |
| `ctf_statusbar` | `char *` | global (extern) | String defining the CTF HUD layout sent to clients |

## Key Functions

### CTFInit / CTFSpawn
- Signature: `void CTFInit(void)` / `void CTFSpawn(void)`
- Purpose: Module-level initialization and per-map spawn setup for CTF state
- Inputs: None
- Outputs/Return: None
- Side effects: Likely registers items, cvars, configstrings
- Calls: Not inferable from this file
- Notes: Called at different lifecycle points — init once, spawn per map load

### CTFFragBonuses
- Signature: `void CTFFragBonuses(edict_t *targ, edict_t *inflictor, edict_t *attacker)`
- Purpose: Awards contextual score bonuses (carrier frag, flag defense, proximity defense) on kill
- Inputs: Target, inflictor, attacker entities
- Outputs/Return: None
- Side effects: Modifies player scores

### CTFCheckRules
- Signature: `qboolean CTFCheckRules(void)`
- Purpose: Evaluates win/round-end conditions each frame
- Outputs/Return: `qtrue` if a rules-ending condition is met

### CTFPickup_Flag / CTFDrop_Flag / CTFDeadDropFlag / CTFResetFlag
- Signatures as declared
- Purpose: Full flag lifecycle — pickup, voluntary drop, death drop, and auto/forced reset
- Side effects: Modifies flag entity state, triggers score events, sends configstring updates

### CTFWeapon_Grapple / CTFGrapplePull / CTFResetGrapple / CTFPlayerResetGrapple
- Purpose: Grapple hook weapon — fire, in-flight pull tick, and cleanup on disconnect or death

### Tech item functions (`CTFPickup_Tech`, `CTFDrop_Tech`, `CTFApply*`, `CTFHasRegeneration`)
- Purpose: Manage one-of-a-kind tech powerups; apply per-frame effects (resistance, strength, haste, regeneration)
- Notes: `CTFApply*` functions return modified damage values or boolean state flags

### Match/voting functions (`CTFVoteYes`, `CTFVoteNo`, `CTFReady`, `CTFNotReady`, `CTFNextMap`, `CTFMatchSetup`, `CTFMatchOn`, `CTFInMatch`)
- Purpose: Cooperative match setup, ready/vote system, and match state queries

## Control Flow Notes
- `CTFInit` is called at engine startup; `CTFSpawn` at map load. Per-frame hooks include `CTFCheckRules`, `CTFEffects`, `CTFApplyRegeneration`, `CTFGrapplePull`, and `SetCTFStats`. Flag and tech events are triggered reactively by game logic (pickup, death, frag).

## External Dependencies
- Notable includes: Implicitly depends on `g_local.h` (defines `edict_t`, `gclient_t`, `gitem_t`, `cvar_t`, `qboolean`)
- External symbols used but not defined here: `edict_t`, `gclient_t`, `gitem_t`, `cvar_t`, `CS_MAXCLIENTS`, `qboolean`, all function bodies
