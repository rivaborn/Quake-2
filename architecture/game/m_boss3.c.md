# game/m_boss3.c

## File Purpose
Implements a static, non-combat boss3 entity (`monster_boss3_stand`) that plays a looping idle animation in place and teleports away when triggered. It serves as a scripted cinematic/decorative monster presence rather than an AI combatant.

## Core Responsibilities
- Spawn the boss3 stand entity with correct model, bounding box, and initial frame
- Loop the boss3 stand animation across frames `FRAME_stand201`–`FRAME_stand260`
- Handle a use/trigger event that broadcasts a teleport visual effect and frees the entity

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions

### Use_Boss3
- **Signature:** `void Use_Boss3(edict_t *ent, edict_t *other, edict_t *activator)`
- **Purpose:** Trigger callback — emits a boss teleport effect at the entity's position then removes the entity.
- **Inputs:** `ent` — the boss3 entity; `other`, `activator` — unused trigger chain participants.
- **Outputs/Return:** void
- **Side effects:** Writes a `TE_BOSSTPORT` temp entity message via `gi.WriteByte`/`gi.WritePosition`, multicasts it to all clients in PVS, then frees `ent` via `G_FreeEdict`.
- **Calls:** `gi.WriteByte`, `gi.WritePosition`, `gi.multicast`, `G_FreeEdict`
- **Notes:** `other` and `activator` are never read; entity is unconditionally destroyed after teleport effect.

### Think_Boss3Stand
- **Signature:** `void Think_Boss3Stand(edict_t *ent)`
- **Purpose:** Per-frame think callback that advances the stand animation, looping from `FRAME_stand260` back to `FRAME_stand201`.
- **Inputs:** `ent` — the boss3 entity.
- **Outputs/Return:** void
- **Side effects:** Mutates `ent->s.frame` and reschedules `ent->nextthink` at `level.time + FRAMETIME`.
- **Calls:** None (direct field mutation only).
- **Notes:** Animation loop is 60 frames (`stand201`–`stand260`). Runs every game frame via `nextthink`.

### SP_monster_boss3_stand
- **Signature:** `void SP_monster_boss3_stand(edict_t *self)`
- **Purpose:** Spawn function registered to the `monster_boss3_stand` map entity. Configures physics, model, bounding box, callbacks, and links the entity into the world.
- **Inputs:** `self` — the newly allocated entity from the map.
- **Outputs/Return:** void
- **Side effects:** Sets numerous fields on `self`; calls `gi.modelindex` and `gi.soundindex` to precache assets; calls `gi.linkentity` to register the entity with the world.
- **Calls:** `G_FreeEdict`, `gi.modelindex`, `gi.soundindex`, `VectorSet`, `gi.linkentity`
- **Notes:** Immediately frees the entity and returns if `deathmatch` is active — this entity is singleplayer-only. Sound `misc/bigtele.wav` is precached here but played client-side via the temp entity, not directly.

## Control Flow Notes
- **Spawn:** `SP_monster_boss3_stand` is called by the game's entity spawn system on map load.
- **Frame update:** `Think_Boss3Stand` is rescheduled each frame via `nextthink`, driving the animation loop indefinitely.
- **Triggered:** When a map trigger targets this entity, `Use_Boss3` fires, emits the teleport effect, and removes the entity — ending all further think scheduling.
- No AI, pathfinding, or combat participation; entirely passive until triggered.

## External Dependencies
- **Includes:** `g_local.h` (game types, `edict_t`, `gi`, `level`, `FRAMETIME`, `G_FreeEdict`, `MOVETYPE_*`, `SOLID_*`, `MULTICAST_PVS`, `TE_BOSSTPORT`, `svc_temp_entity`, `VectorSet`), `m_boss32.h` (animation frame constants `FRAME_stand201`, `FRAME_stand260`)
- **Defined elsewhere:** `gi` (game import vtable), `level` (global level state), `deathmatch` (cvar), `G_FreeEdict`, `VectorSet`
