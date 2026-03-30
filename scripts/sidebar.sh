#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

MY_PANE="$TMUX_PANE"

# Prevent sidebar from affecting window auto-rename
cd / 2>/dev/null

FIFO="/tmp/tain-fifo-${MY_PANE}"
rm -f "$FIFO" 2>/dev/null
mkfifo "$FIFO" 2>/dev/null

# Hide cursor and clear screen
printf '\e[?25l\e[2J\e[H'

cleanup() {
    printf '\e[?25h'
    rm -f "/tmp/tain-targets-${MY_PANE}" 2>/dev/null
    rm -f "$FIFO" 2>/dev/null
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
    local CLR=$'\e[K'

    local sessions
    sessions=$(tmux list-sessions -F '#{session_name}|#{session_windows}' 2>/dev/null)

    while IFS='|' read -r sname swins; do
        [ -z "$sname" ] && continue
        [[ "$sname" == _tain_temp* ]] && continue

        local sc="$DIM"
        [ "$sname" = "$cur_sess" ] && sc="${GRN}${BOLD}"
        output+="${sc}▼ ${sname}${RST}${CLR}"$'\n'
        targets_data+="session|${sname}"$'\n'

        local windows
        windows=$(tmux list-windows -t "=$sname" -F '#{window_index}|#{b:pane_current_path}|#{window_active}|#{window_panes}|#{window_zoomed_flag}|#{pane_current_path}' 2>/dev/null)

        while IFS='|' read -r widx wname wactive wpanes wzoomed wpanepath; do
            [ -z "$widx" ] && continue
            local wc="$DIM" marker="  "
            if [ "$sname" = "$cur_sess" ] && [ "$widx" = "$cur_win" ]; then
                wc="${CYN}${BOLD}"
                marker="● "
            elif [ "$wactive" = "1" ]; then
                wc="$YLW"
                marker="› "
            fi

            # Subtract 1 from pane count to exclude the sidebar pane
            local real_panes=$(( wpanes - 1 ))

            local suffix=""
            # Git-dirty indicator
            if [ -n "$wpanepath" ] && \
               [ -n "$(git -C "$wpanepath" status --porcelain 2>/dev/null | head -1)" ]; then
                suffix+="*"
            fi
            # Pane count when >1
            [ "$real_panes" -gt 1 ] 2>/dev/null && suffix+=" [${real_panes}]"
            # Zoomed indicator
            [ "$wzoomed" = "1" ] && suffix+=" Z"

            # Truncate window name if line would exceed sidebar width
            local prefix_len=$(( 4 + ${#widx} + 2 ))  # "  ● " + index + ": "
            local suffix_len=${#suffix}
            local max_name=$(( SIDEBAR_WIDTH - prefix_len - suffix_len ))
            if [ ${#wname} -gt $max_name ] && [ $max_name -gt 1 ]; then
                wname="${wname:0:$((max_name - 1))}…"
            fi

            output+="${wc}  ${marker}${widx}: ${wname}${suffix}${RST}${CLR}"$'\n'
            targets_data+="window|${sname}:${widx}"$'\n'
        done <<< "$windows"

        output+=$'\n'
        targets_data+="|"$'\n'
    done <<< "$sessions"

    output+="${GRN}${BOLD}  +  new window${RST}${CLR}"$'\n'
    targets_data+="new-window|"$'\n'

    # Clear screen, draw content
    printf '\e[2J\e[H%s' "$output"
    printf '%s' "$targets_data" > "/tmp/tain-targets-${MY_PANE}"
}

# Initial render
render

# Block on FIFO — sidebar-refresh.sh writes to trigger re-render
while read -r < "$FIFO" 2>/dev/null; do
    # Brief delay to let tmux state settle (e.g., after session kill)
    sleep 0.05
    render
done
