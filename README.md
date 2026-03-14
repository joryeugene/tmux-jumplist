# tmux-jumplist

```
  ╭──────────────────────────────────╮
  │  ←  Alt+[   jumplist   Alt+] →   │
  │                                  │
  │    [A] [B] [C] [D] [E]           │
  │             ^                    │
  │       you are here               │
  ╰──────────────────────────────────╯
```

Navigate back and forward through your tmux pane history. Like `Ctrl-O`/`Ctrl-I` in Vim, but for tmux.

tmux remembers your last window (`prefix + l`). That's one step. tmux-jumplist remembers **50**.

## How it works

Every time you switch panes or windows, tmux-jumplist records the location. Press **back** to retrace your steps. Press **forward** to go the other way.

```
You navigate through windows A, B, C, D, E:

  History:  [A] [B] [C] [D] [E]
                                ^  you are here

Press back three times:

  History:  [A] [B] [C] [D] [E]
                  ^
            You are at B. Forward takes you to C, D, E.

At B, you switch to a NEW window F:

  BEFORE:   [A] [B] [C] [D] [E]
  AFTER:    [A] [B] [F]

  C, D, E are gone. You chose a new path.
```

No daemon. No background process. A single shell script (~150 lines) triggered by tmux hooks.

## Install

### With [TPM](https://github.com/tmux-plugins/tpm)

Add to your `tmux.conf`:

```bash
set -g @plugin 'joryeugene/tmux-jumplist'
```

Press `prefix + I` to install.

### Requirements

- tmux 3.0+ (needs `pane-focus-in` hook and `set-hook -a` append syntax)
- `focus-events on` in your tmux.conf (required for `pane-focus-in` to fire)

## Keybindings

| Key | Action |
|-----|--------|
| `Alt+[` | Jump back |
| `Alt+]` | Jump forward |

### Alternative keybindings

```bash
# Use comma/period instead
set -g @jumplist-key-back 'M-,'
set -g @jumplist-key-forward 'M-.'
```

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `@jumplist-key-back` | `M-[` | Key to navigate backward |
| `@jumplist-key-forward` | `M-]` | Key to navigate forward |
| `@jumplist-max-history` | `50` | Maximum entries in the jumplist |

## What gets tracked

Every pane focus change is recorded as `session:window.pane`. Consecutive duplicates are collapsed (switching to the same pane twice records only once). Closed panes and windows are skipped automatically during navigation.

## Prior art

[tmux/tmux#3258](https://github.com/tmux/tmux/issues/3258) requested this feature in 2022. tmux's built-in `last-window` and `last-pane` only toggle between two locations. This plugin fills that gap.

## License

[MIT](LICENSE)
