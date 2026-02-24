# game/g_phys.c

## File Purpose
Implements the server-side physics simulation for all game entities. Dispatches per-frame movement and collision logic based on each entity's `movetype`, covering pusher platforms, toss/bounce projectiles, stepping monsters, and noclip objects.

## Core Responsibilities
- Clamp entity velocity to configured maximum each frame
- Apply gravity, friction, and rotational friction per movetype
- Slide-move resolution across multiple collision planes (`SV_FlyMove`)
- Push-move logic with rollback on blocked movement (`SV_Push`, `SV_Physics_Pusher`)
- Trigger touch dispatch after any positional change
- Run entity think functions at the correct simulation time
- Dispatch all entities through `G_RunEntity` based on `movetype`

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `pushed_t` | struct | Snapshot of an entity's origin/angles/deltayaw before a push attempt, for rollback |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `pushed[MAX_EDICTS]` | `pushed_t[]` | global (file) | Stack of pre-push snapshots for atomic rollback |
| `pushed_p` | `pushed_t *` | global (file) | Stack pointer into `pushed[]` |
| `obstacle` | `edict_t *` | global (file) | The entity that blocked the most recent push, passed to `blocked` callback |

## Key Functions

### SV_TestEntityPosition
- Signature: `edict_t *SV_TestEntityPosition(edict_t *ent)`
- Purpose: Tests whether an entity is currently intersecting solid geometry.
- Inputs: Entity to test.
- Outputs/Return: `g_edicts` (world entity, truthy) if stuck, `NULL` if clear.
- Side effects: None.
- Calls: `gi.trace`
- Notes: Uses `ent->clipmask` if set, else `MASK_SOLID`.

### SV_RunThink
- Signature: `qboolean SV_RunThink(edict_t *ent)`
- Purpose: Fires `ent->think` if `nextthink` has elapsed.
- Inputs: Entity.
- Outputs/Return: `true` if no think fired (too early or no time set); `false` after think executes.
- Side effects: Clears `nextthink`, calls `ent->think(ent)`.
- Calls: `ent->think`, `gi.error` on NULL think with valid time.
- Notes: Tolerance of 0.001s prevents floating-point drift misses.

### SV_Impact
- Signature: `void SV_Impact(edict_t *e1, trace_t *trace)`
- Purpose: Dispatches `touch` callbacks on both entities involved in a collision.
- Inputs: Moving entity `e1`, trace result carrying the hit entity.
- Side effects: Calls `e1->touch` and `trace->ent->touch`; entity callbacks may free either entity.
- Notes: `e2->touch` is called with NULL plane/surface (impact is symmetric but asymmetric data).

### ClipVelocity
- Signature: `int ClipVelocity(vec3_t in, vec3_t normal, vec3_t out, float overbounce)`
- Purpose: Reflects/clips velocity against a surface normal with optional bounce factor.
- Outputs/Return: Blocked flags (1=floor, 2=step/wall).
- Notes: Values within `STOP_EPSILON` (0.1) are zeroed to prevent micro-oscillations.

### SV_FlyMove
- Signature: `int SV_FlyMove(edict_t *ent, float time, int mask)`
- Purpose: Multi-plane slide move — the core continuous-collision loop used by most movetypes.
- Inputs: Entity, time step, collision mask.
- Outputs/Return: Blocked flags (1=floor, 2=wall, 4=dead stop, 7=cornered).
- Side effects: Mutates `ent->s.origin`, `ent->velocity`, `ent->groundentity`; calls `SV_Impact`.
- Calls: `gi.trace`, `SV_Impact`, `ClipVelocity`, `CrossProduct`, `DotProduct`.
- Notes: Up to 4 bumps per frame; crease resolution uses cross-product of two planes; stops if new velocity opposes original to prevent corner oscillation.

### SV_PushEntity
- Signature: `trace_t SV_PushEntity(edict_t *ent, vec3_t push)`
- Purpose: Moves entity by `push` delta, links it, fires impact, retries if hit target was freed.
- Side effects: Mutates `ent->s.origin`; calls `gi.linkentity`, `SV_Impact`, `G_TouchTriggers`.
- Notes: `goto retry` handles the case where the impacted entity was removed by its own touch function.

### SV_Push
- Signature: `qboolean SV_Push(edict_t *pusher, vec3_t move, vec3_t amove)`
- Purpose: Moves a pusher and all entities riding or overlapping it; rolls back everything on failure.
- Outputs/Return: `true` on success, `false` if blocked (sets `obstacle`).
- Side effects: Mutates origins/angles of pusher and affected entities; calls `gi.linkentity`, `G_TouchTriggers`; writes `obstacle`.
- Calls: `SV_TestEntityPosition`, `gi.linkentity`, `AngleVectors`, `G_TouchTriggers`.
- Notes: Clamps movement to 1/8-unit grid for client-side prediction accuracy. Angular push rotates rider positions relative to pusher origin.

### SV_Physics_Pusher
- Signature: `void SV_Physics_Pusher(edict_t *ent)`
- Purpose: Per-frame update for `MOVETYPE_PUSH`/`MOVETYPE_STOP` entities (doors, platforms).
- Side effects: Calls `SV_Push` for each team member; if blocked, bumps `nextthink` for all slaves and calls `part->blocked`; if unblocked, calls `SV_RunThink` for all slaves.
- Notes: Team slaves are skipped at entry — the captain drives the whole chain.

### SV_Physics_Toss
- Signature: `void SV_Physics_Toss(edict_t *ent)`
- Purpose: Per-frame update for toss/bounce/fly/flymissile entities.
- Side effects: Applies gravity, angle rotation, calls `SV_PushEntity`, clips velocity on impact, updates `watertype`/`waterlevel`, plays water entry/exit sound, propagates position to team slaves.
- Calls: `SV_RunThink`, `SV_CheckVelocity`, `SV_AddGravity`, `SV_PushEntity`, `ClipVelocity`, `gi.pointcontents`, `gi.positioned_sound`, `gi.soundindex`.

### SV_Physics_Step
- Signature: `void SV_Physics_Step(edict_t *ent)`
- Purpose: Per-frame update for stepping monsters; applies friction, gravity, and calls `SV_FlyMove`.
- Side effects: Calls `M_CheckGround`, `SV_AddRotationalFriction`, `SV_AddGravity`, `SV_FlyMove`, `gi.linkentity`, `G_TouchTriggers`, `SV_RunThink`; plays landing sound.
- Notes: Dead monsters not fully on ground are allowed to slide; FL_FLY and FL_SWIM bypass standard gravity.

### G_RunEntity
- Signature: `void G_RunEntity(edict_t *ent)`
- Purpose: Top-level per-entity physics dispatch called once per frame per entity.
- Side effects: Calls `ent->prethink`, then one of the `SV_Physics_*` functions.
- Notes: This is the primary engine entry point into this file.

## Control Flow Notes
`G_RunEntity` is called from the game's per-frame entity loop (in `g_main.c`). It first fires `prethink`, then dispatches into the appropriate physics routine based on `movetype`. Think functions are always called within the physics routine, not at the dispatch level (except `SV_Physics_None`/`SV_Physics_Noclip`).

## External Dependencies
- `g_local.h` — entity definitions, game globals, `gi` interface
- `sv_maxvelocity`, `sv_gravity` — cvars defined in server/common layer
- `M_CheckGround`, `M_CheckBottom` — defined in `g_monster.c`/`m_move.c`
- `G_TouchTriggers` — defined in `g_utils.c`
- `gi.trace`, `gi.linkentity`, `gi.sound`, `gi.pointcontents`, `gi.error` — engine interface (`gi` game import struct)
