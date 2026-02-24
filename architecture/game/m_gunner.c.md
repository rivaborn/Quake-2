# game/m_gunner.c

## File Purpose
Implements the Gunner monster AI for Quake 2, a medium-tier humanoid enemy that wields both a chaingun and a grenade launcher. It manages all animation state machines, combat logic, ducking/dodge behavior, and the spawn entry point for `monster_gunner` entities.

## Core Responsibilities
- Define all animation frame sequences (stand, walk, run, pain, death, duck, attack variants)
- Handle dual-weapon attack logic: grenade launcher burst and chaingun fire chain
- Implement dodge/duck behavior with conditional grenade counterattack
- Drive per-frame weapon firing via `GunnerFire` and `GunnerGrenade` callbacks
- Manage pain response with damage-tier selection and nightmare-mode suppression
- Handle death: gib threshold check, corpse physics setup, death animation
- Spawn and initialize the entity via `SP_monster_gunner`

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `mframe_t` | struct (defined elsewhere) | Single animation frame: AI function, move distance, optional callback |
| `mmove_t` | struct (defined elsewhere) | Animation sequence: first/last frame indices, frame array, end callback |
| `edict_t` | struct (defined elsewhere) | General entity; all monster state lives here |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `sound_pain` | `int` | static | Cached sound index for pain sound variant 1 |
| `sound_pain2` | `int` | static | Cached sound index for pain sound variant 2 |
| `sound_death` | `int` | static | Cached sound index for death sound |
| `sound_idle` | `int` | static | Cached sound index for idle ambient sound |
| `sound_open` | `int` | static | Cached sound index for gun-open/spin-up sound |
| `sound_search` | `int` | static | Cached sound index for search vocalization |
| `sound_sight` | `int` | static | Cached sound index for sight vocalization |

## Key Functions

### SP_monster_gunner
- **Signature:** `void SP_monster_gunner(edict_t *self)`
- **Purpose:** Spawns and fully initializes a Gunner entity from map data.
- **Inputs:** `self` — the newly allocated entity
- **Outputs/Return:** void
- **Side effects:** Preloads all sound and model assets via `gi.soundindex`/`gi.modelindex`; sets bbox, health, mass, all AI callbacks; calls `walkmonster_start` to register the monster with the engine walk system.
- **Calls:** `G_FreeEdict`, `gi.soundindex`, `gi.modelindex`, `VectorSet`, `gi.linkentity`, `walkmonster_start`
- **Notes:** Immediately frees the entity in deathmatch mode. `MODEL_SCALE` is defined in `m_gunner.h`.

---

### gunner_attack
- **Signature:** `void gunner_attack(edict_t *self)`
- **Purpose:** Selects attack mode based on range and RNG.
- **Inputs:** `self`
- **Outputs/Return:** void
- **Side effects:** Sets `monsterinfo.currentmove` to either `gunner_move_attack_grenade` or `gunner_move_attack_chain`.
- **Calls:** `range`
- **Notes:** Melee range always forces the chaingun wind-up; otherwise 50/50 split between grenade and chain.

---

### gunner_refire_chain
- **Signature:** `void gunner_refire_chain(edict_t *self)`
- **Purpose:** End-of-fire-burst callback; decides whether to continue firing or wind down.
- **Inputs:** `self`
- **Outputs/Return:** void
- **Side effects:** Sets `currentmove` to `gunner_move_fire_chain` (continue) or `gunner_move_endfire_chain` (stop).
- **Calls:** `visible`
- **Notes:** Requires enemy alive + visible + 50% chance to refire; all three must pass.

---

### GunnerFire
- **Signature:** `void GunnerFire(edict_t *self)`
- **Purpose:** Fires a single chaingun bullet per animation frame callback.
- **Inputs:** `self`
- **Outputs/Return:** void
- **Side effects:** Emits a bullet projectile via `monster_fire_bullet`; flash number derived from current frame offset.
- **Calls:** `AngleVectors`, `G_ProjectSource`, `VectorCopy`, `VectorMA`, `VectorSubtract`, `VectorNormalize`, `monster_fire_bullet`
- **Notes:** Leads the target by −0.2× velocity and adds `viewheight`; damage 3, spread uses `DEFAULT_BULLET_HSPREAD`/`DEFAULT_BULLET_VSPREAD`.

