# Architecture Overview

## Repository Shape

- **Language:** C (primary); x86 AT&T/Intel assembly (inner loops for software renderer and audio mixer)
- **Engine type:** id Software Quake 2 — BSP world, MD2 alias models, plugin-style renderer and game DLLs
- **Top-level directories:**
  - `qcommon/` — shared engine core: command buffer, cvar, VFS, collision model, network channel, player movement, CRC/MD4
  - `client/` — client subsystem: main loop, input, prediction, parsing, effects, sound, UI, cinematic
  - `server/` — server subsystem: main loop, world spatial, entity encoding, client messaging, operator commands
  - `game/` — base game DLL: entities, AI, physics, weapons, players, save/load
  - `ctf/` — CTF game DLL: fork of `game/` extended with flag logic, grapple, team assignment, in-game menus
  - `ref_gl/` — OpenGL renderer plugin (dynamically loaded at runtime)
  - `ref_soft/` — software rasterizer plugin (dynamically loaded at runtime)
  - `win32/` — Windows platform layer (WinSock, DirectSound, DirectDraw, WGL, `WinMain`)
  - `linux/` — Linux platform layer (POSIX sockets, OSS audio, X11/SVGAlib display, ELF DL)
  - `irix/` — IRIX/SGI platform layer (AL audio, GLX display, MIPS DL)
  - `solaris/` — Solaris platform layer (POSIX sockets, POSIX file I/O)
  - `null/` — stub/no-op implementations for headless or porting builds
  - `rhapsody/` — early Rhapsody/Mac OS X port (not analyzed in depth)
  - `baseq2/` — game asset directory (config, not engine source)

---

## Major Subsystems

### Engine Core (`qcommon/`)
- **Purpose:** Shared infrastructure used by both client and server. Provides the glue between all subsystems.
- **Key directories / files:** `qcommon/common.c`, `qcommon/cmd.c`, `qcommon/cvar.c`, `qcommon/files.c`, `qcommon/net_chan.c`, `qcommon/cmodel.c`, `qcommon/pmove.c`, `qcommon/qcommon.h`, `qcommon/qfiles.h`, `qcommon/md4.c`, `qcommon/crc.c`
- **Key responsibilities:**
  - Engine lifecycle: `Qcommon_Init`, `Qcommon_Frame`, `Qcommon_Shutdown`
  - Zone heap allocator (`Z_*`) and growable byte buffers (`SZ_*`)
  - Network message serialization/deserialization (`MSG_*`)
  - Console variable system (`Cvar_*`)
  - Command buffer and execution (`Cbuf_*`, `Cmd_*`)
  - Virtual filesystem over directories and PAK archives (`FS_*`)
  - BSP collision model: traces, PVS/PHS, area portal connectivity (`CM_*`)
  - Reliable-over-UDP channel protocol (`Netchan_*`)
  - Shared player movement simulation (`Pmove`) — executed on both client (prediction) and server
  - CRC-16 and MD4 block checksums for data integrity
- **Key dependencies:** `game/q_shared.h` (shared types), platform `Sys_*` functions, `client/` and `server/` subsystems (called from `Qcommon_Frame`)

---

### Client Subsystem (`client/`)
- **Purpose:** Drives all client-side game logic: connection management, input, prediction, network parsing, visual effects, audio, and UI rendering.
- **Key directories / files:** `client/cl_main.c`, `client/cl_input.c`, `client/cl_parse.c`, `client/cl_ents.c`, `client/cl_pred.c`, `client/cl_fx.c`, `client/cl_newfx.c`, `client/cl_tent.c`, `client/cl_view.c`, `client/cl_scrn.c`, `client/cl_cin.c`, `client/cl_inv.c`, `client/console.c`, `client/keys.c`, `client/menu.c`, `client/qmenu.c`, `client/snd_dma.c`, `client/snd_mem.c`, `client/snd_mix.c`, `client/client.h`, `client/ref.h`, `client/sound.h`, `client/keys.h`, `client/vid.h`, `client/screen.h`
- **Key responsibilities:**
  - Connection state machine (disconnected → connecting → connected → active)
  - Per-frame orchestration: input collection → `usercmd_t` assembly → send to server → receive server frame → prediction → render
  - Delta-decompression of server entity streams (`cl_ents.c`)
  - Client-side movement prediction via `Pmove` with error correction (`cl_pred.c`)
  - Parsing all `svc_*` server messages and dispatching configstrings, sounds, downloads (`cl_parse.c`)
  - Particle system, dynamic lights, light styles, and visual effects (`cl_fx.c`, `cl_newfx.c`, `cl_tent.c`)
  - View assembly: building `refdef_t` and invoking `re.RenderFrame` each frame (`cl_view.c`)
  - Screen compositor: HUD layout execution, console, crosshair, loading plaques, debug graphs (`cl_scrn.c`)
  - In-game console with circular text buffer, tab-completion, history (`console.c`)
  - Key binding and event routing (`keys.c`)
  - Full menu system with widget framework (`menu.c`, `qmenu.c`)
  - Sound system: DMA output, WAV loading/resampling, spatialization, mixing (`snd_dma.c`, `snd_mem.c`, `snd_mix.c`)
  - Cinematic playback: Huffman-compressed `.cin` video and PCX stills (`cl_cin.c`)
  - Inventory UI parsing and rendering (`cl_inv.c`)
  - Demo recording and playback
