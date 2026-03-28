# tmux-all-i-need

Minimal tmux plugin that auto-saves and restores your sessions, windows, panes, and working directories. No plugin manager required.

## What it does

- **Saves**: session names, windows, panes, working directories, layouts, active selections
- **Restores**: recreates the full structure when tmux starts
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

## How it works

- **Auto-save on changes**: Hooks on session/window creation and destruction trigger a save
- **Periodic save**: Background loop saves every 15 seconds to catch directory changes
- **Auto-restore**: On fresh tmux server start, automatically restores the last saved state
- **State file**: `~/.tmux/tmux-all-i-need/last.txt`

## Uninstall

1. Remove the `run-shell` line from `~/.tmux.conf`
2. Delete the repo and state directory:

```bash
rm -rf ~/.tmux/plugins/tmux-all-i-need
rm -rf ~/.tmux/tmux-all-i-need
```