---

### GunnerGrenade
- **Signature:** `void GunnerGrenade(edict_t *self)`
- **Purpose:** Fires a grenade along the forward vector at specific burst frames.
- **Inputs:** `self`
- **Outputs/Return:** void
- **Side effects:** Emits a grenade via `monster_fire_grenade`; flash number selected by `self->s.frame`.
- **Calls:** `AngleVectors`, `G_ProjectSource`, `VectorCopy`, `monster_fire_grenade`
- **Notes:** Fires 4 grenades across frames 105/108/111/114 of attack sequence 1. FIXME comment notes spread is not yet implemented — aim is purely forward.

---

### gunner_pain
- **Signature:** `void gunner_pain(edict_t *self, edict_t *other, float kick, int damage)`
- **Purpose:** Responds to damage: updates skin, debounces pain, selects pain animation tier.
- **Inputs:** `self`, attacker `other`, `kick`, `damage`
- **Outputs/Return:** void
- **Side effects:** May change `s.skinnum` to 1 (damaged skin) at half health; sets `currentmove`; 3-second debounce via `pain_debounce_time`.
- **Calls:** `gi.sound`
- **Notes:** Nightmare (`skill == 3`) suppresses all pain animations. Three tiers: ≤10 → pain3 (short), ≤25 → pain2 (medium), else → pain1 (long).

---

### gunner_dodge
- **Signature:** `void gunner_dodge(edict_t *self, edict_t *attacker, float eta)`
- **Purpose:** 25% chance to trigger a duck sequence when a projectile is incoming.
- **Inputs:** `self`, `attacker`, `eta` (time to impact, unused)
- **Outputs/Return:** void
- **Side effects:** Sets `self->enemy` if unset; sets `currentmove` to `gunner_move_duck`.
- **Notes:** `eta` is not used to scale the response window.

---

### gunner_duck_down / gunner_duck_hold / gunner_duck_up
- Frame callbacks managing the duck state machine: set/clear `AI_DUCKED` flag, shrink/restore bbox, conditionally fire a grenade on duck-down at skill ≥ 2.

### gunner_die
- **Signature:** `void gunner_die(edict_t *self, edict_t *inflictor, edict_t *attacker, int damage, vec3_t point)`
- **Purpose:** Handles death: gib check or death animation.
- **Side effects:** Calls `ThrowGib`/`ThrowHead` on gib; else starts `gunner_move_death`.

## Control Flow Notes
- **Init:** `SP_monster_gunner` → `walkmonster_start` registers the entity; initial move is `gunner_move_stand`.
- **Per-frame:** The monster AI system steps through `currentmove` frame arrays each tick, calling per-frame callbacks (`GunnerFire`, `GunnerGrenade`, duck helpers) and the end-of-sequence callback to transition states.
- **Attack chain:** `gunner_attack` → `gunner_move_attack_chain` → `gunner_fire_chain` → `gunner_move_fire_chain` (loops via `gunner_refire_chain`) → `gunner_move_endfire_chain` → `gunner_run`.

## External Dependencies
- `g_local.h` — core game definitions, entity types, AI helpers (`ai_stand`, `ai_walk`, `ai_run`, `ai_move`, `ai_charge`, `range`, `visible`)
- `m_gunner.h` — frame index constants (`FRAME_*`), `MODEL_SCALE`, `MZ2_GUNNER_*` flash offsets
- **Defined elsewhere:** `monster_flash_offset[]`, `G_ProjectSource`, `monster_fire_bullet`, `monster_fire_grenade`, `ThrowGib`, `ThrowHead`, `walkmonster_start`, `G_FreeEdict`, `gi` (game import interface), `skill`, `deathmatch`, `level`
