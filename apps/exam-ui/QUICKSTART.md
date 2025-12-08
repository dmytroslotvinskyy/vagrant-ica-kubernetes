# Quick Start Guide - Exam Task Navigator

This guide helps you choose and launch the right interface for your exam preparation workflow.

## Option 1: Web UI (Recommended for host machines)

**Best for:** Viewing tasks on your host machine while working on the VM, or when you want a modern browser interface.

**Quick start:**
```bash
cd apps/exam-ui
bun run dev
```

**Access:** Open <http://localhost:4173> in your browser

**Features:**
- Modern split-pane layout
- Live search and filtering
- Click to flag/unflag tasks
- Responsive design (works on mobile)
- localStorage-based flag persistence

---

## Option 2: Terminal TUI (Recommended for VM/tmux workflows)

**Best for:** Working entirely within the VM terminal, tmux users, or those who prefer keyboard-only navigation.

**Quick start:**
```bash
cd apps/exam-ui
bun install  # First time only
bun run tui
```

**Features:**
- Full-screen terminal interface
- Vim-style navigation (j/k)
- Keyboard-driven flag management
- Search with `/`
- Filter modes (all/flagged)
- File-based flag persistence (`~/.ica-task-flags`)

**Keyboard shortcuts:**
| Key | Action |
|-----|--------|
| `↑`/`↓` or `j`/`k` | Navigate task list |
| `Enter` | Select task |
| `f` | Toggle flag on current task |
| `a` | Show all tasks |
| `Shift+F` | Show only flagged tasks |
| `/` | Open search box |
| `PageUp`/`PageDown` | Scroll task details |
| `q` or `Esc` | Quit |

---

## Option 3: Full Exam Environment with TUI

**Best for:** Simulating the real exam environment with task viewer, work shell, and live scoring.

**Quick start (inside VM):**
```bash
sudo /vagrant/scripts/exam-env-tui.sh
```

**Layout:**
```
┌──────────────────┬─────────────────────┐
│                  │                     │
│  Task Navigator  │   Work Shell        │
│  (JavaScript TUI)│   (kubectl, etc.)   │
│                  │                     │
│                  ├─────────────────────┤
│                  │                     │
│                  │   Scoreboard        │
│                  │   (auto-refresh)    │
└──────────────────┴─────────────────────┘
```

**Tmux shortcuts:**
| Key | Action |
|-----|--------|
| `F1` | Jump to task navigator pane |
| `F2` | Jump to work shell pane |
| `F3` | Jump to scoreboard pane |
| `F5` | Restart scoreboard refresh |
| `Ctrl+b d` | Detach from tmux session |

**Reconnect to session:**
```bash
tmux attach -t exam
```

---

## Switching Between Interfaces

Both the Web UI and Terminal TUI read from the same `exam-tasks.md` file. However, flag storage differs:

- **Web UI:** Stores flags in browser `localStorage`
- **Terminal TUI:** Stores flags in `~/.ica-task-flags`

They do **not** sync automatically, but you can manually copy flags if needed.

---

## Customizing Task Source

Override the task file location for any interface:

```bash
# Web UI
TASK_FILE=/path/to/custom-tasks.md bun run dev

# Terminal TUI
TASK_FILE=/path/to/custom-tasks.md bun run tui

# tmux environment
TASK_FILE=/path/to/custom-tasks.md /vagrant/scripts/exam-env-tui.sh
```

---

## Troubleshooting

### "bun: command not found"

Install Bun:
```bash
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc  # or restart your shell
```

### "Cannot find module 'blessed'"

Install dependencies:
```bash
cd apps/exam-ui
bun install
```

### TUI looks broken/garbled

Ensure your terminal supports UTF-8 and has a reasonable size (minimum 80x24 recommended, 120x30 ideal).

Try:
```bash
export TERM=xterm-256color
```

### Port 4173 already in use

Change the port:
```bash
PORT=8080 bun run dev
```

---

## Performance Tips

1. **File watching:** The web UI auto-reloads when `exam-tasks.md` changes. The TUI requires a restart.

2. **tmux performance:** If the TUI feels sluggish in tmux, try reducing the scoreboard refresh interval:
   ```bash
   SCOREBOARD_INTERVAL=300 /vagrant/scripts/exam-env-tui.sh  # Refresh every 5 minutes
   ```

3. **SSH lag:** If running over SSH with high latency, the Web UI on the host (with port forwarding) will feel more responsive than the TUI in the VM.

---

## Getting Help

- Web UI issues: Check browser console (F12)
- TUI issues: Run with debug output: `DEBUG=* bun run tui`
- Task parsing issues: Validate `exam-tasks.md` format (should have `---TASK---` separators)

For more details, see the main [README.md](README.md).

