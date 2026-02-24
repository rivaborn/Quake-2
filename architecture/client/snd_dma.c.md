# client/snd_dma.c

## File Purpose
Main control layer for the Quake 2 streaming sound output system. It manages sound registration, channel allocation, spatialization, playsound queuing, and drives the DMA mixing pipeline each frame.

## Core Responsibilities
- Initialize and shut down the sound system via the platform DMA backend (`SNDDMA_*`)
- Manage the `sfx_t` registry (load, alias, register, expire sounds by sequence)
- Allocate and schedule `playsound_t` events in a time-sorted pending queue
- Pick and configure `channel_t` slots for active playback
- Spatialize channels (stereo pan + distance attenuation) each frame
- Generate looped autosounds from entity state each frame
- Feed raw PCM samples for cinematic/voice streaming (`s_rawsamples`)
- Drive the mixing loop by computing `endtime` and calling `S_PaintChannels`

## Key Types / Data Structures
| Name | Kind | Purpose |
|---|---|---|
| `channel_t` | struct (external) | Active playing sound slot with vol, pos, sfx ptr |
| `playsound_t` | struct (external) | Pending sound event in doubly-linked time-sorted list |
| `sfx_t` | struct (external) | Sound asset descriptor with name, cache ptr, registration seq |
| `sfxcache_t` | struct (external) | Decoded PCM data block |
| `dma_t` | struct (external) | DMA buffer descriptor (speed, samples, bits, buffer ptr) |
| `portable_samplepair_t` | typedef (external) | Stereo int pair used in raw sample buffer |

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `channels[MAX_CHANNELS]` | `channel_t[]` | global | All active sound channels |
| `dma` | `dma_t` | global | DMA buffer state shared with mixer and backend |
| `known_sfx[MAX_SFX]` | `sfx_t[]` | global | Flat array of all loaded/registered sounds |
| `num_sfx` | `int` | global | Count of occupied `known_sfx` slots |
| `s_playsounds[MAX_PLAYSOUNDS]` | `playsound_t[]` | global | Pool backing the free/pending lists |
| `s_freeplays` / `s_pendingplays` | `playsound_t` | global | Doubly-linked list sentinels |
| `soundtime` / `paintedtime` | `int` | global | DMA playback cursor / mixer write cursor (sample pairs) |
| `listener_origin/forward/right/up` | `vec3_t` | global | Listener pose for spatialization |
| `s_rawsamples[MAX_RAW_SAMPLES]` | `portable_samplepair_t[]` | global | Ring buffer for streaming raw PCM |
| `s_rawend` | `int` | global | Write head into raw sample ring buffer |
| `s_beginofs` | `int` | global | Drift correction offset for scheduled sound start times |
| `sound_started` / `snd_initialized` | `int`/`qboolean` | global | System-ready guards |
| `s_registration_sequence` | `int` | global | Incremented each map load to expire stale sounds |
| `s_volume`, `s_khz`, etc. | `cvar_t *` | global | User-configurable sound cvars |

## Key Functions

### S_Init
- Signature: `void S_Init(void)`
- Purpose: Initializes the entire sound subsystem.
- Inputs: None (reads cvars, calls `SNDDMA_Init`).
- Outputs/Return: None.
- Side effects: Registers console commands, sets `sound_started=1`, calls `S_InitScaletable`, `S_StopAllSounds`.
- Calls: `Cvar_Get`, `Cmd_AddCommand`, `SNDDMA_Init`, `S_InitScaletable`, `S_StopAllSounds`.

### S_Shutdown
- Signature: `void S_Shutdown(void)`
- Purpose: Tears down sound system, frees all `sfx_t` caches, removes console commands.
- Side effects: Calls `SNDDMA_Shutdown`, frees `Z_Malloc` blocks, zeroes `known_sfx`.

### S_StartSound
- Signature: `void S_StartSound(vec3_t origin, int entnum, int entchannel, sfx_t *sfx, float fvol, float attenuation, float timeofs)`
- Purpose: Queues a sound into the pending playsound list with timing derived from server frame time and `s_beginofs` drift correction.
- Inputs: World origin (or NULL for entity-tracked), entity/channel IDs, sfx handle, volume, attenuation, time offset.
- Outputs/Return: None.
- Side effects: Allocates a `playsound_t`, inserts it sorted by `begin` into `s_pendingplays`.
- Calls: `S_RegisterSexedSound`, `S_LoadSound`, `S_AllocPlaysound`.
- Notes: Sexed sounds (`*` prefix) are resolved to model-specific files here.

