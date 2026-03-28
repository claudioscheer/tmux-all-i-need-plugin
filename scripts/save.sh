#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

MODE="$1"

# Skip saving while a restore is in progress
if [ "$(tmux show-option -gqv @tain-restoring 2>/dev/null)" = "1" ]; then
    exit 0
fi

# Throttle: skip if saved less than 2 seconds ago (hook-triggered saves only)
if [ "$MODE" != "periodic" ]; then
    last_save=$(tmux show-option -gqv @tain-last-save 2>/dev/null)
    now=$(date +%s)
    if [ -n "$last_save" ] && [ $((now - last_save)) -lt 2 ]; then
        exit 0
    fi
fi

tmux set-option -gq @tain-last-save "$(date +%s)"

mkdir -p "$STATE_DIR"

# Capture all state in a single tmux command
{
    echo "# tmux-all-i-need state file"
    echo "# saved: $(date -Iseconds 2>/dev/null || date)"
    tmux list-panes -a -f '#{!=:#{@tain-sidebar},1}' -F "#{session_name}${TAB}#{window_index}${TAB}#{window_name}${TAB}#{window_layout}${TAB}#{pane_index}${TAB}#{pane_current_path}${TAB}#{window_active}${TAB}#{pane_active}"
} > "$TMP_FILE"

mv "$TMP_FILE" "$STATE_FILE"

if [ "$MODE" != "quiet" ] && [ "$MODE" != "periodic" ]; then
    display_message "saved"
fi
