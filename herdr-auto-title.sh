#!/bin/sh
# Claude Code UserPromptSubmit hook: generate a short kebab-case title for this
# session from the first prompt and report it to Herdr as display-only metadata.
#
# Herdr never generates titles itself — it only renders what is pushed via
# `pane report-metadata`. Repeat invocations exit fast via the cache guard:
# one LLM call and one report per session, everything else is a no-op.

set -eu

# The `claude -p` call below is itself a Claude Code session and runs this very
# hook again with a fresh session_id — without these two guards that recursion
# fork-bombs the machine. The env var stops the direct child; stripping HERDR_*
# from the claude call stops it (and any other herdr hook) one level deeper.
[ -z "${HERDR_TITLE_GENERATING:-}" ] || exit 0

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0

hook_input="$(cat 2>/dev/null || true)"

# sed is enough for session_id: Claude Code emits it as a plain UUID string.
session_id="$(printf '%s' "$hook_input" \
  | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
[ -n "$session_id" ] || exit 0

cache_dir="${TMPDIR:-/tmp}/herdr-claude-titles"
cache_file="$cache_dir/$session_id"

command -v herdr >/dev/null 2>&1 || exit 0
command -v claude >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# Atomic check-and-claim: noclobber create fails if the title was already
# generated (or is in flight), so racing prompts can't double-spawn the LLM.
mkdir -p "$cache_dir"
(set -C; : > "$cache_file") 2>/dev/null || exit 0

# Generation runs detached so Claude Code never waits on the LLM call.
export HERDR_TITLE_HOOK_INPUT="$hook_input"
export HERDR_TITLE_CACHE_FILE="$cache_file"
export HERDR_TITLE_PANE_ID="$HERDR_PANE_ID"
nohup env HERDR_TITLE_GENERATING=1 sh -c '
  set -eu

  prompt="$(printf "%s" "$HERDR_TITLE_HOOK_INPUT" | python3 -c "
import json, sys
try: print((json.load(sys.stdin).get(\"prompt\") or \"\")[:1500])
except Exception: pass
")"
  if [ -z "$prompt" ]; then
    rm -f "$HERDR_TITLE_CACHE_FILE"
    exit 0
  fi

  title="$(env -u HERDR_ENV -u HERDR_PANE_ID -u HERDR_SOCKET_PATH \
    claude -p --model haiku \
    "Task description follows. Reply with ONLY a 2-word kebab-case slug naming it, lowercase ascii, max 20 chars, no quotes. Examples: auth-refactor, fix-tests, csv-export.

$prompt" 2>/dev/null \
    | head -n1 \
    | tr "[:upper:] " "[:lower:]-" \
    | tr -cd "a-z0-9-" \
    | cut -c1-24)"
  if [ -z "$title" ]; then
    rm -f "$HERDR_TITLE_CACHE_FILE"
    exit 0
  fi
  printf "%s" "$title" > "$HERDR_TITLE_CACHE_FILE"

  herdr pane report-metadata "$HERDR_TITLE_PANE_ID" \
    --source user:claude-title \
    --agent claude \
    --title "$title" \
    >/dev/null 2>&1 || true
' >/dev/null 2>&1 &

exit 0
