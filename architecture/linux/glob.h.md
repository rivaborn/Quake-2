# linux/glob.h

## File Purpose
A minimal header file exposing a single glob pattern matching function for use on Linux. It provides the interface for matching filenames or strings against shell-style wildcard patterns.

## Core Responsibilities
- Declare `glob_match` for use by other translation units

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions

### glob_match
- Signature: `int glob_match(char *pattern, char *text);`
- Purpose: Tests whether `text` matches the shell-style wildcard `pattern` (e.g., `*`, `?`).
- Inputs: `pattern` — wildcard pattern string; `text` — candidate string to test.
- Outputs/Return: Non-zero (true) if `text` matches `pattern`, zero (false) otherwise.
- Side effects: None inferable from this file.
- Calls: Not inferable from this file.
- Notes: Implementation is defined in `linux/glob.c`.

## Control Flow Notes
Standalone utility; not tied to any specific engine phase. Likely called during filesystem operations (e.g., file enumeration in `qcommon/files.c`) to filter filenames against wildcard patterns.

## External Dependencies
- No includes in this header.
- `glob_match` is defined in `linux/glob.c` (defined elsewhere).
