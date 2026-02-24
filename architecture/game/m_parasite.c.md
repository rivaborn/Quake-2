# game/m_parasite.c

## File Purpose
Implements the Parasite monster AI for Quake 2, a spider-like creature that attacks by launching a tongue/drain appendage to siphon health from the player. Covers all behavioral states: standing, walking, running, attacking, pain, death, and idle fidgeting.

## Core Responsibilities
- Define all animation frame sequences (stand, walk, run, drain attack, break, pain, death, fidget)
- Implement the drain attack with range/angle validation and health-siphoning logic
- Play contextual sounds for each action (launch, impact, suck, reel-in, sight, tap, scratch)
- Handle pain response including skin damage state and nightmare-mode suppression
- Handle death via normal death animation or gibbing
- Register the entity via `SP_monster_parasite` and configure all AI callbacks
- Manage fidget idle behavior with probabilistic looping

## Key Types / Data Structures
None (uses engine types from `g_local.h` and `m_parasite.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `sound_pain1` | `int` | static | Cached sound index for pain sound 1 |
| `sound_pain2` | `int` | static | Cached sound index for pain sound 2 |
| `sound_die` | `int` | static | Cached sound index for death sound |
| `sound_launch` | `int` | static | Sound when tongue is launched |
| `sound_impact` | `int` | static | Sound when tongue hits target |
| `sound_suck` | `int` | static | Sound during drain |
| `sound_reelin` | `int` | static | Sound when tongue retracts |
| `sound_sight` | `int` | static | Sound on enemy sighting |
| `sound_tap` | `int` | static | Idle tapping sound |
| `sound_scratch` | `int` | static | Idle scratching sound |
| `sound_search` | `int` | static | Search/alert sound |

## Key Functions

### SP_monster_parasite
- Signature: `void SP_monster_parasite(edict_t *self)`
- Purpose: Spawns and fully initializes the Parasite entity.
- Inputs: `self` — the entity being spawned
- Outputs/Return: void
- Side effects: Registers all sound indices, sets model/bbox/health/mass, assigns all AI callbacks, calls `walkmonster_start`
- Calls: `gi.soundindex`, `gi.modelindex`, `VectorSet`, `gi.linkentity`, `walkmonster_start`, `G_FreeEdict`
- Notes: Immediately frees entity if in deathmatch mode; parasite is single-player only.

### parasite_drain_attack
- Signature: `void parasite_drain_attack(edict_t *self)`
- Purpose: Core attack — fires a draining tongue beam toward the enemy, dealing 5 damage on initial hit (FRAME_drain03) and 2 per frame while draining.
- Inputs: `self` — attacking parasite
- Outputs/Return: void
- Side effects: Sends `TE_PARASITE_ATTACK` temp entity network event; calls `T_Damage` on enemy; plays impact/suck sounds
- Calls: `AngleVectors`, `G_ProjectSource`, `parasite_drain_attack_ok`, `gi.trace`, `gi.sound`, `gi.WriteByte`, `gi.WriteShort`, `gi.WritePosition`, `gi.multicast`, `T_Damage`
- Notes: Attempts three progressively adjusted vertical aim positions on the enemy; aborts entirely if none pass range/angle validation or if trace hits something other than the enemy.

### parasite_drain_attack_ok
- Signature: `static qboolean parasite_drain_attack_ok(vec3_t start, vec3_t end)`
- Purpose: Validates that a proposed drain attack is within 256 units and within ±30° pitch.
- Inputs: `start`, `end` — world positions
- Outputs/Return: `qboolean` — true if valid
- Side effects: None
- Calls: `VectorSubtract`, `VectorLength`, `vectoangles`, `fabs`
- Notes: Pitch wraps values below -180 by adding 360 before the absolute check.

### parasite_pain
- Signature: `void parasite_pain(edict_t *self, edict_t *other, float kick, int damage)`
- Purpose: Responds to damage: switches skin at half health, plays pain sound, triggers pain animation.
- Inputs: `self`, attacker `other`, `kick`, `damage`
- Outputs/Return: void
- Side effects: Modifies `self->s.skinnum`, `self->pain_debounce_time`, `self->monsterinfo.currentmove`; plays sound
- Calls: `gi.sound`, sets `currentmove`
- Notes: No pain animation in nightmare (`skill == 3`); 3-second debounce between pain reactions.

### parasite_die
- Signature: `void parasite_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- Purpose: Handles death — gibs at threshold or plays normal death animation.
- Inputs: Standard die callback parameters
- Outputs/Return: void
- Side effects: Spawns gib entities or sets death animation; sets `deadflag`
- Calls: `gi.sound`, `ThrowGib`, `ThrowHead`, sets `currentmove`
- Notes: Guard against double-death via `DEAD_DEAD` check.

### parasite_dead
- Signature: `void parasite_dead(edict_t *self)`
- Purpose: Post-death callback — collapses bbox, enables toss physics, marks as dead monster.
- Inputs: `self`
- Side effects: Modifies `mins`, `maxs`, `movetype`, `svflags`, `nextthink`; calls `gi.linkentity`

### parasite_idle / parasite_refidget / parasite_do_fidget / parasite_end_fidget
- Trivial state-transition helpers directing `currentmove` into the fidget sub-sequence chain. `parasite_refidget` loops fidget with 80% probability or exits.

## Control Flow Notes
- **Init**: `SP_monster_parasite` → `walkmonster_start`
- **Frame**: AI callbacks (`ai_stand`, `ai_run`, `ai_walk`, `ai_charge`) are called per-frame by the monster think system via `currentmove`
- **Attack**: `parasite_attack` always selects `parasite_move_drain`; the `break` move exists but is commented out
- **Idle**: `parasite_idle` → `parasite_move_start_fidget` → `parasite_do_fidget` → looping fidget with probabilistic exit back to stand

## External Dependencies
- `g_local.h` — entity types, game API (`gi`), damage/gib functions
- `m_parasite.h` — `FRAME_*` constants, `MODEL_SCALE`
- Defined elsewhere: `ai_stand`, `ai_run`, `ai_walk`, `ai_charge`, `ai_move`, `G_ProjectSource`, `T_Damage`, `ThrowGib`, `ThrowHead`, `walkmonster_start`, `vectoangles`, `VectorLength`, `level`, `skill`, `g_edicts`
