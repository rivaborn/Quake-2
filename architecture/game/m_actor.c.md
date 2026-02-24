# game/m_actor.c

## File Purpose
Implements the `misc_actor` entity — a scripted NPC that uses the player model and follows a chain of `target_actor` waypoints. Also defines the `target_actor` waypoint entity, which drives actor movement, speech, jumping, and combat behavior.

## Core Responsibilities
- Define all animation frame sequences for the actor (stand, walk, run, pain, attack, death, flipoff, taunt)
- Handle actor AI callbacks: pain response, attack firing, death/gib logic
- Spawn and initialize `misc_actor` entities with full monster AI wiring
- Spawn and initialize `target_actor` waypoint entities with trigger volumes
- Route actors along a target chain via `target_actor_touch` waypoint logic
- Allow actors to taunt/flip off players who damage them and broadcast chat messages

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `mframe_t` | struct (external) | Per-frame AI function + move distance + optional callback |
| `mmove_t` | struct (external) | Animation sequence: first/last frame, frame array, end callback |
| `edict_t` | struct (external) | General entity; used for actor, waypoint, player references |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `actor_names[MAX_ACTOR_NAMES]` | `char *[8]` | static (file) | Fixed name pool indexed by entity slot mod 8 for chat messages |
| `messages[]` | `char *[]` | static (file) | Taunt/pain response strings broadcast when actor is hurt by a player |
| `actor_frames_*` / `actor_move_*` | `mframe_t[]` / `mmove_t` | static (file) | All animation sequences (stand, walk, run, pain1–3, flipoff, taunt, attack, death1–2) |

## Key Functions

### actor_stand
- **Signature:** `void actor_stand(edict_t *self)`
- **Purpose:** Sets idle stand animation; randomizes start frame during level load to desynchronize actors.
- **Inputs:** `self` — the actor entity
- **Outputs/Return:** void
- **Side effects:** Modifies `self->monsterinfo.currentmove`, `self->s.frame`
- **Calls:** none
- **Notes:** Frame randomization only fires when `level.time < 1.0`.

### actor_run
- **Signature:** `void actor_run(edict_t *self)`
- **Purpose:** Selects run/walk/stand animation based on pain debounce state, move target, and AI flags.
- **Inputs:** `self`
- **Outputs/Return:** void
- **Side effects:** Delegates to `actor_walk` or `actor_stand`; sets `currentmove`
- **Calls:** `actor_walk`, `actor_stand`
- **Notes:** Respects `AI_STAND_GROUND` flag; pain debounce suppresses run if no enemy.

### actor_pain
- **Signature:** `void actor_pain(edict_t *self, edict_t *other, float kick, int damage)`
- **Purpose:** Responds to damage: switches skin at half health, randomly triggers taunt/flipoff sequence toward attacker, broadcasts a named chat message, or plays a pain animation.
- **Inputs:** `self` — actor; `other` — attacker
- **Outputs/Return:** void
- **Side effects:** Modifies `currentmove`, `ideal_yaw`, `s.skinnum`, `pain_debounce_time`; calls `gi.cprintf`
- **Calls:** `vectoyaw`, `gi.cprintf`, `VectorSubtract`
- **Notes:** Chat taunts only fire if attacker is a client (`other->client`) and `random() < 0.4`. Name is derived from entity index mod `MAX_ACTOR_NAMES`.

### actorMachineGun
- **Signature:** `void actorMachineGun(edict_t *self)`
- **Purpose:** Fires a single machine gun bullet from the actor's muzzle flash offset toward the enemy (with velocity lead), or straight ahead if no enemy.
- **Inputs:** `self`
- **Outputs/Return:** void
- **Side effects:** Spawns a bullet projectile via `monster_fire_bullet`
- **Calls:** `AngleVectors`, `G_ProjectSource`, `VectorMA`, `VectorCopy`, `VectorSubtract`, `VectorNormalize`, `monster_fire_bullet`
- **Notes:** Targets enemy's predicted future position (`-0.2 * velocity`). Falls back to `absmin + size[2]/2` if enemy is dead.

### actor_attack
- **Signature:** `void actor_attack(edict_t *self)`
- **Purpose:** Initiates attack animation and sets a random `pausetime` (10–17 frames) to control burst length.
- **Inputs:** `self`
- **Outputs/Return:** void
- **Side effects:** Sets `currentmove`, `monsterinfo.pausetime`
- **Calls:** none
- **Notes:** `actor_fire` checks `pausetime` each frame to toggle `AI_HOLD_FRAME`.

