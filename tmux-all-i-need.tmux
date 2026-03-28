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

# Mouse support (required for sidebar clicks and status bar buttons)
tmux set -g mouse on

# Clickable status-right: sessions button (≡) and new-window button (+)
tmux set -g status-right '#[fg=cyan,range=sessions]  ≡  #[norange]#[fg=green,bold,range=newwin]  +  #[norange,default] %H:%M %d-%b-%y'
tmux bind -n MouseDown1StatusRight if-shell -F '#{==:#{mouse_status_range},sessions}' \
    'choose-tree -Zs' \
    'if-shell -F "#{==:#{mouse_status_range},newwin}" "new-window -a -t :{end}"'
tmux set -g window-status-format ''
tmux set -g window-status-current-format ''
tmux set -g window-status-separator ''

# Handle clicks on sidebar panes (navigate) vs normal panes (default behavior)
tmux bind -n MouseDown1Pane if-shell -F '#{@tain-sidebar}' \
    "run-shell '$SCRIPTS_DIR/sidebar-click.sh #{mouse_y} #{pane_top} #{pane_id}'" \
    "select-pane -t ="

# Sidebar toggle keybinding
tmux bind-key b run-shell "$SCRIPTS_DIR/sidebar-toggle.sh"

# Auto-save on structural changes (index [99] to avoid overwriting user hooks)
for hook in session-created session-closed window-linked window-unlinked client-session-changed; do
    tmux set-hook -g "${hook}[99]" "run-shell -b '$SCRIPTS_DIR/save.sh quiet'"
done

# Sidebar hooks: ensure sidebar exists in new windows (index [98])
for hook in after-new-window client-session-changed session-window-changed; do
    tmux set-hook -g "${hook}[98]" "run-shell -b '$SCRIPTS_DIR/sidebar-ensure.sh'"
done

# Detect when all non-sidebar panes are closed (index [97])
tmux set-hook -g "window-layout-changed[97]" "run-shell -b '$SCRIPTS_DIR/handle-empty-window.sh'"

# Refresh sidebar display on state changes (index [96])
for hook in after-new-window client-session-changed session-window-changed session-created session-closed window-linked window-unlinked; do
    tmux set-hook -g "${hook}[96]" "run-shell -b '$SCRIPTS_DIR/sidebar-refresh.sh'"
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

# Create sidebar in current window (unless disabled or restoring)
if ! $fresh_start && [ "$(tmux show-option -gqv @tain-sidebar-enabled)" != "0" ]; then
    tmux run-shell -b "'$SCRIPTS_DIR/sidebar-ensure.sh'"
fi
