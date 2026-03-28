#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/helpers.sh"

MY_PANE="$TMUX_PANE"

# Enable mouse tracking
printf '\e[?1000h\e[?1006h'

cleanup() {
    printf '\e[?1000l\e[?1006l'
    tmux set-option -pu -t "$MY_PANE" @tain-sidebar 2>/dev/null
}
trap cleanup EXIT

# Globals
declare -a TARGETS=()
declare -a TARGET_TYPES=()

render() {
    local cur_sess cur_win
    cur_sess=$(tmux display-message -p '#{client_session}' 2>/dev/null)
    cur_win=$(tmux display-message -p '#{window_index}' 2>/dev/null)

    TARGETS=()
    TARGET_TYPES=()
    local output=""

    local RST=$'\e[0m' BOLD=$'\e[1m' DIM=$'\e[2m'
    local GRN=$'\e[32m' CYN=$'\e[36m' YLW=$'\e[33m'

    local sessions
    sessions=$(tmux list-sessions -F '#{session_name}|#{session_windows}' 2>/dev/null)

    while IFS='|' read -r sname swins; do
        [ -z "$sname" ] && continue

        # Session line
        local sc="$DIM"
        [ "$sname" = "$cur_sess" ] && sc="${GRN}${BOLD}"
        output+="${sc}▼ ${sname}${RST}"$'\n'
        TARGETS+=("$sname")
        TARGET_TYPES+=("session")

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
            TARGETS+=("${sname}:${widx}")
            TARGET_TYPES+=("window")
        done <<< "$windows"

        output+=$'\n'
        TARGETS+=("")
        TARGET_TYPES+=("")
    done <<< "$sessions"

    printf '\e[2J\e[H%s' "$output"
}

handle_click() {
    local row=$1
    local idx=$((row - 1))
    [ "$idx" -lt 0 ] || [ "$idx" -ge "${#TARGETS[@]}" ] && return
    local target="${TARGETS[$idx]}"
    local ttype="${TARGET_TYPES[$idx]}"
    [ -z "$target" ] && return

    case "$ttype" in
        session)
            tmux switch-client -t "=$target" 2>/dev/null
            ;;
        window)
            local sess="${target%%:*}"
            tmux switch-client -t "=$sess" 2>/dev/null
            tmux select-window -t "=$target" 2>/dev/null
            ;;
    esac
}

# Main loop
while true; do
    render

    # Wait for mouse input or 2s timeout
    while IFS= read -r -t 2 -n 1 char; do
        if [[ "$char" == $'\e' ]]; then
            rest=""
            while IFS= read -r -t 0.05 -n 1 c; do
                rest+="$c"
                [[ "$c" == "M" || "$c" == "m" ]] && break
            done
            if [[ "$rest" =~ ^\[?\<([0-9]+)\;([0-9]+)\;([0-9]+)M$ ]]; then
                local btn="${BASH_REMATCH[1]}"
                local row="${BASH_REMATCH[3]}"
                [ "$btn" = "0" ] && handle_click "$row"
            fi
            break
        fi
    done
done
