#!/usr/bin/env bash

# Called by tmux mouse binding when clicking on a sidebar pane
# Arguments: mouse_y pane_top sidebar_pane_id

mouse_y="$1"
pane_top="$2"
sidebar_pane="$3"

row=$(( mouse_y - pane_top + 1 ))
targets_file="/tmp/tain-targets-${sidebar_pane}"

[ ! -f "$targets_file" ] && exit 0

line=$(sed -n "${row}p" "$targets_file")
[ -z "$line" ] && exit 0

ttype="${line%%|*}"
target="${line#*|}"
[ -z "$ttype" ] && exit 0

case "$ttype" in
    session)
        tmux switch-client -t "=$target" 2>/dev/null
        ;;
    window)
        sess="${target%%:*}"
        tmux switch-client -t "=$sess" 2>/dev/null
        tmux select-window -t "=$target" 2>/dev/null
        ;;
    new-window)
        tmux new-window 2>/dev/null
        ;;
esac

# Return focus from sidebar to main pane in sidebar's window
sidebar_win=$(tmux display-message -t "$sidebar_pane" -p '#{session_name}:#{window_index}' 2>/dev/null)
if [ -n "$sidebar_win" ]; then
    main_pane=$(tmux list-panes -t "$sidebar_win" -F '#{pane_id} #{@tain-sidebar}' 2>/dev/null | awk '$2 != "1" {print $1; exit}')
    [ -n "$main_pane" ] && tmux select-pane -t "$main_pane" 2>/dev/null
fi
