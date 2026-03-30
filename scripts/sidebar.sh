#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

MY_PANE="$TMUX_PANE"

# Prevent sidebar from affecting window auto-rename
cd / 2>/dev/null

cleanup() {
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
        [[ "$sname" == _tain_temp* ]] && continue

        local sc="$DIM"
        [ "$sname" = "$cur_sess" ] && sc="${GRN}${BOLD}"
        output+="${sc}▼ ${sname}${RST}"$'\n'
        targets_data+="session|${sname}"$'\n'

        local windows
        windows=$(tmux list-windows -t "=$sname" -F '#{window_index}|#{b:pane_current_path}|#{window_active}' 2>/dev/null)

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

    output+="${GRN}${BOLD}  +  new window${RST}"$'\n'
    targets_data+="new-window|"$'\n'

    printf '\e[2J\e[H%s' "$output"
    printf '%s' "$targets_data" > "/tmp/tain-targets-${MY_PANE}"
}

# One-shot render — tmux hooks call respawn-pane to refresh
render

# Block until killed by respawn-pane
tail -f /dev/null
