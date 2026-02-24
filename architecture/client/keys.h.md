# client/keys.h

## File Purpose
Defines the virtual keycode constants used throughout the Quake 2 input system, along with the key binding state variables and the public API for the keyboard subsystem. It serves as the shared interface between platform-specific input backends and the client input/UI layers.

## Core Responsibilities
- Define numeric key constants (`K_*`) for all supported input sources: keyboard, mouse, joystick, aux buttons, and mouse wheel
- Expose global key binding and state arrays (`keybindings`, `key_repeats`)
- Expose chat buffer state for console/UI access
- Declare the public API for key event processing, initialization, binding management, and state reset

## Key Types / Data Structures
None.

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `keybindings` | `char *[256]` | global (extern) | Maps keycode index to bound command string |
| `key_repeats` | `int[256]` | global (extern) | Tracks repeat count per key while held down |
| `anykeydown` | `int` | global (extern) | Non-zero if any key is currently pressed; used for "press any key" prompts |
| `chat_buffer` | `char[]` | global (extern) | Text being typed in the chat input field |
| `chat_bufferlen` | `int` | global (extern) | Current length of `chat_buffer` |
| `chat_team` | `qboolean` | global (extern) | Whether the active chat is team-only vs. global |

## Key Functions

### Key_Event
- Signature: `void Key_Event(int key, qboolean down, unsigned time)`
- Purpose: Central dispatcher for all input events; routes a key press/release to bindings, console, menu, or chat depending on current input mode.
- Inputs: `key` — `K_*` keycode; `down` — press or release; `time` — event timestamp in ms
- Outputs/Return: void
- Side effects: May execute bound commands, update `anykeydown`, update `key_repeats`, append to `chat_buffer`
- Calls: Defined in `client/keys.c`
- Notes: All platform input backends funnel raw input through this single entry point.

### Key_Init
- Signature: `void Key_Init(void)`
- Purpose: Registers key-related console commands (e.g., `bind`, `unbind`, `bindlist`) and sets up default bindings.
- Inputs: None
- Outputs/Return: void
- Side effects: Registers Cmd entries; populates portions of `keybindings`
- Calls: Defined in `client/keys.c`

### Key_WriteBindings
- Signature: `void Key_WriteBindings(FILE *f)`
- Purpose: Serializes all current key bindings to an open file handle (used when saving `config.cfg`).
- Inputs: `f` — open writable FILE pointer
- Outputs/Return: void
- Side effects: Writes text to `f`
- Calls: Defined in `client/keys.c`

### Key_SetBinding
- Signature: `void Key_SetBinding(int keynum, char *binding)`
- Purpose: Assigns a command string to a keycode slot in `keybindings`.
- Inputs: `keynum` — `K_*` index; `binding` — command string
- Outputs/Return: void
- Side effects: Frees old binding string; allocates and stores new one in `keybindings[keynum]`
- Calls: Defined in `client/keys.c`

### Key_ClearStates
- Signature: `void Key_ClearStates(void)`
- Purpose: Resets all key-down states, typically on focus loss or level transition to prevent stuck keys.
- Inputs: None
- Outputs/Return: void
- Side effects: Clears `key_repeats`, `anykeydown`; may synthesize release events
- Calls: Defined in `client/keys.c`

### Key_GetKey
- Signature: `int Key_GetKey(void)`
- Purpose: Blocking poll that waits for the next key press and returns its keycode; used for interactive key-capture UI (e.g., the "press a key" binding dialog in the options menu).
- Inputs: None
- Outputs/Return: `K_*` keycode of the next pressed key
- Side effects: Spins on engine frame loop until input arrives
- Notes: Not inferable from this file whether it is truly blocking or polls a latched value set by `Key_Event`.

## Control Flow Notes
`Key_Init` is called during client startup. Per-frame, the platform input backend calls `Key_Event` for each raw event. `Key_WriteBindings` is called during config save. `Key_ClearStates` is called on disconnect or window focus loss.

## External Dependencies
- No `#include` directives present in this header.
- `qboolean`, `FILE` — assumed available via `qcommon.h` / standard headers included by translation units that include this header.
- All declared symbols are **defined in `client/keys.c`**.
