# ref_soft/r_image.c

## File Purpose
Manages the software renderer's image/texture system, handling loading, caching, and lifecycle of PCX, WAL, and TGA image assets. It provides the registration-sequence-based cache for all textures used by the software renderer.

## Core Responsibilities
- Maintain a fixed-size image cache (`r_images[MAX_RIMAGES]`) with registration-sequence tracking
- Load and decode PCX files (palette-indexed, RLE-compressed)
- Load and decode TGA files (24/32-bit uncompressed and RLE-compressed)
- Load WAL mip-textured wall tiles directly into multi-level `pixels[]` arrays
- Find-or-load images by name, avoiding redundant disk I/O
- Free images not touched in the current registration sequence
- Expose a debug console command to list all active images

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `TargaHeader` | struct | Parsed TGA file header fields for loading |
| `image_t` | struct (external) | Per-image record: name, width, height, type, pixels[4], registration_sequence, transparent flag |
| `imagetype_t` | typedef/enum (external) | Image category: `it_skin`, `it_sprite`, `it_wall`, `it_pic` |
| `miptex_t` | struct (external) | WAL file header with mip offsets and dimensions |
| `pcx_t` | struct (external) | PCX file header |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `r_images` | `image_t[MAX_RIMAGES]` | global | Flat array of all loaded images |
| `numr_images` | `int` | global | Count of slots used in `r_images` |

## Key Functions

### R_ImageList_f
- **Signature:** `void R_ImageList_f(void)`
- **Purpose:** Console command handler; dumps all active images with type tag, dimensions, and name, plus total texel count.
- **Inputs:** None (reads `r_images`, `numr_images`)
- **Outputs/Return:** None; prints to console via `ri.Con_Printf`
- **Side effects:** Console I/O only
- **Calls:** `ri.Con_Printf`
- **Notes:** Skips entries with `registration_sequence <= 0`.

### LoadPCX
- **Signature:** `void LoadPCX(char *filename, byte **pic, byte **palette, int *width, int *height)`
- **Purpose:** Loads and RLE-decodes a PCX file into a heap-allocated 8-bit pixel buffer; optionally extracts the 768-byte palette.
- **Inputs:** `filename` — VFS path; output pointers for pixel data, palette, dimensions
- **Outputs/Return:** `*pic` set to `malloc`'d buffer (or NULL on failure); `*palette` optionally set
- **Side effects:** Allocates via `malloc`; calls `ri.FS_LoadFile`/`ri.FS_FreeFile`
- **Calls:** `ri.FS_LoadFile`, `ri.FS_FreeFile`, `ri.Con_Printf`, `malloc`, `memcpy`, `free`
- **Notes:** Validates manufacturer/version/encoding fields; frees `*pic` and sets it NULL on malformed data. Maximum image dimensions hardcoded to 640×480.

### LoadTGA
- **Signature:** `void LoadTGA(char *name, byte **pic, int *width, int *height)`
- **Purpose:** Loads a TGA image (type 2 uncompressed or type 10 RLE) into a heap-allocated RGBA buffer with bottom-up row ordering corrected to top-down.
- **Inputs:** `name` — VFS path; output pointers for pixel data and dimensions
- **Outputs/Return:** `*pic` set to `malloc`'d RGBA buffer, or NULL on failure
- **Side effects:** Allocates via `malloc`; calls `ri.FS_LoadFile`/`ri.FS_FreeFile`; calls `ri.Sys_Error` on unsupported formats
- **Calls:** `ri.FS_LoadFile`, `ri.FS_FreeFile`, `ri.Sys_Error`, `malloc`
- **Notes:** RLE packets may span row boundaries; handled via `goto breakOut`. Only 24/32-bit non-colormapped images supported.

### R_FindFreeImage
- **Signature:** `image_t *R_FindFreeImage(void)`
- **Purpose:** Returns a pointer to an unused `image_t` slot, growing `numr_images` if needed.
- **Inputs:** None
- **Outputs/Return:** Pointer into `r_images[]`
- **Side effects:** May increment `numr_images`; calls `ri.Sys_Error` if pool exhausted
- **Calls:** `ri.Sys_Error`
- **Notes:** Slot is "free" when `registration_sequence == 0`.

