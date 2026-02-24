# client/qmenu.c

## File Purpose
Implements the generic menu widget system for the Quake 2 client UI. Provides reusable menu item types (actions, fields, sliders, spin controls, lists, separators) with unified draw, input, and cursor management logic.

## Core Responsibilities
- Draw all menu widget types by dispatching on `menucommon_s.type`
- Handle keyboard input for text field widgets (`Field_Key`)
- Manage cursor movement and selection across menu items
- Render status bar text at the bottom of the screen
- Provide string drawing utilities (left-to-right, right-to-left, normal/dark variants)
- Compute menu slot totals for layout purposes
- Vertically center menus on screen

## Key Types / Data Structures
None defined here; all types are declared in `qmenu.h`.

## Global / File-Static State
None defined here. References external `re` (refexport_t) and `viddef` (viddef_t) for rendering and resolution.

## Key Functions

### Field_Key
- **Signature:** `qboolean Field_Key( menufield_s *f, int key )`
- **Purpose:** Processes a keypress for a text-input field widget, handling editing, cursor movement, deletion, and clipboard paste.
- **Inputs:** Field widget pointer, raw key code
- **Outputs/Return:** `true` if key was consumed, `false` if caller should handle it
- **Side effects:** Mutates `f->buffer`, `f->cursor`, `f->visible_offset`
- **Calls:** `Sys_GetClipboardData`, `strtok`, `strncpy`, `memmove`, `strlen`, `free`, `isdigit`, `toupper`
- **Notes:** Numpad keys are mapped to ASCII digits before processing. Clipboard paste via Ctrl+V or Shift+Ins. `QMF_NUMBERSONLY` flag rejects non-digit characters.

### Menu_Draw
- **Signature:** `void Menu_Draw( menuframework_s *menu )`
- **Purpose:** Renders all items in a menu, then draws the cursor indicator and status bar for the currently highlighted item.
- **Inputs:** Menu framework pointer
- **Outputs/Return:** void
- **Side effects:** Calls renderer via `Draw_Char`/`Draw_Fill`; cursor blink driven by `Sys_Milliseconds()`
- **Calls:** `Field_Draw`, `Slider_Draw`, `MenuList_Draw`, `SpinControl_Draw`, `Action_Draw`, `Separator_Draw`, `Menu_ItemAtCursor`, `Draw_Char`, `Menu_DrawStatusBar`, `Sys_Milliseconds`
- **Notes:** Custom `cursordraw` callbacks on item or menu take priority over default arrow cursor. Status bar priority: item statusbarfunc > item statusbar > menu statusbar.

### Menu_AdjustCursor
- **Signature:** `void Menu_AdjustCursor( menuframework_s *m, int dir )`
- **Purpose:** Advances the cursor in direction `dir` (±1), skipping separator items until a selectable item is found.
- **Inputs:** Menu pointer, direction (+1 or -1)
- **Outputs/Return:** void
- **Side effects:** Mutates `m->cursor`; wraps around at boundaries
- **Calls:** `Menu_ItemAtCursor`
- **Notes:** No-op if cursor already sits on a valid non-separator item.

### Menu_AddItem
- **Signature:** `void Menu_AddItem( menuframework_s *menu, void *item )`
- **Purpose:** Appends a widget to a menu's item list and sets the item's parent pointer.
- **Inputs:** Menu pointer, opaque item pointer (cast to `menucommon_s *` internally)
- **Outputs/Return:** void
- **Side effects:** Mutates `menu->items`, `menu->nitems`, `menu->nslots`; calls `Menu_TallySlots`
- **Notes:** Silently ignores additions beyond `MAXMENUITEMS`.

### Menu_TallySlots
- **Signature:** `int Menu_TallySlots( menuframework_s *menu )`
- **Purpose:** Counts total logical slots in a menu, expanding `MTYPE_LIST` items by their entry count.
- **Inputs:** Menu pointer
- **Outputs/Return:** Total slot count (int)
- **Side effects:** None
- **Calls:** None beyond pointer arithmetic

### Slider_Draw / SpinControl_Draw / Field_Draw
- Trivial draw routines; each reads widget state and emits characters via `Draw_Char`/`Draw_Fill` and `Menu_DrawString*` helpers. `Field_Draw` renders a blinking cursor when the field is active.

## Control Flow Notes
Called from `menu.c` during the client's 2D rendering pass. `Menu_Draw` is the primary per-frame entry point. `Field_Key`, `Menu_SelectItem`, and `Menu_SlideItem` are invoked from input-handling code in response to key events.

## External Dependencies
- `client.h`, `qmenu.h` — type definitions and constants
- `re` (`refexport_t`) — `DrawChar`, `DrawFill` render calls
- `viddef` (`viddef_t`) — screen width/height for layout
- `Sys_Milliseconds()` — cursor blink timing
- `Sys_GetClipboardData()` — clipboard paste support
- `keydown[]` — modifier key state for Ctrl/Shift detection (defined in `keys.c`)
