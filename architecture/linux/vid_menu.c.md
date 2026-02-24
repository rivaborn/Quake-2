# linux/vid_menu.c

## File Purpose
Implements the Linux-specific video settings menu for Quake 2, providing an in-game UI to configure display driver (software/software X11/OpenGL), resolution, brightness, fullscreen, and renderer-specific options. Bridges the qmenu widget system to cvars controlling the video subsystem.

## Core Responsibilities
- Build and initialize two parallel menu frameworks: software and OpenGL
- Synchronize menu widget state with current cvar values on init
- Switch active menu panel when the user changes renderer selection
- Write cvar changes back to the engine on "apply"
- Handle keyboard input for menu navigation and selection
- Draw the video menu banner and active menu panel each frame

## Key Types / Data Structures
None (uses types from `client.h` and `qmenu.h`).

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `s_software_menu` | `menuframework_s` | static | Software renderer menu container |
| `s_opengl_menu` | `menuframework_s` | static | OpenGL renderer menu container |
| `s_current_menu` | `menuframework_s *` | static | Pointer to whichever panel is active |
| `s_current_menu_index` | `int` | static | 0 = software, 1 = OpenGL |
| `s_mode_list[2]` | `menulist_s` | static | Resolution spincontrol (one per panel) |
| `s_ref_list[2]` | `menulist_s` | static | Driver selection spincontrol (one per panel) |
| `s_tq_slider` | `menuslider_s` | static | OpenGL texture quality slider |
| `s_screensize_slider[2]` | `menuslider_s` | static | Screen size slider (one per panel) |
| `s_brightness_slider[2]` | `menuslider_s` | static | Gamma/brightness slider (one per panel) |
| `s_fs_box[2]` | `menulist_s` | static | Fullscreen yes/no toggle (one per panel) |
| `s_stipple_box` | `menulist_s` | static | Software stipple alpha toggle |
| `s_paletted_texture_box` | `menulist_s` | static | OpenGL 8-bit texture toggle |
| `s_windowed_mouse` | `menulist_s` | static | Windowed mouse capture toggle |
| `gl_mode`, `gl_driver`, `gl_picmip`, `gl_ext_palettedtexture` | `cvar_t *` | static | Cached GL cvars |
| `sw_mode`, `sw_stipplealpha` | `cvar_t *` | static | Cached software renderer cvars |
| `_windowed_mouse` | `cvar_t *` | static | Cached mouse capture cvar |

## Key Functions

### DriverCallback
- **Signature:** `static void DriverCallback( void *unused )`
- **Purpose:** Switches the active menu panel when the user changes the renderer dropdown.
- **Inputs:** Ignored `void *` (qmenu callback convention).
- **Outputs/Return:** void
- **Side effects:** Writes `s_current_menu`, `s_current_menu_index`; mirrors `curvalue` to the opposite panel's `s_ref_list`.
- **Calls:** None.
- **Notes:** Values < 2 route to software menu; ≥ 2 route to OpenGL menu.

### ScreenSizeCallback
- **Signature:** `static void ScreenSizeCallback( void *s )`
- **Purpose:** Immediately applies screen-size slider changes to `viewsize` cvar.
- **Inputs:** `menuslider_s *` cast from `void *`.
- **Outputs/Return:** void
- **Side effects:** Calls `Cvar_SetValue("viewsize", ...)`.
- **Calls:** `Cvar_SetValue`.

### BrightnessCallback
- **Signature:** `static void BrightnessCallback( void *s )`
- **Purpose:** Mirrors brightness value across both panels; for software renderers, immediately applies gamma to `vid_gamma`.
- **Inputs:** `menuslider_s *` cast from `void *`.
- **Outputs/Return:** void
- **Side effects:** Writes `s_brightness_slider[other].curvalue`; conditionally calls `Cvar_SetValue("vid_gamma", ...)`.
- **Calls:** `Cvar_SetValue`, `stricmp`.
- **Notes:** GL gamma is applied only in `ApplyChanges`, not live.

