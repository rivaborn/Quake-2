# client/vid.h

## File Purpose
Defines the public interface for the video driver subsystem. It declares shared data types for video geometry and global video state, and exposes the lifecycle and menu functions that the engine uses to manage the display system.

## Core Responsibilities
- Define the `vrect_t` rectangle type used across rendering subsystems
- Define `viddef_t` to carry global display dimensions
- Declare the `viddef` global that all subsystems read for current resolution
- Expose video lifecycle entry points (`Init`, `Shutdown`, `CheckChanges`)
- Expose video options menu entry points used by the in-game menu system

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `vrect_t` | struct (`vrect_s`) | Axis-aligned integer rectangle (x, y, width, height); used for viewport/scissor regions |
| `viddef_t` | struct (anonymous) | Holds current display width and height; read by renderer and HUD code |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `viddef` | `viddef_t` | global (extern) | Single source of truth for current video resolution; defined in a platform video module |

## Key Functions

### VID_Init
- Signature: `void VID_Init(void)`
- Purpose: Initialise the video subsystem; loads the renderer DLL/shared library and sets up the display mode.
- Inputs: None
- Outputs/Return: void
- Side effects: Allocates display resources, sets `viddef`, registers cvars/commands.
- Calls: Not inferable from this file (declaration only).
- Notes: Called once at engine startup.

### VID_Shutdown
- Signature: `void VID_Shutdown(void)`
- Purpose: Tear down the video subsystem and release all display resources.
- Inputs: None
- Outputs/Return: void
- Side effects: Frees display/renderer resources, unloads renderer module.
- Calls: Not inferable from this file.
- Notes: Paired with `VID_Init`; called on engine exit or vid restart.

### VID_CheckChanges
- Signature: `void VID_CheckChanges(void)`
- Purpose: Per-frame check for pending video mode or renderer changes (e.g., resolution cvar changes); triggers a vid restart if needed.
- Inputs: None
- Outputs/Return: void
- Side effects: May call `VID_Shutdown` + `VID_Init` internally; updates `viddef`.
- Calls: Not inferable from this file.
- Notes: Intended to be called once per frame from the main loop.

### VID_MenuInit / VID_MenuDraw / VID_MenuKey
- `VID_MenuInit`: Populates the video options menu state.
- `VID_MenuDraw`: Renders the video options menu each frame.
- `VID_MenuKey(int)`: Handles a key event while the video menu is active; returns a string sound cue or NULL.

## Control Flow Notes
- `VID_Init` is called during engine startup.
- `VID_CheckChanges` is polled each frame (likely from `CL_Frame` or the main loop) to apply deferred mode changes.
- `VID_Shutdown` is called on engine exit or when a full video restart is required.
- The `VID_Menu*` functions are driven by the in-game menu system during the menu frame.

## External Dependencies
- No includes in this header beyond implicit engine conventions.
- `viddef` is **defined elsewhere** (platform-specific video module, e.g., `win32/vid_dll.c` or `linux/vid_so.c`).
- `vrect_t` is consumed by rendering and HUD code across the codebase.
