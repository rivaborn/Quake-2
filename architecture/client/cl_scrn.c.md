# client/cl_scrn.c

## File Purpose
Master screen compositor for the Quake 2 client. Orchestrates every per-frame 2D overlay (HUD, console, center print, loading plaque, debug graphs) and drives the renderer's frame begin/end cycle. Acts as the top-level coordinator between all client subsystems that produce visible output.

## Core Responsibilities
- Initialize and manage screen-related cvars and console commands
- Drive `SCR_UpdateScreen`, the single entry point for all rendering each frame
- Animate the drop-down console (`SCR_RunConsole`)
- Render the HUD via a server-supplied layout string (`SCR_ExecuteLayoutString`)
- Maintain the dirty-rectangle system for background tile clearing
- Display center-print messages, pause overlay, loading plaque, and network/debug graphs
- Handle stereoscopic rendering (dual-frame separation pass)

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `dirty_t` | struct | Axis-aligned bounding rect (`x1,y1,x2,y2`) tracking screen regions needing tile repaint |
| `graphsamp_t` | struct | Single debug-graph sample: float `value` + palette `color` index |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `scr_con_current` | `float` | global | Current animated console height (0.0–1.0) |
| `scr_conlines` | `float` | global | Target console height this frame |
| `scr_initialized` | `qboolean` | global | Guards `SCR_UpdateScreen` until init completes |
| `scr_draw_loading` | `int` | global | 0=none, 1=loading pic, 2=black+loading pic |
| `scr_vrect` | `vrect_t` | global | Pixel rect of the 3D render viewport |
| `scr_dirty`, `scr_old_dirty[2]` | `dirty_t` | global | Rolling 3-frame dirty-rect history for triple-buffer tile clear |
| `current`, `values[1024]` | `int`, `graphsamp_t[]` | static | Circular buffer for debug/net/time graph samples |
| `scr_centerstring[1024]` | `char[]` | global | Text of current center-print message |
| `scr_centertime_off` | `float` | global | Remaining display time for center print |
| `sb_nums[2][11]` | `char*[][]` | global | Pic name table for HUD numeric digit sprites (normal + alternate color) |
| `crosshair_pic`, `crosshair_width/height` | `char[]`, `int` | global | Cached crosshair image name and dimensions |

## Key Functions

### SCR_Init
- **Signature:** `void SCR_Init(void)`
- **Purpose:** Registers all screen cvars and console commands; marks subsystem ready.
- **Inputs:** None
- **Outputs/Return:** void; sets `scr_initialized = true`
- **Side effects:** Registers 13 cvars, 5 commands via `Cvar_Get`/`Cmd_AddCommand`
- **Calls:** `Cvar_Get`, `Cmd_AddCommand`
- **Notes:** Must be called before `SCR_UpdateScreen` is safe.

### SCR_UpdateScreen
- **Signature:** `void SCR_UpdateScreen(void)`
- **Purpose:** Per-frame master compositor. Handles stereo loop, all rendering states (cinematic, loading, normal game), and calls `re.EndFrame`.
- **Inputs:** None (reads global `cls`, `cl`, cvars)
- **Outputs/Return:** void
- **Side effects:** Drives entire render pipeline; calls into renderer (`re.*`), menu, console, view
- **Calls:** `re.BeginFrame`, `re.EndFrame`, `re.CinematicSetPalette`, `SCR_CalcVrect`, `SCR_TileClear`, `V_RenderView`, `SCR_DrawStats`, `SCR_DrawLayout`, `CL_DrawInventory`, `SCR_DrawNet`, `SCR_CheckDrawCenterString`, `SCR_DrawDebugGraph`, `SCR_DrawPause`, `SCR_DrawConsole`, `M_Draw`, `SCR_DrawLoading`
- **Notes:** Bails early if `cls.disable_screen` is set (loading plaque timeout = 120 s). Stereo separation clamped to [0, 1].

