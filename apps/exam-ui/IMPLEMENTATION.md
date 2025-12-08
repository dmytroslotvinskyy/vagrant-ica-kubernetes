# Implementation Summary - Bun Task Navigator

This document summarizes the dual-interface task navigator system implemented for the ICA Istio lab mock exam.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                   exam-tasks.md                         │
│              (Markdown task definitions)                │
└────────────────────┬────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
┌───────────────┐         ┌──────────────┐
│  Web Server   │         │  Terminal    │
│  (server.ts)  │         │  TUI         │
│               │         │  (tui.ts)    │
│  - Bun serve  │         │  - blessed   │
│  - /api/tasks │         │  - Direct    │
│  - Static     │         │    parsing   │
│    assets     │         │              │
└───────┬───────┘         └──────┬───────┘
        │                        │
        ▼                        ▼
┌───────────────┐         ┌──────────────┐
│   Browser     │         │  Terminal    │
│   (app.js)    │         │  (blessed    │
│               │         │   widgets)   │
│ localStorage  │         │  ~/.ica-     │
│   flags       │         │  task-flags  │
└───────────────┘         └──────────────┘
```

## Components

### 1. Core Parsing Logic

**File:** `src/server.ts` (lines 24-83)

- `escapeHtml()`: Sanitizes raw text for HTML output
- `formatInline()`: Converts markdown inline elements (bold, code, links)
- `paragraphToHtml()`: Converts paragraphs and bullet lists to HTML
- `convertMarkdown()`: Orchestrates full markdown-to-HTML conversion
- `parseTasks()`: Splits `exam-tasks.md` on `---TASK---` markers and extracts:
  - Task ID (from title pattern)
  - Points value
  - Subtitle
  - Full body text

**Key pattern matching:**
```regex
/Task\s+(\d+)\s*\((\d+)\s*pts?\)\s*[–-]\s*(.+)/i
```

This captures:
- Group 1: Task number
- Group 2: Points
- Group 3: Task subtitle

### 2. Web Server (Bun)

**File:** `src/server.ts`

**API Endpoints:**
- `GET /api/tasks` - Returns JSON with all tasks and last modified timestamp
- `GET /` - Serves `index.html`
- `GET /app.js` - Serves client-side JavaScript
- `GET /style.css` - Serves styles

**Features:**
- File-based caching (checks `mtimeMs` before re-parsing)
- Hot-reload support via `bun run --watch`
- Configurable via `TASK_FILE` and `PORT` env vars
- Default port: 4173
- Default task file: `../../exam-tasks.md`

### 3. Web Frontend

**Files:**
- `public/index.html` - Semantic HTML structure
- `public/app.js` - Vanilla JavaScript client (no frameworks)
- `public/style.css` - Modern dark theme with responsive layout

**Features:**
- Split-pane layout (sidebar + main content)
- Search functionality (filters by subtitle and body)
- All/Flagged filter tabs
- Per-task flag toggle
- Flag persistence in `localStorage` (key: `icaTaskFlags`)
- Responsive design (stacks on mobile/narrow screens)

**State management:**
```javascript
state = {
  tasks: [],        // All tasks from API
  filtered: [],     // After search/filter
  activeId: null,   // Currently selected task
  filter: "all",    // "all" or "flagged"
  query: "",        // Search query
  flagged: Set      // Task IDs marked as flagged
}
```

### 4. Terminal TUI

**File:** `src/tui.ts`

**Dependencies:**
- `blessed`: Terminal UI framework (creates boxes, lists, scrollable areas)
- Native Bun file I/O

**Layout:**
```
┌─────────────────────────────────────────────┐
│         ICA Istio Lab - Task Navigator      │
├─────────────────┬───────────────────────────┤
│  Task List      │  Task Detail              │
│  ┌───────────┐  │  ┌─────────────────────┐  │
│  │ ★ Task 1  │  │  │ Task 5 (9 pts)      │  │
│  │   (7 pts) │  │  │                     │  │
│  │           │  │  │ Payments weighted   │  │
│  │ > Task 5  │◄─┼─▶│ routing...          │  │
│  │   (9 pts) │  │  │                     │  │
│  │           │  │  │ [Details...]        │  │
│  └───────────┘  │  └─────────────────────┘  │
├─────────────────┴───────────────────────────┤
│ Mode: All | Tasks: 16/16 | Flagged: 3      │
├─────────────────────────────────────────────┤
│ [↑/↓] Navigate | [f] Flag | [q] Quit       │
└─────────────────────────────────────────────┘
```

**Key bindings:**
| Key | Action | Implementation |
|-----|--------|----------------|
| `j`/`k`, `↑`/`↓` | Navigate | `taskList.down()` / `taskList.up()` |
| `Enter` | Select task | `taskList.on('select')` |
| `f` | Toggle flag | `toggleFlag()` → saves to file |
| `a` | Show all | `filterMode = "all"` |
| `Shift+F` | Show flagged | `filterMode = "flagged"` |
| `/` | Search | Shows `blessed.textbox` |
| `PageUp`/`PageDown` | Scroll detail | `taskDetail.scroll()` |
| `q`, `Esc`, `Ctrl+C` | Quit | `process.exit(0)` |

**Flag storage:**
- File: `~/.ica-task-flags`
- Format: One task ID per line
- Shared between TUI instances but **not** with Web UI

### 5. Integration Scripts

#### `scripts/tasks-viewer-tui.sh`

Wrapper script for running the TUI in tmux:
- Checks for Bun installation
- Auto-installs dependencies if needed
- Falls back to bash viewer if Bun unavailable
- Exports `TASK_FILE` and `FLAG_FILE` env vars

#### `scripts/exam-env-tui.sh`

Full exam environment launcher:
- Creates 3-pane tmux session
- Left pane: JavaScript TUI (default 50 columns wide)
- Top-right: Work shell
- Bottom-right: Auto-refreshing scoreboard
- Configures F-key bindings:
  - `F1`: Jump to task navigator
  - `F2`: Jump to work shell
  - `F3`: Jump to scoreboard
  - `F5`: Restart scoreboard

## Data Flow

### Web UI Flow
1. Browser loads `index.html`
2. `app.js` fetches `GET /api/tasks`
3. Server reads and parses `exam-tasks.md`
4. Server returns JSON with tasks array
5. Client renders task list and details
6. User clicks flag → saved to `localStorage`
7. Page refresh/reload → flags restored from `localStorage`

### Terminal TUI Flow
1. Bun runs `src/tui.ts`
2. Script reads `exam-tasks.md` directly
3. Script reads flags from `~/.ica-task-flags`
4. Blessed renders full-screen interface
5. User navigates with keyboard
6. User presses `f` → flag written to file immediately
7. Exit and restart → flags restored from file

## File Formats

### exam-tasks.md Structure
```markdown
### Task 1 (7 pts) – Install Istio 1.26 demo profile

