# client/cl_cin.c

## File Purpose
Implements Quake 2's cinematic playback system, supporting both animated `.cin` video files (Huffman-compressed, with raw PCM audio) and static `.pcx` images displayed fullscreen. It manages frame decoding, audio synchronization, palette activation, and lifecycle (play/stop/finish).

## Core Responsibilities
- Load and decode PCX images for static cinematic screens
- Parse `.cin` binary video files (width/height/audio metadata + Huffman table)
- Build per-context order-1 Huffman decoding trees from the file's 64k count table
- Decompress individual video frames via `Huff1Decompress`
- Synchronize video frame advancement to real time (14 fps)
- Feed raw PCM audio samples to the sound system per frame
- Manage palette switching via the renderer interface
- Signal the server to advance to the next map/cinematic when playback ends

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `cblock_t` | struct | Raw byte buffer with a count; used as input/output for Huffman decompression |
| `cinematics_t` | struct | All global cinematic state: dimensions, pixel buffers, audio params, Huffman tables |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `cin` | `cinematics_t` | global | Singleton holding all active cinematic decode state |

## Key Functions

### SCR_LoadPCX
- **Signature:** `void SCR_LoadPCX(char *filename, byte **pic, byte **palette, int *width, int *height)`
- **Purpose:** Loads and RLE-decodes a PCX image file into a heap-allocated pixel buffer.
- **Inputs:** Filename string; output pointers for pixel data, palette, width, height.
- **Outputs/Return:** Writes allocated pixel buffer to `*pic`, 768-byte palette to `*palette`, dimensions to `*width`/`*height`.
- **Side effects:** Allocates via `Z_Malloc`; frees file buffer via `FS_FreeFile`.
- **Calls:** `FS_LoadFile`, `Z_Malloc`, `Z_Free`, `FS_FreeFile`, `Com_Printf`.
- **Notes:** Validates PCX header fields; sets `*pic = NULL` on malformed input. Does not free palette on error.

### SCR_StopCinematic
- **Signature:** `void SCR_StopCinematic(void)`
- **Purpose:** Tears down all active cinematic resources and resets playback state.
- **Inputs:** None (reads/writes `cin` and `cl` globals).
- **Outputs/Return:** void.
- **Side effects:** Frees `cin.pic`, `cin.pic_pending`, `cin.hnodes1`; closes `cl.cinematic_file`; deactivates renderer palette; may restart sound system.
- **Calls:** `Z_Free`, `re.CinematicSetPalette`, `fclose`, `CL_Snd_Restart_f`.
- **Notes:** Sets `cl.cinematictime = 0` to signal "no cinematic active."

### SCR_FinishCinematic
- **Signature:** `void SCR_FinishCinematic(void)`
- **Purpose:** Notifies the server that cinematic playback is done so the next map/sequence can load.
- **Inputs:** None.
- **Outputs/Return:** void.
- **Side effects:** Writes a `clc_stringcmd` `nextserver` message to the netchan outbound buffer.
- **Calls:** `MSG_WriteByte`, `SZ_Print`, `va`.

### Huff1TableInit
- **Signature:** `void Huff1TableInit(void)`
- **Purpose:** Reads the 256×256 frequency table from the open cinematic file and constructs 256 order-1 Huffman decode trees in `cin.hnodes1`.
- **Inputs:** Reads directly from `cl.cinematic_file`.
- **Outputs/Return:** void; populates `cin.hnodes1` and `cin.numhnodes1[]`.
- **Side effects:** Allocates 256×256×2×4 bytes via `Z_Malloc`; reads file I/O.
- **Calls:** `Z_Malloc`, `memset`, `FS_Read`, `SmallestNode1`.
- **Notes:** Uses a greedy bottom-up tree build (Huffman); `SmallestNode1` is a file-static helper that linearly scans for the lowest-count unused node.

### Huff1Decompress
- **Signature:** `cblock_t Huff1Decompress(cblock_t in)`
- **Purpose:** Decompresses a Huffman-encoded frame buffer into a raw pixel buffer using the prebuilt order-1 trees.
- **Inputs:** `in` — compressed data block (first 4 bytes are little-endian output count).
- **Outputs/Return:** New `cblock_t` with heap-allocated decoded pixel data.
- **Side effects:** Allocates output buffer via `Z_Malloc`.
- **Calls:** `Z_Malloc`, `Com_Printf`.
- **Notes:** Inner loop is manually unrolled 8×per byte for throughput. Overread by 1 byte is tolerated (padding); larger overread logs a warning.

