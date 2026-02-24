# win32/snd_win.c

## File Purpose
Windows-specific sound output backend for Quake 2, implementing the `SNDDMA_*` interface used by the portable sound mixer. Supports two output paths: DirectSound (preferred) and WinMM waveOut (fallback), sharing a common DMA buffer abstraction (`dma`).

## Core Responsibilities
- Load and initialize DirectSound via runtime DLL binding (`dsound.dll`)
- Create and manage DirectSound primary/secondary buffers
- Initialize WinMM waveOut as a fallback audio device
- Expose the `dma` buffer to the portable mixer via lock/unlock (`BeginPainting`/`Submit`)
- Report current playback position to the mixer (`SNDDMA_GetDMAPos`)
- Handle window focus changes by recreating/destroying DS buffers (`S_Activate`)
- Clean up all sound resources on shutdown (`FreeSound`)

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `sndinitstat` | enum | Return code for DirectSound init: `SIS_SUCCESS`, `SIS_FAILURE`, `SIS_NOTAVAIL` |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `pDirectSoundCreate` | function pointer | global | Runtime-bound entry point from `dsound.dll` |
| `dsound_init` | `qboolean` | static | True if DirectSound initialized successfully |
| `wav_init` | `qboolean` | static | True if waveOut initialized successfully |
| `snd_firsttime` | `qboolean` | static | Suppresses repeated log messages after first init attempt |
| `snd_isdirect` / `snd_iswave` | `qboolean` | static | Track which backend was last attempted |
| `primary_format_set` | `qboolean` | static | Whether DS primary buffer format was set |
| `snd_sent` / `snd_completed` | `int` | static | waveOut block send/completion counters |
| `sample16` | `int` | static | Byte-to-sample shift: `(samplebits/8) - 1` |
| `pDS` / `pDSBuf` / `pDSPBuf` | DS COM pointers | global | DirectSound object and buffer handles |
| `hWaveOut` | `HWAVEOUT` | global | WinMM waveOut device handle |
| `lpData` / `hData` | `HPSTR`/`HANDLE` | global | Locked waveOut audio buffer |
| `lpWaveHdr` / `hWaveHdr` | `LPWAVEHDR`/`HGLOBAL` | global | waveOut header array |
| `gSndBufSize` | `DWORD` | global | Total audio buffer size in bytes |
| `mmstarttime` | `MMTIME` | global | DS playback origin sample for position delta |
| `locksize` | `DWORD` | global | Size of currently locked DS buffer region |
| `hInstDS` | `HINSTANCE` | global | Handle to loaded `dsound.dll` |
| `s_wavonly` | `cvar_t *` | global | Cvar forcing waveOut-only mode |

## Key Functions

### DS_CreateBuffers
- **Signature:** `static qboolean DS_CreateBuffers(void)`
- **Purpose:** Creates DirectSound primary and secondary (mixing) buffers; configures format and begins looping playback; populates `dma` fields.
- **Inputs:** Uses globals `dma`, `pDS`, `cl_hwnd`, `s_primary`, `snd_firsttime`
- **Outputs/Return:** `true` on success; `false` on any DS API failure
- **Side effects:** Sets `pDSBuf`, `pDSPBuf`, `gSndBufSize`, `mmstarttime`, `primary_format_set`, `dma.*`, `lpData`; calls `FreeSound` on failure
- **Calls:** `pDS->lpVtbl->SetCooperativeLevel`, `CreateSoundBuffer`, `SetFormat`, `GetCaps`, `Play`, `Stop`, `GetCurrentPosition`, `FreeSound`, `Com_Printf`, `Com_DPrintf`
- **Notes:** If `s_primary->value` is set and the primary buffer format was accepted, uses the primary buffer directly as `pDSBuf` (WRITEPRIMARY mode); otherwise uses a 64 KB secondary buffer.

### DS_DestroyBuffers
- **Signature:** `static void DS_DestroyBuffers(void)`
- **Purpose:** Stops and releases DS buffers; resets coop level to NORMAL.
- **Side effects:** Nulls `pDSBuf`, `pDSPBuf`, `dma.buffer`; releases COM references
- **Calls:** `pDS->lpVtbl->SetCooperativeLevel`, `Stop`, `Release`

### FreeSound
- **Signature:** `void FreeSound(void)`
- **Purpose:** Full teardown of both DirectSound and waveOut subsystems; frees all allocated memory and COM objects.
- **Side effects:** Resets all global sound handles and flags to zero/NULL; sets `dsound_init = wav_init = false`
- **Calls:** `DS_DestroyBuffers`, `waveOutReset`, `waveOutUnprepareHeader`, `waveOutClose`, `GlobalUnlock`, `GlobalFree`, `pDS->Release`, `FreeLibrary`

