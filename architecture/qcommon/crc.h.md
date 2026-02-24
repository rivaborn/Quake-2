# qcommon/crc.h

## File Purpose
Declares the public interface for a CRC (Cyclic Redundancy Check) utility module used throughout the engine for data integrity verification.

## Core Responsibilities
- Expose incremental CRC computation functions (`Init`, `ProcessByte`, `Value`)
- Expose a convenience block-level CRC function for contiguous memory regions

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions

### CRC_Init
- Signature: `void CRC_Init(unsigned short *crcvalue)`
- Purpose: Initializes a CRC accumulator to its starting seed value.
- Inputs: Pointer to a `unsigned short` to be initialized.
- Outputs/Return: void; writes initial CRC state into `*crcvalue`.
- Side effects: Modifies the value at the provided pointer.
- Calls: Not inferable from this file.
- Notes: Must be called before any `CRC_ProcessByte` calls on the same accumulator.

### CRC_ProcessByte
- Signature: `void CRC_ProcessByte(unsigned short *crcvalue, byte data)`
- Purpose: Feeds a single byte into an in-progress CRC computation.
- Inputs: Pointer to current CRC accumulator; the byte to fold in.
- Outputs/Return: void; updates `*crcvalue` in place.
- Side effects: Modifies `*crcvalue`.
- Calls: Not inferable from this file.
- Notes: Intended for streaming/incremental use; caller manages the accumulator lifetime.

### CRC_Value
- Signature: `unsigned short CRC_Value(unsigned short crcvalue)`
- Purpose: Finalizes and returns the CRC result from an accumulated state.
- Inputs: Current CRC accumulator value (passed by value).
- Outputs/Return: Final `unsigned short` CRC checksum.
- Side effects: None.
- Calls: Not inferable from this file.
- Notes: Non-destructive; accumulator can still be used after this call.

### CRC_Block
- Signature: `unsigned short CRC_Block(byte *start, int count)`
- Purpose: Computes a CRC over a contiguous block of memory in a single call.
- Inputs: Pointer to start of data buffer; byte count of the block.
- Outputs/Return: `unsigned short` CRC of the entire block.
- Side effects: None (read-only over input buffer).
- Calls: Likely calls `CRC_Init` + `CRC_ProcessByte` internally; not inferable from this file.
- Notes: Convenience wrapper over the incremental API; used for PAK/asset integrity checks and network message validation.

## Control Flow Notes
This is a header-only declaration file. Actual logic resides in `qcommon/crc.c`. The CRC API is called from asset loading (file/PAK verification) and potentially network subsystems to validate data integrity.

## External Dependencies
- `byte` typedef — defined in `qcommon/qcommon.h` or `game/q_shared.h`, not in this file.
