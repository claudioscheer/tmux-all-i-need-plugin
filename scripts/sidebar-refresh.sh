#!/usr/bin/env bash

# Refresh sidebar in the current window by signaling it to re-render.
# Called by tmux hooks when session/window state changes.

sidebar_pane=$(tmux list-panes -F '#{pane_id} #{@tain-sidebar}' 2>/dev/null | awk '$2 == "1" {print $1; exit}')
[ -z "$sidebar_pane" ] && exit 0

# Write to the sidebar's FIFO to trigger re-render (no pane destruction)
FIFO="/tmp/tain-fifo-${sidebar_pane}"
[ -p "$FIFO" ] && echo r > "$FIFO" 2>/dev/null &
exit 0
