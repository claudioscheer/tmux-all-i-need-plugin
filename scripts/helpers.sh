#!/usr/bin/env bash

STATE_DIR="$HOME/.tmux/tmux-all-i-need"
STATE_FILE="$STATE_DIR/last.txt"
TMP_FILE="$STATE_DIR/.last.txt.tmp"
TAB=$'\t'

SIDEBAR_WIDTH=30

display_message() {
    tmux display-message "tmux-all-i-need: $1"
}
