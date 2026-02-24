# linux/snd_linux.c

## File Purpose
Linux-specific OSS (Open Sound System) audio backend for Quake 2. Initializes the DSP device via `ioctl`, memory-maps the DMA buffer, and provides the platform sound interface consumed by the portable audio mixer.

## Core Responsibilities
- Open and configure `/dev/dsp` (or user-specified device) via OSS ioctls
- Validate DSP capabilities (trigger + mmap support required)
- Negotiate sample rate, bit depth, and channel count with the hardware
- Memory-map the audio DMA buffer into the process address space
- Report current DMA playback position to the mixer
- Provide stub shutdown, submit, and paint-begin entry points

## Key Types / Data Structures
None defined in this file; uses `struct audio_buf_info` and `struct count_info` from `<linux/soundcard.h>`, and `dma_t dma` from `snd_loc.h`.

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `audio_fd` | `int` | global | File descriptor for the open DSP device |
| `snd_inited` | `int` | global | Flag: 1 if sound system is active |
| `sndbits` | `cvar_t *` | global | Cvar: desired sample bit depth (default 16) |
| `sndspeed` | `cvar_t *` | global | Cvar: desired sample rate (0 = auto-detect) |
| `sndchannels` | `cvar_t *` | global | Cvar: desired channel count (default 2) |
| `snddevice` | `cvar_t *` | global | Cvar: device path (default `/dev/dsp`) |
| `tryrates` | `static int[]` | static | Fallback sample rates tried in order when `sndspeed` is 0 |

## Key Functions

### SNDDMA_Init
- **Signature:** `qboolean SNDDMA_Init(void)`
- **Purpose:** Full initialization of the OSS audio device: opens device, negotiates format, mmap's the DMA buffer, and starts playback trigger.
- **Inputs:** None (reads cvars; uses `saved_euid` extern for privilege escalation)
- **Outputs/Return:** `1` on success, `0` on any failure; populates `dma` global fields (`samplebits`, `speed`, `channels`, `samples`, `submission_chunk`, `buffer`, `samplepos`)
- **Side effects:** Opens `audio_fd`; mmaps `dma.buffer`; sets `snd_inited = 1`; temporarily elevates effective UID via `seteuid(saved_euid)` to open the device
- **Calls:** `Cvar_Get`, `seteuid`, `getuid`, `open`, `close`, `ioctl` (RESET, GETCAPS, GETOSPACE, STEREO, SPEED, SETFMT, SETTRIGGER), `mmap`, `perror`, `Com_Printf`
- **Notes:** Returns `void` cast as boolean on the `if (snd_inited) return;` early-exit path — missing explicit return value is a latent bug. Requires both `DSP_CAP_TRIGGER` and `DSP_CAP_MMAP` or aborts. Sample format is set *after* mmap, which is unusual ordering. The `sizeof(tryrates)/4` idiom is fragile (assumes 4-byte int).

### SNDDMA_GetDMAPos
- **Signature:** `int SNDDMA_GetDMAPos(void)`
- **Purpose:** Returns the current hardware playback position in samples, updating `dma.samplepos`.
- **Inputs:** None
- **Outputs/Return:** Current sample position (`dma.samplepos`); `0` if not initialized or on error
- **Side effects:** On ioctl failure: closes `audio_fd`, sets `snd_inited = 0`
- **Calls:** `ioctl(SNDCTL_DSP_GETOPTR)`, `close`, `perror`, `Com_Printf`
- **Notes:** An alternate computation using `count.bytes` is commented out. No wraparound masking applied here (unlike the commented-out line).

### SNDDMA_Shutdown
- **Signature:** `void SNDDMA_Shutdown(void)`
- **Purpose:** Intended to close the audio device on shutdown.
- **Side effects:** None — entire body is `#if 0`'d out; effectively a no-op.
- **Notes:** Device leak; `audio_fd` is never closed on clean shutdown.

### SNDDMA_Submit / SNDDMA_BeginPainting
- Both are empty stubs. With mmap-based DMA, no explicit submission or paint-begin work is needed at this layer.

## Control Flow Notes
Called during engine audio init (`S_Init` → `SNDDMA_Init`). `SNDDMA_GetDMAPos` is polled every frame by the portable mixer to determine how much of the ring buffer has been consumed. `SNDDMA_Submit` is called after mixing; it's a no-op here because the mmap'd buffer is consumed directly by the hardware.

## External Dependencies
- `<linux/soundcard.h>` — OSS API (`SNDCTL_*`, `DSP_CAP_*`, `AFMT_*`, `count_info`, `audio_buf_info`)
- `<sys/mman.h>` — `mmap`
- `../client/client.h` — `Com_Printf`, `cvar_t`, `Cvar_Get`
- `../client/snd_loc.h` — `dma` global (`dma_t`), portable DMA struct
- `saved_euid` — extern `uid_t`, defined in the Linux system layer (`sys_linux.c`)