### ApplyChanges
- **Signature:** `static void ApplyChanges( void *unused )`
- **Purpose:** Commits all widget values to their corresponding cvars and dismisses the menu.
- **Inputs:** Ignored.
- **Outputs/Return:** void
- **Side effects:** Calls `Cvar_SetValue`/`Cvar_Set` for `vid_gamma`, `sw_stipplealpha`, `gl_picmip`, `vid_fullscreen`, `gl_ext_palettedtexture`, `sw_mode`, `gl_mode`, `_windowed_mouse`, `vid_ref`, `gl_driver`; calls `M_ForceMenuOff`.
- **Calls:** `Cvar_SetValue`, `Cvar_Set`, `M_ForceMenuOff`.
- **Notes:** A large `#if 0` block for 3Dfx/SST_GAMMA env-var support is disabled.

### VID_MenuInit
- **Signature:** `void VID_MenuInit( void )`
- **Purpose:** Allocates/initializes all menu widgets, fetches cvars, populates widget initial values, builds both menu frameworks, and centers them.
- **Inputs:** None (reads global cvars).
- **Outputs/Return:** void
- **Side effects:** Lazy-initializes all static cvar pointers via `Cvar_Get`; resets `s_software_menu.nitems` and `s_opengl_menu.nitems` to 0; calls `Menu_AddItem` and `Menu_Center`.
- **Calls:** `Cvar_Get`, `Menu_AddItem`, `Menu_Center`.
- **Notes:** Also doubles as "reset to defaults" via `ResetDefaults` callback. `s_apply_action` / `s_defaults_action` items are appended after all per-panel items.

### VID_MenuDraw
- **Signature:** `void VID_MenuDraw( void )`
- **Purpose:** Renders the video banner graphic and the currently active menu panel.
- **Inputs:** None.
- **Outputs/Return:** void
- **Side effects:** Calls into `re` (renderer export) for pic size/draw; calls `Menu_AdjustCursor`, `Menu_Draw`.
- **Calls:** `re.DrawGetPicSize`, `re.DrawPic`, `Menu_AdjustCursor`, `Menu_Draw`.

### VID_MenuKey
- **Signature:** `const char *VID_MenuKey( int key )`
- **Purpose:** Routes keyboard input to the active menu; returns a UI sound to play.
- **Inputs:** `key` — engine key constant.
- **Outputs/Return:** Sound path string (`"misc/menu1.wav"`) or `NULL` on Escape.
- **Side effects:** Modifies `m->cursor`; may invoke item callbacks via `Menu_SelectItem`/`Menu_SlideItem`; calls `M_PopMenu` on Escape.
- **Calls:** `M_PopMenu`, `Menu_AdjustCursor`, `Menu_SlideItem`, `Menu_SelectItem`.

## Control Flow Notes
`VID_MenuInit` is called once when the video menu is entered (and re-called by `ResetDefaults`). Each frame while the menu is open, `VID_MenuDraw` is called from the client screen rendering path. Key events are dispatched to `VID_MenuKey`. Changes take effect only when the user activates "apply", which triggers `ApplyChanges` and forces a menu close; the engine's cvar-change detection in the video subsystem then handles the actual mode switch.

## External Dependencies
- **Includes:** `../client/client.h`, `../client/qmenu.h`
- **Defined elsewhere:** `vid_ref`, `vid_fullscreen`, `vid_gamma`, `scr_viewsize` (extern cvars); `M_ForceMenuOff`, `M_PopMenu` (menu system); `Cvar_Get`, `Cvar_Set`, `Cvar_SetValue` (cvar system); `Menu_AddItem`, `Menu_Center`, `Menu_Draw`, `Menu_AdjustCursor`, `Menu_SlideItem`, `Menu_SelectItem` (qmenu system); `re` (renderer export struct); `viddef` (video state); key constants (`K_ESCAPE`, etc.).
