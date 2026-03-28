#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

MY_PANE="$TMUX_PANE"

# Prevent sidebar from affecting window auto-rename
cd / 2>/dev/null

cleanup() {
    tmux set-option -pu -t "$MY_PANE" @tain-sidebar 2>/dev/null
    rm -f "/tmp/tain-targets-${MY_PANE}" 2>/dev/null
}
trap cleanup EXIT

render() {
    local cur_sess cur_win
    cur_sess=$(tmux display-message -p '#{client_session}' 2>/dev/null)
    cur_win=$(tmux display-message -p '#{window_index}' 2>/dev/null)

    local output=""
    local targets_data=""

    local RST=$'\e[0m' BOLD=$'\e[1m' DIM=$'\e[2m'
    local GRN=$'\e[32m' CYN=$'\e[36m' YLW=$'\e[33m'

    local sessions
    sessions=$(tmux list-sessions -F '#{session_name}|#{session_windows}' 2>/dev/null)

    while IFS='|' read -r sname swins; do
        [ -z "$sname" ] && continue
        # Hide internal temp session used during restore
        [[ "$sname" == _tain_temp* ]] && continue

        # Session line
        local sc="$DIM"
        [ "$sname" = "$cur_sess" ] && sc="${GRN}${BOLD}"
        output+="${sc}▼ ${sname}${RST}"$'\n'
        targets_data+="session|${sname}"$'\n'

        # Windows
        local windows
        windows=$(tmux list-windows -t "=$sname" -F '#{window_index}|#{window_name}|#{window_active}' 2>/dev/null)

        while IFS='|' read -r widx wname wactive; do
            [ -z "$widx" ] && continue
            local wc="$DIM" marker="  "
            if [ "$sname" = "$cur_sess" ] && [ "$widx" = "$cur_win" ]; then
                wc="${CYN}${BOLD}"
                marker="● "
            elif [ "$wactive" = "1" ]; then
                wc="$YLW"
                marker="› "
            fi
            output+="${wc}  ${marker}${widx}: ${wname}${RST}"$'\n'
            targets_data+="window|${sname}:${widx}"$'\n'
        done <<< "$windows"

        output+=$'\n'
        targets_data+="|"$'\n'
    done <<< "$sessions"

    # New window button
    output+="${GRN}${BOLD}  +  new window${RST}"$'\n'
    targets_data+="new-window|"$'\n'

    printf '\e[2J\e[H%s' "$output"
    printf '%s' "$targets_data" > "/tmp/tain-targets-${MY_PANE}"
}

while true; do
    # If main pane was closed, only sidebar remains — handle it
    my_win=$(tmux display-message -t "$MY_PANE" -p '#{window_id}' 2>/dev/null)
    non_sidebar=$(tmux list-panes -t "$my_win" -F '#{@tain-sidebar}' 2>/dev/null | grep -cv '^1$')
    if [ "$non_sidebar" -eq 0 ]; then
        win_count=$(tmux list-windows -F '#{window_id}' 2>/dev/null | wc -l | tr -d ' ')
        if [ "$win_count" -gt 1 ]; then
            # Other windows exist — switch away and kill this empty one
            tmux select-window -t :+ 2>/dev/null
            tmux kill-window -t "$my_win" 2>/dev/null
            exit 0
        else
            # Last window — create a new pane beside sidebar
            tmux split-window -h -t "$MY_PANE" -c "$HOME" 2>/dev/null
            tmux resize-pane -t "$MY_PANE" -x "$SIDEBAR_WIDTH" 2>/dev/null
        fi
    fi

    render
    sleep 1
done