### SCR_ExecuteLayoutString
- **Signature:** `void SCR_ExecuteLayoutString(char *s)`
- **Purpose:** Interprets a server-supplied token-based layout script to render HUD elements (pics, numbers, strings, client blocks).
- **Inputs:** Layout script string `s`
- **Outputs/Return:** void
- **Side effects:** Calls `re.DrawPic`, `re.DrawChar`, `SCR_DrawField`, `DrawString`, `DrawAltString`, `DrawHUDString`; marks dirty points
- **Calls:** `COM_Parse`, `SCR_AddDirtyPoint`, `SCR_DrawField`, `re.DrawPic`, `DrawString`, `DrawAltString`, `DrawHUDString`, `Com_Error`
- **Notes:** Supports `xl/xr/xv/yt/yb/yv` positioning, `pic/picn/num/hnum/anum/rnum/stat_string/cstring/string/client/ctf/if-endif`. `if` token skips to `endif` when stat is zero.

### SCR_TileClear
- **Signature:** `void SCR_TileClear(void)`
- **Purpose:** Repaints tiled background (`backtile`) in any screen area outside the 3D viewport that was dirty over the last 3 frames.
- **Inputs:** None
- **Outputs/Return:** void
- **Side effects:** Issues up to 4 `re.DrawTileClear` calls; rotates `scr_old_dirty` history
- **Calls:** `SCR_DirtyScreen`, `re.DrawTileClear`
- **Notes:** Early-outs for full-screen console, 100% viewsize, or active cinematic. Union of 3 frames handles triple-buffering.

### SCR_RunConsole
- **Signature:** `void SCR_RunConsole(void)`
- **Purpose:** Smoothly animates `scr_con_current` toward target height (0.5 when console active, 0 otherwise).
- **Inputs:** None (reads `cls.key_dest`, `scr_conspeed`, `cls.frametime`)
- **Outputs/Return:** void; mutates `scr_con_current`
- **Side effects:** None beyond updating `scr_con_current`
- **Calls:** None
- **Notes:** Called once per client frame before `SCR_UpdateScreen`.

### SCR_TimeRefresh_f
- **Signature:** `void SCR_TimeRefresh_f(void)`
- **Purpose:** Benchmark command — spins 128 full 360° render passes and reports FPS.
- **Inputs:** Optional second arg disables page-flipping mode
- **Calls:** `re.BeginFrame`, `re.RenderFrame`, `re.EndFrame`, `Sys_Milliseconds`, `Com_Printf`

### SCR_BeginLoadingPlaque / SCR_EndLoadingPlaque
- **Purpose:** Start/end the loading screen. Begin stops audio, sets `disable_screen`, triggers one `SCR_UpdateScreen` to paint plaque. End clears `disable_screen` and console notify.

### Notes (minor helpers)
- `SCR_AddDirtyPoint` / `SCR_DirtyScreen`: expand dirty rect; trivial.
- `SCR_DrawField`: renders a fixed-width digit field from `sb_nums` sprites.
- `SCR_DebugGraph` / `SCR_DrawDebugGraph`: push/render circular sample buffer.
- `SCR_CalcVrect`: computes `scr_vrect` from `scr_viewsize`, clamped 40–100, aligned to 8/2 px.
- `SCR_CenterPrint` / `SCR_DrawCenterString` / `SCR_CheckDrawCenterString`: store, render, and time-out centered messages.

## Control Flow Notes
- **Init:** `SCR_Init` called once at client startup.
- **Per-frame update path:** `CL_Frame` → `SCR_RunConsole` → `SCR_UpdateScreen`. `SCR_UpdateScreen` is also called directly from `SCR_BeginLoadingPlaque` to force a synchronous frame.
- **Render states (inside `SCR_UpdateScreen`):** loading-black → cinematic (+menu/console overlay) → normal game (3D + HUD + overlays).

## External Dependencies
- **Notable includes:** `client.h` (pulls in all client/common headers)
- **Defined elsewhere:** `re` (refexport_t — renderer API struct), `cls` (client_static_t), `cl` (client_state_t), `viddef`, `con`, `cl_paused`, `cl_stereo`, `cl_stereo_separation`, `crosshair`, `developer`; `V_RenderView`, `CL_DrawInventory`, `M_Draw`, `Con_DrawConsole`, `Con_DrawNotify`, `Con_CheckResize`, `Con_ClearNotify`, `S_StopAllSounds`, `CDAudio_Stop`, `SCR_DrawCinematic`, `DrawString`, `DrawAltString`, `Sys_Milliseconds`, `COM_Parse`, `Com_Error`, `Com_Printf`, `Cvar_*`, `Cmd_*`
