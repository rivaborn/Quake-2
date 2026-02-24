# client/qmenu.h

## File Purpose
Defines the data structures and function interface for Quake 2's in-game menu system. Provides a widget-based UI framework supporting sliders, lists, action buttons, text fields, spin controls, and separators.

## Core Responsibilities
- Define menu item type constants (`MTYPE_*`)
- Define key code constants used exclusively by the menu system
- Define item flag constants (`QMF_*`)
- Declare structs for the menu framework container and each widget type
- Declare the public API for menu management and rendering

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `menuframework_s` | struct | Container for a full menu screen; holds item list, cursor state, position, and optional custom cursor draw callback |
| `menucommon_s` | struct | Base "class" embedded as first member in all widget types; holds type, name, position, parent pointer, flags, and function pointers for callbacks/drawing |
| `menufield_s` | struct | Text input field widget; extends `menucommon_s` with a char buffer, cursor, length, and scroll offset |
| `menuslider_s` | struct | Draggable slider widget; extends `menucommon_s` with min/max/current float values and a range |
| `menulist_s` | struct | Scrollable/selectable list widget; extends `menucommon_s` with current index and a null-terminated `itemnames` array |
| `menuaction_s` | struct | Clickable action button; extends `menucommon_s` with no additional fields |
| `menuseparator_s` | struct | Visual separator; extends `menucommon_s` with no additional fields |

## Global / File-Static State
None.

## Key Functions

### Field_Key
- Signature: `qboolean Field_Key( menufield_s *field, int key )`
- Purpose: Handle a keypress for a text input field widget.
- Inputs: Pointer to field widget, key code integer.
- Outputs/Return: `qboolean` — true if key was consumed.
- Side effects: Modifies `field->buffer`, `field->cursor`, `field->visible_offset`.
- Calls: Not inferable from this file (defined in `qmenu.c`).
- Notes: Key codes use the `K_*` constants defined in this header.

### Menu_AddItem
- Signature: `void Menu_AddItem( menuframework_s *menu, void *item )`
- Purpose: Register a widget with a menu framework, incrementing `nitems`.
- Inputs: Menu container, opaque item pointer (cast to `menucommon_s *` internally).
- Outputs/Return: void.
- Side effects: Writes into `menu->items[]`; sets item's `parent` back-pointer.
- Calls: Not inferable from this file.

### Menu_AdjustCursor
- Signature: `void Menu_AdjustCursor( menuframework_s *menu, int dir )`
- Purpose: Move the cursor up (`dir < 0`) or down (`dir > 0`), skipping non-selectable items.
- Inputs: Menu container, direction integer.
- Outputs/Return: void.
- Side effects: Mutates `menu->cursor`.
- Calls: Not inferable from this file.

### Menu_Draw
- Signature: `void Menu_Draw( menuframework_s *menu )`
- Purpose: Render all items in the menu to screen.
- Inputs: Menu container.
- Outputs/Return: void.
- Side effects: Issues renderer draw calls; invokes per-item `ownerdraw` callbacks if set.
- Calls: Not inferable from this file.

### Menu_SelectItem
- Signature: `qboolean Menu_SelectItem( menuframework_s *s )`
- Purpose: Activate the item currently under the cursor (trigger its `callback`).
- Inputs: Menu container.
- Outputs/Return: `qboolean` — whether selection was handled.
- Side effects: May invoke `menucommon_s.callback`.
- Calls: Not inferable from this file.

### Menu_SlideItem
- Signature: `void Menu_SlideItem( menuframework_s *s, int dir )`
- Purpose: Adjust a slider or spin control value left/right.
- Inputs: Menu container, direction (`-1` or `+1`).
- Outputs/Return: void.
- Side effects: Mutates `curvalue` on the targeted widget.
- Calls: Not inferable from this file.

**Notes on remaining helpers:** `Menu_Center`, `Menu_SetStatusBar`, `Menu_TallySlots`, `Menu_ItemAtCursor`, and the four `Menu_DrawString*` variants are layout/utility helpers; their behavior is self-evident from names.

## Control Flow Notes
This header is included by `menu.c` (the game menu screens) and `qmenu.c` (the framework implementation). It sits outside the per-frame engine loop — menus are driven by key events routed through `cl_main.c` when `cls.key_dest == key_menu`.

## External Dependencies
- Relies on `qboolean` being defined prior to inclusion (typically from `q_shared.h` / `qcommon.h`).
- All function bodies defined in `client/qmenu.c`.
- Rendering calls within implementations depend on `client/ref.h` draw primitives — not visible here.
