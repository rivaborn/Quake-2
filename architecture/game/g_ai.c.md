# game/g_ai.c

## File Purpose
Implements the core AI behavior system for Quake 2 monsters, providing movement primitives, target detection/acquisition, attack decision-making, and enemy pursuit logic. It bridges per-frame monster state machine calls with the engine's movement and trace systems.

## Core Responsibilities
- Cycle the global sight client each frame (`AI_SetSightClient`)
- Provide movement primitives used by monster animation frames (`ai_move`, `ai_stand`, `ai_walk`, `ai_charge`, `ai_turn`, `ai_run`)
- Detect and acquire targets via sight, sound, and proximity (`FindTarget`, `FoundTarget`, `HuntTarget`)
- Evaluate attack feasibility and select attack mode (`M_CheckAttack`, `ai_checkattack`)
- Execute attack approach behaviors: close for melee, align for missile, strafe sideways (`ai_run_melee`, `ai_run_missile`, `ai_run_slide`)
- Implement lost-sight pursuit using player trail waypoints (`ai_run`)

## Key Types / Data Structures
None (uses types defined in `g_local.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `enemy_vis` | `qboolean` | global | Whether current enemy is visible this frame |
| `enemy_infront` | `qboolean` | global | Whether enemy is in the monster's forward arc |
| `enemy_range` | `int` | global | Range category to enemy (MELEE/NEAR/MID/FAR) |
| `enemy_yaw` | `float` | global | Yaw angle toward enemy, set each frame in `ai_checkattack` |

## Key Functions

### AI_SetSightClient
- **Signature:** `void AI_SetSightClient(void)`
- **Purpose:** Advances `level.sight_client` round-robin through active, living, non-notarget players each frame.
- **Inputs:** None (reads `g_edicts`, `game.maxclients`, `level.sight_client`)
- **Outputs/Return:** void; sets `level.sight_client`
- **Side effects:** Writes `level.sight_client`
- **Calls:** None
- **Notes:** If no valid client exists, sets `level.sight_client = NULL`. Called once per server frame.

### FindTarget
- **Signature:** `qboolean FindTarget(edict_t *self)`
- **Purpose:** Attempts to assign a target enemy to `self` by checking sight entity, sound entities, and the cycling sight client.
- **Inputs:** `self` — monster entity
- **Outputs/Return:** `true` if a target was acquired
- **Side effects:** Sets `self->enemy`, `self->ideal_yaw`; calls `FoundTarget`; sets `AI_SOUND_TARGET` flag
- **Calls:** `range`, `visible`, `infront`, `FoundTarget`, `M_ChangeYaw`, `gi.inPHS`, `gi.AreasConnected`
- **Notes:** Respects `FL_NOTARGET`, light level ≤5 darkness check, area portal connectivity for heard sounds. Skips `AI_GOOD_GUY` and `AI_COMBAT_POINT` monsters unconditionally.

### FoundTarget
- **Signature:** `void FoundTarget(edict_t *self)`
- **Purpose:** Commits to a newly found enemy: updates level sight bookkeeping, wakes nearby monsters, resolves `combattarget`, and initiates pursuit.
- **Inputs:** `self` — monster with `self->enemy` already set
- **Outputs/Return:** void
- **Side effects:** Writes `level.sight_entity`, `level.sight_entity_framenum`, `self->show_hostile`, `self->monsterinfo.last_sighting`; may call `G_PickTarget`, `HuntTarget`, `gi.dprintf`
- **Calls:** `G_PickTarget`, `HuntTarget`, `gi.dprintf`

### HuntTarget
- **Signature:** `void HuntTarget(edict_t *self)`
- **Purpose:** Sets goal to the enemy and starts the run or stand state; delays first attack by 1 second.
- **Inputs:** `self`
- **Side effects:** Sets `self->goalentity`, `self->ideal_yaw`; calls `AttackFinished`
- **Calls:** `AttackFinished`, `vectoyaw`, monster's `stand` or `run` callback

### M_CheckAttack
- **Signature:** `qboolean M_CheckAttack(edict_t *self)`
- **Purpose:** Performs a line-of-sight trace to the enemy and probabilistically decides to attack; sets `attack_state`.
- **Inputs:** `self`
- **Outputs/Return:** `true` if attacking this frame
- **Side effects:** Sets `self->monsterinfo.attack_state`, `self->monsterinfo.attack_finished`
- **Calls:** `gi.trace`
- **Notes:** Attack probability scaled by `skill` cvar. Flying monsters may enter `AS_SLIDING`.

### ai_checkattack
- **Signature:** `qboolean ai_checkattack(edict_t *self, float dist)`
- **Purpose:** Master per-frame attack decision: checks if enemy is dead/replaced, updates global `enemy_vis/infront/range/yaw`, dispatches active attack states, and calls `monsterinfo.checkattack`.
- **Inputs:** `self`, `dist` — movement distance available
- **Outputs/Return:** `true` if an attack action was taken
- **Side effects:** Writes all four globals; may call `HuntTarget`, monster walk/stand callbacks
- **Calls:** `visible`, `infront`, `range`, `vectoyaw`, `ai_run_missile`, `ai_run_melee`, `self->monsterinfo.checkattack`

### ai_run
- **Signature:** `void ai_run(edict_t *self, float dist)`
- **Purpose:** Full pursuit frame: handles sound-target rush, attack checks, strafe, visible enemy tracking, and lost-sight trail following with course correction.
- **Inputs:** `self`, `dist`
- **Side effects:** Allocates/frees a temporary `goalentity` via `G_Spawn`/`G_FreeEdict`; modifies `self->monsterinfo.aiflags`, `last_sighting`, `ideal_yaw`
- **Calls:** `M_MoveToGoal`, `ai_checkattack`, `ai_run_slide`, `FindTarget`, `PlayerTrail_PickFirst`, `PlayerTrail_PickNext`, `G_Spawn`, `G_FreeEdict`, `G_ProjectSource`, `gi.trace`
- **Notes:** Course correction probes left/right traces when direct path is blocked. Temporary goal entity is always freed before return.

### Notes (minor helpers)
- `ai_move`, `ai_walk`, `ai_stand`, `ai_charge`, `ai_turn` — thin wrappers calling `M_walkmove`/`M_MoveToGoal` with optional `FindTarget`/idle callbacks.
- `range`, `visible`, `infront` — stateless geometric query helpers used widely across the game module.
- `FacingIdeal` — checks if yaw delta is within ±45° of `ideal_yaw`.
- `ai_run_melee`, `ai_run_missile`, `ai_run_slide` — sub-states called from `ai_checkattack`/`ai_run`.

## Control Flow Notes
`AI_SetSightClient` is called once at the start of each server frame (from `G_RunFrame`). Monster think functions invoke `ai_stand`, `ai_walk`, `ai_run`, or `ai_charge` each animation frame step. `ai_checkattack` is the central decision hub called from both `ai_stand` and `ai_run`. `FindTarget` → `FoundTarget` → `HuntTarget` forms the target acquisition chain that transitions a monster from patrol/idle into combat.

## External Dependencies
- **Includes:** `g_local.h` (all game types, entity fields, `monsterinfo_t`, AI flags, range constants)
- **Defined elsewhere:** `M_walkmove`, `M_MoveToGoal`, `M_ChangeYaw` (`game/m_move.c`); `G_Spawn`, `G_FreeEdict`, `G_PickTarget`, `G_ProjectSource`, `AttackFinished` (various `g_*.c`); `PlayerTrail_PickFirst`, `PlayerTrail_PickNext` (`game/p_trail.c`); `gi.trace`, `gi.inPHS`, `gi.AreasConnected`, `gi.dprintf` (engine import struct); `g_edicts`, `level`, `game`, `coop`, `skill` (game globals)
