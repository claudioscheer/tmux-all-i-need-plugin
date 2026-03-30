# CLAUDE.md

## Project overview

tmux plugin that auto-saves/restores sessions and provides a clickable sidebar for navigating sessions and windows. No plugin manager required.

## Architecture

Entry point: `tmux-all-i-need.tmux` — sourced by tmux via `run-shell` in `~/.tmux.conf`. Registers keybindings, hooks, mouse bindings, and bootstraps sidebar + auto-restore.

### Scripts

| Script | Role |
|--------|------|
| `helpers.sh` | Shared constants (`STATE_DIR`, `SIDEBAR_WIDTH`, `TAB`) and `display_message()` |
| `sidebar.sh` | Runs in the sidebar pane. One-shot render of session/window tree with ANSI colors, then blocks on a named FIFO. Shows per-window indicators: git dirty (`*`), pane count (`[N]`), zoom (`Z`). Writes click target map to `/tmp/tain-targets-{PANE_ID}`. Re-renders when signaled via FIFO. |
| `sidebar-ensure.sh` | Creates sidebar pane in current window if one doesn't exist. Uses `tmux wait-for` lock to prevent races. Tags pane with `@tain-sidebar=1`, enforces width with `resize-pane`, restores focus with `last-pane`. |
| `sidebar-toggle.sh` | Toggles `@tain-sidebar-enabled` flag, kills or creates sidebar panes globally. |
| `sidebar-click.sh` | Called by `MouseDown1Pane` binding. Reads target map file, navigates to clicked session/window. Handles `new-window` action. Restores focus to main pane in the navigated-to window (not the old window). |
| `sidebar-refresh.sh` | Writes to the sidebar pane's FIFO to trigger a re-render without destroying the pane. Called by tmux hooks on state changes. |
| `handle-empty-window.sh` | `window-layout-changed` hook handler. When only sidebar panes remain: switches to next window (killing empty one) or creates a new pane if last window. |
| `save.sh` | Captures all non-sidebar pane state to `~/.tmux/tmux-all-i-need/last.txt`. Throttled (2s min between hook saves). Runs periodically (15s) and on structural hooks. Uses atomic writes (tmp + `mv`). |
| `restore.sh` | Recreates sessions/windows/panes from state file on fresh server start. Uses `pane_left`/`pane_top` to detect vertical vs horizontal splits. Renames initial session to `_tain_temp` during restore, cleans up after. Re-enables `automatic-rename` on restored windows. |
| `git-branch.sh` | Resolves git branch from the active (non-sidebar) pane's working directory. Used by status-right via `#()`. |
| `watch-paths.sh` | Polls pane paths every 3 seconds. Triggers sidebar refresh only when a path actually changes. |

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

Inspired by tmux-sidebar: **no loop, event-driven, flash-free**.

1. `sidebar.sh` renders once (one-shot), writes target map, then blocks reading from a named FIFO (`/tmp/tain-fifo-{PANE_ID}`)
2. tmux hooks (session/window changes) call `sidebar-refresh.sh`
3. `sidebar-refresh.sh` writes to the FIFO, unblocking `sidebar.sh`
4. `sidebar.sh` re-renders in-place (clear screen + redraw) — no pane destruction, no flash
5. `watch-paths.sh` polls pane paths every 3 seconds and triggers a refresh when directories change

Each output line uses `\e[K` (clear to end of line) to prevent stale text artifacts. A 50ms debounce before re-render lets tmux state settle after destructive operations like session kill.

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
- Sidebar pane created with `split-window -hbf` (horizontal, before, full-height), width enforced with `resize-pane`
- Focus always restored to main pane via `last-pane` (sidebar creation) or explicit `select-pane` (click navigation to navigated-to window)
- Pane input disabled with `select-pane -d` on sidebar panes
- Sidebar process `cd /` on startup to prevent affecting `automatic-rename`
- `automatic-rename` set globally to `#{b:pane_current_path}` — windows show directory names
- Status bar hides the window list (`window-status-format` set to empty) — sidebar handles navigation
- Status bar right segment uses `#()` shell command for git branch (via `git-branch.sh`)
- Named FIFOs (`/tmp/tain-fifo-{PANE_ID}`) used for sidebar communication — cleaned up on exit via trap

## Development workflow

- Edit script files directly, then restart tmux to test (`tmux kill-server && tmux`)
- Never test via direct tmux commands in the terminal — always edit the scripts
- State file lives at `~/.tmux/tmux-all-i-need/last.txt`
- Target map files are in `/tmp/tain-targets-*`
- **Never add `Co-Authored-By` or any AI attribution to commit messages**

## Key design principles

- **One-shot render, FIFO-driven refresh** — render once, block on FIFO, re-render in-place when signaled (no pane destruction)
- **Event-driven updates** — tmux hooks trigger instant re-renders, no polling for state changes
- **Path polling as supplement** — `watch-paths.sh` catches directory changes that don't trigger hooks (every 3s, only refreshes when changed)
- **Lifecycle managed by hooks** — sidebar process only renders; creation, destruction, and empty-window handling are separate hook scripts
- **Focus restoration** — `last-pane` after sidebar creation; explicit `select-pane` to main pane in navigated-to window after click navigation
- **tmux options as key-value store** for all runtime state (no external databases)
- **Atomic file writes** (write to tmp, then `mv`)

## Known issues resolved

These issues have been fixed and are documented here for context:

- **Sidebar ghost text** — old text lingered after re-render. Fixed by using `\e[2J\e[H` (full screen clear) and `\e[K` (clear to EOL) on each line.
- **Stale content after session kill** — sidebar showed deleted sessions. Fixed by adding 50ms debounce before re-render to let tmux state settle.
- **Focus lost on session switch** — clicking a session/window left focus in the sidebar. Fixed by resolving the main pane in the navigated-to window (not the old window) and selecting it explicitly.
- **Sidebar width drift** — `split-window -l` didn't always honor the width. Fixed by enforcing exact width with `resize-pane` after creation.
- **Flash on refresh** — original design used `respawn-pane -k` which destroyed and recreated the pane. Replaced with FIFO-based signaling for in-place re-render.
