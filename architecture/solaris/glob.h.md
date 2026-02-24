# solaris/glob.h

## File Purpose
Single-function header declaring a glob-style pattern matching utility for the Solaris platform port. It exposes one function used to match filenames or strings against wildcard patterns.

## Core Responsibilities
- Declares the `glob_match` interface for use by Solaris-specific or shared code that needs wildcard filename/string matching.

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions

### glob_match
- **Signature:** `int glob_match(char *pattern, char *text);`
- **Purpose:** Tests whether `text` matches a glob-style wildcard `pattern` (e.g., `*`, `?`, `[...]` syntax).
- **Inputs:** `pattern` — wildcard pattern string; `text` — candidate string to test against.
- **Outputs/Return:** Presumably non-zero on match, zero on no match (convention inferred from standard glob APIs; not confirmed from this file alone).
- **Side effects:** None inferable.
- **Calls:** Not inferable from this file.
- **Notes:** Implementation lives in `solaris/glob.c`. An identical header exists at `linux/glob.h`, indicating this is a shared POSIX-platform utility duplicated per-platform rather than centralized.

## Control Flow Notes
Not directly part of the engine frame loop. Used on-demand when file listing or pattern filtering is needed (e.g., in `files.c` or platform filesystem code).

## External Dependencies
- No includes.
- `glob_match` implementation defined in `solaris/glob.c`.
