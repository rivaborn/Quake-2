# irix/snd_irix.c

## File Purpose
Implements the IRIX-platform DMA sound backend for Quake 2 using SGI's AL (Audio Library) API. It manages an audio output port, a circular DMA buffer, and frame-accurate submission of mixed audio to the hardware.

## Core Responsibilities
- Initialize the SGI AL audio port and configure sample rate, bit depth, and channel count
- Expose a static DMA buffer to the engine's mixer via the `dma` global
- Track playback position using UST (Unadjusted System Time) timestamps
- Submit mixed audio frames to the AL port, handling buffer wrap-around
- Handle underflow/overflow by discarding stale frames before writing

## Key Types / Data Structures
None (uses AL library types and engine types defined elsewhere).

| Name | Kind | Purpose |
|------|------|---------|
| `ALport` | typedef (AL library) | Handle to an open SGI audio output port |
| `ALconfig` | typedef (AL library) | Configuration object for AL port setup |
| `ALpv` | struct (AL library) | Parameter/value pair for `alSetParams` |
| `dma_t dma` | struct (engine) | Engine-wide DMA sound descriptor; filled by init |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `dma_buffer` | `short int[QSND_BUFFER_SIZE]` | global | Circular audio sample buffer (16-bit stereo, 8192 frames) |
| `sgisnd_aport` | `ALport` | global | Handle to the open SGI audio port |
| `sgisnd_startframe` | `long long` | global | Frame index of the current playback position |
| `sgisnd_frames_per_ns` | `double` | global | Conversion factor: audio frames per nanosecond |
| `sgisnd_lastframewritten` | `long long` | global | Last frame index written; used to detect underflow/overlap |
| `s_loadas8bit` | `cvar_t *` | global | Cvar controlling bit depth (forced to 16) |
| `s_khz` | `cvar_t *` | global | Cvar selecting sample rate |
| `sndchannels` | `cvar_t *` | global | Cvar selecting channel count |

## Key Functions

### SNDDMA_Init
- **Signature:** `qboolean SNDDMA_Init(void)`
- **Purpose:** Initializes the SGI audio subsystem, configures the DMA descriptor, and opens an AL write port.
- **Inputs:** None (reads cvars `s_loadas8bit`, `s_khz`, `sndchannels`)
- **Outputs/Return:** `true` always (even on port open failure); populates `dma` fields
- **Side effects:** Opens `sgisnd_aport`; sets `dma.buffer`, `dma.samples`, `dma.speed`, etc.; computes `sgisnd_frames_per_ns`
- **Calls:** `Cvar_Get`, `Com_Printf`, `alNewConfig`, `alSetChannels`, `alSetSampFmt`, `alSetQueueSize`, `alSetWidth`, `alOpenPort`, `alSetParams`, `alGetResource`, `alIntToFixed`, `alFreeConfig`, `Cvar_SetValue`
- **Notes:** Only 16-bit stereo is actually functional; 8-bit and non-stereo paths emit warnings but do not abort. Returns `true` even if `alOpenPort` fails.

### SNDDMA_GetDMAPos
- **Signature:** `int SNDDMA_GetDMAPos(void)`
- **Purpose:** Returns the current mono sample position within the circular DMA buffer for the mixer to compute fill requirements.
- **Inputs:** None (reads `sgisnd_aport`)
- **Outputs/Return:** Integer buffer position in mono samples (via `UST_TO_BUFFPOS` macro)
- **Side effects:** Updates `sgisnd_startframe` using UST delta correction; adds a +100 frame lookahead fudge
- **Calls:** `alGetFrameTime`, `dmGetUST`
- **Notes:** The +100 frame offset is an undocumented latency compensation hack. Returns 0 if port is not open.

### SNDDMA_Submit
- **Signature:** `void SNDDMA_Submit(void)`
- **Purpose:** Writes pending mixed audio frames from `dma_buffer` to the AL port, handling circular wrap-around and underflow recovery.
- **Inputs:** None (reads `dma`, `dma_buffer`, `paintedtime`, `soundtime`, `sgisnd_startframe`)
- **Outputs/Return:** void
- **Side effects:** Calls `alDiscardFrames` to discard stale/overflowed data; calls `alWriteFrames` (up to twice for wrap); updates `sgisnd_lastframewritten`
- **Calls:** `alGetFillable`, `alDiscardFrames`, `alWriteFrames`
- **Notes:** Skips submission if fewer than `QSND_SKID` (2) frames are pending. Splits write into two calls when the write region wraps past `QSND_BUFFER_SIZE`.

### SNDDMA_Shutdown
- **Signature:** `void SNDDMA_Shutdown(void)`
- **Purpose:** Closes the AL audio port and nulls the handle.
- **Side effects:** Closes `sgisnd_aport`, sets it to `NULL`.
- **Calls:** `alClosePort`

### SNDDMA_BeginPainting
- **Signature:** `void SNDDMA_BeginPainting(void)`
- **Purpose:** No-op stub; required by the engine's platform sound interface.

## Control Flow Notes
- `SNDDMA_Init` is called once at startup by the engine sound system.
- `SNDDMA_GetDMAPos` is polled each frame to determine how much buffer space to fill.
- `SNDDMA_Submit` is called after mixing to push new frames to hardware.
- `SNDDMA_Shutdown` is called on exit or sound system restart.

## External Dependencies
- `<dmedia/dmedia.h>`, `<dmedia/audio.h>` — SGI IRIX AL/DM audio APIs
- `../client/client.h`, `../client/snd_loc.h` — engine sound types (`dma_t dma`, `paintedtime`)
- `soundtime`, `paintedtime` — defined elsewhere in the engine sound mixer
- `dma` — global `dma_t` defined in `client/snd_dma.c`
