# client/snd_mix.c

## File Purpose
Implements the portable sound mixing layer for Quake 2's audio system. It paints active sound channels into an intermediate paintbuffer, then transfers that buffer to the DMA output buffer in the appropriate hardware format.

## Core Responsibilities
- Maintain and fill `paintbuffer` with mixed stereo sample pairs each frame
- Mix 8-bit and 16-bit sound channels into the paintbuffer with per-channel volume scaling
- Handle streaming raw audio (e.g., cinematics) via `s_rawsamples`
- Transfer the paintbuffer to the DMA output buffer, converting to the hardware's bit depth and channel count
- Issue pending `playsound_t` events at the correct time during mixing
- Precompute a volume scale lookup table for fast 8-bit channel mixing

## Key Types / Data Structures
None (types are defined in `snd_loc.h` and `client.h`).

## Global / File-Static State
| Name | Type | Scope | Purpose |
|---|---|---|---|
| `paintbuffer` | `portable_samplepair_t[2048]` | global | Intermediate stereo mix buffer |
| `snd_scaletable` | `int[32][256]` | global | Precomputed volume-scaled lookup for 8-bit samples |
| `snd_p` | `int *` | global | Pointer into paintbuffer during stereo16 transfer |
| `snd_linear_count` | `int` | global | Number of samples to write in one linear blast |
| `snd_vol` | `int` | global | Master volume scaled to integer (used by 16-bit mixer) |
| `snd_out` | `short *` | global | Output pointer into DMA buffer during stereo16 transfer |

## Key Functions

### S_WriteLinearBlastStereo16
- Signature: `void S_WriteLinearBlastStereo16(void)`
- Purpose: Clamp-converts `snd_linear_count` int samples from `snd_p` into 16-bit signed output at `snd_out`.
- Inputs: Implicit globals `snd_p`, `snd_out`, `snd_linear_count`
- Outputs/Return: Writes to `snd_out`
- Side effects: Writes DMA output buffer region
- Calls: None
- Notes: Has two implementations — a portable C path and an x86 MSVC naked-asm path (`id386`). Linux/i386 uses an external `.s` assembly implementation.

### S_TransferStereo16
- Signature: `void S_TransferStereo16(unsigned long *pbuf, int endtime)`
- Purpose: Loops over the recirculating DMA buffer, writing stereo 16-bit output from `paintbuffer` by repeatedly calling `S_WriteLinearBlastStereo16`.
- Inputs: `pbuf` — DMA output buffer; `endtime` — target paint time
- Outputs/Return: Writes to `pbuf`
- Side effects: Sets `snd_p`, `snd_out`, `snd_linear_count`; reads global `paintedtime`, `dma`
- Calls: `S_WriteLinearBlastStereo16`
- Notes: Handles wrap-around in the circular DMA buffer via masking on `dma.samples`.

### S_TransferPaintBuffer
- Signature: `void S_TransferPaintBuffer(int endtime)`
- Purpose: Dispatches paintbuffer to DMA buffer; handles 16-bit stereo fast path, general 16-bit mono, and 8-bit cases. Optionally writes a sine test tone.
- Inputs: `endtime` — paint frame endpoint
- Outputs/Return: None (writes `dma.buffer`)
- Side effects: Reads/writes `paintbuffer`, `paintedtime`, `dma`, `s_testsound`
- Calls: `S_TransferStereo16`, `sin`
- Notes: 8-bit output is bias-shifted by +128 to convert signed to unsigned.

### S_PaintChannels
- Signature: `void S_PaintChannels(int endtime)`
- Purpose: Main per-frame mixer entry point — issues pending playsounds, copies raw stream or clears paintbuffer, then paints all active channels, and transfers output.
- Inputs: `endtime` — target sample time
- Outputs/Return: None
- Side effects: Modifies `paintbuffer`, `paintedtime`, channel `pos`/`end`/`sfx`, calls `S_IssuePlaysound`
- Calls: `S_IssuePlaysound`, `S_LoadSound`, `S_PaintChannelFrom8`, `S_PaintChannelFrom16`, `S_TransferPaintBuffer`, `memset`
- Notes: Chunks work into `PAINTBUFFER_SIZE` (2048) blocks. Handles autosound looping and loopstart-based looping. Stops channel by nulling `ch->sfx`.

### S_InitScaletable
- Signature: `void S_InitScaletable(void)`
- Purpose: Precomputes `snd_scaletable[volume][sample]` for fast 8-bit mixing; clears `s_volume->modified`.
- Inputs: `s_volume->value`
- Outputs/Return: None
- Side effects: Writes `snd_scaletable[32][256]`; sets `s_volume->modified = false`

### S_PaintChannelFrom8
- Signature: `void S_PaintChannelFrom8(channel_t *ch, sfxcache_t *sc, int count, int offset)`
- Purpose: Mixes `count` 8-bit samples from a channel into `paintbuffer` using the precomputed scale table.
- Inputs: Channel (volume, pos), sound cache data, sample count, paintbuffer offset
- Outputs/Return: Accumulates into `paintbuffer`; advances `ch->pos`
- Side effects: Modifies `paintbuffer`, `ch->pos`
- Calls: None
- Notes: Has portable C and x86 asm variants. Clamps `leftvol`/`rightvol` to 255 before table lookup.

### S_PaintChannelFrom16
- Signature: `void S_PaintChannelFrom16(channel_t *ch, sfxcache_t *sc, int count, int offset)`
- Purpose: Mixes `count` 16-bit samples into `paintbuffer` using integer multiply with `snd_vol`.
- Inputs: Channel (leftvol, rightvol, pos), sound cache, sample count, paintbuffer offset
- Outputs/Return: Accumulates into `paintbuffer`; advances `ch->pos`
- Side effects: Modifies `paintbuffer`, `ch->pos`
- Calls: None

## Control Flow Notes
`S_PaintChannels` is the frame-level entry point, called from `snd_dma.c` (`S_Update`). It drives the full mix pipeline: pending sound issuance → raw stream copy or buffer clear → channel paint → DMA transfer. `paintedtime` advances at the end of each chunk, gating all other operations.

## External Dependencies
- `client.h`, `snd_loc.h` — type definitions (`channel_t`, `sfxcache_t`, `portable_samplepair_t`, `dma`, `playsound_t`)
- **Defined elsewhere:** `paintedtime`, `channels`, `MAX_CHANNELS`, `s_pendingplays`, `s_rawend`, `s_rawsamples`, `MAX_RAW_SAMPLES`, `dma`, `s_volume`, `s_testsound`, `S_IssuePlaysound`, `S_LoadSound`
- Platform assembly override: `linux/snd_mixa.s` provides `S_WriteLinearBlastStereo16` and `S_PaintChannelFrom8` for Linux x86
