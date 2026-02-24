# game/m_insane.c

## File Purpose
Implements the "insane" civilian NPC (`misc_insane`), a non-combat ambient character found in single-player maps. It supports multiple behavioral modes (standing, crawling, crucified, wandering) driven by spawnflags, and plays pain/death animations but never attacks.

## Core Responsibilities
- Registers and plays voice sounds (fist, shake, moan, screams) as animation callbacks
- Defines all animation frame sequences and transitions for standing, walking, crawling, crucified, and pain/death states
- Implements state-machine callbacks (`insane_stand`, `insane_walk`, `insane_run`) that select moves based on spawnflags and random chance
- Handles pain response with debounce, skill-level gating, and frame-context detection
- Handles death: gibbing, crucified fly-flag, crawl-vs-stand death selection
- Spawns the entity via `SP_misc_insane`, configuring physics, sounds, AI flags, and start conditions

## Key Types / Data Structures
None (uses engine types only).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `sound_fist` | `int` | static | Cached sound index for fist-slam sound |
| `sound_shake` | `int` | static | Cached sound index for shaking sound |
| `sound_moan` | `int` | static | Cached sound index for moaning sound |
| `sound_scream[8]` | `int[8]` | static | Cached sound indices for 8 scream variants |

## Key Functions

### SP_misc_insane
- Signature: `void SP_misc_insane(edict_t *self)`
- Purpose: Entity spawn entry point; initializes all state for the insane NPC.
- Inputs: `self` — the entity being spawned.
- Outputs/Return: void
- Side effects: Loads sound/model indices via `gi`, sets bbox, health, mass, callbacks, AI flags, links entity, starts walk or fly monster loop.
- Calls: `G_FreeEdict`, `gi.soundindex`, `gi.modelindex`, `gi.linkentity`, `flymonster_start`, `walkmonster_start`
- Notes: Removed in deathmatch. Crucified variant uses `flymonster_start` with a narrower bbox and `FL_NO_KNOCKBACK`. Random skin (0–2) assigned for non-crucified. `AI_GOOD_GUY` prevents other monsters from targeting it.

### insane_stand
- Signature: `void insane_stand(edict_t *self)`
- Purpose: Selects the idle standing animation based on spawnflags and random chance.
- Inputs: `self`
- Outputs/Return: void
- Side effects: Sets `monsterinfo.currentmove`; may set `AI_STAND_GROUND` for crucified.
- Calls: none (sets move pointers)
- Notes: Crucified → cross cycle. Hold_Ground+Crawl → `insane_move_down`. Otherwise 50/50 normal vs. insane stand.

### insane_walk / insane_run
- Signature: `void insane_walk(edict_t *self)` / `void insane_run(edict_t *self)`
- Purpose: Select locomotion animation; walk and run use identical logic but different terminal move callbacks.
- Side effects: Sets `monsterinfo.currentmove`.
- Notes: Spawnflag 16 (Hold Ground) forces `insane_move_down` if transitioning from crawl pain. Spawnflag 4 (Crawl) forces crawl moves. Otherwise 50/50 normal vs. insane walk.

### insane_pain
- Signature: `void insane_pain(edict_t *self, edict_t *other, float kick, int damage)`
- Purpose: Pain response — plays sound, selects pain animation by current posture.
- Side effects: Updates `pain_debounce_time`, plays sound via `gi.sound`/`gi.soundindex`, sets `currentmove`.
- Calls: `gi.sound`, `gi.soundindex`, `va`
- Notes: Debounced (3 s). No animation on Nightmare (skill 3). Crucified → struggle cross instead. Detects crawl/ground posture by frame range to pick correct pain sequence.

### insane_die
- Signature: `void insane_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- Purpose: Death handler; gibs on extreme damage, otherwise plays context-appropriate death animation.
- Side effects: Throws gibs, plays sounds, sets `deadflag`, calls `insane_dead` or sets `currentmove`.
- Calls: `gi.sound`, `gi.soundindex`, `ThrowGib`, `ThrowHead`, `insane_dead`, `va`
- Notes: Guard against double-death. Crucified entity goes directly to `insane_dead` (fly flag path).

### insane_dead
- Signature: `void insane_dead(edict_t *self)`
- Purpose: Final dead state — sets bbox for corpse, marks as dead, stops thinking.
- Side effects: Sets `FL_FLY` (crucified) or collapses bbox + `MOVETYPE_TOSS`. Sets `SVF_DEADMONSTER`, clears `nextthink`, calls `gi.linkentity`.

### insane_cross / insane_checkdown / insane_checkup / insane_onground
- Trivial state-transition callbacks used as frame action functions. `insane_cross` 80/20 splits between idle and struggle cross. `insane_checkdown` may randomly transition standing to prone. `insane_checkup` may randomly rise from prone. `insane_onground` forces `insane_move_down`.

## Control Flow Notes
`SP_misc_insane` is the map-entity entry point, called once at level load. It ends with `walkmonster_start` or `flymonster_start`, which connect the NPC to the engine's per-frame AI think loop. Each frame the engine calls the current `mmove_t` sequence, advancing frames and firing action callbacks, which in turn switch `currentmove` to drive behavior transitions. No attack, dodge, melee, or sight callbacks are registered.

## External Dependencies
- `g_local.h` — entity types, game imports (`gi`), AI helpers, utility macros
- `m_insane.h` — frame constants (`FRAME_*`), `MODEL_SCALE`
- `ai_stand`, `ai_walk`, `ai_move` — AI movement primitives (defined in `g_ai.c`)
- `ThrowGib`, `ThrowHead` — gib helpers (defined in `g_misc.c`)
- `walkmonster_start`, `flymonster_start` — monster init (defined in `g_monster.c`)
- `random()`, `VectorSet`, `va` — engine utility macros/functions
