# client/cl_view.c

## File Purpose
Manages the client-side view rendering pipeline, assembling the render scene (entities, particles, dynamic lights, light styles) into a `refdef` structure each frame and dispatching it to the renderer. Also handles level precaching/registration and development/debugging view tools.

## Core Responsibilities
- Maintain and clear per-frame render lists (entities, particles, dynamic lights, light styles)
- Expose `V_Add*` helpers for other client subsystems to populate those lists
- Assemble `cl.refdef` and invoke `re.RenderFrame` each frame via `V_RenderView`
- Precache all level assets (models, images, skins, sky) in `CL_PrepRefresh`
- Compute vertical FOV from horizontal FOV and viewport dimensions
- Provide developer test modes (test particles, entities, lights, blend)
- Register debug console commands (`gun_next`, `gun_prev`, `gun_model`, `viewpos`)

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `dlight_t` | struct | Dynamic light: origin, intensity, RGB color |
| `entity_t` | struct | Renderable entity: model, skin, origin, etc. |
| `particle_t` | struct | Particle: origin, palette color index, alpha |
| `lightstyle_t` | struct | Light style: RGB + white (sum) scalar |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `gun_frame` | `int` | global | Debug: manual weapon animation frame override |
| `gun_model` | `struct model_s *` | global | Debug: weapon model override |
| `crosshair` | `cvar_t *` | global | Crosshair enable/style cvar |
| `cl_testparticles/entities/lights/blend` | `cvar_t *` | global | Per-category render test mode cvars |
| `cl_stats` | `cvar_t *` | global | Enables per-frame render stats output |
| `r_numdlights` | `int` | global | Count of active dynamic lights this frame |
| `r_dlights[MAX_DLIGHTS]` | `dlight_t[]` | global | Dynamic light list passed to renderer |
| `r_numentities` | `int` | global | Count of entities this frame |
| `r_entities[MAX_ENTITIES]` | `entity_t[]` | global | Entity list passed to renderer |
| `r_numparticles` | `int` | global | Count of particles this frame |
| `r_particles[MAX_PARTICLES]` | `particle_t[]` | global | Particle list passed to renderer |
| `r_lightstyles[MAX_LIGHTSTYLES]` | `lightstyle_t[]` | global | Light style table passed to renderer |
| `cl_weaponmodels` | `char[][MAX_QPATH]` | global | Weapon model name list (prefixed `#` in configstrings) |
| `num_cl_weaponmodels` | `int` | global | Count of registered weapon models |

## Key Functions

### V_ClearScene
- Signature: `void V_ClearScene(void)`
- Purpose: Resets per-frame render list counters to zero before repopulation.
- Inputs: None
- Outputs/Return: None
- Side effects: Zeroes `r_numdlights`, `r_numentities`, `r_numparticles`
- Calls: None
- Notes: Must be called once at the start of each rendered frame.

### V_AddEntity / V_AddParticle / V_AddLight / V_AddLightStyle
- **V_AddEntity**: Appends a copy of `*ent` into `r_entities[]`; silently drops if at capacity.
- **V_AddParticle**: Appends origin/color/alpha into `r_particles[]`.
- **V_AddLight**: Appends origin/intensity/RGB into `r_dlights[]`.
- **V_AddLightStyle**: Writes directly to `r_lightstyles[style]` by index; calls `Com_Error` on out-of-range style.

### CL_PrepRefresh
- Signature: `void CL_PrepRefresh(void)`
- Purpose: Full asset registration pass when entering a new map or reloading the renderer DLL.
- Inputs: `cl.configstrings` (models, images, player skins, sky, CD track)
- Outputs/Return: Sets `cl.refresh_prepped = true`, `cl.force_refdef = true`
- Side effects: Calls `re.BeginRegistration`/`re.EndRegistration`, populates `cl.model_draw[]`, `cl.model_clip[]`, `cl.image_precache[]`; starts CD audio track; marks screen dirty
- Calls: `SCR_AddDirtyPoint`, `SCR_UpdateScreen`, `re.BeginRegistration`, `SCR_TouchPics`, `CL_RegisterTEntModels`, `re.RegisterModel`, `CM_InlineModel`, `re.RegisterPic`, `CL_ParseClientinfo`, `CL_LoadClientinfo`, `re.SetSky`, `re.EndRegistration`, `Con_ClearNotify`, `CDAudio_Play`
- Notes: Early-outs if `CS_MODELS+1` configstring is empty. Weapon models identified by `#` prefix are stored in `cl_weaponmodels[]` rather than registered immediately.

### CalcFov
- Signature: `float CalcFov(float fov_x, float width, float height)`
- Purpose: Derives vertical FOV from horizontal FOV and viewport aspect ratio using trigonometry.
- Inputs: Horizontal FOV in degrees, viewport width and height in pixels
- Outputs/Return: Vertical FOV in degrees
- Side effects: `Com_Error` if `fov_x` outside [1, 179]
- Calls: `tan`, `atan`, `Com_Error`

### V_RenderView
- Signature: `void V_RenderView(float stereo_separation)`
- Purpose: Per-frame entry point: builds `cl.refdef`, optionally applies stereo offset, submits to renderer.
- Inputs: `stereo_separation` — lateral eye offset for stereo rendering (0 = mono)
- Outputs/Return: None
- Side effects: Updates `cl.refdef`, calls `re.RenderFrame`, logs stats, marks dirty screen rect, draws crosshair
- Calls: `V_ClearScene`, `CL_AddEntities`, `V_TestParticles/Entities/Lights`, `CalcFov`, `re.RenderFrame`, `SCR_AddDirtyPoint`, `SCR_DrawCrosshair`, `qsort`
- Notes: Skips refdef rebuild if frame is invalid or `cl_paused` is set; applies `1/16` unit jitter to `vieworg` to avoid node-plane z-fighting.

### V_Init
- Signature: `void V_Init(void)`
- Purpose: Registers debug console commands and initialises all cvars owned by this file.
- Inputs: None
- Outputs/Return: None
- Side effects: Registers `gun_next`, `gun_prev`, `gun_model`, `viewpos` commands; initialises cvars
- Calls: `Cmd_AddCommand`, `Cvar_Get`

## Control Flow Notes
- **Init**: `V_Init` is called once during client startup.
- **Level load**: `CL_PrepRefresh` is called before the first frame of a new map.
- **Per-frame**: `V_RenderView` is the render-loop entry point called from `SCR_UpdateScreen`/`CL_Frame`. It drives `V_ClearScene → CL_AddEntities → re.RenderFrame`.
- `V_Add*` functions are called from `cl_ents.c`, `cl_fx.c`, `cl_tent.c`, and similar subsystems during `CL_AddEntities`.

## External Dependencies
- `client.h` — pulls in `client_state_t cl`, `client_static_t cls`, screen/viewport globals, `re` renderer interface
- `re.*` — renderer DLL interface (`RenderFrame`, `RegisterModel`, `RegisterPic`, `BeginRegistration`, `EndRegistration`, `SetSky`, `DrawPic`) — defined in renderer DLL
- `CL_AddEntities`, `CL_ParseClientinfo`, `CL_LoadClientinfo`, `CL_RegisterTEntModels` — defined in `cl_ents.c` / `cl_parse.c`
- `CM_InlineModel` — defined in `qcommon/cmodel.c`
- `SCR_*`, `Con_ClearNotify`, `CDAudio_Play`, `Sys_Milliseconds`, `Sys_SendKeyEvents` — defined elsewhere in client/common layer
