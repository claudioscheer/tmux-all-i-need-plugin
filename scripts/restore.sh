#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

if [ ! -f "$STATE_FILE" ]; then
    display_message "no saved state found"
    exit 0
fi

# Remember the session we were launched from (likely the auto-created one)
initial_session=""
session_count=$(tmux list-sessions 2>/dev/null | wc -l | tr -d ' ')
if [ "$session_count" -eq 1 ]; then
    initial_session=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)
fi

# Rename initial session to avoid collision with saved sessions
original_session=""
if [ -n "$initial_session" ]; then
    original_session="$initial_session"
    tmux rename-session -t "=$initial_session" "_tain_temp" 2>/dev/null
    initial_session="_tain_temp"
fi

base_index=$(tmux show-option -gv base-index 2>/dev/null || echo 0)

prev_session=""
prev_window=""
restored_sessions=()

declare -A active_windows
declare -A active_panes

while IFS=$'\t' read -r session win_idx win_name layout pane_idx pane_path win_active pane_active pane_left pane_top; do
    # Skip comments and empty lines
    [[ "$session" =~ ^#.*$ || -z "$session" ]] && continue

    # Skip if session already exists in tmux (don't duplicate)
    if [ "$session" != "$prev_session" ]; then
        if tmux has-session -t "=$session" 2>/dev/null; then
            prev_session="$session"
            prev_window=""
            continue
        fi
    elif [ -z "$prev_window" ] && [ "$session" = "$prev_session" ]; then
        # We're skipping this session (it already existed)
        continue
    fi

    if [ "$session" != "$prev_session" ]; then
        # New session
        tmux new-session -d -s "$session" -c "$pane_path" -x 200 -y 50 2>/dev/null
        tmux rename-window -t "=$session:$base_index" "$win_name" 2>/dev/null
        prev_session="$session"
        prev_window="$win_idx"
        first_pane_top="$pane_top"
        restored_sessions+=("$session")

    elif [ "$win_idx" != "$prev_window" ]; then
        # New window in existing session
        tmux new-window -d -t "=$session:$win_idx" -n "$win_name" -c "$pane_path" 2>/dev/null
        prev_window="$win_idx"
        first_pane_top="$pane_top"

    else
        # Additional pane in current window
        # Determine split direction from pane positions
        split_flag=""
        if [ -n "$pane_top" ] && [ -n "$first_pane_top" ] && [ "$pane_top" = "$first_pane_top" ]; then
            split_flag="-h"  # Same row = side by side = vertical split
        fi
        tmux split-window $split_flag -t "=$session:$win_idx" -c "$pane_path" 2>/dev/null
    fi

    # Track active window and pane
    if [ "$win_active" = "1" ]; then
        active_windows["$session"]="$win_idx"
    fi
    if [ "$pane_active" = "1" ]; then
        active_panes["$session:$win_idx"]="$pane_idx"
    fi

done < "$STATE_FILE"

# Restore active window and pane selections
for session in "${restored_sessions[@]}"; do
    if [ -n "${active_windows[$session]}" ]; then
        tmux select-window -t "=$session:${active_windows[$session]}" 2>/dev/null
    fi
    win="${active_windows[$session]}"
    if [ -n "$win" ] && [ -n "${active_panes[$session:$win]}" ]; then
        tmux select-pane -t "=$session:$win.${active_panes[$session:$win]}" 2>/dev/null
    fi
done

# Clean up the initial temp session
if [ -n "$initial_session" ]; then
    if [ ${#restored_sessions[@]} -gt 0 ]; then
        # Kill temp session if it wasn't part of restored state
        is_restored=false
        for s in "${restored_sessions[@]}"; do
            if [ "$s" = "$initial_session" ]; then
                is_restored=true
                break
            fi
        done
        if ! $is_restored; then
            tmux switch-client -t "=${restored_sessions[0]}" 2>/dev/null
            tmux kill-session -t "=$initial_session" 2>/dev/null
        fi
    else
        # No sessions restored — rename temp session back to original name
        tmux rename-session -t "=$initial_session" "${original_session:-main}" 2>/dev/null
    fi
fi

# Re-enable automatic-rename on restored windows (rename-window/-n disables it)
for session in "${restored_sessions[@]}"; do
    tmux list-windows -t "=$session" -F '#{window_index}' 2>/dev/null | while read -r win_id; do
        tmux set-option -wt "=$session:$win_id" automatic-rename on 2>/dev/null
    done
done

# Allow saves again
tmux set-option -gq @tain-restoring 0

# Create sidebar synchronously (so it finishes before any hooks race)
if [ "$(tmux show-option -gqv @tain-sidebar-enabled)" != "0" ]; then
    "$CURRENT_DIR/sidebar-ensure.sh"
fi

display_message "restored (${#restored_sessions[@]} sessions)"
