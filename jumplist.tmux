#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_tmux_option() {
    local option="$1" default="$2"
    local value
    value="$(tmux show-option -gqv "$option")"
    echo "${value:-$default}"
}

main() {
    local script="$CURRENT_DIR/scripts/jumplist.sh"

    local key_back key_forward max_history
    key_back="$(get_tmux_option '@jumplist-key-back' 'M-[')"
    key_forward="$(get_tmux_option '@jumplist-key-forward' 'M-]')"
    max_history="$(get_tmux_option '@jumplist-max-history' '50')"

    local data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/jumplist"
    mkdir -p "$data_dir"

    # Store config where the script can read it without extra tmux calls
    tmux set-environment -g TMUX_JUMPLIST_DATA "$data_dir"
    tmux set-environment -g TMUX_JUMPLIST_MAX "$max_history"

    # Initialize state
    tmux set-option -gq @jumplist-cursor 0
    tmux set-option -gq @jumplist-navigating 0

    # Record pane focus changes (format strings resolve before the script runs)
    # Clear first to prevent duplicate hooks on plugin reload
    tmux set-hook -gu pane-focus-in 2>/dev/null
    tmux set-hook -ga pane-focus-in \
        "run-shell \"$script record '#{session_name}:#{window_index}.#{pane_index}'\""

    # Navigation keybindings (no prefix)
    tmux bind-key -n "$key_back" run-shell "$script back"
    tmux bind-key -n "$key_forward" run-shell "$script forward"
}

main
