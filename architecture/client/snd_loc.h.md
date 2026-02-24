# client/snd_loc.h

## File Purpose
Private header for the Quake 2 software sound system. Defines internal data structures, shared state (extern declarations), and internal function prototypes used across `snd_dma.c`, `snd_mem.c`, `snd_mix.c`, and platform-specific DMA backends.

## Core Responsibilities
- Define the core sound data structures (`sfx_t`, `sfxcache_t`, `channel_t`, `dma_t`, `playsound_t`, `wavinfo_t`)
- Declare the DMA abstraction layer (SNDDMA_* functions) that platform backends must implement
- Expose shared globals (channels, listener state, DMA handle, cvars) to all sound subsystem translation units
- Declare internal utility functions used across sound subsystem files

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `portable_samplepair_t` | struct | Stereo sample pair (left/right int) for the mixer paint buffer; layout is ABI-critical (referenced by asm) |
| `sfxcache_t` | struct | Decoded/cached audio data for a loaded sound effect; `data[1]` is a flexible array |
| `sfx_t` | struct | Sound effect handle: name, registration sequence, pointer to decoded cache, and optional true filename |
| `playsound_t` | struct | Deferred play request linked-list node; holds all parameters needed to assign a sound to a channel at a future sample time |
| `dma_t` | struct | DMA buffer descriptor: layout, size, position, and pointer to the platform-provided ring buffer |
| `channel_t` | struct | Active mixing channel; holds spatialised volumes, playback position, loop info, and entity association; layout is ABI-critical (referenced by asm) |
| `wavinfo_t` | struct | Parsed WAV file metadata used during sound loading |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `channels[MAX_CHANNELS]` | `channel_t[32]` | global | All active mixing channels |
| `paintedtime` | `int` | global | Current mix position in global paintsamples |
| `s_rawend` | `int` | global | End position of raw (streaming) audio in paintsamples |
| `listener_origin/forward/right/up` | `vec3_t` | global | Listener transform used for spatialization |
| `dma` | `dma_t` | global | DMA buffer handle shared between mixer and platform backend |
| `s_pendingplays` | `playsound_t` | global | Head/sentinel of the pending playsound linked list |
| `s_rawsamples[MAX_RAW_SAMPLES]` | `portable_samplepair_t[8192]` | global | Ring buffer for raw (cinematic/streaming) audio injection |
| `s_volume`, `s_nosound`, `s_loadas8bit`, `s_khz`, `s_show`, `s_mixahead`, `s_testsound`, `s_primary` | `cvar_t *` | global | Sound configuration cvars |

## Key Functions

### SNDDMA_Init
- Signature: `qboolean SNDDMA_Init(void)`
- Purpose: Platform-specific DMA initialization; fills `dma` struct and begins cycling the DMA buffer.
- Inputs: None
- Outputs/Return: `qtrue` on success
- Side effects: Allocates/maps platform audio buffer, populates `dma`
- Calls: Defined in platform backends (e.g., `win32/snd_win.c`, `linux/snd_linux.c`)
- Notes: Declared here; implemented elsewhere

### SNDDMA_GetDMAPos
- Signature: `int SNDDMA_GetDMAPos(void)`
- Purpose: Returns the current hardware playback position within the DMA buffer in mono samples.
- Inputs: None
- Outputs/Return: Current sample position
- Side effects: None
- Calls: Platform backend

### SNDDMA_BeginPainting / SNDDMA_Submit
- Signature: `void SNDDMA_BeginPainting(void)` / `void SNDDMA_Submit(void)`
- Purpose: Lock/unlock the DMA buffer around a mix cycle (required on some platforms).
- Side effects: May lock audio hardware buffer

### S_PaintChannels
- Signature: `void S_PaintChannels(int endtime)`
- Purpose: Mix all active channels up to `endtime` into the DMA paint buffer.
- Inputs: `endtime` — target mix position in paintsamples
- Outputs/Return: None
- Side effects: Writes to platform DMA buffer, advances `paintedtime`
- Calls: Defined in `snd_mix.c`

### S_Spatialize
- Signature: `void S_Spatialize(channel_t *ch)`
- Purpose: Compute per-channel left/right volumes based on listener position and channel origin/attenuation.
- Inputs: `ch` — channel to spatialise
- Side effects: Writes `ch->leftvol`, `ch->rightvol`, `ch->dist_mult`

### S_PickChannel
- Signature: `channel_t *S_PickChannel(int entnum, int entchannel)`
- Purpose: Select a free or lowest-priority channel slot for a new sound, evicting if necessary.
- Outputs/Return: Pointer to chosen `channel_t`

### Notes
- `GetWavinfo`, `S_LoadSound`, `S_InitScaletable`, `S_IssuePlaysound` are internal helpers declared here and implemented across `snd_mem.c`/`snd_dma.c`/`snd_mix.c`.

## Control Flow Notes
This header is included by all three sound subsystem files. `snd_dma.c` drives the frame update (calls `S_PaintChannels` → `SNDDMA_Submit`). `snd_mem.c` handles loading (`S_LoadSound`, `GetWavinfo`). `snd_mix.c` implements the mixer (`S_PaintChannels`, `S_InitScaletable`). Platform DMA backends implement the `SNDDMA_*` interface.

## External Dependencies
- `qcommon/qcommon.h` (implied) — `vec3_t`, `vec_t`, `qboolean`, `byte`, `MAX_QPATH`, `cvar_t`
- Platform DMA backends — implement all `SNDDMA_*` functions
- ASM mixer routines — depend on exact layout of `portable_samplepair_t` and `channel_t`
