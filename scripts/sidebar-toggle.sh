#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

current_state=$(tmux show-option -gqv @tain-sidebar-enabled)

if [ "$current_state" = "0" ]; then
    # Enable sidebar
    tmux set -gq @tain-sidebar-enabled 1
    "$CURRENT_DIR/sidebar-ensure.sh"
    display_message "sidebar enabled"
else
    # Disable sidebar and kill all sidebar panes
    tmux set -gq @tain-sidebar-enabled 0
    tmux list-panes -a -F '#{pane_id} #{@tain-sidebar}' 2>/dev/null | while read -r pane_id is_sidebar; do
        if [ "$is_sidebar" = "1" ]; then
            tmux kill-pane -t "$pane_id" 2>/dev/null
        fi
    done
    display_message "sidebar disabled"
fi