### SCR_ReadNextFrame
- **Signature:** `byte *SCR_ReadNextFrame(void)`
- **Purpose:** Reads, decompresses, and returns the next video frame; feeds corresponding audio samples to the sound system.
- **Inputs:** None (reads `cl.cinematic_file`, uses `cl.cinematicframe`, `cin` state).
- **Outputs/Return:** Pointer to decoded pixel buffer (caller owns), or `NULL` on EOF/last-frame marker.
- **Side effects:** Reads file, advances `cl.cinematicframe`, calls `S_RawSamples`, allocates frame buffer.
- **Calls:** `fread`, `LittleLong`, `FS_Read`, `S_RawSamples`, `Huff1Decompress`, `Com_Error`.
- **Notes:** Command byte `2` signals end-of-file; command `1` triggers palette reload. Frame audio computed at 14 fps rate.

### SCR_RunCinematic
- **Signature:** `void SCR_RunCinematic(void)`
- **Purpose:** Per-frame update: advances frame when real time warrants, handles drop detection, and triggers stop/finish on EOF.
- **Inputs:** None (reads `cls.realtime`, `cl.cinematicframe`, `cin.pic_pending`).
- **Outputs/Return:** void.
- **Side effects:** May free `cin.pic`, swap pending frame, call stop/finish, begin loading plaque.
- **Calls:** `SCR_StopCinematic`, `SCR_ReadNextFrame`, `SCR_FinishCinematic`, `SCR_BeginLoadingPlaque`, `Z_Free`, `Com_Printf`.

### SCR_DrawCinematic
- **Signature:** `qboolean SCR_DrawCinematic(void)`
- **Purpose:** Draws the current cinematic frame fullscreen; returns true if active (suppresses 3D view).
- **Inputs:** None.
- **Outputs/Return:** `true` if cinematic is active (even if no frame to draw yet), `false` if inactive.
- **Side effects:** Calls renderer palette and stretch-blit functions.
- **Calls:** `re.CinematicSetPalette`, `re.DrawStretchRaw`.

### SCR_PlayCinematic
- **Signature:** `void SCR_PlayCinematic(char *arg)`
- **Purpose:** Opens and initializes a cinematic (`.cin` video or `.pcx` static image) and starts playback.
- **Inputs:** `arg` — filename (with extension), relative to `video/` or `pics/`.
- **Outputs/Return:** void.
- **Side effects:** Stops CD audio, opens file, reads header, allocates Huffman tables, may restart sound system at new sample rate, sets `cls.state = ca_active`.
- **Calls:** `CDAudio_Stop`, `SCR_LoadPCX`, `FS_FOpenFile`, `FS_Read`, `LittleLong`, `Huff1TableInit`, `SCR_ReadNextFrame`, `Cvar_VariableValue`, `Cvar_SetValue`, `CL_Snd_Restart_f`, `SCR_EndLoadingPlaque`, `Sys_Milliseconds`, `SCR_FinishCinematic`.

## Control Flow Notes
- `SCR_PlayCinematic` is called during map/server transitions to begin playback; sets `cl.cinematictime` and `cls.state`.
- `SCR_RunCinematic` is called each client frame (from the screen update loop) to advance frames.
- `SCR_DrawCinematic` is called during the render phase; its `true` return suppresses the normal 3D view.
- On EOF, `SCR_RunCinematic` calls `SCR_StopCinematic` → `SCR_FinishCinematic` → sends `nextserver` to the server.

## External Dependencies
- **Includes:** `client.h` (pulls in `cl`, `cls`, `viddef`, `re`, message/network types)
- **Defined elsewhere:** `FS_LoadFile`, `FS_FreeFile`, `FS_Read`, `FS_FOpenFile`, `Z_Malloc`, `Z_Free`, `S_RawSamples`, `CDAudio_Stop`, `CL_Snd_Restart_f`, `MSG_WriteByte`, `SZ_Print`, `re.CinematicSetPalette`, `re.DrawStretchRaw`, `SCR_BeginLoadingPlaque`, `SCR_EndLoadingPlaque`, `Sys_Milliseconds`, `Cvar_VariableValue`, `Cvar_SetValue`, `Com_Error`, `Com_Printf`, `Com_sprintf`
