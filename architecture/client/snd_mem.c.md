# client/snd_mem.c

## File Purpose
Handles loading and caching of sound samples from disk. Parses WAV files into engine-usable `sfxcache_t` structures and resamples audio data to match the output device's sample rate.

## Core Responsibilities
- Load WAV files from the virtual filesystem into memory
- Parse RIFF/WAV chunk structure to extract audio metadata and PCM data
- Resample audio from source rate to DMA output rate
- Allocate and populate `sfxcache_t` cache entries on `sfx_t` objects
- Detect and reject stereo samples (engine requires mono)
- Parse optional loop points from WAV `cue ` chunks

## Key Types / Data Structures
| Name | Kind | Purpose |
|------|------|---------|
| `sfxcache_t` | struct (defined in `snd_loc.h`) | Cached decoded audio: length, loopstart, speed, width, stereo, raw PCM data |
| `sfx_t` | struct (defined in `snd_loc.h`) | Sound effect handle with name, truename, and pointer to cache |
| `wavinfo_t` | struct (defined in `snd_loc.h`) | Intermediate WAV parse result: rate, width, channels, samples, loopstart, dataofs |

## Global / File-Static State
| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `cache_full_cycle` | `int` | global | Cycle counter for cache eviction (declared but not used in this file) |
| `data_p` | `byte *` | static (file-level) | Current read cursor into WAV buffer during parsing |
| `iff_end` | `byte *` | static (file-level) | End boundary of WAV buffer |
| `last_chunk` | `byte *` | static (file-level) | Start of last visited chunk; used by `FindNextChunk` |
| `iff_data` | `byte *` | static (file-level) | Base pointer for chunk search scope |
| `iff_chunk_len` | `int` | static (file-level) | Length of current chunk being examined |

## Key Functions

### ResampleSfx
- **Signature:** `void ResampleSfx(sfx_t *sfx, int inrate, int inwidth, byte *data)`
- **Purpose:** Converts raw PCM data from its source rate/width to the DMA output rate/width and writes it into the already-allocated `sfx->cache->data` buffer.
- **Inputs:** `sfx` with a valid `cache` pointer; `inrate`/`inwidth` from WAV metadata; `data` pointer to raw PCM bytes.
- **Outputs/Return:** void; writes decoded samples directly into `sc->data`.
- **Side effects:** Mutates `sc->length`, `sc->loopstart`, `sc->speed`, `sc->width`, `sc->stereo`.
- **Calls:** `LittleShort`
- **Notes:** Uses fixed-point arithmetic (`samplefrac`/`fracstep` at 8-bit fractional precision) for the general resampling case. Fast path exists when `stepscale == 1 && inwidth == 1 && sc->width == 1`. Assumes `dma.speed` is non-zero.

### S_LoadSound
- **Signature:** `sfxcache_t *S_LoadSound(sfx_t *s)`
- **Purpose:** Top-level entry point to load and cache a sound. Returns existing cache if already loaded, otherwise reads the WAV file, validates it, allocates a cache block, and calls `ResampleSfx`.
- **Inputs:** `sfx_t *s` — sound handle to load.
- **Outputs/Return:** Pointer to populated `sfxcache_t`, or `NULL` on failure.
- **Side effects:** Allocates via `Z_Malloc`; sets `s->cache`; calls `FS_LoadFile`/`FS_FreeFile`.
- **Calls:** `FS_LoadFile`, `GetWavinfo`, `Z_Malloc`, `ResampleSfx`, `FS_FreeFile`, `Com_sprintf`, `Com_DPrintf`, `Com_Printf`
- **Notes:** Skips names prefixed with `'*'` (inline/procedural sounds). Respects `s->truename` alias. Prefixes `sound/` to relative paths unless name starts with `'#'`.

### GetWavinfo
- **Signature:** `wavinfo_t GetWavinfo(char *name, byte *wav, int wavlength)`
- **Purpose:** Parses a RIFF/WAV buffer and extracts format metadata and data offset.
- **Inputs:** `name` for error messages; `wav` pointer to raw file bytes; `wavlength` buffer size.
- **Outputs/Return:** Populated `wavinfo_t`; zeroed struct on parse failure.
- **Side effects:** Writes to file-level WAV parser globals (`data_p`, `iff_data`, `iff_end`, `last_chunk`, `iff_chunk_len`).
- **Calls:** `FindChunk`, `FindNextChunk`, `GetLittleShort`, `GetLittleLong`, `Com_Printf`, `Com_Error`
- **Notes:** Only accepts Microsoft PCM format (format tag == 1). Parses optional `cue ` chunk for loop start; validates loop length against total sample count. **Not re-entrant** due to global parser state.

### Notes (trivial helpers)
- `GetLittleShort` / `GetLittleLong` — read little-endian values from `data_p` and advance it.
- `FindChunk` / `FindNextChunk` — scan `iff_data` for a named 4-byte RIFF chunk tag.
- `DumpChunks` — debug utility that prints all chunk names/offsets; not called in release paths.

## Control Flow Notes
`S_LoadSound` is called lazily by the mixer when a sound is first played. It is not part of the per-frame update loop directly. `ResampleSfx` executes once per sound load and stores results persistently in `Z_Malloc`'d memory attached to the `sfx_t`.

## External Dependencies
- **Includes:** `client.h`, `snd_loc.h`
- **Defined elsewhere:** `dma` (`dma_t` output device state, `snd_dma.c`), `s_loadas8bit` (cvar, `snd_dma.c`), `Z_Malloc`, `FS_LoadFile`, `FS_FreeFile`, `Com_sprintf`, `Com_DPrintf`, `Com_Printf`, `Com_Error`, `LittleShort`; `sfx_t`, `sfxcache_t`, `wavinfo_t` from `snd_loc.h`.
