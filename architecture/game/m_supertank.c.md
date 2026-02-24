# game/m_supertank.c

## File Purpose
Implements the Supertank boss monster (monster_supertank), a large armored vehicle enemy that attacks with a chaingun and rocket launcher. It manages all animation states, AI transitions, attack logic, and a staged explosion death sequence.

## Core Responsibilities
- Define all animation frame sequences (stand, run, walk, turn, attack, pain, death)
- Drive chaingun and rocket fire at frame-accurate trigger points
- Select attack mode (chaingun vs rockets) based on range
- Handle pain response with damage-threshold branching and skill-level suppression
- Execute a multi-stage BossExplode death sequence with gibs and explosions
- Register sounds and initialize entity properties via SP_monster_supertank

## Key Types / Data Structures
None (uses engine types from g_local.h and m_supertank.h).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| sound_pain1/2/3 | int | static | Cached sound indices for pain variants |
| sound_death | int | static | Cached sound index for death cry |
| sound_search1/2 | int | static | Cached sound indices for idle search vocalizations |
| tread_sound | int | static | Cached sound index for movement tread loop |

## Key Functions

### SP_monster_supertank
- Signature: `void SP_monster_supertank(edict_t *self)`
- Purpose: Spawns and fully initializes the supertank entity.
- Inputs: `self` — the entity to initialize.
- Outputs/Return: void
- Side effects: Indexes sounds and model, sets bbox, health (1500), mass (800), assigns all AI callbacks, calls `walkmonster_start`.
- Calls: `gi.soundindex`, `gi.modelindex`, `gi.linkentity`, `walkmonster_start`, `G_FreeEdict`
- Notes: Immediately frees entity in deathmatch mode; no dodge or melee callbacks assigned.

### supertank_attack
- Signature: `void supertank_attack(edict_t *self)`
- Purpose: Selects attack animation based on range to enemy.
- Inputs: `self`
- Outputs/Return: void; sets `currentmove`
- Side effects: None beyond state transition.
- Calls: `VectorSubtract`, `VectorLength`, `random`
- Notes: ≤160 units forces chaingun; beyond that, 70% chance rockets, 30% chaingun.

### supertankRocket
- Signature: `void supertankRocket(edict_t *self)`
- Purpose: Fires a single rocket toward the enemy; called 3 times across attack2 frames.
- Inputs: `self`
- Outputs/Return: void
- Side effects: Spawns rocket projectile via `monster_fire_rocket`.
- Calls: `AngleVectors`, `G_ProjectSource`, `VectorCopy`, `VectorSubtract`, `VectorNormalize`, `monster_fire_rocket`
- Notes: Flash number determined by current frame (attak2_8/11/14).

### supertankMachineGun
- Signature: `void supertankMachineGun(edict_t *self)`
- Purpose: Fires one bullet per frame during attack1 (6 total).
- Inputs: `self`
- Outputs/Return: void
- Side effects: Spawns bullet via `monster_fire_bullet`.
- Calls: `AngleVectors`, `G_ProjectSource`, `VectorMA`, `VectorSubtract`, `VectorNormalize`, `monster_fire_bullet`
- Notes: Contains a `//FIXME!!!` comment — uses only yaw angle (dir[0]=0, dir[2]=0) to compute forward vector, ignoring pitch/roll. `VectorMA` multiplier is 0, making it a no-op.

### supertank_reattack1
- Signature: `void supertank_reattack1(edict_t *self)`
- Purpose: After each chaingun burst, decides whether to continue firing or end the attack.
- Inputs: `self`
- Outputs/Return: void; sets `currentmove`
- Calls: `visible`, `random`
- Notes: 90% re-attack chance if enemy is visible; otherwise plays end_attack1 wind-down.

### supertank_pain
- Signature: `void supertank_pain(edict_t *self, edict_t *other, float kick, int damage)`
- Purpose: Handles pain response with debounce, skill suppression, and damage-tiered animations.
- Inputs: `self`, damage amount
- Side effects: Sets `pain_debounce_time`, switches skin to damage-state (skinnum=1) below half health.
- Notes: Suppressed entirely on skill 3 (nightmare); also suppressed during rocket-fire frames on skill ≥2.

### BossExplode
- Signature: `void BossExplode(edict_t *self)`
- Purpose: Staged explosion think function; fires 8 offset explosions over 0.8s, then spawns gibs.
- Inputs: `self`
- Side effects: Writes multicast explosion events, schedules itself repeatedly via `self->think`, throws gibs on case 8, sets `DEAD_DEAD`.
- Calls: `gi.WriteByte`, `gi.WritePosition`, `gi.multicast`, `ThrowGib`, `ThrowHead`
- Notes: Uses `self->count` as stage counter; final stage silences ambient sound before gibs.

### supertank_die
- Signature: `void supertank_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- Purpose: Triggers death sequence — plays death sound, disables damage, starts death animation.
- Side effects: Sets `deadflag`, `takedamage=DAMAGE_NO`, resets `count` for BossExplode staging.

## Control Flow Notes
- `SP_monster_supertank` → `walkmonster_start` hooks into the engine's per-frame monster think loop.
- Per-frame: AI functions (`ai_run`, `ai_charge`, etc.) drive movement; frame callbacks fire `supertankMachineGun`/`supertankRocket`/`TreadSound`/`BossExplode` at specific frames.
- Death flow: `supertank_die` → `supertank_move_death` (24 frames, BossExplode triggered at frame 24) → `supertank_dead` finalizes bbox and movetype.

## External Dependencies
- `g_local.h`, `m_supertank.h` (frame constants, MODEL_SCALE)
- Defined elsewhere: `ai_stand`, `ai_run`, `ai_walk`, `ai_move`, `ai_charge`, `walkmonster_start`, `monster_fire_rocket`, `monster_fire_bullet`, `G_ProjectSource`, `monster_flash_offset[]`, `ThrowGib`, `ThrowHead`, `visible`, `BossExplode` (forward-declared), `skill`, `level`, `deathmatch`
