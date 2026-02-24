# game/p_weapon.c

## File Purpose
Implements all player weapon logic for Quake 2, including weapon pickup, switching, firing, and per-frame think routines. Each weapon has a dedicated fire function and a `Weapon_*` entry point that drives its animation state machine via the shared `Weapon_Generic` framework.

## Core Responsibilities
- Manage weapon state transitions (ACTIVATING → READY → FIRING → DROPPING)
- Route per-frame weapon think calls through `Think_Weapon`
- Compute muzzle/projectile spawn positions accounting for handedness
- Generate `PlayerNoise` entities for AI monster awareness
- Handle weapon pickup, use, and drop inventory logic
- Implement fallback weapon selection when ammo runs out (`NoAmmoWeaponChange`)
- Apply Quad Damage and silencer modifiers to all fire functions

## Key Types / Data Structures
None (uses types from `g_local.h` and `m_player.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `is_quad` | `qboolean` | static | Set each think frame; multiplies damage ×4 for all fire functions |
| `is_silenced` | `byte` | static | Set to `MZ_SILENCED` or 0; OR'd into muzzle flash network messages |

## Key Functions

### P_ProjectSource
- **Signature:** `static void P_ProjectSource(gclient_t *client, vec3_t point, vec3_t distance, vec3_t forward, vec3_t right, vec3_t result)`
- **Purpose:** Wraps `G_ProjectSource` with left/center handedness mirroring of the Y offset.
- **Inputs:** Client handedness pref, world origin, per-weapon barrel offset, view vectors.
- **Outputs/Return:** `result` — world-space muzzle position.
- **Side effects:** None.
- **Calls:** `G_ProjectSource`

### PlayerNoise
- **Signature:** `void PlayerNoise(edict_t *who, vec3_t where, int type)`
- **Purpose:** Positions a noise-marker entity so monsters can pathfind toward where a player made noise. Silenced shots skip PNOISE_WEAPON; deathmatch and FL_NOTARGET skip entirely.
- **Inputs:** Source player, world position, noise type (`PNOISE_SELF`, `PNOISE_WEAPON`, `PNOISE_IMPACT`).
- **Outputs/Return:** None.
- **Side effects:** Spawns up to two `player_noise` entities on first call; updates `level.sound_entity` / `level.sound2_entity` and their frame stamps; calls `gi.linkentity`.
- **Calls:** `G_Spawn`, `gi.linkentity`

### Pickup_Weapon
- **Signature:** `qboolean Pickup_Weapon(edict_t *ent, edict_t *other)`
- **Purpose:** Grants a weapon to the picking-up player, optionally adding ammo, setting respawn, and auto-switching if it is a new acquisition.
- **Side effects:** Modifies inventory, may set `FL_RESPAWN` or call `SetRespawn`; sets `other->client->newweapon`.
- **Calls:** `FindItem`, `Add_Ammo`, `SetRespawn`

### ChangeWeapon
- **Signature:** `void ChangeWeapon(edict_t *ent)`
- **Purpose:** Commits the pending weapon swap: fires any held grenade, updates `pers.weapon`, resets gun frame/state, sets player body animation.
- **Side effects:** Writes `weaponstate`, `ps.gunindex`, `ps.gunframe`, `ammo_index`, body `s.frame`.
- **Calls:** `weapon_grenade_fire`, `gi.modelindex`

### NoAmmoWeaponChange
- **Signature:** `void NoAmmoWeaponChange(edict_t *ent)`
- **Purpose:** Selects the best available weapon when current weapon runs dry, in priority order: railgun → hyperblaster → chaingun → machinegun → super shotgun → shotgun → blaster.
- **Side effects:** Sets `newweapon`.
- **Calls:** `FindItem`

### Think_Weapon
- **Signature:** `void Think_Weapon(edict_t *ent)`
- **Purpose:** Per-frame entry point called by client frame logic. Sets `is_quad`/`is_silenced` globals, then dispatches to the active weapon's `weaponthink` callback.
- **Side effects:** Sets file-static `is_quad`, `is_silenced`; calls weapon-specific think via function pointer.
- **Calls:** `ChangeWeapon`, weapon think (via `pers.weapon->weaponthink`)
- **Notes:** Must be called once per client per server frame.

### Weapon_Generic
- **Signature:** `void Weapon_Generic(edict_t *ent, int FRAME_ACTIVATE_LAST, int FRAME_FIRE_LAST, int FRAME_IDLE_LAST, int FRAME_DEACTIVATE_LAST, int *pause_frames, int *fire_frames, void (*fire)(edict_t*))`
- **Purpose:** Central weapon animation state machine shared by all weapons except the hand grenade. Drives ACTIVATING → READY → FIRING → DROPPING transitions, handles random idle pauses, fires on matching frames, plays quad sound.
- **Side effects:** Modifies `weaponstate`, `ps.gunframe`, body animation fields; calls `fire` callback and `ChangeWeapon`.
- **Notes:** `pause_frames` and `fire_frames` are zero-terminated arrays. Skips logic entirely for dead/non-255 model-index entities to avoid VWep corpse bugs.

### Per-Weapon Fire Functions
- `weapon_grenade_fire` — throws timed grenade; speed scales with hold time; can detonate in hand.
- `weapon_grenadelauncher_fire` / `Weapon_RocketLauncher_Fire` — launch projectiles, send muzzle flash, call `PlayerNoise`.
- `Blaster_Fire` — shared by blaster and hyperblaster; handles both effect types.
- `Machinegun_Fire` — applies progressive barrel-raise kick (`machinegun_shots`); alternates frames 4/5.
- `Chaingun_Fire` — fires 1–3 bullets per frame depending on spin-up frame; manages spin-up/down sounds.
- `weapon_shotgun_fire` / `weapon_supershotgun_fire` — pellet spreads; SSG fires two yaw-offset bursts.
- `weapon_railgun_fire` — single hitscan, higher damage in SP vs DM.
- `weapon_bfg_fire` — two-phase: muzzle flash on frame 9, projectile on frame 17; consumes 50 cells; aborts if cells drop below 50 during windup.

## Control Flow Notes
`Think_Weapon` is the per-frame entry point, called from `ClientBeginServerFrame` and `ClientThink` in the server game loop. Each `Weapon_*` function passes fixed frame-range constants and callback arrays into `Weapon_Generic`, which ticks the animation and invokes the fire callback at designated frames. `ChangeWeapon` is triggered either by `Think_Weapon` (on death) or from within `Weapon_Generic` / `Weapon_Grenade` when `weaponstate == WEAPON_DROPPING` completes.

## External Dependencies
- **Includes:** `g_local.h`, `m_player.h`
- **Defined elsewhere:** `G_ProjectSource`, `G_Spawn`, `SetRespawn`, `Drop_Item`, `Add_Ammo`, `FindItem`, `ITEM_INDEX`; projectile functions `fire_grenade`, `fire_grenade2`, `fire_rocket`, `fire_blaster`, `fire_bullet`, `fire_shotgun`, `fire_rail`, `fire_bfg`; `gi` interface (sound, modelindex, WriteByte/Short, multicast, linkentity, cprintf); cvars `deathmatch`, `coop`, `dmflags`, `g_select_empty`; player animation frame constants from `m_player.h`.
