# client/screen.h

## File Purpose
Public interface header for the Quake 2 screen/HUD subsystem. It declares all externally-visible screen management functions and shared global state that other client subsystems depend on.

## Core Responsibilities
- Declare screen lifecycle functions (init, update)
- Expose console sizing and positioning state
- Declare HUD/viewport geometry globals
- Expose crosshair state
- Declare dirty-region tracking API
- Declare the cinematic playback API (attributed to `scr_cin.c`)

## Key Types / Data Structures
None. (All types used here — `cvar_t`, `vrect_t` — are defined elsewhere.)

## Global / File-Static State

| Name | Type | Scope (global) | Purpose |
|---|---|---|---|
| `scr_con_current` | `float` | global | Current console drop animation position (0.0–1.0) |
| `scr_conlines` | `float` | global | Number of screen lines the console occupies |
| `sb_lines` | `int` | global | Number of lines occupied by the status bar (HUD) |
| `scr_viewsize` | `cvar_t *` | global | Cvar controlling the in-game viewport size percentage |
| `crosshair` | `cvar_t *` | global | Cvar controlling crosshair enable/style |
| `scr_vrect` | `vrect_t` | global | Rectangle defining the 3D render window position/size |
| `crosshair_pic` | `char[MAX_QPATH]` | global | Asset path of the current crosshair image |
| `crosshair_width` | `int` | global | Pixel width of loaded crosshair image |
| `crosshair_height` | `int` | global | Pixel height of loaded crosshair image |

## Key Functions

### SCR_Init
- **Signature:** `void SCR_Init(void)`
- **Purpose:** Initializes the screen subsystem (registers cvars, loads assets).
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** Registers console commands/cvars, loads crosshair pic.
- **Calls:** Not inferable from this file.
- **Notes:** Called once at engine startup.

### SCR_UpdateScreen
- **Signature:** `void SCR_UpdateScreen(void)`
- **Purpose:** Main per-frame screen compositing entry point — renders 3D view, HUD, console, menus, cinematics.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** Triggers full frame render and buffer swap.
- **Calls:** Not inferable from this file.
- **Notes:** Central render dispatch; called once per game frame.

### SCR_BeginLoadingPlaque / SCR_EndLoadingPlaque
- **Signature:** `void SCR_BeginLoadingPlaque(void)` / `void SCR_EndLoadingPlaque(void)`
- **Purpose:** Shows/hides the loading screen overlay during map transitions.
- **Side effects:** Suppresses normal rendering while active.

### SCR_CenterPrint
- **Signature:** `void SCR_CenterPrint(char *str)`
- **Purpose:** Queues a center-screen message for display (e.g., objective text).
- **Inputs:** `str` — null-terminated message string.

### SCR_AddDirtyPoint / SCR_DirtyScreen
- **Signature:** `void SCR_AddDirtyPoint(int x, int y)` / `void SCR_DirtyScreen(void)`
- **Purpose:** Mark screen regions as needing redraw; used by the software renderer's dirty-rectangle optimization.

### SCR_RunCinematic / SCR_DrawCinematic / SCR_PlayCinematic / SCR_StopCinematic / SCR_FinishCinematic
- **Purpose:** Full cinematic lifecycle — start, per-frame decode/draw, stop, and finalize (e.g., on map load completing). Implemented in `scr_cin.c`.

## Control Flow Notes
`SCR_Init` is called during client startup. `SCR_UpdateScreen` is called each frame from the main client loop, compositing all 2D and 3D layers. `SCR_RunConsole` is called per-frame to animate the console slide. Cinematic functions intercept the normal render path when a cinematic is active.

## External Dependencies
- `cvar_t` — defined in `qcommon/qcommon.h`
- `vrect_t` — defined in shared/renderer headers
- `MAX_QPATH` — defined in `game/q_shared.h`
- `qboolean` — defined in `game/q_shared.h`
- All function implementations defined in `client/cl_scrn.c` and `client/cl_cin.c`