- **Key dependencies:** `qcommon/` (all), renderer DLL via `re` (`refexport_t` in `ref.h`), platform input (`IN_*`), platform video (`VID_*`), CD audio (`CDAudio_*`), game `q_shared.h`

---

### Server Subsystem (`server/`)
- **Purpose:** Runs the authoritative game simulation, manages connected clients, encodes world state for transmission, and bridges to the game DLL.
- **Key directories / files:** `server/sv_main.c`, `server/sv_init.c`, `server/sv_game.c`, `server/sv_ents.c`, `server/sv_send.c`, `server/sv_user.c`, `server/sv_world.c`, `server/sv_ccmds.c`, `server/server.h`
- **Key responsibilities:**
  - Per-frame server loop: receive client packets → run game DLL frame → encode and send world state
  - Connection handshake with challenge/response DoS mitigation
  - Configstring and entity baseline streaming to connecting clients
  - Delta-encoding entity and player state into network frames (`sv_ents.c`)
  - Fat PVS computation for entity visibility culling per client
  - World spatial database: 2D AABB BSP area tree, `SV_LinkEdict`/`SV_UnlinkEdict`, `SV_Trace`, `SV_AreaEdicts` (`sv_world.c`)
  - Game DLL interface: populates `game_import_t` vtable passed to game module (`sv_game.c`)
  - Operator console commands, savegame management, map cycling (`sv_ccmds.c`)
  - Rate-limited datagram delivery, multicast sound events, demo recording (`sv_send.c`)
  - File download serving, `begin`/`configstrings`/`baselines` handshake, `ClientCommand` dispatch (`sv_user.c`)
  - Master server registration and heartbeats
- **Key dependencies:** `qcommon/cmodel.c` (BSP collision), game DLL (`game_export_t ge`), `qcommon/net_chan.c`, `qcommon/files.c`

---

### Base Game DLL (`game/`)
- **Purpose:** Implements all gameplay logic as a separately-loaded shared library. Runs entirely server-side. Defines entities, AI, combat, physics, items, weapons, player mechanics, and serialization.
- **Key directories / files:** `game/g_main.c`, `game/g_local.h`, `game/game.h`, `game/g_ai.c`, `game/g_combat.c`, `game/g_phys.c`, `game/g_items.c`, `game/g_weapon.c`, `game/g_func.c`, `game/g_misc.c`, `game/g_monster.c`, `game/g_spawn.c`, `game/g_save.c`, `game/g_utils.c`, `game/g_target.c`, `game/g_trigger.c`, `game/g_turret.c`, `game/g_chase.c`, `game/g_svcmds.c`, `game/g_cmds.c`, `game/p_client.c`, `game/p_hud.c`, `game/p_trail.c`, `game/p_view.c`, `game/p_weapon.c`, `game/m_*.c` (monster implementations), `game/q_shared.c`, `game/q_shared.h`
- **Key responsibilities:**
  - DLL entry point `GetGameAPI` wiring `game_export_t` to engine
  - Per-frame entity loop (`G_RunFrame`) dispatching entity physics and think functions
  - Monster AI: target acquisition, sight/sound detection, attack decisions, locomotion, player trail pursuit
  - All monster type implementations (Berserk, Boss2, Jorg, Makron, Brain, Chick, Flipper, Floater, Flyer, Gladiator, Gunner, Hover, Infantry, Insane, Medic, Mutant, Parasite, Soldier, Supertank, Tank, Actor)
  - Damage pipeline: direct damage, radius damage, armor/power-armor absorption, knockback, kill accounting
  - Entity physics: pushmover, toss/bounce/fly, step-walk
  - Item registry (`itemlist[]`), pickup/use/drop/respawn lifecycle
  - Weapon state machines and firing logic (hitscan and projectile)
  - Player lifecycle: connect/spawn/respawn/die/disconnect, body queue, pmove integration
  - HUD stat population and deathmatch scoreboard
  - BSP entity spawning from map text, team linking, world entity initialization
  - Save/load system with pointer swizzling
  - Spectator chase camera
