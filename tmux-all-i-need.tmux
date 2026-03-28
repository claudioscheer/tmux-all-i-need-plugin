#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$CURRENT_DIR/scripts"

mkdir -p "$HOME/.tmux/tmux-all-i-need"

# Keybindings
tmux bind-key C-s run-shell "$SCRIPTS_DIR/save.sh"
tmux bind-key R run-shell "$SCRIPTS_DIR/restore.sh"

# Detect fresh server start BEFORE registering saves
fresh_start=false
server_start=$(tmux display-message -p -F '#{start_time}' 2>/dev/null)
now=$(date +%s)
if [ -n "$server_start" ] && [ $((now - server_start)) -lt 10 ]; then
    session_count=$(tmux list-sessions 2>/dev/null | wc -l | tr -d ' ')
    if [ "$session_count" -le 1 ]; then
        fresh_start=true
        tmux set-option -gq @tain-restoring 1
    fi
fi

# Auto-save on structural changes (index [99] to avoid overwriting user hooks)
for hook in session-created session-closed window-linked window-unlinked client-session-changed; do
    tmux set-hook -g "${hook}[99]" "run-shell -b '$SCRIPTS_DIR/save.sh quiet'"
done

# Periodic save every 15 seconds (background loop)
if [ "$(tmux show-option -gqv @tain-periodic-running)" != "1" ]; then
    tmux set-option -gq @tain-periodic-running 1
    tmux run-shell -b "while tmux info >/dev/null 2>&1; do '$SCRIPTS_DIR/save.sh' periodic; sleep 15; done"
fi

# Auto-restore on fresh server start
if $fresh_start; then
    tmux run-shell -b "'$SCRIPTS_DIR/restore.sh'"
fi
