# game/m_berserk.c

## File Purpose
Implements the Berserk monster — a melee-only humanoid enemy that charges and strikes players with spike and club attacks. It defines all animation frame sequences, AI callbacks, and the spawn function used to instantiate the entity in-world.

## Core Responsibilities
- Define all animation sequences (stand, fidget, walk, run, melee attacks, pain, death)
- Handle melee combat logic with two attack variants (spike and club)
- Respond to pain events with debounced, skill-aware reactions
- Handle death with gibbing threshold and two death animations
- Pre-cache all required sounds and models at spawn time
- Register AI callbacks (stand, walk, run, melee, sight, search) into `monsterinfo`

## Key Types / Data Structures
None (all types defined in `g_local.h` / `m_berserk.h`).

| Name | Kind | Purpose |
|------|------|---------|
| `mframe_t` | struct | Single animation frame: AI move function, distance, optional callback |
| `mmove_t` | struct | Animation sequence: frame range, frame array, end callback |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `sound_pain` | `int` | static | Cached sound index for pain vocalisation |
| `sound_die` | `int` | static | Cached sound index for death vocalisation |
| `sound_idle` | `int` | static | Cached sound index for idle fidget |
| `sound_punch` | `int` | static | Cached sound index for swing/attack |
| `sound_sight` | `int` | static | Cached sound index for sight alert |
| `sound_search` | `int` | static | Cached sound index for search alert |

## Key Functions

### SP_monster_berserk
- Signature: `void SP_monster_berserk (edict_t *self)`
- Purpose: Entity spawn function; initialises all Berserk state and registers it with the game world.
- Inputs: `self` — the entity being spawned
- Outputs/Return: `void`
- Side effects: Pre-caches sounds/model via `gi.soundindex`/`gi.modelindex`; sets bbox, health, mass, callbacks; calls `gi.linkentity` and `walkmonster_start`
- Calls: `G_FreeEdict`, `gi.soundindex`, `gi.modelindex`, `gi.linkentity`, `walkmonster_start`
- Notes: Immediately frees entity in deathmatch mode. Initial move set to `berserk_move_stand`.

### berserk_melee
- Signature: `void berserk_melee (edict_t *self)`
- Purpose: Randomly selects between spike (faster, less damage) and club (slower, variable damage) attack sequences.
- Inputs: `self`
- Outputs/Return: `void`
- Side effects: Sets `monsterinfo.currentmove`
- Calls: `rand()`
- Notes: 50/50 probability split. Both sequences return to `berserk_run` on completion.

### berserk_attack_spike
- Signature: `void berserk_attack_spike (edict_t *self)`
- Purpose: Delivers a fast upward/backward melee hit at short range.
- Inputs: `self`
- Outputs/Return: `void`
- Side effects: Calls `fire_hit` which may damage a target entity
- Calls: `fire_hit`, `rand()`
- Notes: Aim vector is static `{MELEE_DISTANCE, 0, -24}`; damage 15–20, knockback 400.

### berserk_attack_club
- Signature: `void berserk_attack_club (edict_t *self)`
- Purpose: Delivers a slower club swing using the entity's own mins for lateral aim.
- Inputs: `self`
- Outputs/Return: `void`
- Side effects: Calls `fire_hit`
- Calls: `fire_hit`, `rand()`, `VectorSet`
- Notes: Damage 5–10, knockback 400. Aim uses `self->mins[0]` for lateral offset.

### berserk_pain
- Signature: `void berserk_pain (edict_t *self, edict_t *other, float kick, int damage)`
- Purpose: Handles incoming damage: updates skin to wounded state at half health, triggers pain animation.
- Inputs: `self`, `other` (attacker), `kick`, `damage`
- Outputs/Return: `void`
- Side effects: Mutates `self->s.skinnum`, `self->pain_debounce_time`, `self->monsterinfo.currentmove`; plays sound
- Calls: `gi.sound`, `random()`
- Notes: 3-second debounce. No pain animation in skill 3 (nightmare). Uses short `pain1` if damage < 20 or random roll < 0.5.

### berserk_die
- Signature: `void berserk_die (edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- Purpose: Handles death; gibs at low health, otherwise plays one of two death animations.
- Inputs: `self`, `inflictor`, `attacker`, `damage`, `point`
- Outputs/Return: `void`
- Side effects: Spawns gibs via `ThrowGib`/`ThrowHead`; sets `deadflag`, `takedamage`; selects death animation
- Calls: `gi.sound`, `gi.soundindex`, `ThrowGib`, `ThrowHead`
- Notes: Gib threshold is `gib_health` (-60). Guard against double-death with `DEAD_DEAD` check. High-damage deaths (≥ 50) use the longer `death1` sequence.

### berserk_fidget
- Signature: `void berserk_fidget (edict_t *self)`
- Purpose: Randomly triggers a stand-fidget animation when idle.
- Inputs: `self`
- Outputs/Return: `void`
- Side effects: May set `currentmove` and play idle sound
- Notes: Suppressed when `AI_STAND_GROUND` flag is set; 85% chance to skip per frame call.

### berserk_dead
- Signature: `void berserk_dead (edict_t *self)`
- Purpose: End-of-death-animation callback; finalises corpse bbox and physics.
- Inputs: `self`
- Side effects: Shrinks bbox, sets `MOVETYPE_TOSS`, sets `SVF_DEADMONSTER`, clears `nextthink`, relinks entity.
- Notes: Called as the terminal callback of both death `mmove_t` sequences.

## Control Flow Notes
- Spawned via `SP_monster_berserk` → `walkmonster_start`, entering the stand state.
- Per-frame AI is driven by `monsterinfo.currentmove`; each `mframe_t` invokes `ai_stand`/`ai_walk`/`ai_run`/`ai_charge`/`ai_move` as appropriate.
- `berserk_melee` is the sole attack entry point (no ranged attack; `monsterinfo.attack = NULL`).
- Pain and death transitions override `currentmove`; death sequences terminate in `berserk_dead`.

## External Dependencies
- `g_local.h` — core game types, entity fields, AI functions (`ai_stand`, `ai_run`, etc.), `fire_hit`, `ThrowGib`, `ThrowHead`, `walkmonster_start`
- `m_berserk.h` — frame index constants (`FRAME_*`) and `MODEL_SCALE`
- `gi` (game import) — `sound`, `soundindex`, `modelindex`, `linkentity` — defined in engine, accessed via import table
- `level`, `skill`, `deathmatch` — global game state; defined in `g_main.c` / `g_local.h`