- **Key dependencies:** Engine via `game_import_t gi` (all engine I/O), `qcommon/pmove.c` (shared via `gi.Pmove`), `game/q_shared.h`

---

### CTF Game DLL (`ctf/`)
- **Purpose:** Alternate game DLL implementing ThreeWave Capture the Flag, forked from `game/` with CTF-specific gameplay additions. Loaded in place of the base game DLL when running CTF.
- **Key directories / files:** `ctf/g_ctf.c`, `ctf/g_ctf.h`, `ctf/g_local.h`, `ctf/g_main.c`, `ctf/p_client.c`, `ctf/p_hud.c`, `ctf/p_menu.c`, `ctf/p_menu.h`, `ctf/g_save.c`, `ctf/g_spawn.c`, and near-identical forks of all other `game/g_*.c` files
- **Key responsibilities:**
  - All base game responsibilities (see Base Game DLL), with the following additions:
  - Flag pickup, capture, drop, and auto-return logic
  - Team assignment, CTF skin assignment, team spawn selection
  - Grappling hook weapon simulation (fire, pull, cable rendering, reset)
  - Tech powerup system (quad, regen, resistance, haste, strength, etc.)
  - Match lifecycle management (SETUP → PREGAME → GAME → POST)
  - Election/voting system for admin, map changes, match requests
  - Ghost code system for reconnection score restoration
  - Per-client in-game HUD menus (join, admin, settings) rendered via `svc_layout`
  - CTF-specific HUD stats and scoreboard
- **Key dependencies:** Same as Base Game DLL; additionally `ctf/p_menu.c` (in-game HUD menus)

---

### OpenGL Renderer (`ref_gl/`)
- **Purpose:** Hardware-accelerated 3D renderer loaded as a DLL at runtime. Implements the `refexport_t` API and accepts a `refimport_t` from the engine.
- **Key directories / files:** `ref_gl/gl_rmain.c`, `ref_gl/gl_rsurf.c`, `ref_gl/gl_mesh.c`, `ref_gl/gl_model.c`, `ref_gl/gl_image.c`, `ref_gl/gl_light.c`, `ref_gl/gl_draw.c`, `ref_gl/gl_warp.c`, `ref_gl/gl_rmisc.c`, `ref_gl/gl_local.h`, `ref_gl/gl_model.h`, `ref_gl/qgl.h`, `ref_gl/anorms.h`, `ref_gl/anormtab.h`, `ref_gl/warpsin.h`
- **Key responsibilities:**
  - DLL entry point `GetRefAPI` returning `refexport_t`
  - Full 3D frame pipeline: frustum → BSP traversal → world surfaces → entities → dlights → particles → alpha surfaces → 2D overlays
  - BSP surface rendering with single-texture and SGIS multitexture lightmap paths
  - Lightmap atlas allocation, static + dynamic light accumulation
  - MD2 alias model rendering: frame interpolation, per-vertex lighting, GL command list dispatch, shadow projection
  - Sprite and beam entity rendering
  - Sky box rendering with UV clipping and optional rotation
  - Turbulent water/warp surface animation via sinusoidal UV distortion
  - Texture loading (PCX, TGA, WAL), scrap atlas packing, mipmap generation, GPU upload
  - OpenGL function pointer abstraction (`qgl*`) via `QGL_Init`/`QGL_Shutdown`
  - Optional per-call GL logging for debugging
