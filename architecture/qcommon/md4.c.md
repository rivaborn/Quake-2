# qcommon/md4.c

## File Purpose
Implements the RSA MD4 message-digest algorithm (RFC 1320) as a cryptographic hash utility. Used by the Quake 2 engine primarily for block checksum verification via `Com_BlockChecksum`.

## Core Responsibilities
- Initialize, update, and finalize MD4 hash contexts
- Process 64-byte blocks through a 3-round bitwise transformation
- Encode/decode between little-endian byte streams and 32-bit word arrays
- Expose `Com_BlockChecksum` as the engine-facing checksum API

## Key Types / Data Structures

| Name | Kind | Purpose |
|------|------|---------|
| `MD4_CTX` | struct | Holds running MD4 hash state: 4-word state, 64-bit bit count, 64-byte input buffer |
| `POINTER` | typedef | Generic `unsigned char *` alias used for `memcpy`/`memset` casts |
| `UINT2` | typedef | 16-bit unsigned integer |
| `UINT4` | typedef | 32-bit unsigned integer; platform-conditional (`unsigned int` on Alpha, `unsigned long` elsewhere) |

## Global / File-Static State

| Name | Type | Scope | Purpose |
|------|------|-------|---------|
| `PADDING` | `static unsigned char[64]` | static | Standard MD4 padding block; `0x80` followed by zeros, used during finalization |

## Key Functions

### MD4Init
- **Signature:** `void MD4Init(MD4_CTX *context)`
- **Purpose:** Resets an MD4 context to its initial state.
- **Inputs:** `context` — pointer to an `MD4_CTX` to initialize.
- **Outputs/Return:** void; modifies `*context` in place.
- **Side effects:** Sets magic IV constants (`0x67452301`, `0xefcdab89`, `0x98badcfe`, `0x10325476`) and zeroes bit counters.
- **Calls:** None.
- **Notes:** Must be called before any `MD4Update`/`MD4Final` calls on a context.

---

### MD4Update
- **Signature:** `void MD4Update(MD4_CTX *context, unsigned char *input, unsigned int inputLen)`
- **Purpose:** Feeds an arbitrary-length input chunk into an in-progress MD4 computation.
- **Inputs:** `context` — active hash state; `input` — byte buffer; `inputLen` — byte count.
- **Outputs/Return:** void; updates `context->state`, `context->count`, `context->buffer`.
- **Side effects:** Calls `MD4Transform` for each complete 64-byte block; buffers remaining bytes.
- **Calls:** `MD4Transform`, `memcpy`.
- **Notes:** Handles carry propagation on the 64-bit bit counter. Safe to call multiple times for streaming input.

---

### MD4Final
- **Signature:** `void MD4Final(unsigned char digest[16], MD4_CTX *context)`
- **Purpose:** Finalizes the hash, writing the 16-byte digest and zeroing the context.
- **Inputs:** `digest` — 16-byte output buffer; `context` — active hash state.
- **Outputs/Return:** void; writes 16-byte MD4 hash to `digest`.
- **Side effects:** Calls `MD4Update` twice (padding + length); zeroes `*context` via `memset`.
- **Calls:** `Encode`, `MD4Update`, `memset`.
- **Notes:** Context is zeroized after finalization and must not be reused.

---

### Com_BlockChecksum
- **Signature:** `unsigned Com_BlockChecksum(void *buffer, int length)`
- **Purpose:** Engine-facing API; computes a 32-bit checksum over an arbitrary memory block using MD4.
- **Inputs:** `buffer` — data to hash; `length` — byte count.
- **Outputs/Return:** XOR of all four 32-bit MD4 digest words, collapsed to a single `unsigned int`.
- **Side effects:** Allocates `MD4_CTX` on stack; context is zeroized inside `MD4Final`.
- **Calls:** `MD4Init`, `MD4Update`, `MD4Final`.
- **Notes:** Used for map/BSP integrity verification and demo checksumming in the engine.

---

### Notes (internal helpers)
- `MD4Transform` — core 3-round (FF/GG/HH) 64-byte block compression; zeroizes working array `x` after use.
- `Encode` — serializes `UINT4[]` to little-endian `unsigned char[]`; assumes `len` is a multiple of 4.
- `Decode` — deserializes little-endian `unsigned char[]` to `UINT4[]`; assumes `len` is a multiple of 4.

## Control Flow Notes
Stateless utility file — no per-frame update hook. `Com_BlockChecksum` is called on demand by other `qcommon` subsystems (e.g., map loading, network message validation) whenever data integrity must be verified.

## External Dependencies
- `<string.h>` — for `memcpy`, `memset`
- No other engine headers included; all types are self-contained within this file.
- `Com_BlockChecksum` is defined here and declared externally in `qcommon/qcommon.h`.
