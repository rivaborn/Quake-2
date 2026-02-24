# game/m_boss31.c

## File Purpose
Implements the Jorg boss monster (Boss 3 / "rider" platform), a massive bipedal mech that serves as a penultimate boss in Quake 2. Jorg carries the Makron on its back and spawns it upon death. It attacks with dual chainguns and a BFG cannon.

## Core Responsibilities
- Define all animation frame sequences (stand, walk, run, pain, attack, death)
- Handle dual-chaingun bullet fire from left and right barrels
- Handle BFG projectile fire
- Implement custom attack-check logic (`Jorg_CheckAttack`)
- Play footstep, pain, idle, and death sounds at appropriate frame callbacks
- Trigger `MakronToss` and `BossExplode` at end of death sequence
- Register entity via `SP_monster_jorg` and wire all monster callbacks

## Key Types / Data Structures
| Name | Kind | Purpose |
|---|---|---|
| `mframe_t` | struct (extern) | Single animation frame: AI func, dist, callback |
| `mmove_t` | struct (extern) | Animation sequence: start/end frame, frame array, end callback |

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `sound_pain1/2/3` | `int` | static | Cached sound indices for pain sounds |
| `sound_idle` | `int` | static | Cached idle vocalization index |
| `sound_death` | `int` | static | Cached death sound index |
| `sound_search1/2/3` | `int` | static | Cached search/alert sounds |
| `sound_attack1/2` | `int` | static | Cached attack vocalization indices |
| `sound_firegun` | `int` | static | Cached chaingun firing sound |
| `sound_step_left/right` | `int` | static | Cached footstep sounds |
| `sound_death_hit` | `int` | static | Cached death impact sound |

## Key Functions

### SP_monster_jorg
- **Signature:** `void SP_monster_jorg(edict_t *self)`
- **Purpose:** Spawn entry point; precaches assets, sets physical properties, wires all monster callbacks.
- **Inputs:** `self` — the entity being spawned
- **Outputs/Return:** void
- **Side effects:** Allocates sound/model indices via `gi.soundindex`/`gi.modelindex`; calls `MakronPrecache()`; calls `walkmonster_start()`; links entity.
- **Calls:** `G_FreeEdict`, `gi.soundindex`, `gi.modelindex`, `MakronPrecache`, `VectorSet`, `gi.linkentity`, `walkmonster_start`
- **Notes:** Immediately frees self in deathmatch. Uses two model slots (`modelindex` = rider platform, `modelindex2` = Jorg body). Health = 3000, mass = 1000.

### Jorg_CheckAttack
- **Signature:** `qboolean Jorg_CheckAttack(edict_t *self)`
- **Purpose:** Custom attack-decision function; replaces the generic `M_CheckAttack` to add LOS trace and range-gated probability.
- **Inputs:** `self` — Jorg entity
- **Outputs/Return:** `qboolean` — true if attack should fire
- **Side effects:** Sets `self->monsterinfo.attack_state`, `self->ideal_yaw`, `self->monsterinfo.attack_finished`.
- **Calls:** `gi.trace`, `infront`, `range`, `vectoyaw`, `VectorSubtract`, `VectorCopy`, `random`
- **Notes:** Traces through `CONTENTS_SOLID|MONSTER|SLIME|LAVA`; returns false if trace doesn't reach the enemy. Chance values: stand-ground 0.4, melee 0.8, near 0.4, mid 0.2.

### jorg_firebullet
- **Signature:** `void jorg_firebullet(edict_t *self)`
- **Purpose:** Frame callback that fires both left and right chaingun barrels simultaneously.
- **Inputs:** `self`
- **Outputs/Return:** void
- **Side effects:** Spawns two bullet projectiles via `monster_fire_bullet`.
- **Calls:** `jorg_firebullet_left`, `jorg_firebullet_right`

### jorg_firebullet_left / jorg_firebullet_right
- **Signature:** `void jorg_firebullet_{left|right}(edict_t *self)`
- **Purpose:** Compute muzzle origin from flash offset, lead the target slightly, fire one bullet.
- **Inputs:** `self`
- **Side effects:** Calls `monster_fire_bullet` with damage=6, kick=4, default spread.
- **Calls:** `AngleVectors`, `G_ProjectSource`, `VectorMA`, `VectorSubtract`, `VectorNormalize`, `monster_fire_bullet`
- **Notes:** Uses `-0.2` velocity lead on enemy position.

### jorgBFG
- **Signature:** `void jorgBFG(edict_t *self)`
- **Purpose:** Frame callback to fire a BFG blast toward the enemy.
- **Inputs:** `self`
- **Side effects:** Calls `monster_fire_bfg`; plays attack2 sound.
- **Calls:** `AngleVectors`, `G_ProjectSource`, `VectorCopy`, `VectorSubtract`, `VectorNormalize`, `gi.sound`, `monster_fire_bfg`
- **Notes:** BFG params: damage=50, speed=300, kick=100, radius=200, flash=`MZ2_JORG_BFG_1`.

### jorg_pain
- **Signature:** `void jorg_pain(edict_t *self, edict_t *other, float kick, int damage)`
- **Purpose:** Handle pain response with debounce, damage thresholds, and frame-state suppression.
- **Side effects:** Sets `skinnum=1` at half health; resets `s.sound`; sets `pain_debounce_time`; assigns `currentmove`.
- **Notes:** Nightmare skill skips all pain animations. Suppresses pain with near-zero probability while firing attack1 (`attak109–114`).

### jorg_die
- **Signature:** `void jorg_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- **Purpose:** Triggers death sequence; sets dead flags and plays death sound.
- **Side effects:** Sets `deadflag=DEAD_DEAD`, `takedamage=DAMAGE_NO`, silences looping sound, sets `currentmove = &jorg_move_death`.

### jorg_dead
- **Signature:** `void jorg_dead(edict_t *self)`
- **Purpose:** End-of-death-animation callback. Body of function is `#if 0`-disabled; was intended to spawn the Makron via `SP_monster_makron`.
- **Notes:** Makron spawning is handled instead via `MakronToss` at frame 49 of the death animation.

## Control Flow Notes
- **Init:** `SP_monster_jorg` → `walkmonster_start` enters standard walk-monster think loop.
- **Frame:** AI functions (`ai_stand`, `ai_run`, `ai_charge`, `ai_move`) drive per-frame movement; frame callbacks fire sounds and projectiles.
- **Attack:** `jorg_attack` → `jorg_move_start_attack1` → `jorg_move_attack1` (loops via `jorg_reattack1` at 90% while visible) or `jorg_move_attack2` for BFG.
- **Death:** Frame 49 calls `MakronToss`, frame 50 calls `BossExplode`; sequence ends calling `jorg_dead` (currently no-op).

## External Dependencies
- **Includes:** `g_local.h`, `m_boss31.h`
- **Defined elsewhere:** `ai_stand`, `ai_run`, `ai_walk`, `ai_move`, `ai_charge`, `walkmonster_start`, `monster_fire_bullet`, `monster_fire_bfg`, `G_ProjectSource`, `monster_flash_offset`, `infront`, `range`, `vectoyaw`, `visible`, `BossExplode`, `MakronToss`, `MakronPrecache`, `SP_monster_makron`, `gi` (game import struct)