- **Key dependencies:** Platform `GLimp_*` (context/window, defined in `win32/glw_imp.c` or `linux/qgl_linux.c`), engine `refimport_t ri` (VFS, cvars, console)

---

### Software Renderer (`ref_soft/`)
- **Purpose:** CPU-only rasterizer loaded as a DLL at runtime. Implements the same `refexport_t` API as `ref_gl`. Uses fixed-point arithmetic and x86 assembly inner loops for performance.
- **Key directories / files:** `ref_soft/r_main.c`, `ref_soft/r_local.h`, `ref_soft/r_model.c`, `ref_soft/r_model.h`, `ref_soft/r_edge.c`, `ref_soft/r_rast.c`, `ref_soft/r_surf.c`, `ref_soft/r_scan.c`, `ref_soft/r_alias.c`, `ref_soft/r_polyse.c`, `ref_soft/r_poly.c`, `ref_soft/r_bsp.c`, `ref_soft/r_light.c`, `ref_soft/r_image.c`, `ref_soft/r_draw.c`, `ref_soft/r_part.c`, `ref_soft/r_sprite.c`, `ref_soft/r_misc.c`, `ref_soft/asm_draw.h`, `ref_soft/d_ifacea.h`, plus assembly files (`r_aclipa.asm`, `r_edgea.asm`, `r_polysa.asm`, `r_scana.asm`, etc.)
- **Key responsibilities:**
  - DLL entry point `GetRefAPI` returning `refexport_t`
  - Active Edge Table (AET) algorithm for BSP surface visibility and painter's-algorithm ordering
  - Perspective-correct texture span rasterization in 8-bit paletted color
  - Per-surface linear lightmap cache (`surfcache`) with lightmap blending and mip selection
  - MD2 alias model rendering: per-vertex lighting, affine rasterization, clip/project pipeline
  - Polygon span fill with multiple blend modes (opaque, 33%/66% alpha, stipple, turbulent warp)
  - Particle rasterization with alpha blending against 8-bit framebuffer
  - 2D draw operations writing directly to `vid.buffer`
  - Sinusoidal full-screen warp distortion for liquid surfaces
  - Sky box geometry construction and rendering as fake BSP faces
  - Self-modifying x86 code patches for inner loop color table addresses (`LBPatch*`)
  - Assembly-language struct offset contracts (`asm_draw.h`, `d_ifacea.h`, `qasm.inc`) that must stay manually synchronized with C struct layouts
- **Key dependencies:** Platform `SWimp_*` (framebuffer, defined in `win32/rw_imp.c`, `linux/rw_x11.c`, etc.), engine `refimport_t ri`, x86 assembly runtime

---

### Sound System (`client/snd_*.c`)
- **Purpose:** Portable audio mixing layer with platform-specific DMA output backends.
- **Key directories / files:** `client/snd_dma.c`, `client/snd_mem.c`, `client/snd_mix.c`, `client/snd_loc.h`, `client/sound.h`, platform backends (`win32/snd_win.c`, `linux/snd_linux.c`, `irix/snd_irix.c`, `null/snddma_null.c`)
- **Key responsibilities:**
  - Sound registration and WAV loading/resampling to DMA output rate
  - Channel allocation and time-sorted `playsound_t` queue
  - Per-frame stereo spatialization (pan + distance attenuation)
  - Looped autosound generation from entity state
  - Raw PCM streaming for cinematics
  - Mixing paintbuffer → DMA output buffer in correct bit depth and channel count
  - Platform backends implement `SNDDMA_*` interface (OSS, DirectSound/WaveOut, SGI AL)
- **Key dependencies:** `client/client.h`, platform DMA backends, ASM mixer override (`linux/snd_mixa.s`) for x86 Linux

---

### Platform Layers (`win32/`, `linux/`, `irix/`, `solaris/`, `null/`)
- **Purpose:** OS-specific implementations of all `Sys_*`, hunk allocator, network, input, audio, and renderer window management interfaces. Provides a stable abstraction boundary so the engine core is platform-independent.
- **Key directories / files:**
  - Win32: `sys_win.c`, `vid_dll.c`, `in_win.c`, `net_wins.c`, `snd_win.c`, `glw_imp.c`, `qgl_win.c`, `rw_imp.c`, `rw_ddraw.c`, `rw_dib.c`, `winquake.h`
  - Linux: `sys_linux.c`, `vid_so.c`, `in_linux.c`, `net_udp.c`, `snd_linux.c`, `qgl_linux.c`, `rw_x11.c`, `rw_svgalib.c`, `rw_in_svgalib.c`
  - IRIX: `sys_irix.c`, `vid_so.c`, `snd_irix.c`, `glw_imp.c`, `qgl_irix.c`
  - Solaris: `sys_solaris.c`, `net_udp.c`
  - Null: all `null/*.c` stubs
