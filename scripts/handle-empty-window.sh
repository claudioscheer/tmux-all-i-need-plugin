#!/usr/bin/env bash

# Hook handler for window-layout-changed.
# Detects when only sidebar panes remain and either switches
# to another window or creates a new pane.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

# Check if any non-sidebar panes exist in the current window
non_sidebar=$(tmux list-panes -F '#{@tain-sidebar}' 2>/dev/null | grep -cv '^1$')
[ "$non_sidebar" -gt 0 ] && exit 0

# Only sidebar panes remain
win_id=$(tmux display-message -p '#{window_id}' 2>/dev/null)
win_count=$(tmux list-windows -F '#{window_id}' 2>/dev/null | wc -l | tr -d ' ')

if [ "$win_count" -gt 1 ]; then
    # Other windows exist — switch away and kill this empty one
    tmux select-window -t :+ 2>/dev/null
    tmux kill-window -t "$win_id" 2>/dev/null
else
    # Last window — create a new pane beside the sidebar
    sidebar_pane=$(tmux list-panes -F '#{pane_id} #{@tain-sidebar}' 2>/dev/null | awk '$2 == "1" {print $1; exit}')
    if [ -n "$sidebar_pane" ]; then
        tmux split-window -h -t "$sidebar_pane" -c "$HOME" 2>/dev/null
        tmux resize-pane -t "$sidebar_pane" -x "$SIDEBAR_WIDTH" 2>/dev/null
    fi
fi
