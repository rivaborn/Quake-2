# ref_gl/gl_rmisc.c

## File Purpose
Miscellaneous OpenGL renderer initialization and utility routines. Handles particle/fallback texture creation, TGA screenshot capture, GL state initialization, and swap interval management.

## Core Responsibilities
- Generate and upload the particle dot texture and the "no texture" fallback texture
- Capture and write TGA-format screenshots to disk
- Print GL vendor/renderer/version/extension strings to console
- Set the default OpenGL render state at renderer startup
- Update the vsync swap interval when the cvar changes

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `TargaHeader` | struct | Layout of a TGA file header for writing screenshots |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `dottexture[8][8]` | `byte` (file-static) | static | 8×8 binary dot bitmap used to generate particle and notexture images |

## Key Functions

### R_InitParticleTexture
- **Signature:** `void R_InitParticleTexture(void)`
- **Purpose:** Builds two procedural textures: a white RGBA particle sprite (alpha from `dottexture`) and a red-channel-only fallback "no texture" tile.
- **Inputs:** None (reads `dottexture` global)
- **Outputs/Return:** Void; sets `r_particletexture` and `r_notexture` globals
- **Side effects:** Allocates GL texture objects via `GL_LoadPic`; writes `r_particletexture`, `r_notexture`
- **Calls:** `GL_LoadPic`
- **Notes:** The notexture uses `x&3`/`y&3` to tile the dot at half resolution. Alpha is forced to 255 (opaque).

---

### GL_ScreenShot_f
- **Signature:** `void GL_ScreenShot_f(void)`
- **Purpose:** Console command handler that reads the framebuffer and saves it as an uncompressed 24-bit TGA file in `<gamedir>/scrnshot/quake00–99.tga`.
- **Inputs:** None (reads `vid.width`, `vid.height`, `ri.FS_Gamedir()`)
- **Outputs/Return:** Void; writes a `.tga` file to disk
- **Side effects:** Filesystem I/O (directory probe loop, file write); heap alloc/free for pixel buffer; prints to console
- **Calls:** `Com_sprintf`, `Sys_Mkdir`, `fopen`, `fclose`, `malloc`, `memset`, `free`, `qglReadPixels`, `fwrite`, `ri.Con_Printf`
- **Notes:** Iterates `quake00`–`quake99`; fails silently with a console message at 100. RGB→BGR swap is done in-place before writing. TGA header is hand-packed directly into the start of the buffer.

---

### GL_Strings_f
- **Signature:** `void GL_Strings_f(void)`
- **Purpose:** Console command handler; dumps GL driver identification strings.
- **Inputs:** None (reads `gl_config`)
- **Outputs/Return:** Void; prints to console
- **Side effects:** Console output via `ri.Con_Printf`
- **Calls:** `ri.Con_Printf`

---

### GL_SetDefaultState
- **Signature:** `void GL_SetDefaultState(void)`
- **Purpose:** Establishes the canonical OpenGL state baseline at renderer init: culling, blending, alpha test, texture parameters, shade model, and optional extension setup (point parameters, paletted textures).
- **Inputs:** None (reads multiple `gl_*` cvars and `gl_state`)
- **Outputs/Return:** Void
- **Side effects:** Modifies global GL pipeline state; calls `GL_UpdateSwapInterval`
- **Calls:** `qglClearColor`, `qglCullFace`, `qglEnable/Disable`, `qglAlphaFunc`, `qglColor4f`, `qglPolygonMode`, `qglShadeModel`, `GL_TextureMode`, `GL_TextureAlphaMode`, `GL_TextureSolidMode`, `qglTexParameterf`, `qglBlendFunc`, `GL_TexEnv`, `qglPointParameterfEXT`, `qglPointParameterfvEXT`, `qglColorTableEXT`, `GL_SetTexturePalette`, `GL_UpdateSwapInterval`
- **Notes:** Point attenuation and shared palette extensions are guarded by capability checks. Clear color is magenta-ish (1, 0, 0.5, 0.5) — intentionally visible for debugging.

---

### GL_UpdateSwapInterval
- **Signature:** `void GL_UpdateSwapInterval(void)`
- **Purpose:** Applies the `gl_swapinterval` cvar change to the platform vsync interval, Windows-only.
- **Inputs:** None (reads `gl_swapinterval->modified`, `gl_state.stereo_enabled`)
- **Outputs/Return:** Void
- **Side effects:** Clears `gl_swapinterval->modified`; calls `qwglSwapIntervalEXT` on Win32
- **Calls:** `qwglSwapIntervalEXT` (Win32 only)
- **Notes:** No-op when stereo is enabled or on non-Win32 platforms.

## Control Flow Notes
`R_InitParticleTexture` and `GL_SetDefaultState` are called during renderer initialization (`R_Init` in `gl_rmain.c`). `GL_ScreenShot_f` and `GL_Strings_f` are registered as console commands at init time. `GL_UpdateSwapInterval` is called every frame from `GL_SetDefaultState` and potentially elsewhere to pick up cvar changes.

## External Dependencies
- **Includes:** `gl_local.h` (pulls in all GL types, cvars, `gl_config`, `gl_state`, `vid`, `ri`)
- **Defined elsewhere:** `r_particletexture`, `r_notexture`, `gl_config`, `gl_state`, `vid`, `ri`, `d_8to24table`, `GL_LoadPic`, `GL_TextureMode`, `GL_TextureAlphaMode`, `GL_TextureSolidMode`, `GL_TexEnv`, `GL_SetTexturePalette`, `Sys_Mkdir`, `Com_sprintf`, all `qgl*` function pointers
