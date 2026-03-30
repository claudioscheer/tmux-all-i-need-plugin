#!/usr/bin/env bash
# Polls pane paths every 3 seconds; refreshes sidebar only when something changed.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

prev=""
while tmux info >/dev/null 2>&1; do
    cur=$(tmux list-windows -a -F '#{session_name}:#{window_index}:#{pane_current_path}' 2>/dev/null)
    if [ "$cur" != "$prev" ]; then
        "$CURRENT_DIR/sidebar-refresh.sh"
        prev="$cur"
    fi
    sleep 3
done
