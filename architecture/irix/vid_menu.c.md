# irix/vid_menu.c

## File Purpose
Implements the in-game Video Options menu for the IRIX platform port of Quake 2. It provides a dual-panel UI (Software vs. OpenGL) allowing the player to configure renderer, resolution, brightness, fullscreen, and renderer-specific options, then apply or reset them.

## Core Responsibilities
- Initialize and lay out two `menuframework_s` panels (software and OpenGL) with appropriate widgets
- Synchronize shared settings (brightness, fullscreen, driver) between both panels
- Convert menu widget values to cvar writes on "Apply"
- Handle keyboard navigation and item interaction via `VID_MenuKey`
- Draw the active panel and video banner via `VID_MenuDraw`
- Reset all menu state to current cvar defaults via `ResetDefaults`

## Key Types / Data Structures
None (all types imported from `client.h` / `qmenu.h`).

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `s_software_menu` | `menuframework_s` | static | Software renderer menu panel |
| `s_opengl_menu` | `menuframework_s` | static | OpenGL renderer menu panel |
| `s_current_menu` | `menuframework_s *` | static | Pointer to whichever panel is active |
| `s_current_menu_index` | `int` | static | 0=software, 1=OpenGL; drives panel selection |
| `s_mode_list[2]` | `menulist_s` | static | Resolution spinbox, one per panel |
| `s_ref_list[2]` | `menulist_s` | static | Renderer driver spinbox, one per panel |
| `s_tq_slider` | `menuslider_s` | static | Texture quality slider (OpenGL only) |
| `s_screensize_slider[2]` | `menuslider_s` | static | Screen size slider, one per panel |
| `s_brightness_slider[2]` | `menuslider_s` | static | Brightness slider, one per panel |
| `s_fs_box[2]` | `menulist_s` | static | Fullscreen yes/no, one per panel |
| `s_stipple_box` | `menulist_s` | static | Stipple alpha toggle (software only) |
| `s_paletted_texture_box` | `menulist_s` | static | 8-bit texture toggle (OpenGL only) |
| `s_windowed_mouse` | `menulist_s` | static | Windowed mouse toggle (software only) |
| `s_apply_action[2]` | `menuaction_s` | static | "Apply" button, one per panel |
| `s_defaults_action[2]` | `menuaction_s` | static | "Reset to default" button, one per panel |
| `gl_mode`, `gl_driver`, `gl_picmip`, `gl_ext_palettedtexture` | `cvar_t *` | static | Cached OpenGL cvars |
| `sw_mode`, `sw_stipplealpha` | `cvar_t *` | static | Cached software renderer cvars |
| `_windowed_mouse` | `cvar_t *` | static | Cached windowed mouse cvar |

## Key Functions

### VID_MenuInit
- **Signature:** `void VID_MenuInit(void)`
- **Purpose:** Allocates (via `Cvar_Get`) and caches all relevant cvars, initializes all menu widget structs, populates both panels with items, and centers them.
- **Inputs:** None (reads global cvars)
- **Outputs/Return:** None
- **Side effects:** Writes to all static menu widget state; calls `Cvar_Get` for lazy cvar initialization; modifies `s_current_menu_index` and `s_current_menu` pointer.
- **Calls:** `Cvar_Get`, `Menu_AddItem`, `Menu_Center`
- **Notes:** Called on first open and also by `ResetDefaults` to re-sync UI from live cvar values. The `#if 0` block for 3Dfx/PowerVR sub-driver selection is disabled.

### VID_MenuDraw
- **Signature:** `void VID_MenuDraw(void)`
- **Purpose:** Renders the active menu panel and the video banner graphic.
- **Inputs:** None (reads `s_current_menu_index`, `viddef`)
- **Outputs/Return:** None
- **Side effects:** Calls into renderer (`re.DrawGetPicSize`, `re.DrawPic`); adjusts menu cursor.
- **Calls:** `re.DrawGetPicSize`, `re.DrawPic`, `Menu_AdjustCursor`, `Menu_Draw`

### VID_MenuKey
- **Signature:** `const char *VID_MenuKey(int key)`
- **Purpose:** Dispatches keyboard input to the active menu panel; handles escape, cursor movement, and item interaction.
- **Inputs:** `key` — engine key code
- **Outputs/Return:** Pointer to UI sound filename (`"misc/menu1.wav"`) or `NULL` on escape.
- **Side effects:** Modifies `m->cursor`; may trigger item callbacks; calls `M_PopMenu` on escape.
- **Calls:** `M_PopMenu`, `Menu_AdjustCursor`, `Menu_SlideItem`, `Menu_SelectItem`

### ApplyChanges
- **Signature:** `static void ApplyChanges(void *unused)`
- **Purpose:** Syncs cross-panel widget state and writes all menu selections to cvars, then closes the menu.
- **Side effects:** Calls `Cvar_SetValue`/`Cvar_Set` for `vid_gamma`, `sw_stipplealpha`, `gl_picmip`, `vid_fullscreen`, `gl_ext_palettedtexture`, `sw_mode`, `gl_mode`, `_windowed_mouse`, `vid_ref`, `gl_driver`; calls `M_ForceMenuOff`.
- **Notes:** A `#if 0` block for OpenGL gamma via `putenv`/`SST_GAMMA` (3Dfx-specific) is disabled.

### DriverCallback / ScreenSizeCallback / BrightnessCallback / ResetDefaults
- **Notes:** `DriverCallback` switches the active panel based on the renderer spinbox. `ScreenSizeCallback` immediately writes `viewsize` on slider move. `BrightnessCallback` mirrors brightness between panels and updates `vid_gamma` only for the software renderer. `ResetDefaults` simply calls `VID_MenuInit` to reload from cvars.

## Control Flow Notes
`VID_MenuInit` is called when the video menu is pushed onto the menu stack. Each frame while the menu is open, `VID_MenuDraw` is called by the client draw loop. Input events are routed to `VID_MenuKey`. On "Apply", cvars are written and the menu is closed; the engine's main loop detects `vid_ref->modified` and triggers a renderer restart.

## External Dependencies
- `../client/client.h` — `viddef`, `re` (renderer export struct)
- `../client/qmenu.h` — all menu widget types and `Menu_*` functions
- **Defined elsewhere:** `vid_ref`, `vid_fullscreen`, `vid_gamma`, `scr_viewsize` (extern cvars); `M_ForceMenuOff`, `M_PopMenu` (menu system); `Cvar_Get`, `Cvar_Set`, `Cvar_SetValue`; `Q_stricmp`; all `re.*` draw functions