- **Key responsibilities:**
  - Process entry point (`WinMain`/`main`), main loop, frame timing
  - Renderer DLL dynamic loading (`dlopen`/`LoadLibrary`) and `GetRefAPI` bootstrap
  - Game DLL dynamic loading (`dlopen`/`LoadLibrary`) and `GetGameAPI` bootstrap
  - Hunk (virtual) memory management (`VirtualAlloc`, `mmap`)
  - UDP socket creation, send/receive, loopback buffers
  - Input device management (mouse, keyboard, joystick)
  - Audio DMA buffer creation and playback position reporting
  - GL context creation and buffer swap (WGL on Win32, GLX on IRIX/Linux)
  - Software framebuffer presentation (DirectDraw, DIB, X11 SHM, SVGAlib)
- **Key dependencies:** Respective OS/hardware APIs; engine common via `qcommon.h`; renderer via `refimport_t` / `refexport_t`

---

## Key Runtime Flows

### Initialization

1. Platform entry point (`WinMain` / `main`) parses command line and calls `Qcommon_Init`.
2. `Qcommon_Init` initializes subsystems in order: zone allocator → command buffer → cvars → filesystem → network → collision model → server (`SV_Init`) → client (`CL_Init`).
3. `CL_Init` registers all client cvars, commands, initializes console, key system, menus, and calls the platform video init.
4. Platform video init (`VID_Init`) dynamically loads the renderer DLL, builds a `refimport_t` vtable, calls `GetRefAPI`, and stores the returned `refexport_t` as `re`.
5. When a map is loaded: `SV_InitGame` calls `SV_InitGameProgs`, which dynamically loads the game DLL, builds `game_import_t gi`, calls `GetGameAPI`, and stores `game_export_t* ge`. `ge->InitGame` is then called.
6. `SV_Map` calls `CM_LoadMap` (BSP collision load), `ge->SpawnEntities` (map entity parse and spawn), and establishes entity baselines.
7. Sound system initialized during `CL_Init`: `S_Init` opens platform DMA device (`SNDDMA_Init`).

### Per-frame / Main Loop

1. Platform calls `Qcommon_Frame(msec)` once per OS tick.
2. `Qcommon_Frame` calls `SV_Frame` then `CL_Frame`.
3. **Server frame** (`SV_Frame`):
   - Reads all incoming UDP packets; dispatches connectionless packets or routes to clients.
   - For each connected client: processes buffered `usercmd_t` commands via `ge->ClientThink`.
   - Calls `ge->RunFrame`: iterates all entities, runs physics (`G_RunEntity`) and think callbacks.
   - Calls `SV_SendClientMessages`: for each spawned client, builds a visibility frame (`SV_BuildClientFrame`), delta-encodes entity and player state (`SV_WriteFrameToClient`), and transmits via rate-limited netchan.
4. **Client frame** (`CL_Frame`):
   - Reads incoming server datagrams; `CL_ParseServerMessage` dispatches all `svc_*` messages.
   - `CL_SendCmd`: assembles `usercmd_t` from input state and sends to server.
   - `CL_PredictMovement`: reruns `Pmove` over unacknowledged commands to predict local position.
   - `SCR_UpdateScreen`: calls `V_RenderView` → `re.RenderFrame` to draw the 3D scene; then composites all 2D overlays.
   - `S_Update`: spatializes audio channels and drives the DMA mixing pipeline.

### Shutdown

1. `Sys_Quit` / `Sys_Error` triggers `Qcommon_Shutdown`.
2. `CL_Shutdown`: writes `config.cfg`, shuts down sound, stops renderer (`re.Shutdown`), unloads renderer DLL.
3. `SV_Shutdown`: broadcasts quit message to clients, calls `SV_ShutdownGameProgs` (calls `ge->Shutdown`, unloads game DLL).
4. Platform network and timer resources released.
5. Process exits.