### GL_LoadPic
- **Signature:** `image_t *GL_LoadPic(char *name, byte *pic, int width, int height, imagetype_t type)`
- **Purpose:** Stores a decoded 8-bit pixel buffer into a new image slot, detecting palette index 255 as the transparency sentinel.
- **Inputs:** Name, raw 8-bit pixel data, dimensions, image type
- **Outputs/Return:** Populated `image_t*`
- **Side effects:** `malloc` for `pixels[0]`; sets `registration_sequence`
- **Calls:** `R_FindFreeImage`, `ri.Sys_Error`, `malloc`, `strcpy`
- **Notes:** Named `GL_LoadPic` despite being in the software renderer — a naming artifact from shared heritage with `ref_gl`.

### R_LoadWal
- **Signature:** `image_t *R_LoadWal(char *name)`
- **Purpose:** Loads a WAL wall texture and maps all four mip levels into a single contiguous allocation.
- **Inputs:** `name` — VFS path to `.wal` file
- **Outputs/Return:** Populated `image_t*`, or `r_notexture_mip` on failure
- **Side effects:** `malloc`; calls `ri.FS_LoadFile`/`ri.FS_FreeFile`
- **Calls:** `R_FindFreeImage`, `ri.FS_LoadFile`, `ri.FS_FreeFile`, `ri.Con_Printf`, `malloc`, `memcpy`
- **Notes:** `pixels[1..3]` are computed as offsets into the same block as `pixels[0]`.

### R_FindImage
- **Signature:** `image_t *R_FindImage(char *name, imagetype_t type)`
- **Purpose:** Primary image lookup: returns a cached image if present, otherwise dispatches to the appropriate loader by file extension.
- **Inputs:** `name` — asset path with extension; `type` — image category hint
- **Outputs/Return:** `image_t*` or NULL
- **Side effects:** May load from disk and allocate; updates `registration_sequence` on cache hit
- **Calls:** `LoadPCX`, `GL_LoadPic`, `R_LoadWal`, `free`, `strlen`, `strcmp`
- **Notes:** `.tga` extension explicitly returns NULL (unsupported in software renderer). Minimum name length enforced at 5 characters.

### R_FreeUnusedImages
- **Signature:** `void R_FreeUnusedImages(void)`
- **Purpose:** Frees all non-pic images whose `registration_sequence` does not match the current sequence.
- **Side effects:** `free(pixels[0])`; `memset` clears the slot; calls `Com_PageInMemory` on retained images
- **Notes:** `it_pic` images are never freed here. `pixels[0]` covers the entire mip allocation for WAL textures.

### R_InitImages / R_ShutdownImages
- **Notes:** `R_InitImages` seeds `registration_sequence = 1`. `R_ShutdownImages` frees all allocated pixel data and zeroes all slots.

## Control Flow Notes
- `R_InitImages` is called at renderer startup; `R_ShutdownImages` at teardown.
- `R_FreeUnusedImages` is called at the end of each map load/registration pass.
- `R_FindImage` is the normal runtime entry point; `R_RegisterSkin` is a thin wrapper for skin assets.
- `R_ImageList_f` is registered as a console command by the renderer init code elsewhere.

## External Dependencies
- `r_local.h` — pulls in `image_t`, `imagetype_t`, `miptex_t`, `pcx_t`, `registration_sequence`, `r_notexture_mip`, `ri` (refimport_t), and byte-swap macros
- `ri.FS_LoadFile` / `ri.FS_FreeFile` — VFS I/O, defined in engine
- `ri.Con_Printf`, `ri.Sys_Error` — engine console/error, defined elsewhere
- `Com_PageInMemory` — defined in `qcommon`
- `registration_sequence` — global defined in `r_main.c` or equivalent
- `r_notexture_mip` — fallback texture, defined in `r_misc.c` or similar
