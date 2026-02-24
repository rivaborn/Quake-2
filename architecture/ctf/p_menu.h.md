# ctf/p_menu.h

## File Purpose
Declares the in-game player menu system used by the CTF (Capture the Flag) mod. It defines the data structures and public API for presenting a navigable, text-based HUD menu to individual players during gameplay.

## Core Responsibilities
- Define alignment constants for menu entry text positioning
- Declare the `pmenu_t` structure representing a single menu entry (text, alignment, callback)
- Declare the `pmenuhnd_t` handle tracking an open menu instance and its cursor state
- Expose the full lifecycle API: open, close, update, navigate, and select menu entries

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `pmenuhnd_t` | struct | Handle for an active player menu; tracks entry array, cursor position, entry count, and an opaque user argument |
| `pmenu_t` | struct | A single menu row: display text, text alignment, and an optional selection callback |
| `SelectFunc_t` | typedef (function pointer) | Callback signature invoked when a player selects a menu entry; receives the owning entity and menu handle |
| Anonymous alignment enum | enum | `PMENU_ALIGN_LEFT`, `PMENU_ALIGN_CENTER`, `PMENU_ALIGN_RIGHT` — text justification constants for `pmenu_t.align` |

## Global / File-Static State
None.

## Key Functions

### PMenu_Open
- Signature: `pmenuhnd_t *PMenu_Open(edict_t *ent, pmenu_t *entries, int cur, int num, void *arg)`
- Purpose: Opens and displays a player menu for a given entity.
- Inputs: `ent` — player entity; `entries` — array of menu items; `cur` — initial cursor index; `num` — number of entries; `arg` — opaque context passed to callbacks.
- Outputs/Return: Allocated `pmenuhnd_t *` handle for the open menu.
- Side effects: Allocates menu handle, associates it with the player entity, triggers initial render to player HUD.
- Calls: Defined in `ctf/p_menu.c`.
- Notes: Caller is responsible for closing the menu via `PMenu_Close`; `arg` provides callback context without globals.

### PMenu_Close
- Signature: `void PMenu_Close(edict_t *ent)`
- Purpose: Closes and cleans up the active menu for a player.
- Inputs: `ent` — player entity whose menu should be dismissed.
- Outputs/Return: void.
- Side effects: Frees handle memory, removes HUD menu layout from player.
- Calls: Defined in `ctf/p_menu.c`.

### PMenu_UpdateEntry
- Signature: `void PMenu_UpdateEntry(pmenu_t *entry, const char *text, int align, SelectFunc_t SelectFunc)`
- Purpose: Mutates a single `pmenu_t` entry's text, alignment, and callback in place.
- Inputs: Target entry pointer, new text, new alignment, new callback.
- Outputs/Return: void.
- Side effects: Modifies the entry struct directly; does not trigger a redraw by itself.

### PMenu_Do_Update / PMenu_Update
- Signatures: `void PMenu_Do_Update(edict_t *ent)` / `void PMenu_Update(edict_t *ent)`
- Purpose: `PMenu_Do_Update` performs the immediate HUD repaint; `PMenu_Update` likely schedules or rate-limits the repaint.
- Side effects: Sends updated layout data to player HUD.

### PMenu_Next / PMenu_Prev / PMenu_Select
- Signatures: `void PMenu_Next(edict_t *ent)` / `void PMenu_Prev(edict_t *ent)` / `void PMenu_Select(edict_t *ent)`
- Purpose: Advance cursor down, move cursor up, and invoke the `SelectFunc` of the current entry, respectively.
- Side effects: Modify `pmenuhnd_t.cur`; `PMenu_Select` invokes the entry's `SelectFunc_t` callback.

## Control Flow Notes
This header is consumed by `ctf/p_menu.c` (implementation) and any CTF game code that needs to present in-game menus to players (e.g., team selection). Navigation functions (`Next`, `Prev`, `Select`) are driven by player input events handled elsewhere in the CTF game module.

## External Dependencies
- `edict_t` — defined in `ctf/g_local.h` / `game.h`; the core game entity type
- `SelectFunc_t` depends on `edict_t` being declared prior to this header's inclusion
