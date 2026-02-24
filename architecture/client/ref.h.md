# client/ref.h

## File Purpose
Defines the ABI contract between the Quake 2 engine client and dynamically loaded renderer (refresh) modules. It declares all shared data structures passed to the renderer and the two-sided function-pointer tables that form the renderer plugin interface.

## Core Responsibilities
- Define scene-object types (`entity_t`, `dlight_t`, `particle_t`, `lightstyle_t`, `refdef_t`) passed per-frame to the renderer
- Declare `refexport_t`: the function table the renderer DLL exposes to the engine
- Declare `refimport_t`: the function table the engine exposes to the renderer DLL
- Define the single exported linker symbol type `GetRefAPI_t` used to bootstrap the renderer
- Provide palette index constants for player powersuit shell effects
- Set capacity limits for scene objects (`MAX_DLIGHTS`, `MAX_ENTITIES`, etc.)

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `entity_t` | struct | Renderable world/game entity: model, position, frame, lerp state, skin, flags |
| `dlight_t` | struct | Dynamic point light: origin, RGB color, intensity radius |
| `particle_t` | struct | Single particle: origin, palette color index, alpha |
| `lightstyle_t` | struct | Animated light style value: RGB floats (0–2) + pre-computed white peak |
| `refdef_t` | struct | Complete per-frame scene descriptor passed to `RenderFrame` |
| `refexport_t` | struct | Function pointer table exported by renderer DLL to the engine |
| `refimport_t` | struct | Function pointer table exported by engine to the renderer DLL |
| `GetRefAPI_t` | typedef | Type of the single DLL entry point: `refexport_t GetRefAPI(refimport_t)` |

## Global / File-Static State
None.

## Key Functions
No function definitions in this header. All callable interfaces are expressed as function-pointer fields within `refexport_t` and `refimport_t`.

**`refexport_t` entry points (renderer → engine calls):**
- `Init` / `Shutdown` — library lifecycle
- `BeginRegistration` / `RegisterModel` / `RegisterSkin` / `RegisterPic` / `SetSky` / `EndRegistration` — asset registration phase before level rendering
- `RenderFrame(refdef_t*)` — submit a full scene for rendering
- `DrawPic`, `DrawStretchPic`, `DrawChar`, `DrawTileClear`, `DrawFill`, `DrawFadeScreen`, `DrawStretchRaw` — 2-D HUD/cinematic drawing
- `BeginFrame` / `EndFrame` — frame bracket with stereo separation support
- `CinematicSetPalette` — swap palette for cinematic playback
- `AppActivate` — focus/minimize notification

**`refimport_t` entry points (engine → renderer calls):**
- `Sys_Error`, `Con_Printf` — error reporting and console output
- `Cmd_*` — command registration and argument parsing
- `FS_LoadFile` / `FS_FreeFile` / `FS_Gamedir` — filesystem access
- `Cvar_Get` / `Cvar_Set` / `Cvar_SetValue` — console variable access
- `Vid_GetModeInfo` / `Vid_MenuInit` / `Vid_NewWindow` — video mode management callbacks

## Control Flow Notes
- At startup, the client loads a renderer DLL and calls its single exported `GetRefAPI(refimport_t)` function, receiving a populated `refexport_t` in return.
- Each rendered frame: client populates a `refdef_t` (entities, dlights, particles, lightstyles, view parameters) then calls `refexport_t.RenderFrame`.
- Level load path: `BeginRegistration` → register assets → `EndRegistration`; pointers from a prior registration become invalid after `EndRegistration`.

## External Dependencies
- `../qcommon/qcommon.h` — pulls in `vec3_t`, `byte`, `qboolean`, `cvar_t`, and shared constants
- `model_s`, `image_s` — opaque forward-declared types; defined inside each renderer module, not visible to the client
- All `refexport_t` implementations reside in `ref_gl/` or `ref_soft/` renderer modules (defined elsewhere)
- All `refimport_t` implementations reside in the engine client/common layer (defined elsewhere)