### SNDDMA_InitDirect
- **Signature:** `sndinitstat SNDDMA_InitDirect(void)`
- **Purpose:** Loads `dsound.dll`, creates a DS object, validates driver presence, then calls `DS_CreateBuffers`.
- **Inputs:** `s_khz->value` for sample rate selection
- **Outputs/Return:** `SIS_SUCCESS`, `SIS_FAILURE`, or `SIS_NOTAVAIL` (user declined retry)
- **Side effects:** Sets `dsound_init = true`, populates `dma.channels/samplebits/speed`, loads `hInstDS`
- **Calls:** `LoadLibrary`, `GetProcAddress`, `iDirectSoundCreate`, `pDS->GetCaps`, `DS_CreateBuffers`, `FreeSound`, `MessageBox`
- **Notes:** Bug present — the `s_khz == 44` branch does not use `else if`, so `s_khz == 22` also falls through to set 11025 Hz.

### SNDDMA_InitWav
- **Signature:** `qboolean SNDDMA_InitWav(void)`
- **Purpose:** Opens a waveOut device, allocates globally-shared PCM and header buffers, prepares 64 wave headers, sets up `dma`.
- **Inputs:** `s_khz->value` for sample rate; shares the same rate-selection bug as `SNDDMA_InitDirect`
- **Outputs/Return:** `true` on success, `false` on any failure
- **Side effects:** Sets `wav_init`, `gSndBufSize`, `hWaveOut`, `lpData`, `lpWaveHdr`, `dma.*`
- **Calls:** `waveOutOpen`, `GlobalAlloc`, `GlobalLock`, `waveOutPrepareHeader`, `FreeSound`, `MessageBox`

### SNDDMA_Init
- **Signature:** `int SNDDMA_Init(void)`
- **Purpose:** Top-level init entry point; tries DirectSound then falls back to waveOut; sets `snd_buffer_count = 1`.
- **Outputs/Return:** `1` on success, `0` if no device initialized
- **Calls:** `SNDDMA_InitDirect`, `SNDDMA_InitWav`, `Cvar_Get`

### SNDDMA_GetDMAPos
- **Signature:** `int SNDDMA_GetDMAPos(void)`
- **Purpose:** Returns current playback position in mono samples within the circular DMA buffer.
- **Side effects:** Queries DS `GetCurrentPosition` or computes from `snd_sent`
- **Notes:** Position is delta from `mmstarttime` for DS; masked to `dma.samples - 1`.

### SNDDMA_BeginPainting
- **Signature:** `void SNDDMA_BeginPainting(void)`
- **Purpose:** Locks the DS buffer for mixer write access; restores/restarts buffer if lost/stopped; sets `dma.buffer`.
- **Side effects:** Sets `dma.buffer` and `locksize`; may call `S_Shutdown` on unrecoverable lock failure

### SNDDMA_Submit
- **Signature:** `void SNDDMA_Submit(void)`
- **Purpose:** Unlocks DS buffer after mixing; for waveOut, advances completed-block counter and submits pending blocks via `waveOutWrite`.
- **Side effects:** Increments `snd_sent`/`snd_completed`; calls `FreeSound` on waveOut write error

### S_Activate
- **Signature:** `void S_Activate(qboolean active)`
- **Purpose:** Called on window focus change; recreates DS buffers on activation, destroys them on deactivation.
- **Calls:** `DS_CreateBuffers`, `DS_DestroyBuffers`

## Control Flow Notes
- `SNDDMA_Init` is called once during client audio startup.
- Each frame: `SNDDMA_GetDMAPos` → `SNDDMA_BeginPainting` → mixer writes into `dma.buffer` → `SNDDMA_Submit`.
- `S_Activate` is called from the Win32 window procedure on `WM_ACTIVATE`.
- `SNDDMA_Shutdown` / `FreeSound` called on engine exit or audio restart.

## External Dependencies
- `../client/client.h`, `../client/snd_loc.h` — `dma`, `s_khz`, `s_primary`, `paintedtime`, `S_Shutdown`
- `winquake.h` — `cl_hwnd`, Windows types
- `dsound.dll` — loaded at runtime; `DirectSoundCreate` resolved via `GetProcAddress`
- WinMM (`waveOut*`) — linked statically via Windows SDK
