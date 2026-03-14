#!/usr/bin/env bash

DATA_DIR="$(tmux show-environment -g TMUX_JUMPLIST_DATA 2>/dev/null | cut -d= -f2-)"
DATA_DIR="${DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/tmux/jumplist}"
HISTORY_FILE="$DATA_DIR/history"
MAX="$(tmux show-environment -g TMUX_JUMPLIST_MAX 2>/dev/null | cut -d= -f2- || echo 50)"

# Load history into array once (eliminates sed/wc/tail subprocesses)
ENTRIES=()
if [ -f "$HISTORY_FILE" ] && [ -s "$HISTORY_FILE" ]; then
    while IFS= read -r line; do
        ENTRIES+=("$line")
    done < "$HISTORY_FILE"
fi

get_cursor() {
    local val
    val="$(tmux show-option -gqv @jumplist-cursor 2>/dev/null)"
    echo "${val:-0}"
}

set_cursor() {
    tmux set-option -gq @jumplist-cursor "$1"
}

is_navigating() {
    local val
    val="$(tmux show-option -gqv @jumplist-navigating 2>/dev/null)"
    [ "$val" = "1" ]
}

target_exists() {
    tmux display-message -t "$1" -p '' >/dev/null 2>&1
}

switch_to() {
    local target="$1"
    tmux switch-client -t "$target" 2>/dev/null ||
        tmux select-window -t "$target" 2>/dev/null ||
        tmux select-pane -t "$target" 2>/dev/null ||
        return 1
}

write_history() {
    if [ "${#ENTRIES[@]}" -eq 0 ]; then
        > "$HISTORY_FILE"
    else
        printf '%s\n' "${ENTRIES[@]}" > "$HISTORY_FILE"
    fi
}

# ── record ──────────────────────────────────────
cmd_record() {
    local location="${1:-}"
    [ -z "$location" ] && return 0

    if is_navigating; then
        tmux set-option -gq @jumplist-navigating 0
        return 0
    fi

    local cursor total
    cursor="$(get_cursor)"
    total="${#ENTRIES[@]}"

    # Dedup: check against current position in history.
    # Must run BEFORE truncation to prevent popup/refocus from destroying
    # forward history when the same pane regains focus.
    if [ "$total" -gt 0 ]; then
        local check_idx
        if [ "$cursor" -gt 0 ]; then
            check_idx=$(( total - cursor ))
        else
            check_idx="$total"
        fi
        if [ "$check_idx" -gt 0 ] && [ "${ENTRIES[check_idx-1]}" = "$location" ]; then
            return 0
        fi
    fi

    # If cursor > 0, truncate forward history (new path chosen)
    if [ "$cursor" -gt 0 ] && [ "$total" -gt 0 ]; then
        local keep=$(( total - cursor ))
        if [ "$keep" -gt 0 ]; then
            ENTRIES=("${ENTRIES[@]:0:$keep}")
            total="$keep"
        fi
    fi

    # Append
    ENTRIES+=("$location")
    total=$(( total + 1 ))

    # Enforce max history (trim oldest)
    if [ "$total" -gt "$MAX" ]; then
        local trim=$(( total - MAX ))
        ENTRIES=("${ENTRIES[@]:$trim}")
    fi

    write_history
    set_cursor 0
}

# ── back ────────────────────────────────────────
cmd_back() {
    local total="${#ENTRIES[@]}"
    [ "$total" -eq 0 ] && return 0

    local cursor current
    cursor="$(get_cursor)"
    current="$(tmux display-message -p '#{session_name}:#{window_index}.#{pane_index}')"
    local try_cursor=$(( cursor + 1 ))

    while [ "$try_cursor" -lt "$total" ]; do
        local idx=$(( total - 1 - try_cursor ))
        [ "$idx" -lt 0 ] && break

        local target="${ENTRIES[$idx]}"

        if [ "$target" = "$current" ]; then
            try_cursor=$(( try_cursor + 1 ))
            continue
        fi

        if target_exists "$target"; then
            tmux set-option -gq @jumplist-navigating 1
            set_cursor "$try_cursor"
            switch_to "$target" || true
            return 0
        fi

        # Dead target, skip
        try_cursor=$(( try_cursor + 1 ))
    done
}

# ── forward ─────────────────────────────────────
cmd_forward() {
    local total="${#ENTRIES[@]}"
    [ "$total" -eq 0 ] && return 0

    local cursor
    cursor="$(get_cursor)"
    [ "$cursor" -eq 0 ] && return 0

    local current
    current="$(tmux display-message -p '#{session_name}:#{window_index}.#{pane_index}')"
    local try_cursor=$(( cursor - 1 ))

    while [ "$try_cursor" -ge 0 ]; do
        local idx=$(( total - 1 - try_cursor ))
        [ "$idx" -lt 0 ] && break
        [ "$idx" -ge "$total" ] && break

        local target="${ENTRIES[$idx]}"

        if [ "$target" = "$current" ]; then
            try_cursor=$(( try_cursor - 1 ))
            continue
        fi

        if target_exists "$target"; then
            tmux set-option -gq @jumplist-navigating 1
            set_cursor "$try_cursor"
            switch_to "$target" || true
            return 0
        fi

        try_cursor=$(( try_cursor - 1 ))
    done
}

# ── dispatch ────────────────────────────────────
case "${1:-}" in
    record)  cmd_record "${2:-}" ;;
    back)    cmd_back ;;
    forward) cmd_forward ;;
    *)       exit 1 ;;
esac
