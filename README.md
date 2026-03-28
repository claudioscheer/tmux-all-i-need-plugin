# tmux-all-i-need

Minimal tmux plugin that auto-saves/restores sessions and adds a clickable sidebar for navigating sessions and windows. No plugin manager required.

## What it does

- **Auto-save/restore**: sessions, windows, panes, working directories, layouts
- **Sidebar**: tree view of all sessions and windows, click to navigate
- **Status bar**: clickable `+` button (new window) and `≡` button (session picker)
- **Mouse support**: enabled automatically
- **Does NOT save**: pane content, command history, or running processes

## Install

Clone the repo:

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

## Sidebar

The sidebar shows a tree of all sessions and windows. Click on any entry to switch to it. The current session is highlighted in green, the active window with a `●` marker.

## Status bar

| Button | Action |
|--------|--------|
| `≡` | Open session picker (`choose-tree`) |
| `+` | Create a new window |

## How it works

- **Auto-save on changes**: hooks on session/window creation and destruction trigger a save
- **Periodic save**: background loop saves every 15 seconds to catch directory changes
- **Auto-restore**: on fresh tmux server start, automatically restores the last saved state
- **State file**: `~/.tmux/tmux-all-i-need/last.txt`

## Uninstall

1. Remove the `run-shell` line from `~/.tmux.conf`
2. Delete the repo and state directory:

```bash
rm -rf ~/.tmux/plugins/tmux-all-i-need
rm -rf ~/.tmux/tmux-all-i-need
```