Task body with instructions, requirements, and details.
Can include **bold**, `code`, bullet lists, etc.

---TASK---
### Task 2 (5 pts) – Enable default namespace workloads

Another task body...

---TASK---
...
```

**Critical elements:**
- `---TASK---` separator (exactly 3 dashes on each side)
- Title format: `### Task N (X pts) – Description`
- Body can use basic markdown

### Flag Storage

**Web UI (`localStorage`):**
```json
["1", "5", "12"]
```

**Terminal TUI (`~/.ica-task-flags`):**
```
1
5
12
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TASK_FILE` | `/vagrant/exam-tasks.md` | Path to task markdown file |
| `FLAG_FILE` | `~/.ica-task-flags` | Path to flag storage (TUI only) |
| `PORT` | `4173` | Web server port |
| `SESSION_NAME` | `exam` | Tmux session name |
| `VIEWER_WIDTH` | `50` | Width of TUI pane in tmux |
| `SCOREBOARD_INTERVAL` | `180` | Scoreboard refresh interval (seconds) |

### Package Configuration

**package.json:**
```json
{
  "scripts": {
    "dev": "bun run --watch src/server.ts",
    "start": "bun run src/server.ts",
    "tui": "bun run src/tui.ts"
  },
  "dependencies": {
    "@types/blessed": "^0.1.25",
    "blessed": "^0.1.81"
  }
}
```

**bunfig.toml:**
```toml
[run]
dev = "src/server.ts"
```

## Testing

### Manual Testing Checklist

