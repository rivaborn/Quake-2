# client/cl_inv.c

## File Purpose
Handles the client-side inventory UI: parsing inventory data from the server and rendering the inventory overlay screen during gameplay.

## Core Responsibilities
- Parse incoming inventory item counts from network messages into `cl.inventory[]`
- Render the inventory screen with item names, counts, and key bindings
- Scroll the inventory list to keep the selected item centered
- Highlight the currently selected item with a blinking cursor
- Look up key bindings for each inventory item's `use <item>` command

## Key Types / Data Structures
None defined in this file.

## Global / File-Static State
None defined in this file.

## Key Functions

### CL_ParseInventory
- **Signature:** `void CL_ParseInventory(void)`
- **Purpose:** Reads `MAX_ITEMS` shorts from the incoming network message and stores them in `cl.inventory[]`.
- **Inputs:** None (reads from global `net_message`)
- **Outputs/Return:** void
- **Side effects:** Writes to `cl.inventory[0..MAX_ITEMS-1]`
- **Calls:** `MSG_ReadShort`
- **Notes:** Called during server message parsing when an inventory update packet is received.

---

### Inv_DrawString
- **Signature:** `void Inv_DrawString(int x, int y, char *string)`
- **Purpose:** Renders a string to screen using the renderer's `DrawChar`, advancing 8 pixels per character.
- **Inputs:** Screen coordinates `(x, y)`, null-terminated `string`
- **Outputs/Return:** void
- **Side effects:** Issues draw calls via `re.DrawChar`
- **Calls:** `re.DrawChar`
- **Notes:** Character width is hardcoded to 8 pixels (Quake console font).

---

### SetStringHighBit
- **Signature:** `void SetStringHighBit(char *s)`
- **Purpose:** Sets bit 7 on every character of a string, causing the renderer to draw them in an alternate (dimmed/colored) style.
- **Inputs:** Mutable string `s`
- **Outputs/Return:** void
- **Side effects:** Modifies string in-place
- **Calls:** None
- **Notes:** Used to visually de-emphasize non-selected inventory items.

---

### CL_DrawInventory
- **Signature:** `void CL_DrawInventory(void)`
- **Purpose:** Renders the full inventory overlay: background image, column headers, scrolled item list with hotkeys, counts, and names. Highlights the selected item with a blinking cursor.
- **Inputs:** None (reads global `cl`, `cls`, `viddef`, `keybindings`)
- **Outputs/Return:** void
- **Side effects:** Multiple `re.DrawPic`/`re.DrawChar` calls; calls `SCR_DirtyScreen()` to force a full repaint next frame
- **Calls:** `SCR_DirtyScreen`, `re.DrawPic`, `Inv_DrawString`, `Com_sprintf`, `Q_stricmp`, `Key_KeynumToString`, `SetStringHighBit`, `re.DrawChar`
- **Notes:**
  - Scroll logic clamps `top` so the selected item stays near center of the `DISPLAY_ITEMS` (17) window.
  - Key binding lookup is O(256) linear scan over `keybindings[]` per item per frame — no caching.
  - Blink rate: `(int)(cls.realtime * 10) & 1` toggles at ~5 Hz.
  - Screen is centered via `viddef.width`/`viddef.height`.

## Control Flow Notes
- `CL_ParseInventory` is called from the client network message dispatcher (in `cl_parse.c`) when the server sends an inventory update.
- `CL_DrawInventory` is called from the 2D HUD/screen rendering path (likely `SCR_ExecuteLayoutString` or equivalent in `cl_scrn.c`) each frame when the inventory screen is open.

## External Dependencies
- **Includes:** `client.h` (pulls in `cl_parse`, `keys`, renderer refs, etc.)
- **External symbols used but not defined here:**
  - `cl` — global client state (`client_state_t`)
  - `cls` — global client static state (`client_static_t`), used for `realtime`
  - `net_message` — global incoming network message buffer
  - `viddef` — global video dimensions
  - `keybindings[]` — global key-to-command binding table
  - `re` — global renderer export struct (`refexport_t`)
  - `MSG_ReadShort`, `Com_sprintf`, `Q_stricmp`, `Key_KeynumToString`, `SCR_DirtyScreen` — defined elsewhere in engine
