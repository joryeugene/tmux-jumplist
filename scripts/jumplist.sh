#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="$(tmux show-environment -g TMUX_JUMPLIST_DATA 2>/dev/null | cut -d= -f2-)"
HISTORY_FILE="$DATA_DIR/history"
MAX="$(tmux show-environment -g TMUX_JUMPLIST_MAX 2>/dev/null | cut -d= -f2- || echo 50)"

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

line_count() {
    if [ -f "$HISTORY_FILE" ] && [ -s "$HISTORY_FILE" ]; then
        wc -l < "$HISTORY_FILE" | tr -d ' '
    else
        echo 0
    fi
}

get_line() {
    sed -n "${1}p" "$HISTORY_FILE"
}

switch_to() {
    local target="$1"
    tmux switch-client -t "$target" 2>/dev/null ||
        tmux select-window -t "$target" 2>/dev/null ||
        tmux select-pane -t "$target" 2>/dev/null ||
        return 1
}

# ── record ──────────────────────────────────────
cmd_record() {
    local location="${1:-}"
    [ -z "$location" ] && return 0

    # The hook clears this flag after consuming it
    if is_navigating; then
        tmux set-option -gq @jumplist-navigating 0
        return 0
    fi

    [ -f "$HISTORY_FILE" ] || touch "$HISTORY_FILE"

    local cursor total
    cursor="$(get_cursor)"
    total="$(line_count)"

    # If cursor > 0, user navigated back then jumped somewhere new.
    # Truncate forward history.
    if [ "$cursor" -gt 0 ] && [ "$total" -gt 0 ]; then
        local keep=$(( total - cursor ))
        if [ "$keep" -gt 0 ]; then
            head -n "$keep" "$HISTORY_FILE" > "$HISTORY_FILE.tmp"
            mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
            total="$keep"
        fi
    fi

    # Dedup: skip if same as current head
    if [ "$total" -gt 0 ]; then
        local last
        last="$(tail -1 "$HISTORY_FILE")"
        if [ "$last" = "$location" ]; then
            set_cursor 0
            return 0
        fi
    fi

    # Append
    echo "$location" >> "$HISTORY_FILE"
    total=$(( total + 1 ))

    # Enforce max history (trim oldest)
    if [ "$total" -gt "$MAX" ]; then
        local trim=$(( total - MAX ))
        tail -n +"$(( trim + 1 ))" "$HISTORY_FILE" > "$HISTORY_FILE.tmp"
        mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    fi

    set_cursor 0
}

# ── back ────────────────────────────────────────
cmd_back() {
    [ -f "$HISTORY_FILE" ] || return 0

    local cursor total
    cursor="$(get_cursor)"
    total="$(line_count)"
    [ "$total" -eq 0 ] && return 0

    local try_cursor=$(( cursor + 1 ))

    while [ "$try_cursor" -lt "$total" ]; do
        local line_num=$(( total - try_cursor ))
        [ "$line_num" -lt 1 ] && break

        local target
        target="$(get_line "$line_num")"

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
    [ -f "$HISTORY_FILE" ] || return 0

    local cursor total
    cursor="$(get_cursor)"
    total="$(line_count)"

    [ "$cursor" -eq 0 ] && return 0

    local try_cursor=$(( cursor - 1 ))

    while [ "$try_cursor" -ge 0 ]; do
        local line_num=$(( total - try_cursor ))
        [ "$line_num" -lt 1 ] && break
        [ "$line_num" -gt "$total" ] && break

        local target
        target="$(get_line "$line_num")"

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
    *)       echo "Usage: jumplist.sh {record|back|forward}" >&2; exit 1 ;;
esac
