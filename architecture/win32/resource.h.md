# win32/resource.h

## File Purpose
Auto-generated Windows resource header produced by Microsoft Developer Studio (MSVC IDE). It defines resource IDs used by the Win32 resource script `q2.rc` and tracks next-available ID counters for the IDE's resource editor.

## Core Responsibilities
- Defines the numeric ID (`IDI_ICON1`) for the application icon resource
- Provides APSTUDIO counter macros so the MSVC resource editor can assign non-conflicting IDs to new resources

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions
None. This is a pure macro/constant header with no functions.

## Control Flow Notes
Not applicable. Included by `q2.rc` at compile time; the `APSTUDIO_INVOKED` guard ensures the counter macros are only visible to the IDE resource editor, not to the C compiler.

## External Dependencies
- Included by: `win32/q2.rc`
- No external symbols; entirely self-contained preprocessor definitions

---

**Notes:**
- `IDI_ICON1 = 101` — the application icon, loaded via `LoadIcon()` in the Win32 startup path (likely `win32/sys_win.c` or `win32/vid_dll.c`)
- The `_APS_*` macros are IDE bookkeeping only and have no runtime effect
- The `//{{NO_DEPENDENCIES}}` sentinel is an MSVC resource editor annotation, not a functional directive
