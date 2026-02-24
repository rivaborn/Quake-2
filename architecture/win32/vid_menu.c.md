# win32/vid_menu.c

## File Purpose
Implements the Windows-specific video options menu UI for Quake 2, allowing players to select renderer (software/OpenGL/3Dfx/PowerVR), video mode, brightness, fullscreen, and renderer-specific settings. It manages two parallel menu frameworks (software and OpenGL) that share certain controls.

## Core Responsibilities
- Define and initialize all menu items for both software and OpenGL video menus
- Switch between software/OpenGL menu views based on driver selection
- Apply video setting changes to cvars and trigger renderer restarts
- Handle special-case gamma correction for 3Dfx via environment variables
- Translate key input events into menu navigation and selection
- Draw the video menu with banner graphic each frame

## Key Types / Data Structures
None (uses types from `client.h` / `qmenu.h`).

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `gl_mode` | `cvar_t *` | static | Current GL resolution mode index |
| `gl_driver` | `cvar_t *` | static | GL driver DLL name (e.g. `opengl32`, `3dfxgl`) |
| `gl_picmip` | `cvar_t *` | static | Texture quality mip level |
| `gl_ext_palettedtexture` | `cvar_t *` | static | Enable 8-bit paletted textures |
| `gl_finish` | `cvar_t *` | static | Enable `glFinish` sync per frame |
| `sw_mode` | `cvar_t *` | static | Software renderer resolution mode index |
| `sw_stipplealpha` | `cvar_t *` | static | Software renderer stipple alpha toggle |
| `s_software_menu` | `menuframework_s` | static | Software renderer menu framework |
| `s_opengl_menu` | `menuframework_s` | static | OpenGL renderer menu framework |
| `s_current_menu` | `menuframework_s *` | static | Pointer to whichever menu is active |
| `s_current_menu_index` | `int` | static | 0 = software, 1 = OpenGL |
| `s_mode_list[2]` | `menulist_s` | static | Resolution selector (one per menu) |
| `s_ref_list[2]` | `menulist_s` | static | Driver/renderer selector (one per menu) |
| `s_tq_slider` | `menuslider_s` | static | GL texture quality slider |
| `s_screensize_slider[2]` | `menuslider_s` | static | Screen size/viewsize slider |
| `s_brightness_slider[2]` | `menuslider_s` | static | Brightness/gamma slider |
| `s_fs_box[2]` | `menulist_s` | static | Fullscreen yes/no toggle |
| `s_stipple_box` | `menulist_s` | static | Software stipple alpha toggle |
| `s_paletted_texture_box` | `menulist_s` | static | GL paletted texture toggle |
| `s_finish_box` | `menulist_s` | static | GL sync-every-frame toggle |
| `s_cancel_action[2]` | `menuaction_s` | static | Cancel button (one per menu) |
| `s_defaults_action[2]` | `menuaction_s` | static | Reset defaults button (one per menu) |

## Key Functions

### DriverCallback
- **Signature:** `static void DriverCallback( void *unused )`
- **Purpose:** Switches the active menu between software and OpenGL when the driver spincontrol changes.
- **Inputs:** Unused callback parameter.
- **Outputs/Return:** void
- **Side effects:** Writes `s_current_menu`, `s_current_menu_index`, and mirrors the ref list selection to the inactive menu.
- **Calls:** None.
- **Notes:** Keeps both `s_ref_list` entries in sync so switching back preserves the selection.

### BrightnessCallback
- **Signature:** `static void BrightnessCallback( void *s )`
- **Purpose:** Live-updates `vid_gamma` cvar from the brightness slider and mirrors slider value between menus.
- **Inputs:** `s` — pointer to the triggering `menuslider_s`.
- **Outputs/Return:** void
- **Side effects:** Calls `Cvar_SetValue("vid_gamma", ...)`. Only applies gamma immediately when `vid_ref` is `"soft"`.
- **Calls:** `Cvar_SetValue`, `stricmp`.

