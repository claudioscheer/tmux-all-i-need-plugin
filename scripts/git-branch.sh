#!/usr/bin/env bash
# Prints the git branch of the active (non-sidebar) pane's working directory.
# Used by tmux status-right via #(script).

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

pane_path=$(tmux list-panes \
    -f '#{!=:#{@tain-sidebar},1}' \
    -F '#{pane_current_path}' 2>/dev/null | head -1)

[ -z "$pane_path" ] && exit 0

branch=$(git -C "$pane_path" rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -n "$branch" ] && printf '%s' "$branch"
