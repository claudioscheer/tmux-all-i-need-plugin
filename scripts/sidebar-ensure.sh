#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

# Skip if disabled
[ "$(tmux show-option -gqv @tain-sidebar-enabled)" = "0" ] && exit 0

# Skip during restore (hooks should not create sidebars mid-restore)
[ "$(tmux show-option -gqv @tain-restoring)" = "1" ] && exit 0

# Acquire exclusive lock (blocks if another instance is running)
tmux wait-for -L tain-sidebar-lock 2>/dev/null

# Check if current window already has a sidebar pane
if tmux list-panes -F '#{@tain-sidebar}' 2>/dev/null | grep -q '^1$'; then
    tmux wait-for -U tain-sidebar-lock 2>/dev/null
    exit 0
fi

# Create sidebar pane on the left, full height
pane_id=$(tmux split-window -hbf -l "$SIDEBAR_WIDTH" \
    -P -F '#{pane_id}' \
    "'$CURRENT_DIR/sidebar.sh'" 2>/dev/null)

# Tag it immediately so other callers see it
if [ -n "$pane_id" ]; then
    tmux set-option -p -t "$pane_id" @tain-sidebar 1 2>/dev/null
    tmux select-pane -d -t "$pane_id" 2>/dev/null
    tmux select-pane -T "sidebar" -t "$pane_id" 2>/dev/null
    # Enforce exact width in case split didn't honor -l
    tmux resize-pane -t "$pane_id" -x "$SIDEBAR_WIDTH" 2>/dev/null
fi

# Return focus to user's pane
tmux last-pane 2>/dev/null

# Release lock
tmux wait-for -U tain-sidebar-lock 2>/dev/null
