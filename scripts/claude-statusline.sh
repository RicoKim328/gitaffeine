#!/bin/sh
# Saves Claude Code's status line input (rate_limits) for gitaffeine, then runs your existing status line
# command with the same input, so its output doesn't change.
# Install yourself in ~/.claude/settings.json (gitaffeine never edits it):
#   "statusLine": {"type": "command", "command": "/path/to/claude-statusline.sh '<your current command>'"}
dir="$HOME/Library/Application Support/gitaffeine"
mkdir -p "$dir"
tmp=$(mktemp "$dir/claude-status.XXXXXX") || exit 1
cat > "$tmp"
if [ $# -gt 0 ]; then
    sh -c "$1" < "$tmp"
    status=$?
else
    status=0
fi
mv -f "$tmp" "$dir/claude-status.json"
exit $status
