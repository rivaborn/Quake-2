# linux/glob.c

## File Purpose
Implements a portable glob-style pattern matching library for use on Linux. Provides shell-like wildcard matching (`*`, `?`, `[SET]`) against strings, used for filename or resource lookup in the engine's Linux port.

## Core Responsibilities
- Match a full string against a glob pattern (`glob_match`)
- Handle `*` wildcard by matching against any suffix (`glob_match_after_star`)
- Support character sets `[SET]` and negated sets `[!SET]` or `[^SET]`
- Support escape sequences via `\`
- Detect whether a pattern contains any special glob characters (`glob_pattern_p`)

## Key Types / Data Structures
None.

## Global / File-Static State
None.

## Key Functions

### glob_match
- **Signature:** `int glob_match(char *pattern, char *text)`
- **Purpose:** Matches the entirety of `text` against `pattern` using glob semantics.
- **Inputs:** `pattern` — glob pattern string; `text` — candidate string to test.
- **Outputs/Return:** `1` if `text` fully matches `pattern`, `0` otherwise.
- **Side effects:** None.
- **Calls:** `glob_match_after_star`
- **Notes:** `*` delegates immediately to `glob_match_after_star`. `[SET]` parsing handles ranges (`a-z`), negation (`!`/`^`), and `\`-escapes. Returns nonzero only if `text` is entirely consumed.

### glob_match_after_star
- **Signature:** `static int glob_match_after_star(char *pattern, char *text)`
- **Purpose:** Handles the `*` wildcard case by attempting to match the remainder of `pattern` against any suffix of `text`.
- **Inputs:** `pattern` — pattern pointer positioned after the `*`; `text` — current position in input string.
- **Outputs/Return:** `1` on match, `0` on no match.
- **Side effects:** None.
- **Calls:** `glob_match` (recursive)
- **Notes:** Consecutive `*`/`?` wildcards at the head of `pattern` are consumed greedily before the recursive match attempt. Returns `1` immediately if `pattern` is exhausted (bare `*` matches anything).

### glob_pattern_p
- **Signature:** `static int glob_pattern_p(char *pattern)`
- **Purpose:** Tests whether `pattern` contains any special glob metacharacters.
- **Inputs:** `pattern` — string to inspect.
- **Outputs/Return:** `1` if glob-special characters are present, `0` otherwise.
- **Side effects:** None.
- **Calls:** None.
- **Notes:** `[` is only treated as special if a matching `]` is found later (POSIX.2 compliance). A trailing `\` with no following character returns `0`.

## Control Flow Notes
This file is a pure utility library with no engine lifecycle hooks. It is called on-demand by filesystem/directory enumeration code in the Linux port (e.g., `linux/sys_linux.c` or `linux/glob.h` consumers) wherever wildcard file matching is needed. It has no init, frame, or shutdown involvement.

## External Dependencies
- `#include <stdio.h>` — included but no stdio symbols are visibly used; likely a legacy inclusion.
- `#include "../linux/glob.h"` — declares `glob_match` and `glob_pattern_p` for use by other translation units.
- No other external engine symbols are referenced.
