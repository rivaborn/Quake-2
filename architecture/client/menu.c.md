# client/menu.c

## File Purpose
Implements the entire in-game menu system for Quake 2, including the main menu, all submenus (game, multiplayer, options, keys, video, load/save, server browser, player config, DM options, credits, etc.). It manages a layered menu stack with draw/key function dispatch, and registers all menu console commands.

## Core Responsibilities
- Maintain a depth-limited menu stack (`m_layers[]`) with push/pop semantics
- Dispatch per-frame draw and per-keypress key callbacks to the active menu
- Provide shared UI primitives: character drawing, text printing, cursor animation, text boxes
- Initialize and configure each submenu's `menuframework_s` and its items on demand
- Apply cvar reads/writes when menu items change (audio, input, gameplay settings)
- Scan the filesystem for player models/skins and map lists at menu open time
- Register all `menu_*` console commands during engine init

## Key Types / Data Structures
| Name | Kind | Purpose |
|---|---|---|
| `menulayer_t` | struct | Pairs a draw function and key function for one menu stack frame |
| `playermodelinfo_s` | struct | Holds scan results for one player model: skin list, display name, directory |

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `m_drawfunc` | `void (*)(void)` | global | Active menu's draw callback |
| `m_keyfunc` | `const char *(*)(int)` | global | Active menu's key callback |
| `m_entersound` | `qboolean` | global | Flag to play entry sound after first draw |
| `m_layers[MAX_MENU_DEPTH]` | `menulayer_t[8]` | global | Menu stack storage |
| `m_menudepth` | `int` | global | Current stack depth |
| `m_main_cursor` | `int` | static | Cursor position for the hand-rolled main menu |
| `bind_grab` | `int` | static | Waiting-for-key state in the Keys menu |
| `credits` | `const char **` | static | Pointer to active credits string array |
| `creditsBuffer` | `char *` | static | Heap buffer for file-loaded credits |
| `mapnames` | `char **` | static | Heap-allocated map name list for Start Server menu |
| `nummaps` | `int` | static | Count of maps parsed from `maps.lst` |
| `s_pmi[MAX_PLAYERMODELS]` | `playermodelinfo_s[]` | static | Scanned player model info array |
| `s_numplayermodels` | `int` | static | Count of valid player models found |

## Key Functions

### M_PushMenu
- **Signature:** `void M_PushMenu(void (*draw)(void), const char *(*key)(int k))`
- **Purpose:** Pushes a new menu onto the stack, or collapses to an existing instance if already present.
- **Inputs:** Draw and key function pointers for the new menu.
- **Outputs/Return:** None.
- **Side effects:** Sets `cls.key_dest = key_menu`; pauses single-player game; sets `m_entersound`.
- **Calls:** `Cvar_VariableValue`, `Com_ServerState`, `Cvar_Set`, `Com_Error`
- **Notes:** Deduplication loop has an off-by-one: `i == m_menudepth` check runs even after the loop sets `m_menudepth = i`, so a found menu still pushes. Intentional behavior to collapse to that level.

### M_PopMenu
- **Signature:** `void M_PopMenu(void)`
- **Purpose:** Restores the previous menu from the stack; calls `M_ForceMenuOff` if stack empties.
- **Side effects:** Plays `menu_out_sound`.
- **Calls:** `S_StartLocalSound`, `Com_Error`, `M_ForceMenuOff`

### M_ForceMenuOff
- **Signature:** `void M_ForceMenuOff(void)`
- **Purpose:** Immediately clears all menu state and returns input to the game.
- **Side effects:** Zeros `m_drawfunc`/`m_keyfunc`, resets `m_menudepth`, clears key states, unpauses.
- **Calls:** `Key_ClearStates`, `Cvar_Set`

### Default_MenuKey
- **Signature:** `const char *Default_MenuKey(menuframework_s *m, int key)`
- **Purpose:** Generic key handler for `qmenu`-based menus; routes navigation, selection, and field input.
- **Inputs:** Active menu framework, raw key code.
- **Outputs/Return:** Sound filename string or NULL.
- **Calls:** `Menu_ItemAtCursor`, `Field_Key`, `Menu_AdjustCursor`, `Menu_SlideItem`, `Menu_SelectItem`, `M_PopMenu`

