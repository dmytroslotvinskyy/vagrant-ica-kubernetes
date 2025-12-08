# Interface Comparison Guide

Quick comparison to help you choose between Web UI and Terminal TUI.

## Side-by-Side Feature Matrix

| Feature | Web UI | Terminal TUI |
|---------|--------|--------------|
| **Platform** | Browser (any device) | Terminal (VM/Linux) |
| **Framework** | Vanilla JavaScript | Bun + blessed |
| **Task rendering** | HTML with CSS | Terminal box drawing |
| **Navigation** | Mouse + keyboard | Keyboard only |
| **Search** | Live filtering | Modal search box |
| **Flag storage** | localStorage | File (`~/.ica-task-flags`) |
| **Flag sync** | Per-browser | Per-user (file-based) |
| **Responsive** | Yes (mobile-friendly) | Terminal size dependent |
| **Hot reload** | Yes (file watching) | Manual restart needed |
| **Offline mode** | Yes (after initial load) | Yes (reads file directly) |
| **Multi-user** | No (localStorage per browser) | Yes (shared file) |
| **Accessibility** | Screen reader support | Terminal reader support |
| **Copy/paste** | Native browser support | Terminal dependent |
| **Themes** | Dark (hardcoded) | Terminal theme |
| **Dependencies** | None (vanilla JS) | blessed library |
| **Resource usage** | Low (static files) | Low (native app) |
| **Port requirement** | Yes (4173) | No |

## Visual Comparison

### Web UI Layout

```
┌──────────────────────────────────────────────────────────────┐
│  ICA Istio Lab                                  [16 tasks]    │
│  Task Navigator                                               │
│                                                               │
│  [Search tasks...                                        ]    │
│  [All] [Flagged]                                              │
│                                                               │
│  ┌─ Tasks ──────────┐  ┌─ Task Details ──────────────────┐  │
│  │ ★ 1 Task 1 (7)   │  │ Task 5                           │  │
│  │                  │  │ Payments weighted routing         │  │
│  │ 2 Task 2 (5)     │  │ [9 pts] [Flag task]              │  │
│  │                  │  │                                   │  │
│  │ ⯈ 5 Task 5 (9)   │◀▶│ In namespace payments, create    │  │
│  │                  │  │ DestinationRule payments-dr...   │  │
│  │ 6 Task 6 (7)     │  │                                   │  │
│  │                  │  │ • Create DestinationRule         │  │
│  │ ...              │  │ • Define subsets v1 and v2       │  │
│  └──────────────────┘  └──────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

**Characteristics:**
- Clean, modern dark theme
- Smooth scrolling
- Hover effects and animations
- Gradient backgrounds
- Icon-based interactions (★ for flags)

### Terminal TUI Layout

```
┌────────────────────────────────────────────────────────────┐
│            ICA Istio Lab - Task Navigator                  │
├────────────────────┬───────────────────────────────────────┤
│ Tasks              │ Task Details                          │
│┌──────────────────┐│┌─────────────────────────────────────┐│
││ ★ Task 1 (7pts)  │││ Payments weighted routing           ││
││    Install Ist.. │││ Task 5 • 9pts ★ FLAGGED             ││
││                  │││                                     ││
││ Task 2 (5pts)    │││─────────────────────────────────────││
││    Enable defa.. │││                                     ││
││                  │││ In namespace payments, create       ││
││⯈Task 5 (9pts)    ││◀ DestinationRule payments-dr with   ││
││    Payments we.. │││ subsets v1/v2 and a VirtualService  ││
││                  │││ payments-vs that splits / traffic:  ││
││ Task 6 (7pts)    │││                                     ││
││    Header-base.. │││   • 70% to subset v1                ││
││                  │││   • 30% to subset v2                ││
││ ...              │││                                     ││
│└──────────────────┘│└─────────────────────────────────────┘│
├────────────────────┴───────────────────────────────────────┤
│ Mode: All | Tasks: 16/16 | Flagged: 3                      │
├─────────────────────────────────────────────────────────────┤
│ [↑/↓/j/k] Navigate | [f] Flag | [q] Quit                   │
└─────────────────────────────────────────────────────────────┘
```

**Characteristics:**
- ASCII box drawing characters
- Keyboard-driven navigation
- Status bar with live stats
- Vim-inspired keybindings
- Minimal resource usage

## Use Case Recommendations

### Choose Web UI when:
✅ Working from host machine while VM runs in background  
✅ Need to reference tasks on mobile/tablet  
✅ Prefer mouse-based navigation  
✅ Want rich visual styling and animations  
✅ Multiple team members need to view tasks (share URL)  
✅ Working on Windows host without SSH

### Choose Terminal TUI when:
✅ Working entirely within the VM terminal  
✅ Already using tmux for session management  
✅ Prefer keyboard-only workflows  
✅ Want minimal resource overhead  
✅ Need flag sync across terminal sessions  
✅ Following vim/terminal-based workflows  
✅ Simulating exam conditions (terminal-only)

## Workflow Examples

### Web UI Workflow

**Scenario:** Working from host machine, want tasks visible on second monitor

```bash
# On host machine
cd vagrant-ica-kubernetes/apps/exam-ui
bun install
bun run dev

# Open http://localhost:4173 in browser
# Drag window to second monitor
# Keep task list visible while working in IDE
```

**Or with VM:**
```bash
# On host
vagrant ssh controlplane -- -L 4173:localhost:4173

# In VM session
cd /vagrant/apps/exam-ui
bun run dev

# On host browser: http://localhost:4173
```

### Terminal TUI Workflow

**Scenario:** Full terminal-based exam simulation

```bash
# SSH into VM
vagrant ssh controlplane