### S_Update
- Signature: `void S_Update(vec3_t origin, vec3_t forward, vec3_t right, vec3_t up)`
- Purpose: Per-frame sound update — respatialization, loop sound generation, then mixing.
- Inputs: Current listener pose vectors.
- Side effects: Updates `listener_*` globals, clears dead autosound channels, calls `S_AddLoopSounds`, drives `S_Update_`.
- Calls: `S_ClearBuffer`, `S_InitScaletable`, `S_Spatialize`, `S_AddLoopSounds`, `S_Update_`.

### S_Update_ (internal mixer pump)
- Signature: `void S_Update_(void)`
- Purpose: Computes `endtime` from `soundtime + s_mixahead`, calls `S_PaintChannels` to fill the DMA buffer, then submits.
- Calls: `SNDDMA_BeginPainting`, `GetSoundtime`, `S_PaintChannels`, `SNDDMA_Submit`.
- Notes: Clamps `endtime` to buffer size; detects `paintedtime` overflow and resets.

### S_IssuePlaysound
- Signature: `void S_IssuePlaysound(playsound_t *ps)`
- Purpose: Dequeues the next pending playsound, picks a channel, spatialization, and schedules its end time.
- Calls: `S_PickChannel`, `S_FreePlaysound`, `S_Spatialize`, `S_LoadSound`.
- Notes: Called by the update loop, not directly by `S_StartSound`.

### S_SpatializeOrigin
- Signature: `void S_SpatializeOrigin(vec3_t origin, float master_vol, float dist_mult, int *left_vol, int *right_vol)`
- Purpose: Computes left/right volumes using dot-product stereo pan and linear distance attenuation.
- Notes: Full volume within `SOUND_FULLVOLUME` (80 units); mono or zero `dist_mult` disables panning.

### S_AddLoopSounds
- Signature: `void S_AddLoopSounds(void)`
- Purpose: Scans current frame entities, accumulates spatialized volume for each unique looped sound, allocates autosound channels.
- Calls: `S_SpatializeOrigin`, `S_PickChannel`.
- Notes: Channels are marked `autosound=true` so they are cleared at the next frame's `S_Update`.

### S_RawSamples
- Signature: `void S_RawSamples(int samples, int rate, int width, int channels, byte *data)`
- Purpose: Feeds external PCM (cinematic, voice) into the `s_rawsamples` ring buffer with rate conversion.
- Notes: Handles all combinations of mono/stereo × 8-bit/16-bit; ring buffer indexed by `s_rawend & (MAX_RAW_SAMPLES-1)`.

### GetSoundtime
- Signature: `void GetSoundtime(void)`
- Purpose: Reads `SNDDMA_GetDMAPos`, tracks buffer wrap-arounds, updates `soundtime`.
- Notes: Resets to avoid 32-bit overflow when `paintedtime > 0x40000000`.

## Control Flow Notes
`S_Init` is called at engine startup. Each client frame, `S_Update` is called with the listener pose: it respatialized channels, rebuilds loop sounds, then calls `S_Update_` which fills the DMA buffer via `S_PaintChannels` (defined in `snd_mix.c`). `S_IssuePlaysound` is called from within the update path to drain the pending queue. `S_Shutdown` is called on engine exit or sound restart.

## External Dependencies
- `client.h` — `cl`, `cls`, `cl_entities`, `cl_parse_entities`, `cl_paused`
- `snd_loc.h` — `channel_t`, `playsound_t`, `sfx_t`, `sfxcache_t`, `dma_t`, `MAX_CHANNELS`, `MAX_RAW_SAMPLES`, `ATTN_STATIC`
- `SNDDMA_Init/Shutdown/BeginPainting/Submit/GetDMAPos` — platform DMA backend (defined in `snd_win.c` / `snd_linux.c`)
- `S_PaintChannels` — defined in `snd_mix.c`
- `S_LoadSound`, `S_InitScaletable` — defined in `snd_mem.c`
- `CL_GetEntitySoundOrigin` — defined in `cl_ents.c`
- `Z_Malloc`, `Z_Free`, `Com_PageInMemory`, `FS_FOpenFile`, `FS_FCloseFile` — engine common
