#!/bin/bash
# Lightweight Stop hook for continuous-learning skill.
# Reads Claude Code's stdin JSON, extracts session metadata,
# and appends a one-line log entry for the auto-capture workflow to process.
#
# This script does NOT do AI analysis — it just records that a session happened.
# The actual distillation is done by Claude via the skill workflows.

set -euo pipefail

LEARNING_DIR="$HOME/.claude/learning"
LOG_FILE="$LEARNING_DIR/session-log.jsonl"
INDEX_FILE="$LEARNING_DIR/.index.json"

# Ensure directories exist
mkdir -p "$LEARNING_DIR/sessions" "$LEARNING_DIR/patterns" "$LEARNING_DIR/candidates"

# Read stdin JSON from Claude Code (non-blocking, with timeout)
STDIN_DATA=""
if read -t 2 -r STDIN_DATA 2>/dev/null; then
  : # got data
fi

# Extract transcript path if available
TRANSCRIPT_PATH=""
if command -v python3 &>/dev/null && [ -n "$STDIN_DATA" ]; then
  TRANSCRIPT_PATH=$(echo "$STDIN_DATA" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('transcript_path',''))" 2>/dev/null || true)
fi

# Count user messages in transcript (lightweight heuristic)
MSG_COUNT=0
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  MSG_COUNT=$(grep -c '"type"[[:space:]]*:[[:space:]]*"human"' "$TRANSCRIPT_PATH" 2>/dev/null || echo "0")
fi

# Log session entry
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CWD="${PWD:-unknown}"

echo "{\"ts\":\"$NOW\",\"cwd\":\"$CWD\",\"messages\":$MSG_COUNT,\"transcript\":\"$TRANSCRIPT_PATH\"}" >> "$LOG_FILE"

# Update index last_capture timestamp
if [ -f "$INDEX_FILE" ] && command -v python3 &>/dev/null; then
  python3 -c "
import json, sys
try:
    with open('$INDEX_FILE') as f:
        idx = json.load(f)
    idx['last_capture'] = '$NOW'
    with open('$INDEX_FILE', 'w') as f:
        json.dump(idx, f, indent=2)
except:
    pass
" 2>/dev/null || true
fi

exit 0
