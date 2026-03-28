# CLAUDE.md

## Project overview

tmux plugin that auto-saves/restores sessions and provides a clickable sidebar for navigating sessions and windows. No plugin manager required.

## Architecture

Entry point: `tmux-all-i-need.tmux` — sourced by tmux via `run-shell` in `~/.tmux.conf`. Registers keybindings, hooks, mouse bindings, and bootstraps sidebar + auto-restore.

### Scripts

| Script | Role |
|--------|------|
| `helpers.sh` | Shared constants (`STATE_DIR`, `SIDEBAR_WIDTH`, `TAB`) and `display_message()` |
| `sidebar.sh` | Runs in the sidebar pane. One-shot render of session/window tree with ANSI colors, then blocks with `tail -f /dev/null`. Writes click target map to `/tmp/tain-targets-{PANE_ID}`. Refreshed via `respawn-pane` from hooks. |
| `sidebar-ensure.sh` | Creates sidebar pane in current window if one doesn't exist. Uses `tmux wait-for` lock to prevent races. Tags pane with `@tain-sidebar=1`, restores focus with `last-pane`. |
| `sidebar-toggle.sh` | Toggles `@tain-sidebar-enabled` flag, kills or creates sidebar panes globally. |
| `sidebar-click.sh` | Called by `MouseDown1Pane` binding. Reads target map file, navigates to clicked session/window, returns focus to main pane. |
| `sidebar-refresh.sh` | Respawns the current window's sidebar pane via `respawn-pane -k`, triggering a fresh render. Called by tmux hooks on state changes. |
| `handle-empty-window.sh` | `window-layout-changed` hook handler. When only sidebar panes remain: switches to next window (killing empty one) or creates a new pane if last window. |
| `save.sh` | Captures all non-sidebar pane state to `~/.tmux/tmux-all-i-need/last.txt`. Throttled (2s min between hook saves). Runs periodically (15s) and on structural hooks. |
| `restore.sh` | Recreates sessions/windows/panes from state file on fresh server start. Uses `pane_left`/`pane_top` to detect vertical vs horizontal splits. Renames initial session to `_tain_temp` during restore, cleans up after. |

### Hook priority

Hooks use index suffixes to avoid colliding with user hooks:
- `[99]` — auto-save on structural changes
- `[98]` — sidebar-ensure on window/session changes
- `[97]` — handle-empty-window on layout changes
- `[96]` — sidebar-refresh on state changes (instant re-render)

### tmux options used as state

| Option | Scope | Purpose |
|--------|-------|---------|
| `@tain-sidebar` | pane | Marks pane as sidebar (`1`). Persists across `respawn-pane`. |
| `@tain-sidebar-enabled` | global | `0` to disable sidebar globally |
| `@tain-restoring` | global | `1` during restore (suppresses saves and sidebar creation) |
| `@tain-periodic-running` | global | `1` when background save loop is active |
| `@tain-last-save` | global | Unix timestamp of last save (for throttling) |

### Sidebar rendering

Inspired by tmux-sidebar: **no loop, event-driven**.

1. `sidebar.sh` renders once (one-shot), writes target map, then blocks with `tail -f /dev/null`
2. tmux hooks (session/window changes) call `sidebar-refresh.sh`
3. `sidebar-refresh.sh` runs `respawn-pane -k` on the sidebar pane, killing `tail` and starting a fresh `sidebar.sh`
4. The new `sidebar.sh` renders the updated state immediately

This eliminates polling delays — the sidebar updates the instant tmux state changes.

### State file format

Tab-separated, one line per pane (sidebar panes excluded):
```
session_name \t window_index \t window_name \t window_layout \t pane_index \t pane_current_path \t window_active \t pane_active \t pane_left \t pane_top
```

`pane_left`/`pane_top` determine split direction on restore: same `pane_top` = vertical split (`-h`), different = horizontal.

### Click routing

1. `sidebar.sh` writes a target map file (`/tmp/tain-targets-{PANE_ID}`) on render, one line per display row: `type|target`
2. `MouseDown1Pane` binding detects clicks on sidebar panes via `#{@tain-sidebar}`
3. `sidebar-click.sh` receives `mouse_y`, `pane_top`, `pane_id`, computes row, reads target map, executes navigation
4. Navigation triggers tmux hooks (`session-window-changed`), which call `sidebar-refresh.sh` to update the display

## Conventions

- All tmux options prefixed with `@tain-`
- All scripts source `helpers.sh` for shared constants
- `2>/dev/null` on all tmux commands (defensive)
- `tmux wait-for -L/-U` for exclusive locking where races are possible
- Sidebar pane created with `split-window -hbf` (horizontal, before, full-height)
- Focus always restored to main pane via `last-pane` or explicit `select-pane`
- Pane input disabled with `select-pane -d` on sidebar panes
- Pane options (like `@tain-sidebar`) persist across `respawn-pane` — don't unset them in sidebar.sh cleanup

## Development workflow

- Edit script files directly, then restart tmux to test (`tmux kill-server && tmux`)
- Never test via direct tmux commands in the terminal — always edit the scripts
- State file lives at `~/.tmux/tmux-all-i-need/last.txt`
- Target map files are in `/tmp/tain-targets-*`

## Key design principles (from tmux-sidebar reference)

- **One-shot render, not a loop** — render once, block, use `respawn-pane` to refresh
- **Event-driven updates** — tmux hooks trigger re-renders, no polling
- **Lifecycle managed by hooks** — sidebar process only renders; creation, destruction, and empty-window handling are separate hook scripts
- **Focus restoration** via `tmux last-pane` after any sidebar operation
- **tmux options as key-value store** for all runtime state (no external databases)
- **Atomic file writes** (write to tmp, then `mv`)
