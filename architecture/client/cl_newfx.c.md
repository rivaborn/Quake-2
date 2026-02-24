# client/cl_newfx.c

## File Purpose
Implements an extended set of client-side particle and dynamic light effects for Quake 2, supplementing `cl_fx.c`. Contains visual effects introduced for newer weapons and enemies (CTF, Widow, Tracker, Heatbeam, etc.), operating entirely on the client particle/light systems.

## Core Responsibilities
- Spawn and configure `cparticle_t` entries from the free-list for trails, explosions, shells, and ambient effects
- Allocate `cdlight_t` dynamic lights for flashlight and colored flash effects
- Provide sustain-callback effects (`cl_sustain_t`) that re-fire on a timer (steam, widow beam, nuke blast)
- Implement the Heatbeam visual (compile-time switchable between CORKSCREW, RINGS, and SPRAY variants; RINGS active)
- Provide utility `vectoangles2` for converting a direction vector to Euler angles (client-local copy)

## Key Types / Data Structures
None declared in this file; consumes types from `client.h`.

## Global / File-Static State
None owned by this file. All state is accessed via `extern` references.

| Name | Type | Scope (global/static) | Purpose |
|---|---|---|---|
| `active_particles` | `cparticle_t *` | global (extern) | Head of live particle linked list |
| `free_particles` | `cparticle_t *` | global (extern) | Head of free particle pool |
| `particles` | `cparticle_t[]` | global (extern) | Backing storage for all particles |
| `cl_numparticles` | `int` | global (extern) | Total particle pool size |
| `vid_ref` | `cvar_t *` | global (extern) | Used indirectly via `vidref_val` for renderer path checks |

## Key Functions

### CL_Flashlight
- Signature: `void CL_Flashlight(int ent, vec3_t pos)`
- Purpose: Creates a white dynamic light at `pos` tied to entity `ent`.
- Inputs: Entity number, world position.
- Outputs/Return: void
- Side effects: Calls `CL_AllocDlight`; mutates a `cdlight_t` entry.
- Calls: `CL_AllocDlight`, `VectorCopy`
- Notes: Fixed radius 400, minlight 250, 100ms lifetime.

### CL_ColorFlash
- Signature: `void CL_ColorFlash(vec3_t pos, int ent, int intensity, float r, float g, float b)`
- Purpose: Colored dynamic light flash; negates intensity/color for software renderer when any channel is negative.
- Inputs: Position, entity, intensity (radius), RGB channels.
- Outputs/Return: void
- Side effects: Allocates a `cdlight_t`.
- Calls: `CL_AllocDlight`, `VectorCopy`
- Notes: Software renderer path (`VIDREF_SOFT`) flips sign of negative-channel values.

### CL_Heatbeam
- Signature: `void CL_Heatbeam(vec3_t start, vec3_t forward)` (RINGS variant, active)
- Purpose: Renders the BFG/Heatbeam as animated rings of instant particles along the beam axis using camera right/up vectors.
- Inputs: Beam start, forward direction; extends 4096 units.
- Outputs/Return: void
- Side effects: Consumes up to ~20 rings × ~20 particles each from the free list per frame; reads `cl.v_right`, `cl.v_up`, `cl.time`; adjusts origin for GL vs. soft renderer.
- Calls: `VectorMA`, `VectorCopy`, `VectorSubtract`, `VectorNormalize`, `VectorScale`, `VectorAdd`, `VectorClear`, `fmod`, `cos`, `sin`
- Notes: `p->alphavel = -1000.0` acts as INSTANT_PARTICLE; stops after 5th ring. Two unused variants (CORKSCREW, SPRAY) are compiled out via `#ifdef`.

### CL_ParticleSteamEffect / CL_ParticleSteamEffect2
- Signature: `void CL_ParticleSteamEffect(vec3_t org, vec3_t dir, int color, int count, int magnitude)` / `void CL_ParticleSteamEffect2(cl_sustain_t *self)`
- Purpose: Directional steam puff burst. `...2` is the sustain callback variant that advances `nextthink`.
- Inputs: Origin, direction, palette color, count, magnitude. `...2` reads these from `cl_sustain_t`.
- Side effects: Allocates `count` particles; `...2` mutates `self->nextthink`.
- Calls: `MakeNormalVectors`, `VectorScale`, `VectorMA`, `VectorCopy`

### CL_Widowbeamout / CL_Nukeblast
- Signature: `void CL_Widowbeamout(cl_sustain_t *self)` / `void CL_Nukeblast(cl_sustain_t *self)`
- Purpose: Sustain callbacks that expand a shell of instant particles over time (300 and 700 particles/tick respectively) using a `ratio` derived from remaining endtime.
- Side effects: Heavy particle allocation; reads `cl.time`.
- Notes: Static `colortable[]` arrays for per-effect color palettes.

### Notes (minor helpers)
- `CL_DebugTrail`, `CL_SmokeTrail`, `CL_BlasterTrail2`, `CL_TagTrail`: step along a segment emitting spaced particles.
- `CL_ForceWall`: sparse vertical-falling particles along a segment (30% spawn chance).
- `CL_FlameEffects`: random count flame + smoke particles around an origin.
- `CL_BubbleTrail2`: controllable-density bubble trail, rising velocity.
- `CL_TrackerTrail`: sinusoidal up-offset trail using `cos(DotProduct)`.
- `CL_Tracker_Shell`, `CL_MonsterPlasma_Shell`: instant spherical shell bursts (300 / 40 particles).
- `CL_Tracker_Explode`, `CL_WidowSplash`: radial explosion bursts with outward velocity.
- `CL_GenericParticleEffect`, `CL_ColorExplosionParticles`, `CL_ParticleSmokeEffect`, `CL_BlasterParticles2`: general-purpose parameterized burst emitters.
- `vectoangles2`: local duplicate of server-side utility; converts `vec3_t` direction to pitch/yaw/roll.

## Control Flow Notes
All functions are called from `cl_fx.c` or the sustain system during the client frame update (`CL_RunParticles` / `CL_AddParticles`). Sustain callbacks (`...2`, `CL_Widowbeamout`, `CL_Nukeblast`) are registered in `cl_sustain_t` structures and invoked by the sustain ticker each frame. No init or shutdown logic is present in this file.

## External Dependencies
- `client.h` — `cparticle_t`, `cdlight_t`, `centity_t`, `cl_sustain_t`, `cl`, `vidref_val`, `PARTICLE_GRAVITY`, `INSTANT_PARTICLE`, `MAX_PARTICLES`, `VIDREF_GL`, `VIDREF_SOFT`
- `CL_AllocDlight` — defined in `cl_fx.c`
- `MakeNormalVectors` — defined in `cl_fx.c` (extern declared)
- `AngleVectors`, `VectorNormalize`, `VectorMA`, `DotProduct` — math utilities in `qcommon`
- `frand`, `crand` — random helpers defined elsewhere in client code
