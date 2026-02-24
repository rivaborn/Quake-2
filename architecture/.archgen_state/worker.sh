#!/usr/bin/env bash
set -euo pipefail

rel="$1"
REPO_ROOT="$2"
ARCH_DIR="$3"
STATE_DIR="$4"
LOCK="$5"
COUNT_FILE="$6"
ERROR_LOG="$7"
FATAL_FLAG="$8"
FATAL_MSG="$9"
MODEL="${10}"
MAX_TURNS="${11}"
OUTPUT_FORMAT="${12}"
PROMPT_FILE="${13}"
CLAUDE_CONFIG_DIR="${14}"
MAX_RETRIES="${15}"
RETRY_DELAY="${16}"
DEFAULT_FENCE="${17}"

bump_count() {
  local field="$1"
  flock "$LOCK" bash -c "
    awk -F= 'BEGIN{OFS=FS} \$1==\"$field\"{ \$2=\$2+1 } {print}' '$COUNT_FILE' > '${COUNT_FILE}.tmp' \
      && mv '${COUNT_FILE}.tmp' '$COUNT_FILE'
  " 2>/dev/null || true
}

is_rate_limit() {
  # Detect actual Claude API / CLI rate-limit errors.
  #
  # CRITICAL: Never grep the full response body. Claude's code analysis
  # contains words like "error", "rate", "limit", "capacity", "overloaded"
  # in normal technical prose (e.g. "Com_Error", "c->rate", "rate limiting").
  # Scanning the body guarantees false positives on game engine code.
  #
  # Strategy: only check the FIRST 3 LINES of output. Real API errors
  # (HTTP 429, CLI error messages) always appear at the very top.
  # A successful response starts with markdown (# heading).
  local text="$1"
  local first3
  first3="$(echo "$text" | head -3)"

  # If response starts with markdown (# heading or ## heading), it's valid content
  echo "$first3" | grep -qE '^#' && return 1

  # Check first 3 lines for actual error signatures
  echo "$first3" | grep -qiE '(^|[^0-9])429([^0-9]|$)' && return 0
  echo "$first3" | grep -qiE 'rate.?limit|usage.?limit|too many requests' && return 0
  echo "$first3" | grep -qiE '^error:.*overloaded|^error:.*quota' && return 0

  return 1
}

log_error() {
  local etype="$1" code="$2" attempt="$3" resp="$4"
  flock "$LOCK" bash -c "
    {
      echo '===================================================='
      echo \"Timestamp: \$(date)\"
      echo \"File: $rel\"
      echo \"Exit Code: $code\"
      echo \"Attempt: $attempt\"
      echo \"Type: $etype\"
      echo '----------------------------------------------------'
    } >> '$ERROR_LOG'
    cat >> '$ERROR_LOG' <<'RESPEOF'
$resp
RESPEOF
    echo >> '$ERROR_LOG'
  " 2>/dev/null || true
}

# Map file extension to code fence language
ext_to_fence() {
  local file="$1"
  case "${file##*.}" in
    c|h|inc)           echo "c" ;;
    cpp|cc|cxx|hpp|hh|hxx|inl) echo "cpp" ;;
    cs)                echo "csharp" ;;
    java)              echo "java" ;;
    py)                echo "python" ;;
    rs)                echo "rust" ;;
    lua)               echo "lua" ;;
    gd|gdscript)       echo "gdscript" ;;
    swift)             echo "swift" ;;
    m|mm)              echo "objectivec" ;;
    shader|cginc|hlsl|glsl|compute) echo "hlsl" ;;
    toml)              echo "toml" ;;
    tscn|tres)         echo "ini" ;;
    *)                 echo "$DEFAULT_FENCE" ;;
  esac
}

if [[ -f "$FATAL_FLAG" ]]; then exit 1; fi

src="$REPO_ROOT/$rel"
out="$ARCH_DIR/$rel.md"
mkdir -p "$(dirname "$out")"

fence_lang="$(ext_to_fence "$rel")"

payload="FILE PATH (relative): ${rel}

FILE CONTENT:
\`\`\`${fence_lang}
$(cat "$src")
\`\`\`"

attempt=0
while true; do
  if [[ -f "$FATAL_FLAG" ]]; then exit 1; fi

  set +e
  resp="$(printf '%s' "$payload" | CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" claude -p \
    --model "$MODEL" \
    --max-turns "$MAX_TURNS" \
    --output-format "$OUTPUT_FORMAT" \
    --append-system-prompt-file "$PROMPT_FILE" \
    2>&1)"
  code=$?
  set -e

  if [[ $code -eq 0 ]]; then
    if is_rate_limit "$resp"; then
      code=429
    else
      break
    fi
  fi

  if is_rate_limit "$resp"; then
    log_error "RATE_LIMIT" "$code" "$((attempt+1))" "$resp"
    bump_count fail
    echo "Rate limit hit processing: $rel" > "$FATAL_MSG"
    : > "$FATAL_FLAG"
    exit 1
  fi

  attempt=$((attempt + 1))
  if [[ $attempt -le $MAX_RETRIES ]]; then
    bump_count retries
    echo "  [retry $attempt/$MAX_RETRIES] exit=$code on: $rel (waiting ${RETRY_DELAY}s)" >&2
    sleep "$RETRY_DELAY"
    continue
  fi

  log_error "PERSISTENT_FAILURE" "$code" "$attempt" "$resp"
  bump_count fail
  echo "Claude failed (exit=$code) after $attempt attempts on: $rel" > "$FATAL_MSG"
  : > "$FATAL_FLAG"
  exit 1
done

tmp="$(mktemp "$STATE_DIR/tmp.XXXXXX")"
printf '%s\n' "$resp" > "$tmp"
mv -f "$tmp" "$out"

bump_count done
