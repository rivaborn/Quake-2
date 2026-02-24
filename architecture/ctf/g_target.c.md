# ctf/g_target.c

## File Purpose
Defines all `target_*` entity types for the CTF game module. Each entity responds to trigger/use events by performing a discrete world effect such as playing sounds, changing levels, firing lasers, spawning entities, or causing earthquakes.

## Core Responsibilities
- Register spawn functions (`SP_target_*`) and use callbacks (`use_target_*`) for each target entity class
- Send temp-entity network messages (splashes, explosions, laser sparks) to clients via multicast
- Manage level progression: secret/goal tracking, level changes, cross-level trigger state
- Drive per-frame thinking entities (laser, lightramp, earthquake) via `nextthink`/`think`
- Apply radius damage or direct damage on certain target activations
- Modify global `game` and `level` state (help messages, server flags, secret/goal counts)

## Key Types / Data Structures
None (operates entirely on `edict_t` fields defined in `g_local.h`).

## Global / File-Static State
None declared in this file; all state is read/written through `level`, `game`, and `g_edicts` (defined elsewhere).

## Key Functions

### Use_Target_Tent
- Signature: `void Use_Target_Tent(edict_t *ent, edict_t *other, edict_t *activator)`
- Purpose: Broadcasts a temp-entity event at the entity's origin to all PVS clients.
- Inputs: `ent->style` (temp entity type), `ent->s.origin`
- Outputs/Return: void
- Side effects: Writes to network via `gi.WriteByte`/`gi.WritePosition`/`gi.multicast`
- Calls: `gi.WriteByte`, `gi.WritePosition`, `gi.multicast`
- Notes: Minimal; purely a network broadcast wrapper.

### Use_Target_Speaker
- Signature: `void Use_Target_Speaker(edict_t *ent, edict_t *other, edict_t *activator)`
- Purpose: Toggles looping ambient sound or plays a one-shot positional sound.
- Inputs: `ent->spawnflags` (bits 0–2), `ent->s.sound`, `ent->noise_index`, `ent->volume`, `ent->attenuation`
- Outputs/Return: void
- Side effects: Mutates `ent->s.sound`; calls `gi.positioned_sound`
- Calls: `gi.positioned_sound`
- Notes: Looped sounds use `s.sound` field (replicated to clients automatically); non-looped use explicit positioned_sound call because the entity is otherwise invisible.

### target_explosion_explode
- Signature: `void target_explosion_explode(edict_t *self)`
- Purpose: Emits explosion temp entity, applies radius damage, then chains `G_UseTargets`.
- Inputs: `self->dmg`, `self->activator`, `self->delay`
- Outputs/Return: void
- Side effects: Network multicast (PHS), radius damage, `G_UseTargets`
- Calls: `gi.WriteByte`, `gi.WritePosition`, `gi.multicast`, `T_RadiusDamage`, `G_UseTargets`
- Notes: Temporarily zeroes `self->delay` before calling `G_UseTargets` to prevent re-entrancy loop, then restores it.

### use_target_changelevel
- Signature: `void use_target_changelevel(edict_t *self, edict_t *other, edict_t *activator)`
- Purpose: Initiates level transition; handles noexit damage, exit announcements, and cross-unit server flag clearing.
- Inputs: `self->map`, `dmflags`, `deathmatch`, `coop` cvars
- Outputs/Return: void
- Side effects: Modifies `game.serverflags`; calls `BeginIntermission`; may call `T_Damage`
- Calls: `T_Damage`, `gi.bprintf`, `BeginIntermission`
- Notes: Guards against re-activation via `level.intermissiontime`; checks player health in SP/coop.

### target_laser_think
- Signature: `void target_laser_think(edict_t *self)`
- Purpose: Per-frame laser trace loop — damages monsters/players in beam path, emits spark effect on first solid hit after direction change.
- Inputs: `self->movedir`, `self->enemy`, `self->dmg`, `self->spawnflags`
- Outputs/Return: void
- Side effects: Writes `self->s.old_origin` (beam end point), network multicast for sparks, `T_Damage` on hit entities, reschedules `self->nextthink`
- Calls: `gi.trace`, `T_Damage`, `gi.WriteByte`, `gi.WritePosition`, `gi.WriteDir`, `gi.multicast`
- Notes: `0x80000000` spawnflag bit is an internal dirty flag for direction change detection; traces through monsters until hitting a non-monster solid.

### target_lightramp_think / target_lightramp_use
- Purpose: Smoothly interpolates a light's style string between two levels (`'a'`–`'z'`) over `self->speed` seconds; TOGGLE flag reverses direction on completion.
- Side effects: `gi.configstring` on `CS_LIGHTS + enemy->style` each frame.

### target_earthquake_think
- Signature: `void target_earthquake_think(edict_t *self)`
- Purpose: Each frame applies random horizontal velocity and upward kick to all grounded players; plays looping quake sound every 0.5 s.
- Side effects: Mutates `e->velocity`, `e->groundentity` for all player edicts; `gi.positioned_sound`
- Calls: `gi.positioned_sound`, `crandom`
- Notes: Upward impulse is `speed * (100 / mass)`, making lighter entities fly higher.

## Control Flow Notes
All entities here are purely **reactive** (use-callback driven) or **think-driven** (laser, lightramp, earthquake). Spawn functions run during map load (`SP_*`). Use callbacks fire when another entity targets them. Think functions self-reschedule via `nextthink = level.time + FRAMETIME` and are ticked by the server's `G_RunFrame` entity loop.

## External Dependencies
- `g_local.h` — all engine/game types, constants, macros
- `G_UseTargets`, `G_FreeEdict`, `G_Spawn`, `G_SetMovedir`, `G_Find`, `KillBox` — entity utilities (defined in `g_utils.c`)
- `T_Damage`, `T_RadiusDamage` — damage system (`g_combat.c`)
- `BeginIntermission` — level transition (`p_hud.c` / `g_main.c`)
- `fire_blaster` — projectile code (`p_weapon.c`)
- `ED_CallSpawn` — entity spawner dispatcher (declared extern, defined in `g_spawn.c`)
- `gi.*` — engine game import API (server interface)
- `level`, `game`, `g_edicts`, `globals` — global state defined in `g_main.c`