# Launch exam environment
sudo /vagrant/scripts/exam-env-tui.sh

# Now you have:
# F1 - Task navigator (TUI)
# F2 - Work shell for kubectl, istioctl, etc.
# F3 - Live scoreboard

# Work through tasks without leaving terminal
# Press F1 to check task requirements
# Press F2 to run commands
# Press F3 to see current score
# Press F5 to refresh score
```

## Keyboard Shortcut Comparison

| Action | Web UI | Terminal TUI |
|--------|--------|--------------|
| Navigate up | `↑` or scroll | `↑` or `k` |
| Navigate down | `↓` or scroll | `↓` or `j` |
| Select task | Click | `Enter` |
| Flag task | Click star icon | `f` |
| Search | Type in search box | `/` then type |
| Show all | Click "All" button | `a` |
| Show flagged | Click "Flagged" button | `Shift+F` |
| Scroll detail | Mouse wheel | `PageUp`/`PageDown` |
| Clear search | Click X or clear text | `Esc` in search |
| Quit/Close | Close tab | `q` or `Esc` |

## Performance Characteristics

### Web UI

**Startup time:** ~500ms (server + page load)  
**Memory usage:** ~20MB (Bun server) + browser memory  
**CPU usage:** Minimal (idle), <5% during navigation  
**Network:** Requires port 4173 open  
**Latency:** Depends on network (local: <10ms, remote: 50-500ms)

### Terminal TUI

**Startup time:** ~200ms (Bun + blessed init)  
**Memory usage:** ~30MB (Bun process)  
**CPU usage:** Minimal (idle), <2% during navigation  
**Network:** None required  
**Latency:** Near-zero (native terminal rendering)

## Storage & Persistence

### Web UI

**Flag storage:** Browser localStorage  
**Location:** Browser profile directory  
**Scope:** Per-browser, per-origin  
**Capacity:** ~5-10MB (plenty for flags)  
**Backup:** None (cleared if browser cache cleared)

**Example data:**
```json
{
  "icaTaskFlags": "[\"1\",\"5\",\"12\"]"
}
```

### Terminal TUI

**Flag storage:** Plain text file  
**Location:** `~/.ica-task-flags`  
**Scope:** Per-user account  
**Capacity:** Unlimited (practical limit: thousands of task IDs)  
**Backup:** Standard file backup tools

**Example file:**
```
1
5
12
```

## Customization Options

### Web UI

**Theme:** Edit `public/style.css`
- Change colors: `:root` CSS variables
- Adjust layout: Grid/flex properties
- Fonts: `font-family` declarations

**Behavior:** Edit `public/app.js`
- Search algorithm: `applyFilters()` function
- Storage key: `localStorage.setItem("icaTaskFlags", ...)`

### Terminal TUI

**Colors:** Terminal theme + blessed style objects
- Edit `src/tui.ts` style properties
- Use terminal's color scheme settings

**Keybindings:** Edit `src/tui.ts`
- Add/change: `screen.key([...], handler)`
- Example: `screen.key(["h"], () => showHelp())`

**Layout:** Edit blessed widget configurations
- Adjust `width`, `height` properties
- Change split percentages

## Integration with Exam Workflow

### Web UI Integration

**Typical setup:**
1. Run web server on VM or host
2. Open browser to task list
3. SSH into VM in separate terminal/IDE
4. Reference tasks in browser while working

**Best for:**
- Exam preparation with notes
- Team study sessions (screenshare)
- Long study sessions (minimize tmux switching)

### Terminal TUI Integration

**Typical setup:**
1. SSH into VM
2. Run `exam-env-tui.sh` for 3-pane layout
3. All work in single terminal window
4. Use tmux panes and F-keys for navigation

**Best for:**
- Exam simulation (terminal-only environment)
- Tmux power users
- Low-latency workflows
- Screen recording demos

## Troubleshooting Quick Reference

| Issue | Web UI Solution | TUI Solution |
|-------|----------------|--------------|
| Port in use | `PORT=8080 bun run dev` | N/A (no port needed) |
| Can't connect | Check port forwarding | N/A |
| Garbled display | Check browser compatibility | `export TERM=xterm-256color` |
| Flags not saving | Check localStorage quota | Check file permissions on `~/.ica-task-flags` |
| Slow rendering | Check network latency | Check terminal emulator performance |
| Tasks not loading | Check `/api/tasks` endpoint | Check `TASK_FILE` path |
| Search not working | Check JavaScript console | Check blessed input handling |

## Migration Between Interfaces

### Exporting Flags from Web UI

1. Open browser console (F12)
2. Run:
   ```javascript
   const flags = JSON.parse(localStorage.getItem("icaTaskFlags") || "[]");
   console.log(flags.join("\n"));
   ```
3. Copy output to `~/.ica-task-flags`

### Importing Flags to Web UI

1. Read file:
   ```bash
   cat ~/.ica-task-flags
   ```
2. Open browser console
3. Run:
   ```javascript
   const flags = ["1", "5", "12"];  // Replace with your flags
   localStorage.setItem("icaTaskFlags", JSON.stringify(flags));
   location.reload();
   ```

## Conclusion

Both interfaces are powerful and well-suited for different workflows:

- **Web UI** excels at visual presentation, ease of use, and cross-device access
- **Terminal TUI** excels at speed, integration with tmux, and terminal-based workflows

Choose based on your personal preferences and exam preparation style. Many users find value in using **both**:
- TUI during focused practice sessions in tmux
- Web UI for reviewing tasks during planning or on mobile

Both interfaces share the same task parser and will always show identical task content, ensuring consistency regardless of which you choose.

Happy studying! 🚀

