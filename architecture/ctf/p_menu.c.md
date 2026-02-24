# ctf/p_menu.c

## File Purpose
Implements a per-client in-game HUD menu system for the CTF game module. Menus are rendered via the layout string mechanism (svc_layout) and displayed over the inventory screen. Each client maintains its own dynamically allocated menu state.

## Core Responsibilities
- Allocate and initialize per-client menu handles with deep-copied entries
- Serialize menu entries into a layout string and send via unicast
- Rate-limit menu redraws (dirty flag + 1-second threshold)
- Navigate menu cursor forward/backward, skipping non-selectable entries
- Invoke the selected entry's callback function
- Free all menu resources on close

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `pmenu_t` | struct (defined in p_menu.h) | Single menu entry: text, alignment, and a `SelectFunc` callback |
| `pmenuhnd_t` | struct (defined in p_menu.h) | Active menu handle: copied entries array, entry count, current cursor index, and opaque `arg` pointer |
| `SelectFunc_t` | typedef (defined elsewhere) | Function pointer type `void (*)(edict_t *, pmenuhnd_t *)` for entry selection callbacks |

## Global / File-Static State
None.

## Key Functions

### PMenu_Open
- **Signature:** `pmenuhnd_t *PMenu_Open(edict_t *ent, pmenu_t *entries, int cur, int num, void *arg)`
- **Purpose:** Opens a menu for a client, deep-copying the entries array and their text strings.
- **Inputs:** `ent` — target client entity; `entries` — source menu entry array; `cur` — preferred initial cursor position; `num` — entry count; `arg` — caller-owned opaque data (ownership transferred).
- **Outputs/Return:** Pointer to the new `pmenuhnd_t`, or `NULL` if entity has no client.
- **Side effects:** Allocates `hnd`, `hnd->entries`, duplicates text strings via `strdup`; sets `client->showscores`, `client->inmenu`, `client->menu`; calls `PMenu_Do_Update` and `gi.unicast`.
- **Calls:** `malloc`, `memcpy`, `strdup`, `PMenu_Do_Update`, `gi.unicast`, `PMenu_Close` (if menu already open), `gi.dprintf`.
- **Notes:** If `cur` is negative or points to a non-selectable entry, scans forward for the first selectable one. `arg` must be heap-allocated; ownership passes to the handle and is freed on close.

### PMenu_Close
- **Signature:** `void PMenu_Close(edict_t *ent)`
- **Purpose:** Frees all resources associated with the client's active menu and clears menu state flags.
- **Inputs:** `ent` — client entity with an active menu.
- **Outputs/Return:** void.
- **Side effects:** Frees each entry's text string, the entries array, `hnd->arg`, and `hnd` itself. Clears `client->menu` and `client->showscores`.
- **Calls:** `free`.
- **Notes:** No-op if `client->menu` is already NULL.

### PMenu_Do_Update
- **Signature:** `void PMenu_Do_Update(edict_t *ent)`
- **Purpose:** Builds and transmits the full layout string representing the current menu state to the client.
- **Inputs:** `ent` — client entity with an active menu.
- **Outputs/Return:** void.
- **Side effects:** Writes `svc_layout` + layout string to the message buffer via `gi.WriteByte`/`gi.WriteString`. Uses a 1400-byte stack buffer.
- **Calls:** `gi.dprintf`, `strcpy`, `sprintf`, `strlen`, `gi.WriteByte`, `gi.WriteString`.
- **Notes:** Leading `*` on entry text switches rendering to `string2` (alternate color) for that line. Selected entry is offset 8 pixels left and prefixed with `\x0d` (arrow glyph). Does not call `gi.unicast` itself — callers must do so.

### PMenu_Update
- **Signature:** `void PMenu_Update(edict_t *ent)`
- **Purpose:** Rate-limited wrapper around `PMenu_Do_Update`; only flushes if ≥1 second has elapsed since last update, otherwise marks dirty.
- **Side effects:** Updates `client->menutime` and `client->menudirty`; may call `gi.unicast`.
- **Calls:** `PMenu_Do_Update`, `gi.unicast`.

### PMenu_Next / PMenu_Prev
- **Signature:** `void PMenu_Next(edict_t *ent)` / `void PMenu_Prev(edict_t *ent)`
- **Purpose:** Advance or retreat the cursor to the next/previous selectable entry, wrapping around.
- **Calls:** `PMenu_Update`.
- **Notes:** Both use do-while loops that terminate if they wrap back to `hnd->cur` without finding another selectable entry (no infinite loop on single-item menus).

### PMenu_Select
- **Signature:** `void PMenu_Select(edict_t *ent)`
- **Purpose:** Invokes the `SelectFunc` of the currently highlighted entry.
- **Calls:** `p->SelectFunc(ent, hnd)` (indirect).

## Control Flow Notes
Called from player input handling during a CTF frame: input events map to `PMenu_Next`, `PMenu_Prev`, and `PMenu_Select`. `PMenu_Update` is also polled each frame to flush dirty menus. Init occurs via `PMenu_Open`; teardown via `PMenu_Close` on disconnect or explicit close.

## External Dependencies
- `g_local.h` — pulls in all game types, `gi` import table, `level`, entity/client structs
- `gi.unicast`, `gi.WriteByte`, `gi.WriteString`, `gi.dprintf` — engine import table (defined in engine)
- `pmenu_t`, `pmenuhnd_t`, `SelectFunc_t` — declared in `ctf/p_menu.h`
- `svc_layout` — engine protocol constant (defined in `qcommon/qcommon.h` or equivalent)
- `level.time` — global game state (defined in `g_local.h`)