### actor_die
- **Signature:** `void actor_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- **Purpose:** Handles death: gibs if health ≤ -80, otherwise plays one of two death animations.
- **Inputs:** `self`, `inflictor`, `attacker`, `damage`, `point`
- **Outputs/Return:** void
- **Side effects:** Calls `ThrowGib`/`ThrowHead` for gibs; sets `deadflag`, `takedamage`, `currentmove`
- **Calls:** `ThrowGib`, `ThrowHead`
- **Notes:** Guard against double-death via `DEAD_DEAD` check.

### actor_use
- **Signature:** `void actor_use(edict_t *self, edict_t *other, edict_t *activator)`
- **Purpose:** Activates a dormant actor; resolves its first `target_actor` waypoint and starts walking.
- **Inputs:** `self`, `other`, `activator`
- **Outputs/Return:** void
- **Side effects:** Sets `goalentity`, `movetarget`, `ideal_yaw`, `s.angles`; calls `monsterinfo.walk`
- **Calls:** `G_PickTarget`, `VectorSubtract`, `vectoyaw`, `gi.dprintf`
- **Notes:** Errors and stops if target is missing or not a `target_actor`. Clears `self->target` after use.

### SP_misc_actor
- **Signature:** `void SP_misc_actor(edict_t *self)`
- **Purpose:** Spawns the actor entity: validates requirements, sets physics/model/bbox, wires all AI callbacks, calls `walkmonster_start`.
- **Inputs:** `self`
- **Outputs/Return:** void
- **Side effects:** Sets many `edict_t` fields; calls `gi.modelindex`, `gi.linkentity`, `walkmonster_start`
- **Calls:** `G_FreeEdict`, `gi.modelindex`, `gi.linkentity`, `walkmonster_start`
- **Notes:** Removed in deathmatch. Requires both `targetname` and `target`. Always starts dormant (`use = actor_use`). Sets `AI_GOOD_GUY` flag.

### target_actor_touch
- **Signature:** `void target_actor_touch(edict_t *self, edict_t *other, cplane_t *plane, csurface_t *surf)`
- **Purpose:** Waypoint logic triggered when actor walks into a `target_actor` volume; broadcasts messages, handles JUMP/ATTACK/SHOOT flags, advances to next waypoint.
- **Inputs:** `self` — waypoint; `other` — actor touching it
- **Outputs/Return:** void
- **Side effects:** Modifies `other->velocity`, `goalentity`, `movetarget`, `enemy`, `monsterinfo.aiflags`, `pausetime`; calls `gi.cprintf`, `gi.sound`, `G_UseTargets`
- **Calls:** `G_PickTarget`, `G_UseTargets`, `gi.cprintf`, `gi.sound`, `vectoyaw`, `actor_stand`, `actor_run`
- **Notes:** Ignores touch if `other->movetarget != self` or actor has an active enemy. SHOOT flag body is empty (unimplemented).

### SP_target_actor
- **Signature:** `void SP_target_actor(edict_t *self)`
- **Purpose:** Spawns a waypoint trigger volume; sets up JUMP direction/speed from spawn fields.
- **Inputs:** `self`
- **Outputs/Return:** void
- **Side effects:** Sets solid, touch, bbox, svflags; calls `G_SetMovedir`, `gi.linkentity`
- **Calls:** `G_SetMovedir`, `gi.linkentity`, `gi.dprintf`
- **Notes:** Uses `st.height` for vertical jump velocity. Missing `targetname` is warned but not fatal.

## Control Flow Notes
`SP_misc_actor` runs at map load (spawn phase). The actor idles until `actor_use` is triggered by another entity, launching it into `walkmonster_start`'s think loop. Each game frame the monster AI calls the appropriate `actor_run/walk/stand/attack` via `monsterinfo` function pointers. `target_actor_touch` fires when the actor's movement reaches a waypoint SOLID_TRIGGER volume.

## External Dependencies
- **Includes:** `g_local.h`, `m_actor.h`
- **Defined elsewhere:** `ai_stand`, `ai_walk`, `ai_run`, `ai_move`, `ai_turn`, `ai_charge` (AI primitives, `g_ai.c`); `monster_fire_bullet`, `G_ProjectSource`, `monster_flash_offset` (`g_monster.c`/`m_flash.c`); `ThrowGib`, `ThrowHead`, `G_PickTarget`, `G_UseTargets`, `G_SetMovedir`, `G_FreeEdict` (`g_utils.c`/`g_misc.c`); `walkmonster_start` (`g_monster.c`); `gi` (game import struct, engine-provided); `g_edicts`, `level`, `game`, `deathmatch` (globals, `g_main.c`)
