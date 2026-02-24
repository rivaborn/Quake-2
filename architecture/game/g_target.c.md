# game/g_target.c

## File Purpose
Implements all `target_*` entities for the Quake 2 game logic layer. These are trigger-response objects spawned from map data that produce scripted gameplay events (sounds, explosions, level changes, lasers, etc.) when activated by other entities.

## Core Responsibilities
- Register spawn functions (`SP_*`) and use callbacks (`use_*` / `Use_*`) for each target entity type
- Produce client-side temporary entity events (multicast packets) for visual/audio effects
- Manage level state: secret/goal counters, intermission, cross-level serverflags
- Apply radius damage, laser beam tracing, and earthquake physics to world entities
- Handle looping/positional audio via `gi.sound` / `gi.positioned_sound`
- Deferred execution via `think`/`nextthink` for delayed effects (explosion, laser, lightramp, earthquake)

## Key Types / Data Structures
None — operates entirely on `edict_t` fields defined in `g_local.h`.

## Global / File-Static State
None defined in this file. Reads/writes `level`, `game`, `g_edicts`, `globals`, and cvars defined elsewhere.

## Key Functions

### Use_Target_Speaker
- Signature: `void Use_Target_Speaker(edict_t *ent, edict_t *other, edict_t *activator)`
- Purpose: Toggles a looping sound on/off, or plays a one-shot positional sound.
- Inputs: `ent` — speaker entity with `noise_index`, `volume`, `attenuation`, `spawnflags`.
- Outputs/Return: void
- Side effects: Modifies `ent->s.sound`; calls `gi.positioned_sound`.
- Calls: `gi.positioned_sound`
- Notes: Looping sounds (spawnflags & 3) use `s.sound` toggle; reliable sounds use `CHAN_RELIABLE`.

### SP_target_speaker
- Signature: `void SP_target_speaker(edict_t *ent)`
- Purpose: Validates and registers the speaker, caches sound index, pre-starts looping sound if flagged.
- Inputs: `st.noise`, `ent->volume`, `ent->attenuation`, `ent->spawnflags`.
- Outputs/Return: void
- Side effects: Sets `ent->noise_index`, `ent->volume`, `ent->attenuation`, `ent->s.sound`; calls `gi.linkentity`.
- Calls: `gi.soundindex`, `gi.linkentity`, `gi.dprintf`, `Com_sprintf`, `strncpy`
- Notes: `attenuation == -1` is mapped to 0 (global broadcast). Entity must be linked so the server tracks its PVS clusters.

### use_target_changelevel
- Signature: `void use_target_changelevel(edict_t *self, edict_t *other, edict_t *activator)`
- Purpose: Initiates level transition; enforces no-exit deathmatch rule; clears cross-level trigger flags for unit transitions.
- Inputs: `self->map`, `dmflags`, `deathmatch`, `coop`, `g_edicts[1]` (player 1 health).
- Outputs/Return: void
- Side effects: Calls `BeginIntermission`; may call `T_Damage`; modifies `game.serverflags`; broadcasts player name.
- Calls: `BeginIntermission`, `T_Damage`, `gi.bprintf`, `strstr`, `G_FreeEdict` (indirectly via damage)
- Notes: Guard against `level.intermissiontime` prevents double activation. Hardcoded map fix: `fact1 → fact3$secret1`.

### target_laser_think
- Signature: `void target_laser_think(edict_t *self)`
- Purpose: Per-frame laser beam trace; damages penetrable monsters, stops at solid/immune entities, emits spark effect on direction change.
- Inputs: `self->enemy`, `self->movedir`, `self->dmg`, `self->s.skinnum`.
- Outputs/Return: void
- Side effects: Calls `T_Damage` on hit entities; writes multicast temp-entity packets; updates `self->s.old_origin` and `self->nextthink`.
- Calls: `gi.trace`, `T_Damage`, `gi.WriteByte`, `gi.WritePosition`, `gi.WriteDir`, `gi.multicast`, `VectorMA`, `VectorNormalize`, `VectorSubtract`, `VectorCompare`
- Notes: Uses `0x80000000` spawnflag bit as internal "direction changed" dirty flag. Laser penetrates monsters but stops at solid non-monster geometry.

### target_earthquake_think
- Signature: `void target_earthquake_think(edict_t *self)`
- Purpose: Each frame during quake duration: plays rumble sound every 0.5 s and applies random velocity kicks to all grounded clients.
- Inputs: `self->speed`, `self->timestamp`, `self->noise_index`; iterates `g_edicts`.
- Outputs/Return: void
- Side effects: Modifies client `edict_t` velocity and `groundentity`; calls `gi.positioned_sound`.
- Calls: `gi.positioned_sound`, `crandom`
- Notes: Only affects entities with `e->client && e->groundentity`. Z-velocity scales by `speed / mass`.

### target_lightramp_think
- Signature: `void target_lightramp_think(edict_t *self)`
- Purpose: Advances a light style string one step per frame between two intensity levels.
- Inputs: `self->movedir` (start level, end level, step), `self->timestamp`, `self->speed`.
- Side effects: Calls `gi.configstring(CS_LIGHTS + style)`. TOGGLE flag reverses direction at completion.
- Calls: `gi.configstring`

### trigger_crosslevel_trigger_use / target_crosslevel_target_think
- Summarized: `trigger_crosslevel_trigger_use` ORs its spawnflags into `game.serverflags` then frees itself. `target_crosslevel_target_think` fires `G_UseTargets` if all required flags are set in `game.serverflags`, enabling cross-map trigger persistence within a unit.

## Control Flow Notes
- All `SP_*` functions run at map load time (called from `ED_CallSpawn`).
- Use callbacks fire during frame processing when another entity activates this target's `targetname`.
- Several entities defer work via `think`/`nextthink`: laser starts after 1 s delay (`target_laser_start`), explosion supports configurable delay, lightramp and earthquake tick each `FRAMETIME`.

## External Dependencies
- `g_local.h` — `edict_t`, `level`, `game`, `g_edicts`, `globals`, `st`, spawn flags, damage flags
- `gi` game import table — `WriteByte`, `WritePosition`, `WriteDir`, `multicast`, `positioned_sound`, `sound`, `soundindex`, `linkentity`, `unlinkentity`, `trace`, `configstring`, `dprintf`, `bprintf`
- Defined elsewhere: `T_Damage`, `T_RadiusDamage`, `G_UseTargets`, `G_FreeEdict`, `G_Spawn`, `G_Find`, `G_SetMovedir`, `KillBox`, `BeginIntermission`, `ED_CallSpawn`, `fire_blaster`, `VectorMA`, `VectorNormalize`, `crandom`, `vtos`, `Com_sprintf`, `Q_stricmp`
