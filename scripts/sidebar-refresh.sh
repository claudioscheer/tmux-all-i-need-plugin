#!/usr/bin/env bash

# Refresh sidebar in the current window by respawning its pane process.
# Called by tmux hooks when session/window state changes.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sidebar_pane=$(tmux list-panes -F '#{pane_id} #{@tain-sidebar}' 2>/dev/null | awk '$2 == "1" {print $1; exit}')
[ -z "$sidebar_pane" ] && exit 0

tmux respawn-pane -k -t "$sidebar_pane" "$CURRENT_DIR/sidebar.sh" 2>/dev/null
exit 0