#### Web UI
- [ ] Server starts on port 4173
- [ ] All 16 tasks load correctly
- [ ] Search filters tasks by substring
- [ ] "All" filter shows all tasks
- [ ] "Flagged" filter shows only flagged tasks
- [ ] Click flag icon to toggle flag
- [ ] Flags persist after page reload
- [ ] Task details render with proper formatting
- [ ] Responsive layout works on narrow screens

#### Terminal TUI
- [ ] TUI launches without errors
- [ ] All 16 tasks visible in left pane
- [ ] Arrow keys/j/k navigate correctly
- [ ] Enter selects task and shows details
- [ ] Press `f` to flag/unflag task
- [ ] Star appears next to flagged tasks
- [ ] Press `a` to show all tasks
- [ ] Press `Shift+F` to filter flagged
- [ ] Press `/` to open search box
- [ ] Search filters tasks correctly
- [ ] Press `q` to quit cleanly
- [ ] Flags persist to `~/.ica-task-flags`
- [ ] Relaunch restores flags correctly

#### tmux Integration
- [ ] `exam-env-tui.sh` creates 3-pane layout
- [ ] TUI appears in left pane
- [ ] Work shell appears in top-right
- [ ] Scoreboard appears in bottom-right
- [ ] F1/F2/F3 keys jump to correct panes
- [ ] F5 restarts scoreboard
- [ ] Mouse clicking switches panes
- [ ] Detach (Ctrl+b d) and reattach works

## Known Limitations

1. **Flag sync:** Web UI and TUI flags do not sync automatically
2. **Hot reload:** TUI requires restart to see task file changes (Web UI hot-reloads)
3. **Terminal compatibility:** TUI requires UTF-8 and 256-color terminal
4. **Markdown support:** Limited to bold, code, links, and bullet lists (no images, tables, etc.)
5. **Concurrency:** Multiple TUI instances can race when saving flags

## Future Enhancements

Possible improvements:
- [ ] Flag sync via file watching or shared backend
- [ ] Rich markdown rendering (tables, code blocks, images)
- [ ] Task completion tracking (separate from flags)
- [ ] Timer/stopwatch integration for exam simulation
- [ ] Export results to CSV/JSON
- [ ] Dark/light theme toggle for web UI
- [ ] Mobile app (React Native or PWA)
- [ ] Multi-user mode (shared progress on team labs)

## Deployment Notes

### On Vagrant VM

The scripts are designed to run inside the Vagrant VM at `/vagrant/apps/exam-ui`.

**First-time setup:**
```bash
vagrant ssh controlplane
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc
cd /vagrant/apps/exam-ui
bun install
```

**Make scripts executable (Linux):**
```bash
chmod +x /vagrant/scripts/tasks-viewer-tui.sh
chmod +x /vagrant/scripts/exam-env-tui.sh
```

**Launch TUI exam environment:**
```bash
sudo /vagrant/scripts/exam-env-tui.sh
```

### On Host Machine

**Web UI only:**
```bash
cd vagrant-ica-kubernetes/apps/exam-ui
bun install
bun run dev
```

Open <http://localhost:4173>

**Port forwarding from VM:**
```bash
vagrant ssh controlplane -- -L 4173:localhost:4173
# In VM:
cd /vagrant/apps/exam-ui
bun run dev
# On host: open http://localhost:4173
```

## Troubleshooting

### Common Issues

**Issue:** `bun: command not found`
**Solution:**
```bash
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc  # or restart terminal
```

**Issue:** `Cannot find module 'blessed'`
**Solution:**
```bash
cd apps/exam-ui
bun install
```

**Issue:** TUI displays garbled characters
**Solution:**
```bash
export TERM=xterm-256color
```

**Issue:** Port 4173 already in use
**Solution:**
```bash
PORT=8080 bun run dev
```

**Issue:** Tasks not loading
**Solution:**
- Verify `exam-tasks.md` exists
- Check `TASK_FILE` path
- Ensure `---TASK---` separators are present
- Look for parse errors in console

## Credits

- **Framework:** [Bun](https://bun.sh) - Fast all-in-one JavaScript runtime
- **TUI Library:** [blessed](https://github.com/chjj/blessed) - High-level terminal interface library
- **Inspired by:** tmux workflows, vim navigation, exam preparation tools

## License

Same as parent repository (see LICENSE.md in root).

