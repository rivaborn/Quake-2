# client/sound.h

## File Purpose
Public interface header for the Quake 2 client sound system. Declares all sound lifecycle, playback, registration, and spatial update functions consumed by the client and other engine subsystems.

## Core Responsibilities
- Declare the sound system init/shutdown entry points
- Expose spatial and local sound playback functions
- Declare raw PCM sample streaming support
- Provide the sound asset registration API
- Declare the listener (camera) position update function
- Declare the reverse callback for dynamic entity spatialization

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `sfx_s` | struct (forward declaration only) | Opaque handle to a loaded sound effect; defined in `snd_loc.h` |

## Global / File-Static State
None.

## Key Functions

### S_Init
- **Signature:** `void S_Init(void)`
- **Purpose:** Initializes the sound subsystem (device, mixing buffers, cvars).
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** Allocates sound hardware/software resources; registers console commands and cvars.
- **Calls:** Not inferable from this file.
- **Notes:** Called once at engine startup.

### S_Shutdown
- **Signature:** `void S_Shutdown(void)`
- **Purpose:** Tears down the sound system and frees all resources.
- **Inputs:** None
- **Outputs/Return:** None
- **Side effects:** Frees loaded sounds, closes audio device.
- **Calls:** Not inferable from this file.

### S_StartSound
- **Signature:** `void S_StartSound(vec3_t origin, int entnum, int entchannel, struct sfx_s *sfx, float fvol, float attenuation, float timeofs)`
- **Purpose:** Emits a spatialized sound from an entity or fixed world position.
- **Inputs:** `origin` — world position (NULL = derive from entity); `entnum` — source entity; `entchannel` — channel slot (body, weapon, etc.); `sfx` — loaded sound asset; `fvol` — volume scalar; `attenuation` — falloff constant; `timeofs` — start time offset (desynchronization).
- **Outputs/Return:** None
- **Side effects:** Queues a sound channel for mixing next update.
- **Calls:** Not inferable from this file.
- **Notes:** When `origin` is NULL, position is resolved dynamically each frame via `CL_GetEntitySoundOrigin`.

### S_StartLocalSound
- **Signature:** `void S_StartLocalSound(char *s)`
- **Purpose:** Plays a 2D (non-spatialized) sound by name, typically for UI or menu feedback.
- **Inputs:** Sound asset name string.
- **Outputs/Return:** None
- **Side effects:** Registers and immediately plays the named sound.

### S_RawSamples
- **Signature:** `void S_RawSamples(int samples, int rate, int width, int channels, byte *data)`
- **Purpose:** Streams raw PCM audio data into the mixer; used for Cinematic/music playback.
- **Inputs:** Sample count, sample rate, bit width, channel count, raw PCM buffer.
- **Outputs/Return:** None
- **Side effects:** Writes into a raw sample queue consumed by the mixer.

### S_Update
- **Signature:** `void S_Update(vec3_t origin, vec3_t v_forward, vec3_t v_right, vec3_t v_up)`
- **Purpose:** Updates the listener position/orientation each frame; spatializes and mixes all active channels.
- **Inputs:** Listener world-space origin and orientation vectors.
- **Outputs/Return:** None
- **Side effects:** Reads entity positions via `CL_GetEntitySoundOrigin`; writes to DMA mixing buffer.
- **Notes:** Called once per client frame from the view/render loop.

### S_BeginRegistration / S_RegisterSound / S_EndRegistration
- **Signature:** `void S_BeginRegistration(void)` / `struct sfx_s *S_RegisterSound(char *sample)` / `void S_EndRegistration(void)`
- **Purpose:** Bracket a map load; register sound assets by name; purge unreferenced sounds on end.
- **Inputs:** `sample` — asset path string.
- **Outputs/Return:** `S_RegisterSound` returns an `sfx_s *` handle, or NULL on failure.
- **Side effects:** May load WAV data from disk; frees unused sfx on `S_EndRegistration`.

### S_FindName
- **Signature:** `struct sfx_s *S_FindName(char *name, qboolean create)`
- **Purpose:** Looks up a sound by name in the loaded sfx table; optionally allocates a new slot.
- **Inputs:** `name` — sound file name; `create` — allocate if not found.
- **Outputs/Return:** Pointer to existing or new `sfx_s`; NULL if not found and `create` is false.

### CL_GetEntitySoundOrigin
- **Signature:** `void CL_GetEntitySoundOrigin(int ent, vec3_t org)`
- **Purpose:** Callback from the sound system back into the client to fetch a living entity's current world position for dynamic spatialization.
- **Inputs:** `ent` — entity number; `org` — output vector filled by client.
- **Outputs/Return:** Writes to `org`.
- **Side effects:** None beyond populating `org`.
- **Notes:** Declared here to make the dependency explicit; implemented in client code (`cl_main.c` or `cl_ents.c`).

## Control Flow Notes
- `S_Init` is called at engine startup; `S_BeginRegistration`/`S_EndRegistration` bracket each map load.
- `S_Update` is driven once per client frame after the view is computed.
- `S_StartSound` is called by game event parsing (`cl_parse.c`, `cl_tent.c`) and entity effect code.
- `S_RawSamples` is called by the cinematic subsystem (`cl_cin.c`) for video audio.
- `S_Shutdown` is called on engine exit.

## External Dependencies
- `vec3_t`, `qboolean`, `byte` — defined in `qcommon/q_shared.h`
- `struct sfx_s` — defined in `client/snd_loc.h`
- `CL_GetEntitySoundOrigin` — implemented in client code, not in this header
