# tmux-all-i-need

Minimal tmux plugin that auto-saves/restores sessions and adds a clickable sidebar for navigating sessions and windows. No plugin manager required.

## Features

### Session persistence
- **Auto-save** on session/window create/destroy and every 15 seconds
- **Auto-restore** on fresh tmux server start — sessions, windows, panes, working directories, and split layouts
- **Smart split detection** — uses pane positions (`pane_left`/`pane_top`) to restore vertical and horizontal splits correctly
- Throttled saves (2s minimum between hook-triggered saves) to avoid redundant writes
- Atomic file writes (write to tmp, then `mv`) to prevent corruption
- Does NOT save: pane content, command history, or running processes

### Sidebar
- **Tree view** of all sessions and windows with click-to-navigate
- **Current session** highlighted in green, **active window** marked with `●`, other sessions' active windows marked with `›`
- **Per-window indicators**: git dirty status (`*`), pane count (`[N]` when >1), zoom flag (`Z`)
- **"+ new window" button** at the bottom of the sidebar
- **Flash-free refresh** via named pipe (FIFO) — no pane destruction on updates
- **Event-driven updates** — tmux hooks trigger instant re-renders on state changes (no polling)
- **Path change detection** — polls pane paths every 3 seconds and refreshes sidebar when directories change
- **Window name truncation** — long names are clipped with `…` to fit sidebar width
- **Scroll prevention** — mouse wheel is disabled on sidebar panes to avoid entering copy mode
- **Empty window handling** — when all non-sidebar panes are closed, switches to next window or creates a new pane
- **Width enforcement** — sidebar width is enforced via `resize-pane` after creation

### Status bar
- **Styled** with dark background and gradient segments
- **Left**: session name (green badge)
- **Right**: current pane command, git branch (magenta), date/time
- **Git branch** resolved from the active (non-sidebar) pane's working directory
- Window list hidden — sidebar handles all navigation

### General
- **Mouse support** enabled automatically
- **Auto-rename windows** to current directory name
- Keybindings use prefix to avoid conflicts

## Install

```bash
git clone https://github.com/yourusername/tmux-all-i-need.git ~/.tmux/plugins/tmux-all-i-need
```

Add to `~/.tmux.conf`:

```bash
run-shell ~/.tmux/plugins/tmux-all-i-need/tmux-all-i-need.tmux
```

Reload tmux:

```bash
tmux source ~/.tmux.conf
```

## Keybindings

| Key | Action |
|-----|--------|
| `prefix + Ctrl-s` | Manual save |
| `prefix + R` | Manual restore |
| `prefix + b` | Toggle sidebar |

## How it works

- **Auto-save on changes**: hooks on session/window creation and destruction trigger a save
- **Periodic save**: background loop saves every 15 seconds to catch directory changes
- **Auto-restore**: on fresh tmux server start, automatically restores the last saved state
- **Sidebar rendering**: one-shot render to screen, then block on FIFO; hooks signal the FIFO to trigger re-render without destroying the pane
- **State file**: `~/.tmux/tmux-all-i-need/last.txt`

## State file format

Tab-separated text file with `#` comment lines. Each non-comment line represents one pane (sidebar panes excluded).

```
session_name \t window_index \t window_name \t window_layout \t pane_index \t pane_current_path \t window_active \t pane_active \t pane_left \t pane_top
```

| Column | Description |
|--------|-------------|
| `session_name` | Name of the tmux session |
| `window_index` | Window number within the session |
| `window_name` | Display name of the window |
| `window_layout` | tmux layout string (stored for reference, not used during restore) |
| `pane_index` | Pane number within the window |
| `pane_current_path` | Working directory of the pane |
| `window_active` | `1` if this is the active window in its session |
| `pane_active` | `1` if this is the active pane in its window |
| `pane_left` | X position of the pane (used to detect vertical splits) |
| `pane_top` | Y position of the pane (used to detect horizontal splits) |

Split direction on restore: same `pane_top` as the first pane = vertical split (side by side); different = horizontal split (stacked).

## Uninstall

1. Remove the `run-shell` line from `~/.tmux.conf`
2. Delete the repo and state directory:

```bash
rm -rf ~/.tmux/plugins/tmux-all-i-need
rm -rf ~/.tmux/tmux-all-i-need
```
