# qcommon/qfiles.h

## File Purpose
Defines all on-disk binary file format structures for Quake 2 asset types. This is a pure data-layout header shared between the engine and toolchain, containing no logic — only struct declarations, constants, and format magic numbers.

## Core Responsibilities
- Define the `.pak` archive container format (header + file directory entries)
- Define the `.pcx` image format layout
- Define the `.md2` triangle mesh format (vertices, frames, skins, GL commands)
- Define the `.sp2` sprite format
- Define the `.wal` texture (mipmap) format
- Define the `.bsp` map format in full (header, lumps, planes, nodes, leaves, faces, brushes, visibility, areas)
- Declare content flags and surface flags used by both BSP data and game logic

## Key Types / Data Structures

| Name | Kind | Purpose |
|---|---|---|
| `dpackfile_t` | struct | Single file entry in a `.pak` directory (name, offset, length) |
| `dpackheader_t` | struct | `.pak` file header (magic, dir offset, dir length) |
| `pcx_t` | struct | PCX image file header with unbounded trailing pixel data |
| `dstvert_t` | struct | MD2 texture coordinate (s, t shorts) |
| `dtriangle_t` | struct | MD2 triangle — indices into xyz and st arrays |
| `dtrivertx_t` | struct | Compressed per-vertex position (3 bytes) + light normal index |
| `daliasframe_t` | struct | MD2 animation frame: scale/translate + variable vertex array |
| `dmdl_t` | struct | MD2 file header; all section counts and byte offsets |
| `dsprframe_t` | struct | Single sprite frame (dimensions, origin, PCX name) |
| `dsprite_t` | struct | `.sp2` sprite file header + variable frame array |
| `miptex_t` | struct | `.wal` texture: name, dimensions, 4 mip offsets, anim chain, flags |
| `lump_t` | struct | BSP lump descriptor (file offset + byte length) |
| `dheader_t` | struct | BSP file header: magic, version, 19-lump directory |
| `dmodel_t` | struct | BSP submodel (brush entity bounding box, headnode, face range) |
| `dvertex_t` | struct | BSP vertex (float[3]) |
| `dplane_t` | struct | BSP plane (normal, dist, axial type) |
| `dnode_t` | struct | BSP internal node (plane, children, bounds, face range) |
| `texinfo_t` | struct | Surface texture projection vectors, flags, texture name, anim chain |
| `dedge_t` | struct | BSP edge — two vertex indices |
| `dface_t` | struct | BSP face: plane, edge range, texinfo, lightmap styles + offset |
| `dleaf_t` | struct | BSP leaf: contents, cluster/area, bounds, leafface/leafbrush ranges |
| `dbrushside_t` | struct | One side of a brush (plane + texinfo) |
| `dbrush_t` | struct | Brush: side range + contents flags |
| `dvis_t` | struct | Visibility lump header: cluster count + PVS/PHS bit vector offsets |
| `dareaportal_t` | struct | Portal linking two areas |
| `darea_t` | struct | Area: range into areaportal list |

## Global / File-Static State
None.

## Key Functions
None. This is a pure header — no functions are defined.

## Control Flow Notes
This header is consumed at load time by:
- `qcommon/files.c` — PAK archive reading (`dpackheader_t`, `dpackfile_t`)
- `qcommon/cmodel.c` — BSP collision model loading (all `d*` BSP types)
- `ref_gl/gl_model.c`, `ref_soft/r_model.c` — MD2/SP2/WAL/BSP rendering model loading
- Map compilers and toolchain utilities (file is intentionally shared)

No frame/update/shutdown involvement — purely structural definitions for I/O deserialization.

## External Dependencies
- No includes of its own; depends on basic C types (`short`, `int`, `byte`, `char`, `float`) being defined by the including translation unit (typically via `q_shared.h` or platform headers).
- `MAX_SKINNAME` (64) is defined here and reused by `dsprframe_t` and MD2 skin offsets.
- Content flags (`CONTENTS_*`) and surface flags (`SURF_*`) defined here are also required in `q_shared.h` — the comment explicitly notes this dual-residency requirement.
