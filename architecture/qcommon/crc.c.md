# qcommon/crc.c

## File Purpose
Implements a 16-bit CRC (Cyclic Redundancy Check) using the CCITT standard (polynomial 0x1021, XMODEM variant). Used throughout the engine to verify data integrity for network packets, file validation, and content checksumming.

## Core Responsibilities
- Initialize CRC state to the standard CCITT seed value
- Process individual bytes into a running CRC accumulator
- Finalize a CRC value via XOR (no-op here since `CRC_XOR_VALUE` is `0x0000`)
- Compute a CRC over a contiguous block of bytes in one call

## Key Types / Data Structures
None.

## Global / File-Static State
| Name | Type | Scope | Purpose |
|------|-------|--------|---------|
| `crctable` | `static unsigned short[256]` | static | Precomputed lookup table for the 0x1021 polynomial; avoids per-bit computation |

## Key Functions

### CRC_Init
- **Signature:** `void CRC_Init(unsigned short *crcvalue)`
- **Purpose:** Seeds a CRC accumulator with the CCITT initial value.
- **Inputs:** Pointer to a caller-owned `unsigned short` accumulator.
- **Outputs/Return:** None; writes `0xffff` into `*crcvalue`.
- **Side effects:** Modifies caller's variable via pointer.
- **Calls:** None.
- **Notes:** Must be called before the first `CRC_ProcessByte` call on a new stream.

---

### CRC_ProcessByte
- **Signature:** `void CRC_ProcessByte(unsigned short *crcvalue, byte data)`
- **Purpose:** Folds one byte into a running CRC accumulator using a table lookup.
- **Inputs:** Pointer to current CRC state; byte to process.
- **Outputs/Return:** None; updates `*crcvalue` in place.
- **Side effects:** Modifies `*crcvalue`.
- **Calls:** Indexes `crctable`.
- **Notes:** Algorithm: `crc = (crc << 8) ^ crctable[(crc >> 8) ^ data]`. Non-reflected (big-endian bit order).

---

### CRC_Value
- **Signature:** `unsigned short CRC_Value(unsigned short crcvalue)`
- **Purpose:** Finalizes the CRC by applying the terminal XOR mask.
- **Inputs:** Completed accumulator value.
- **Outputs/Return:** Final CRC (`crcvalue ^ 0x0000`, effectively a no-op with this configuration).
- **Side effects:** None.
- **Calls:** None.
- **Notes:** The XOR step is retained for structural completeness; changing `CRC_XOR_VALUE` would make it meaningful.

---

### CRC_Block
- **Signature:** `unsigned short CRC_Block(byte *start, int count)`
- **Purpose:** Convenience function — initializes, processes an entire byte buffer, and returns the raw CRC.
- **Inputs:** `start` — pointer to data buffer; `count` — number of bytes.
- **Outputs/Return:** 16-bit CRC of the block.
- **Side effects:** None (local state only).
- **Calls:** `CRC_Init`, then inlines the `CRC_ProcessByte` loop directly.
- **Notes:** Does **not** call `CRC_Value`; returns the raw accumulator. Callers needing the finalized value must call `CRC_Value` themselves. `count` must be ≥ 0; passing negative values will loop due to `count--` decrement of an `int`.

## Control Flow Notes
Stateless utility module. Called on demand from network (`net_chan.c`), file system, and pak/asset validation paths. No participation in the frame loop directly.

## External Dependencies
- **Includes:** `qcommon.h` (provides `byte` typedef and common engine definitions)
- **External symbols:** `byte` — defined in shared headers, not this file.