### M_Init
- **Signature:** `void M_Init(void)`
- **Purpose:** Registers all `menu_*` console commands at engine startup.
- **Calls:** `Cmd_AddCommand` (×18)

### M_Draw
- **Signature:** `void M_Draw(void)`
- **Purpose:** Per-frame menu render entry point; dims the screen, calls `m_drawfunc`, plays enter sound.
- **Calls:** `SCR_DirtyScreen`, `re.DrawFill`, `re.DrawFadeScreen`, `S_StartLocalSound`

### M_Keydown
- **Signature:** `void M_Keydown(int key)`
- **Purpose:** Routes a keypress to `m_keyfunc` and plays any returned sound.
- **Calls:** `m_keyfunc`, `S_StartLocalSound`

### PlayerConfig_ScanDirectories
- **Signature:** `static qboolean PlayerConfig_ScanDirectories(void)`
- **Purpose:** Walks `players/*/` in the search path, validates `tris.md2` + PCX skins with icons, and populates `s_pmi[]`.
- **Side effects:** Heap-allocates skin name arrays; populates global `s_pmi` and `s_numplayermodels`.
- **Calls:** `FS_ListFiles`, `Sys_FindFirst`, `Sys_FindClose`, `malloc`, `strdup`, `FreeFileList`

### M_Menu_Credits_f
- **Signature:** `void M_Menu_Credits_f(void)`
- **Purpose:** Loads external `credits` file or selects built-in credits array based on `Developer_searchpath` result; pushes scrolling credits menu.
- **Calls:** `FS_LoadFile`, `Developer_searchpath`, `M_PushMenu`

### StartServer_MenuInit
- **Signature:** `void StartServer_MenuInit(void)`
- **Purpose:** Parses `maps.lst` (filesystem or pak), builds `mapnames[]`, and initializes the start-server `menuframework_s`.
- **Side effects:** Heap-allocates `mapnames`; freed on K_ESCAPE in `StartServer_MenuKey`.
- **Calls:** `FS_LoadFile`, `fopen`, `malloc`, `COM_Parse`, `Developer_searchpath`, `Menu_AddItem`, `RulesChangeFunc`

### Notes
- Trivial wrappers (`M_Banner`, `M_DrawCharacter`, `M_Print`, `M_PrintWhite`, `M_DrawPic`, `M_DrawTextBox`) provide resolution-independent 320×240-space drawing via `re.*`.
- Each menu section follows the pattern: `*_MenuInit` → `M_PushMenu(*_MenuDraw, *_MenuKey)`.
- `DMFlagCallback` and `DownloadCallback` use pointer-identity dispatch instead of a type field.

## Control Flow Notes
- **Init:** `M_Init` called once at engine startup to register commands.
- **Frame:** `M_Draw` is called each rendered frame from the client screen pipeline when `cls.key_dest == key_menu`.
- **Input:** `M_Keydown` is called from the key event system whenever a key is pressed while in menu mode.
- Menus are not ticked independently; animation (cursor, credits scroll) is driven by `cls.realtime` sampled during draw.

## External Dependencies
- **Includes:** `client.h`, `client/qmenu.h`, `<ctype.h>`, `<io.h>` (Win32)
- **External symbols (defined elsewhere):**
  - `re` — renderer export table (`DrawPic`, `DrawChar`, `DrawGetPicSize`, `DrawFill`, `DrawFadeScreen`, `RegisterPic`, `RegisterModel`, `RegisterSkin`, `RenderFrame`, `EndFrame`)
  - `viddef` — video dimensions
  - `cls`, `cl` — client state structs
  - `keybindings[]`, `Key_SetBinding`, `Key_KeynumToString`, `Key_ClearStates`
  - `Cvar_*`, `Cbuf_*`, `Cmd_AddCommand`, `Com_*`, `FS_*`, `S_StartLocalSound`
  - `Menu_*`, `Field_Key` — from `qmenu.c`
  - `VID_MenuInit`, `VID_MenuDraw`, `VID_MenuKey` — from platform video module
  - `CL_Snd_Restart_f`, `CL_PingServers_f`, `CL_Quit_f`
  - `Developer_searchpath` — defined elsewhere (game/filesystem layer)
  - `CalcFov` — renderer utility
