# ref_soft/r_part.c

## File Purpose
Implements software-renderer particle drawing for the Quake 2 ref_soft renderer. Each particle is projected into screen space, z-tested, alpha-blended, and rasterized as a screen-aligned square of variable pixel size. Provides both an x86 assembly fast path and a portable C reference implementation.

## Core Responsibilities
- Transform particle world-space origins into camera/screen space using view basis vectors
- Z-clip and screen-clip each particle before rasterization
- Select a blend function (33%, 66%, or 100% opaque) based on particle alpha
- Compute screen-space pixel size scaled by inverse-Z
- Z-buffer test and write per pixel (writes guarded by `ENABLE_ZWRITES_FOR_PARTICLES`)
- Write blended color values into the 8-bit framebuffer
- Iterate over the full particle list in `R_DrawParticles`

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `partparms_t` | struct | Passes particle pointer, blend level, and color to `R_DrawParticle` via file-static |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `r_pright` | `vec3_t` | global | Scaled right view basis vector for particle projection |
| `r_pup` | `vec3_t` | global | Scaled up view basis vector for particle projection |
| `r_ppn` | `vec3_t` | global | Forward view basis vector for particle projection |
| `partparms` | `static partparms_t` | static | Shared parameter block passed to `R_DrawParticle` |
| `s_prefetch_address` | `static unsigned` | static | x86-only: address of next particle to prefetch |

## Key Functions

### R_DrawParticles
- Signature: `void R_DrawParticles(void)`
- Purpose: Entry point; iterates all particles in `r_newrefdef`, sets blend level from `p->alpha`, populates `partparms`, and calls `R_DrawParticle` per particle.
- Inputs: None (reads `r_newrefdef.particles`, `r_newrefdef.num_particles`)
- Outputs/Return: void
- Side effects: Writes `r_pright`, `r_pup`, `r_ppn`; modifies framebuffer and z-buffer indirectly via `R_DrawParticle`; on x86 non-Linux, switches FPU to single-precision-24 rounding mode and restores chop mode after the loop
- Calls: `VectorScale`, `VectorCopy`, `R_DrawParticle`
- Notes: `s_prefetch_address` is set to next particle's address to hint a prefetch load in the asm path; wraps around to list start on final particle

### R_DrawParticle (C path)
- Signature: `void R_DrawParticle(void)`
- Purpose: Projects one particle, clips it, selects blend mode, and rasterizes a `pix × pix` screen block using z-test and alpha blending.
- Inputs: Reads `partparms` (particle pointer, level, color)
- Outputs/Return: void; early-return on z-clip or screen-clip failure
- Side effects: Writes to `d_pzbuffer` and `d_viewbuffer`
- Calls: `VectorSubtract`, `DotProduct`; inline `vid.alphamap` lookups
- Notes: `pix` is derived from `izi >> d_pix_shift`, clamped to `[d_pix_min, d_pix_max]`; the switch-on-level unrolls the inner blend inline (bypassing the function pointer) for cache efficiency; comments note z-writes are always performed in C path despite the `ENABLE_ZWRITES_FOR_PARTICLES` guard existing only in asm

### BlendParticle33 / BlendParticle66 / BlendParticle100 (C path)
- Trivial helpers: index `vid.alphamap` for 33% and 66% alpha blends; `BlendParticle100` is an identity returning `pcolor`. Only used via function pointer in the asm path; the C `R_DrawParticle` inlines equivalent logic directly in the switch.

### R_DrawParticle (x86 asm path)
- Signature: `__declspec(naked) void R_DrawParticle(void)` — no stack frame
- Purpose: High-performance MSVC inline-asm equivalent of the C version; stores locals as file-statics to avoid needing a stack frame; uses `s_prefetch_address` to preload the next particle during the 1/z divide latency.
- Notes: Uses `fpu_sp24_cw` precision mode set by the caller; `ENABLE_ZWRITES_FOR_PARTICLES` macro gates z-buffer writes; `blendfunc` is a static function pointer set each call.

## Control Flow Notes
- **Frame update**: `R_DrawParticles` is called once per frame during the render pass after world geometry.
- **Per-particle**: `R_DrawParticles` → `R_DrawParticle` → blend + rasterize into framebuffer.
- No init or shutdown involvement.

## External Dependencies
- `r_local.h` — renderer globals (`d_pzbuffer`, `d_viewbuffer`, `d_scantable`, `d_zwidth`, `xcenter`, `ycenter`, `r_newrefdef`, `r_origin`, `vright`, `vup`, `vpn`, `xscaleshrink`, `yscaleshrink`, `d_vrect*`, `d_pix_*`, `r_screenwidth`, `PARTICLE_Z_CLIP`)
- `vid.alphamap` — 256×256 precomputed alpha blend table (defined in platform vid layer)
- `fpu_sp24_cw`, `fpu_chop_cw` — FPU control words (defined elsewhere, x86 only)
