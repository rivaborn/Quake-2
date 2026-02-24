# solaris/glob.c

## File Purpose
Implements Unix-style filename glob pattern matching for the Solaris platform port. Provides `glob_match` and supporting utilities to test whether a string matches a wildcard pattern containing `*`, `?`, and `[SET]` constructs.

## Core Responsibilities
- Match a full string against a glob pattern (`glob_match`)
- Handle wildcard `*` by recursively matching any suffix (`glob_match_after_star`)
- Detect whether a pattern contains any special glob characters (`glob_pattern_p`)
- Support character sets `[SET]` and negated sets `[!SET]` / `[^SET]`
- Support escape sequences via `\` to match literal special characters

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions

### glob_match
- **Signature:** `int glob_match(char *pattern, char *text)`
- **Purpose:** Tests whether the entire string `text` matches the glob `pattern`.
- **Inputs:** `pattern` — glob pattern string; `text` — candidate string to match.
- **Outputs/Return:** `1` if full match, `0` otherwise.
- **Side effects:** None.
- **Calls:** `glob_match_after_star`
- **Notes:** Consumes the full `text`; a partial prefix match returns `0`. `[SET]` ranges use byte comparison (`c1 >= cstart && c1 <= cend`), so behavior is locale-dependent.

### glob_match_after_star
- **Signature:** `static int glob_match_after_star(char *pattern, char *text)`
- **Purpose:** Handles the `*` wildcard by trying to match `pattern` against every possible suffix of `text`.
- **Inputs:** `pattern` — remainder of pattern after `*`; `text` — current position in text.
- **Outputs/Return:** `1` if any suffix matches, `0` otherwise.
- **Side effects:** None.
- **Calls:** `glob_match` (mutual recursion)
- **Notes:** Consecutive `*`/`?` wildcards at the start of `pattern` are consumed eagerly before the recursive scan begins. A lone `*` (pattern ends immediately) always returns `1`.

### glob_pattern_p
- **Signature:** `static int glob_pattern_p(char *pattern)`
- **Purpose:** Determines whether a pattern string contains any active glob metacharacters.
- **Inputs:** `pattern` — string to inspect.
- **Outputs/Return:** `1` if pattern contains `?`, `*`, or a complete `[…]` set; `0` otherwise.
- **Side effects:** None.
- **Calls:** None.
- **Notes:** Bracket expressions are only considered special if a matching `]` is present (`open` counter). Exported symbol is unused within this file — intended for callers that want to short-circuit plain string comparison.

## Control Flow Notes
This file is a standalone utility module. It is not part of any frame/update/render loop. It is called on demand whenever path or filename matching is needed (e.g., from filesystem enumeration routines in the Solaris port). No init or shutdown involvement.

## External Dependencies
- `<stdio.h>` — included but no stdio functions are used; likely a vestigial include.
- `../linux/glob.h` — provides the declaration for `glob_match` (shared header between Linux and Solaris ports); `glob_pattern_p` and `glob_match_after_star` are file-static and not declared there.
