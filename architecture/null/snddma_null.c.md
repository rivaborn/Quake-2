# null/snddma_null.c

## File Purpose
Provides a no-op null implementation of the platform-specific DMA sound driver interface. Used as a stub when no audio hardware or audio system is available, allowing the engine to compile and run silently without platform sound support.

## Core Responsibilities
- Satisfies the `SNDDMA_*` link-time interface required by the portable sound mixer
- Always reports initialization failure (`SNDDMA_Init` returns `false`)
- Returns safe zero/void values for all queries and lifecycle callbacks

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions

### SNDDMA_Init
- **Signature:** `qboolean SNDDMA_Init(void)`
- **Purpose:** Attempts to initialize the DMA sound device; always fails in this null driver.
- **Inputs:** None
- **Outputs/Return:** `false` — signals to the sound system that no audio device is available
- **Side effects:** None
- **Calls:** None
- **Notes:** Returning `false` causes the upper-level sound system (`snd_dma.c`) to disable all audio processing for the session.

### SNDDMA_GetDMAPos
- **Signature:** `int SNDDMA_GetDMAPos(void)`
- **Purpose:** Returns the current DMA write cursor position in the output buffer.
- **Inputs:** None
- **Outputs/Return:** `0` — always reports position zero
- **Side effects:** None
- **Calls:** None
- **Notes:** Only called if the sound system is active; unreachable in practice since `SNDDMA_Init` always returns `false`.

### SNDDMA_Shutdown
- **Signature:** `void SNDDMA_Shutdown(void)`
- **Purpose:** Releases platform sound resources on shutdown.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** None
- **Calls:** None

### SNDDMA_BeginPainting
- **Signature:** `void SNDDMA_BeginPainting(void)`
- **Purpose:** Called before the portable mixer writes samples into the DMA buffer; typically locks the audio buffer on real drivers.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** None
- **Calls:** None

### SNDDMA_Submit
- **Signature:** `void SNDDMA_Submit(void)`
- **Purpose:** Called after the portable mixer finishes writing samples; typically unlocks and submits the buffer to hardware.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** None
- **Calls:** None

## Control Flow Notes
The `SNDDMA_*` functions are called by `client/snd_dma.c` during the sound subsystem lifecycle: `SNDDMA_Init` at startup, `SNDDMA_BeginPainting`/`SNDDMA_Submit` each frame around the portable mix step, `SNDDMA_GetDMAPos` to track buffer progress, and `SNDDMA_Shutdown` at exit. Because `SNDDMA_Init` returns `false`, the sound system marks itself disabled and none of the remaining functions are reached at runtime.

## External Dependencies
- `../client/client.h` — pulls in `qboolean` and shared client types
- `../client/snd_loc.h` — declares the `SNDDMA_*` interface contract; all five symbols are defined here and expected by `snd_dma.c`
