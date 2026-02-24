# ctf/p_weapon.c

## File Purpose
Implements all player weapon logic for the CTF (Capture the Flag) game module, including weapon pickup, switching, firing, animation state management, and noise generation for AI targeting. This is the CTF variant of the standard `game/p_weapon.c`, augmented with CTF-specific haste and strength power-up hooks.

## Core Responsibilities
- Manage weapon state machine (ACTIVATING → READY → FIRING → DROPPING → ChangeWeapon)
- Project weapon fire origin accounting for player handedness (left/center/right)
- Generate `PlayerNoise` entities for monster AI awareness
- Handle weapon pickup, drop, and ammo-conditional switching
- Implement per-weapon fire callbacks (grenade, rocket, blaster, shotguns, machinegun, chaingun, railgun, BFG)
- Apply CTF power-ups: quad damage (`is_quad`), silencer (`is_silenced`), haste (double tick via `CTFApplyHaste`), strength sound (`CTFApplyStrengthSound`)

## Key Types / Data Structures
None (uses types from `g_local.h` and `m_player.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `is_quad` | `qboolean` | static | Caches whether quad damage is active this weapon think tick |
| `is_silenced` | `byte` | static | Caches `MZ_SILENCED` flag or 0 for muzzle flash packet |

## Key Functions

### P_ProjectSource
- **Signature:** `void P_ProjectSource(gclient_t *client, vec3_t point, vec3_t distance, vec3_t forward, vec3_t right, vec3_t result)`
- **Purpose:** Computes world-space weapon muzzle origin, mirroring offset for left-handed players and centering for center-handed.
- **Inputs:** Client handedness, base point, local offset, orientation vectors.
- **Outputs/Return:** `result` — world-space fire origin.
- **Side effects:** None.
- **Calls:** `G_ProjectSource`

### PlayerNoise
- **Signature:** `void PlayerNoise(edict_t *who, vec3_t where, int type)`
- **Purpose:** Creates/updates invisible noise marker entities (`mynoise`, `mynoise2`) used by monster AI to locate the player indirectly.
- **Inputs:** Source entity, world position, noise type (`PNOISE_SELF`, `PNOISE_WEAPON`, `PNOISE_IMPACT`).
- **Outputs/Return:** None.
- **Side effects:** Spawns up to 2 `player_noise` entities on first call; updates `level.sound_entity` / `level.sound2_entity` and their frame timestamps; calls `gi.linkentity`.
- **Calls:** `G_Spawn`, `gi.linkentity`
- **Notes:** Silencer shots suppress `PNOISE_WEAPON`; no-ops in deathmatch or for `FL_NOTARGET` entities.

### Weapon_Generic / Weapon_Generic2
- **Signature:** `void Weapon_Generic(edict_t *ent, int FRAME_ACTIVATE_LAST, int FRAME_FIRE_LAST, int FRAME_IDLE_LAST, int FRAME_DEACTIVATE_LAST, int *pause_frames, int *fire_frames, void (*fire)(edict_t*))`
- **Purpose:** Central weapon state machine tick. `Weapon_Generic2` does the actual work; `Weapon_Generic` wraps it to optionally tick a second time when CTF haste is active (doubles weapon fire rate), with a special carve-out to prevent double-ticking the Grapple while firing.
- **Inputs:** Frame boundary constants, null-terminated pause/fire frame arrays, fire callback.
- **Outputs/Return:** None.
- **Side effects:** Mutates `weaponstate`, `ps.gunframe`, `anim_priority`, `s.frame`, `anim_end`; calls `fire` callback; calls `ChangeWeapon`, `NoAmmoWeaponChange`, `gi.sound`.
- **Calls:** `Weapon_Generic2`, `CTFApplyHaste`, `CTFApplyStrengthSound`, `CTFApplyHasteSound`, `ChangeWeapon`, `NoAmmoWeaponChange`, `gi.sound`
- **Notes:** `instantweap->value` skips activation/deactivation animations entirely.

### ChangeWeapon
- **Signature:** `void ChangeWeapon(edict_t *ent)`
- **Purpose:** Commits a pending weapon switch: fires held grenade if needed, swaps `pers.weapon` ← `newweapon`, resets gun state, triggers body activation animation.
- **Side effects:** Modifies `pers.weapon`, `pers.lastweapon`, `newweapon`, `weaponstate`, `ps.gunframe`, `ps.gunindex`, `s.skinnum`, `ammo_index`, body animation fields.
- **Calls:** `weapon_grenade_fire`, `gi.modelindex`, `FindItem`

### NoAmmoWeaponChange
- **Signature:** `void NoAmmoWeaponChange(edict_t *ent)`
- **Purpose:** Falls back to the best weapon the player has ammo for, in priority order: railgun → hyperblaster → chaingun → machinegun → super shotgun → shotgun → blaster.
- **Side effects:** Sets `client->newweapon`.
- **Calls:** `FindItem`, `ITEM_INDEX`

### Think_Weapon
- **Signature:** `void Think_Weapon(edict_t *ent)`
- **Purpose:** Per-frame entry point called by client frame logic; forces weapon-away on death, then dispatches to `pers.weapon->weaponthink`, caching `is_quad`/`is_silenced` beforehand.
- **Calls:** `ChangeWeapon`, `pers.weapon->weaponthink` (function pointer)

### Per-Weapon Fire Functions
- `weapon_grenade_fire` — timed grenade with speed scaling by cook time; can detonate in-hand.
- `weapon_grenadelauncher_fire` — arc grenade projectile, fixed speed 600.
- `Weapon_RocketLauncher_Fire` — randomized damage 100–120, speed 650.
- `Blaster_Fire` — shared blaster/hyperblaster helper; handles both `EF_BLASTER` and `EF_HYPERBLASTER`.
- `Machinegun_Fire` — single bullet with escalating barrel-rise kick up to 9 shots.
- `Chaingun_Fire` — 1–3 bullets per frame depending on spin-up frame, with spin sound management.
- `weapon_shotgun_fire` / `weapon_supershotgun_fire` — pellet spread; SSG fires two angled bursts (±5° yaw).
- `weapon_railgun_fire` — hitscan, lower damage in DM.
- `weapon_bfg_fire` — two-phase: muzzle flash at frame 9, projectile at frame 17; costs 50 cells.

## Control Flow Notes
`Think_Weapon` is the per-frame entry point, called from `ClientBeginServerFrame` and `ClientThink`. Each weapon's `Weapon_*` function (registered as `weaponthink` on the item) delegates to `Weapon_Generic`, which drives the state machine and calls the fire callback at the appropriate animation frames.

## External Dependencies
- **Includes:** `g_local.h`, `m_player.h`
- **Defined elsewhere:** `G_ProjectSource`, `G_Spawn`, `gi.*` (engine game import), `fire_grenade`, `fire_grenade2`, `fire_rocket`, `fire_blaster`, `fire_bullet`, `fire_shotgun`, `fire_rail`, `fire_bfg`, `FindItem`, `Add_Ammo`, `Drop_Item`, `SetRespawn`, `CTFApplyHaste`, `CTFApplyHasteSound`, `CTFApplyStrengthSound`, `instantweap` (cvar), `dmflags`, `coop`, `g_select_empty`, `level`, `g_edicts`