### ApplyChanges
- **Signature:** `static void ApplyChanges( void *unused )`
- **Purpose:** Commits all pending menu selections to cvars and closes the menu. Core entry point for saving video settings.
- **Inputs:** Unused.
- **Outputs/Return:** void
- **Side effects:** Calls `Cvar_SetValue`/`Cvar_Set` for `vid_gamma`, `sw_stipplealpha`, `gl_picmip`, `vid_fullscreen`, `gl_ext_palettedtexture`, `gl_finish`, `sw_mode`, `gl_mode`, `vid_ref`, `gl_driver`. For 3Dfx, sets `SSTV2_GAMMA` and `SST_GAMMA` environment variables via `putenv`. Sets `vid_ref->modified` to trigger renderer restart. Calls `M_ForceMenuOff`.
- **Calls:** `Cvar_SetValue`, `Cvar_Set`, `Com_sprintf`, `putenv`, `M_ForceMenuOff`, `stricmp`.
- **Notes:** Gamma inversion formula: `gamma = (0.8 - (slider/10.0 - 0.5)) + 0.5`. REF_VERITE case is commented out and falls through to REF_OPENGL.

### VID_MenuInit
- **Signature:** `void VID_MenuInit( void )`
- **Purpose:** Initializes or re-initializes all menu items and frameworks, binding cvar values into menu widget state.
- **Inputs:** None (reads global cvars).
- **Outputs/Return:** void
- **Side effects:** Lazy-initializes static cvar pointers via `Cvar_Get`. Resets `nitems` on both menu frameworks. Calls `Menu_AddItem` and `Menu_Center`.
- **Calls:** `Cvar_Get`, `Menu_AddItem`, `Menu_Center`.
- **Notes:** Serves as both init and "reset to defaults" (called by `ResetDefaults`). Brightness slider uses inverted scale: `curvalue = (1.3 - vid_gamma->value + 0.5) * 10`.

### VID_MenuDraw
- **Signature:** `void VID_MenuDraw( void )`
- **Purpose:** Renders the video menu each frame, including the banner graphic and active menu items.
- **Inputs:** None.
- **Outputs/Return:** void
- **Side effects:** Calls `re.DrawGetPicSize`, `re.DrawPic`, `Menu_AdjustCursor`, `Menu_Draw`.
- **Calls:** `re.DrawGetPicSize`, `re.DrawPic`, `Menu_AdjustCursor`, `Menu_Draw`.

### VID_MenuKey
- **Signature:** `const char *VID_MenuKey( int key )`
- **Purpose:** Routes keyboard input to menu navigation or applies/cancels changes.
- **Inputs:** `key` — keycode constant.
- **Outputs/Return:** Returns a sound path string `"misc/menu1.wav"` for all handled keys; `NULL` on `K_ESCAPE`.
- **Side effects:** Modifies `m->cursor`. Calls `ApplyChanges` on `K_ESCAPE` or `K_ENTER` (if no item handles it).
- **Calls:** `Menu_AdjustCursor`, `Menu_SlideItem`, `Menu_SelectItem`, `ApplyChanges`.
- **Notes:** `K_ESCAPE` applies (not cancels) changes — unlike typical escape behavior. `CancelChanges` is only reachable via the explicit cancel menu item.

## Control Flow Notes
- `VID_MenuInit` is called at menu open time and by the "reset to defaults" action.
- `VID_MenuDraw` is called every render frame while the menu is open.
- `VID_MenuKey` is called per keypress while the menu is open.
- `ApplyChanges` sets `vid_ref->modified = true`, which the engine polls each frame to trigger a renderer reload.

## External Dependencies
- **Includes:** `../client/client.h`, `../client/qmenu.h`
- **Defined elsewhere:** `vid_ref`, `vid_fullscreen`, `vid_gamma`, `scr_viewsize` (extern cvars); `viddef` (video dimensions); `re` (refexport render API); `M_ForceMenuOff`, `M_PopMenu` (menu system); `Menu_AddItem`, `Menu_Center`, `Menu_AdjustCursor`, `Menu_Draw`, `Menu_SlideItem`, `Menu_SelectItem`, `Cvar_Get`, `Cvar_Set`, `Cvar_SetValue`, `Com_sprintf` (engine utilities).
