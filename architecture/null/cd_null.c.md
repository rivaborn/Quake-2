# null/cd_null.c

## File Purpose
Null (stub) implementation of the CD audio subsystem. Provides no-op function bodies so the engine can compile and link on platforms or configurations where CD audio support is intentionally absent.

## Core Responsibilities
- Satisfy the CD audio interface contract required by the rest of the engine
- Allow headless/dedicated-server or unsupported-platform builds to link without a real CD audio backend
- Return success (`0`) from `CDAudio_Init` to avoid triggering error paths in callers

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions

### CDAudio_Init
- Signature: `int CDAudio_Init(void)`
- Purpose: Stub initializer; signals successful init to the caller.
- Inputs: None
- Outputs/Return: `0` (success)
- Side effects: None
- Calls: None
- Notes: Real implementations would open the CD device here. Returning `0` prevents the engine from treating missing CD audio as a fatal error.

### CDAudio_Play
- Signature: `void CDAudio_Play(int track, qboolean looping)`
- Purpose: No-op stub for starting CD track playback.
- Inputs: `track` — track number; `looping` — whether to loop
- Outputs/Return: None
- Side effects: None
- Calls: None
- Notes: None

### CDAudio_Stop / CDAudio_Resume / CDAudio_Update / CDAudio_Shutdown
- All are void no-ops with no side effects, inputs, or calls.
- `CDAudio_Update` would normally be pumped each frame; here it is safe to call every frame with zero cost.

## Control Flow Notes
`CDAudio_Init` is called during engine startup; `CDAudio_Shutdown` during teardown. `CDAudio_Update` is driven per-frame by the client loop. None of these participate in any real control flow in this null build.

## External Dependencies
- `../client/client.h` — pulled in for `qboolean` and to satisfy the interface declaration; no symbols from it are actually used here.
