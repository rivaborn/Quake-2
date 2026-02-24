# ctf/g_ai.c

## File Purpose
Implements monster AI locomotion, target acquisition, and attack decision logic for the CTF game module. It provides the core per-frame AI state machine entry points (`ai_stand`, `ai_walk`, `ai_run`, `ai_charge`, etc.) and the target-finding/enemy-tracking subsystem used by all monsters.

## Core Responsibilities
- Cycling `level.sight_client` each frame so monsters check players fairly in multiplayer
- Providing movement primitives (`ai_move`, `ai_stand`, `ai_walk`, `ai_charge`, `ai_turn`, `ai_run`) called by monster animation frames
- Spatial queries: range classification, line-of-sight (`visible`), facing check (`infront`)
- Target acquisition (`FindTarget`) via sight, sound, and area-connectivity checks
- Alerting the level when a target is found (`FoundTarget`, `HuntTarget`)
- Attack decision (`M_CheckAttack`, `ai_checkattack`) including melee, missile, and sliding strafing
- Lost-sight pursuit using player trail waypoints (`ai_run`)

## Key Types / Data Structures
None (all types imported from `g_local.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `enemy_vis` | `qboolean` | global | Whether current enemy is visible this frame |
| `enemy_infront` | `qboolean` | global | Whether current enemy is in front of monster |
| `enemy_range` | `int` | global | Range category to enemy (MELEE/NEAR/MID/FAR) |
| `enemy_yaw` | `float` | global | Yaw angle toward enemy this frame |

## Key Functions

### AI_SetSightClient
- Signature: `void AI_SetSightClient(void)`
- Purpose: Advances `level.sight_client` round-robin through live, targetable clients each frame.
- Inputs: None (reads `g_edicts`, `game.maxclients`, `level.sight_client`)
- Outputs/Return: void; sets `level.sight_client`
- Side effects: Writes `level.sight_client`
- Calls: None
- Notes: If no valid client exists, sets `level.sight_client = NULL`

### ai_stand
- Signature: `void ai_stand(edict_t *self, float dist)`
- Purpose: Per-frame update for a standing monster; checks for targets and triggers idle/walk transitions.
- Inputs: `self` — the monster; `dist` — optional positional nudge
- Outputs/Return: void
- Side effects: May call `self->monsterinfo.run`, `walk`, `idle`, `stand`; modifies `aiflags`, `idle_time`, `ideal_yaw`
- Calls: `M_walkmove`, `M_ChangeYaw`, `ai_checkattack`, `FindTarget`

### ai_walk
- Signature: `void ai_walk(edict_t *self, float dist)`
- Purpose: Per-frame update for a patrolling monster; moves toward goal then checks for targets.
- Inputs: `self`, `dist`
- Outputs/Return: void
- Side effects: Calls `M_MoveToGoal`; may trigger `search` callback; modifies `idle_time`
- Calls: `M_MoveToGoal`, `FindTarget`

### ai_charge
- Signature: `void ai_charge(edict_t *self, float dist)`
- Purpose: Turns monster toward its enemy and advances.
- Inputs: `self`, `dist`
- Outputs/Return: void
- Side effects: Writes `self->ideal_yaw`; calls `M_ChangeYaw`, `M_walkmove`
- Calls: `vectoyaw`, `M_ChangeYaw`, `M_walkmove`

### ai_run
- Signature: `void ai_run(edict_t *self, float dist)`
- Purpose: Primary run-state AI; handles attack checks, sound pursuit, lost-sight trail following, and obstacle course-correction.
- Inputs: `self`, `dist`
- Outputs/Return: void
- Side effects: Spawns/frees a temporary goal entity; reads/writes `monsterinfo` trail fields, `aiflags`; calls `G_Spawn`/`G_FreeEdict`
- Calls: `M_MoveToGoal`, `ai_checkattack`, `ai_run_slide`, `FindTarget`, `PlayerTrail_PickFirst`, `PlayerTrail_PickNext`, `G_Spawn`, `G_FreeEdict`, `G_ProjectSource`, `gi.trace`
- Notes: Course-correction logic casts left/right traces to navigate around obstacles when the direct path is blocked

### FindTarget
- Signature: `qboolean FindTarget(edict_t *self)`
- Purpose: Tests whether the monster should acquire a new enemy from sight/sound events this frame.
- Inputs: `self`
- Outputs/Return: `true` if enemy acquired
- Side effects: Sets `self->enemy`, `self->ideal_yaw`, `self->monsterinfo.aiflags`; calls `FoundTarget`
- Calls: `range`, `visible`, `infront`, `M_ChangeYaw`, `FoundTarget`, `gi.inPHS`, `gi.AreasConnected`, `vectoyaw`
- Notes: Good-guy monsters (`AI_GOOD_GUY`) always return false; spawnflag bit 1 suppresses sound-only waking

### FoundTarget / HuntTarget
- Signature: `void FoundTarget(edict_t *self)` / `void HuntTarget(edict_t *self)`
- Purpose: `HuntTarget` begins active pursuit (sets `goalentity`, transitions to run/stand, delays first attack). `FoundTarget` signals the level, optionally navigates to a `combattarget` waypoint, then calls `HuntTarget`.
- Side effects: Writes `level.sight_entity`, `level.sight_entity_framenum`; calls `AttackFinished`, `G_PickTarget`, `gi.dprintf`

### M_CheckAttack
- Signature: `qboolean M_CheckAttack(edict_t *self)`
- Purpose: Decides whether to initiate melee or missile attack based on range, skill, timing, and line-of-sight.
- Inputs: `self` (uses global `enemy_range`)
- Outputs/Return: `true` if attack is initiated
- Side effects: Sets `self->monsterinfo.attack_state`, `attack_finished`; calls `gi.trace`
- Notes: Skill 0 halves chance; skill ≥ 2 doubles; RANGE_FAR always returns false

### ai_checkattack
- Signature: `qboolean ai_checkattack(edict_t *self, float dist)`
- Purpose: Sets frame-global enemy state (`enemy_vis`, `enemy_infront`, `enemy_range`, `enemy_yaw`), handles dead-enemy cleanup, then dispatches to `M_CheckAttack`.
- Inputs: `self`, `dist`
- Side effects: Writes all four global enemy state vars; may call `HuntTarget`, `walk`, `stand`; clears `self->enemy`

## Control Flow Notes
Called per animation frame: monster think functions invoke `ai_stand`, `ai_walk`, `ai_run`, or `ai_charge` with a per-frame distance. `AI_SetSightClient` is called once per server frame (from `G_RunFrame`) before any monster thinks. The globals `enemy_vis/infront/range/yaw` are scratch state valid only for the duration of a single monster's think.

## External Dependencies
- `g_local.h` — all engine/game types, constants (`MELEE_DISTANCE`, `RANGE_*`, `AI_*`, `AS_*`)
- `M_walkmove`, `M_MoveToGoal`, `M_ChangeYaw` — monster movement (defined in `m_move.c`)
- `AttackFinished`, `G_PickTarget`, `G_Spawn`, `G_FreeEdict`, `G_ProjectSource` — game utilities (defined elsewhere)
- `PlayerTrail_PickFirst`, `PlayerTrail_PickNext` — trail system (defined in `p_trail.c`)
- `gi.trace`, `gi.inPHS`, `gi.AreasConnected`, `gi.dprintf` — engine imports via `gi` game interface
- `level`, `g_edicts`, `game`, `coop`, `skill` — global game state (defined in `g_main.c` / `g_local.h`)
