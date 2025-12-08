# Bun Task Viewer UI

A minimal Bun-powered exam task navigator available in **two flavors**:
1. **Web UI** - Modern browser-based split-pane interface
2. **Terminal TUI** - Rich terminal interface powered by `blessed` for tmux workflows

Both interfaces share the same task parser and flag storage, letting you seamlessly switch between browser and terminal views.

## Prerequisites

- [Bun](https://bun.sh) v1.1 or newer installed on your host or VM

## Quick start

### Web UI (Browser-based)

```bash
cd apps/exam-ui
bun run dev
```

By default the server watches `/vagrant/exam-tasks.md` and serves the UI on <http://localhost:4173>. Changes to `exam-tasks.md` hot-reload automatically thanks to Bun's `--watch` flag.

Open <http://localhost:4173> in your browser to access the split-pane interface with search, filters, and flag toggles.

### Terminal TUI (tmux-friendly)

```bash
cd apps/exam-ui
bun install  # First time only
bun run tui
```

This launches a full-screen terminal interface with:
- Split-pane layout (task list on left, details on right)
- Vim-style navigation (`j`/`k` or arrow keys)
- Flag toggling with `f`
- Search with `/`
- Filter modes: `a` (all) / `Shift+F` (flagged only)
- Shared flag storage with the web UI in `~/.ica-task-flags`

**Quit** with `q` or `Esc`.

### Running TUI in tmux

Use the wrapper script for the full exam environment:

```bash
sudo /vagrant/scripts/exam-env-tui.sh
```

This creates a 3-pane tmux layout:
- **Left:** JavaScript TUI task navigator
- **Top-right:** Your work shell
- **Bottom-right:** Auto-refreshing scoreboard

Press `F1`/`F2`/`F3` to jump between panes, `F5` to restart the scoreboard.

## Customizing the task source

Both UI modes respect the `TASK_FILE` environment variable:

```bash
TASK_FILE=/path/to/tasks.md bun run dev    # Web UI
TASK_FILE=/path/to/tasks.md bun run tui    # Terminal TUI
```

## Production-style run (Web UI)

```bash
bun run start
```

Launches the server without watch mode (useful for deployments or supervisor processes).

## Features

### Web UI
- Sticky navigation with live search
- All/Flagged filter tabs
- Flag toggles stored in `localStorage`
- Responsive layout for mobile/narrow screens
- Markdown rendering (bold, code, links, lists)

### Terminal TUI
- Full keyboard navigation (arrow keys, vim bindings)
- Real-time search (`/` to activate)
- Flag management synced to `~/.ica-task-flags`
- Scrollable task details with `PageUp`/`PageDown`
- Works perfectly in tmux splits

## Port forwarding

If running on a VM, forward the web UI port to your host:

```bash
ssh -L 4173:localhost:4173 controlplane
```

Then open <http://localhost:4173> on your host machine.