---

## Data & Control Boundaries

- **Engine ↔ Game DLL:** Defined by `game/game.h`. The engine passes a `game_import_t` (function pointer table of ~50 engine services) to the game DLL via `GetGameAPI`. The game DLL returns a `game_export_t` (function pointer table of ~20 entry points plus `edict_t*` array). The server sees only opaque stub `edict_s`/`gclient_s` structs; the full layouts live only inside the game DLL behind `GAME_INCLUDE`.
- **Engine ↔ Renderer DLL:** Defined by `client/ref.h`. The engine passes `refimport_t` to the renderer via `GetRefAPI`; the renderer returns `refexport_t`. The renderer sees opaque `model_s`/`image_s` forward declarations; actual types are internal to each renderer module.
- **Client ↔ Server (network):** Protocol messages serialized into `sizebuf_t` and transmitted over `netchan_t` (reliable-over-UDP). Defined by opcode tables in `qcommon/qcommon.h` (`svc_*`, `clc_*`).
- **Client ↔ Server (shared code):** `pmove.c` is compiled into `qcommon` and called by both sides with identical inputs to ensure deterministic prediction. `q_shared.h` / `q_shared.c` are compiled separately into both the engine and each game DLL.
- **Game DLL global state:** `game_locals_t game`, `level_locals_t level`, `edict_t* g_edicts`, `gclient_t* game.clients` — owned entirely by the game DLL. The server accesses entities only through `ge->edicts` and `ge->num_edicts`.
- **Renderer global state:** All render state (model cache, texture cache, lightmaps, view globals) is owned by the renderer DLL. The engine accesses it exclusively through `re.*` function calls.
- **Resource lifetimes:** Model and texture registration is keyed by `registration_sequence` counter incremented at each `BeginRegistration`/`EndRegistration` cycle. Assets not referenced in the current sequence are evicted at `EndRegistration`. Hunk memory for map data is allocated on `BeginRegistration` and freed on the next.
- **Sound ownership:** `sfx_t` registry and channel pool owned by `snd_dma.c`. Entity sound origin resolution is a callback (`CL_GetEntitySoundOrigin`) from the sound system into the client entity state.

---

## Notable Risks / Hotspots

- **Assembly struct offset contracts:** `ref_soft/asm_draw.h`, `ref_soft/d_ifacea.h`, `linux/qasm.h`, `ref_soft/qasm.inc` mirror C struct field offsets as raw integer constants. There is no compile-time enforcement; any C struct layout change requires manual update of all mirroring files. Comments in the headers explicitly warn of this dependency.
- **Self-modifying x86 code in software renderer:** `client/block8.h`, `client/block16.h`, `ref_soft/block8.inc`, `ref_soft/block16.inc` use `0x12345678` placeholder addresses patched at runtime by the surrounding rasterizer. This is incompatible with non-executable data pages (modern W^X enforcement) and non-x86 targets.
- **CTF code duplication:** `ctf/` is a near-complete fork of `game/` (most files are described as "near-identical copies"). Divergence accumulates silently; bug fixes in `game/` are not automatically reflected in `ctf/`.
- **Monolithic `g_local.h`:** Both `game/g_local.h` and `ctf/g_local.h` expose the full `edict_s` and `gclient_s` definitions and declare every cross-file symbol in the game module. Any change to these structs requires recompilation of the entire game DLL and manual update of save-field descriptor tables in `g_save.c`.
- **Renderer DLL hot-reload:** The engine supports reloading the renderer DLL at runtime when `vid_ref` changes. This requires all renderer-held GPU resources to be cleanly destroyed and recreated; failure to do so on any code path would cause resource leaks or crashes.
- **Fixed-capacity arrays:** Multiple subsystems use fixed-size static arrays (e.g., `MAX_GLTEXTURES`, `MAX_CHANNELS`, `MAX_EDICTS`, surface cache `sc_rover`). Exhaustion silently drops content or triggers `Com_Error`.
- **x86-only fast paths:** Several performance-critical paths (software renderer inner loops, sound mixer, `BoxOnPlaneSide` in `q_shared.c`) have x86-specific assembly implementations that are compiled out on other architectures, with slower C fallbacks.
