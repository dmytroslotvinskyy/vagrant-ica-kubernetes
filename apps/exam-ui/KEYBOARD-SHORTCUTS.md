# Keyboard Shortcuts Reference

Quick reference card for both Web UI and Terminal TUI keyboard shortcuts.

## Terminal TUI Shortcuts

### Navigation
| Key | Action |
|-----|--------|
| `↑` or `k` | Move up in task list |
| `↓` or `j` | Move down in task list |
| `Enter` | Select highlighted task |
| `PageUp` | Scroll task details up |
| `PageDown` | Scroll task details down |
| `Home` | Jump to first task |
| `End` | Jump to last task |

### Task Management
| Key | Action |
|-----|--------|
| `f` | Toggle flag on current task |
| `a` | Show all tasks (clear filter) |
| `Shift+F` | Show only flagged tasks |

### Search & Filter
| Key | Action |
|-----|--------|
| `/` | Open search box |
| `Enter` (in search) | Apply search and close box |
| `Esc` (in search) | Cancel search and close box |

### General
| Key | Action |
|-----|--------|
| `q` | Quit TUI |
| `Esc` | Quit TUI (alternative) |
| `Ctrl+C` | Force quit |
| `Ctrl+L` | Redraw screen |

## Web UI Shortcuts

### Navigation
| Key | Action |
|-----|--------|
| `↑` | Scroll up in task list |
| `↓` | Scroll down in task list |
| `Tab` | Navigate between UI elements |
| `Shift+Tab` | Navigate backwards |
| Mouse wheel | Scroll task list or details |

### Task Management
| Key | Action |
|-----|--------|
| Click star icon | Toggle flag on task |
| Click task item | Select and view task |
| Click "All" button | Show all tasks |
| Click "Flagged" button | Show only flagged tasks |

### Search
| Key | Action |
|-----|--------|
| Type in search box | Filter tasks in real-time |
| `Esc` | Clear search box |
| `Ctrl+A` | Select all text in search |

### Browser
| Key | Action |
|-----|--------|
| `Ctrl+R` | Reload page |
| `F5` | Reload page |
| `Ctrl+W` | Close tab |
| `F12` | Open developer tools |

## tmux Environment Shortcuts

When using `exam-env-tui.sh` or `exam-env.sh`:

### Pane Navigation
| Key | Action |
|-----|--------|
| `F1` | Jump to task navigator pane (left) |
| `F2` | Jump to work shell pane (top-right) |
| `F3` | Jump to scoreboard pane (bottom-right) |
| `F5` | Restart scoreboard refresh |
| `Ctrl+b` then `↑/↓/←/→` | Navigate between panes |
| `Ctrl+b` then `o` | Cycle through panes |
| `Ctrl+b` then `q` | Show pane numbers |

### Session Management
| Key | Action |
|-----|--------|
| `Ctrl+b` then `d` | Detach from session |
| `Ctrl+b` then `[` | Enter copy mode (scroll) |
| `Ctrl+b` then `]` | Paste from buffer |
| `Ctrl+b` then `z` | Zoom current pane (toggle) |

### Window Management
| Key | Action |
|-----|--------|
| `Ctrl+b` then `c` | Create new window |
| `Ctrl+b` then `n` | Next window |
| `Ctrl+b` then `p` | Previous window |
| `Ctrl+b` then `&` | Kill current window |

## Quick Reference Cards

### Terminal TUI - Minimal Card

```
┌─────────────────────────────────┐
│   ICA Task Navigator - TUI      │
├─────────────────────────────────┤
│ j/k or ↑/↓  Navigate            │
│ Enter       Select task         │
│ f           Toggle flag         │
│ /           Search              │
│ a           Show all            │
│ Shift+F     Show flagged        │
│ q or Esc    Quit                │
└─────────────────────────────────┘
```

### tmux Exam Environment - Minimal Card

```
┌─────────────────────────────────┐
│   Exam Environment - tmux       │
├─────────────────────────────────┤
│ F1          Task navigator      │
│ F2          Work shell          │
│ F3          Scoreboard          │
│ F5          Restart scoreboard  │
│ Ctrl+b d    Detach session      │
└─────────────────────────────────┘
```

## Vim-Style Navigation Comparison

For vim users, the TUI navigation will feel familiar:

| vim | TUI | Action |
|-----|-----|--------|
| `j` | `j` or `↓` | Down |
| `k` | `k` or `↑` | Up |
| `gg` | `Home` | First item |
| `G` | `End` | Last item |
| `/pattern` | `/` then type | Search |
| `n` | (auto-filter) | Next match |
| `:q` | `q` | Quit |
| `Ctrl+d` | `PageDown` | Scroll down |
| `Ctrl+u` | `PageUp` | Scroll up |

## Mouse Support

### Terminal TUI (when tmux mouse mode enabled)

| Action | Result |
|--------|--------|
| Click task item | Select task |
| Scroll wheel | Navigate task list |
| Click pane | Focus pane |
| Drag pane border | Resize pane |

Enable mouse mode in tmux:
```bash
tmux set-option mouse on
```

### Web UI (always enabled)

| Action | Result |
|--------|--------|
| Click task item | Select task |
| Click star icon | Toggle flag |
| Click filter button | Change filter |
| Scroll wheel | Scroll list/details |
| Click search box | Focus search |

## Accessibility Shortcuts

### Screen Reader Support (Web UI)

| Key | Action |
|-----|--------|
| `Tab` | Navigate to next element |
| `Shift+Tab` | Navigate to previous element |
| `Enter` or `Space` | Activate button/link |
| `Esc` | Close modal/dialog |

ARIA labels are provided for all interactive elements.

### Terminal Reader Support (TUI)

The TUI uses plain text rendering compatible with terminal screen readers like:
- `screen-reader` (Linux)
- `JAWS` (Windows with WSL)
- `NVDA` (Windows with WSL)

## Custom Keybindings

### Terminal TUI

Edit `src/tui.ts` to customize:

```typescript
// Add custom keybinding
screen.key(["h"], () => {
  // Show help screen
  showHelp();
});

// Change existing keybinding
screen.key(["space"], () => {
  toggleFlag();  // Use spacebar instead of 'f'
});
```

### tmux Environment

Edit `scripts/exam-env-tui.sh` to customize:

```bash
# Change F-key bindings
tmux bind-key -n F6 respawn-pane -k -t "$SCOREBOARD_PANE"
tmux bind-key -n F7 select-pane -t "${SESSION_NAME}:0.0"
```

## Cheat Sheet for Printing

```
╔═══════════════════════════════════════════════════════════╗
║           ICA Istio Lab - Keyboard Shortcuts              ║
╠═══════════════════════════════════════════════════════════╣
║ TERMINAL TUI                                              ║
║ ─────────────────────────────────────────────────────────║
║  j/k or ↑/↓     Navigate tasks                           ║
║  Enter          Select task                               ║
║  f              Toggle flag                               ║
║  /              Search tasks                              ║
║  a              Show all tasks                            ║
║  Shift+F        Show flagged only                         ║
║  PageUp/Down    Scroll details                            ║
║  q or Esc       Quit                                      ║
║                                                            ║
║ TMUX ENVIRONMENT                                          ║
║ ─────────────────────────────────────────────────────────║
║  F1             Jump to task navigator                    ║
║  F2             Jump to work shell                        ║
║  F3             Jump to scoreboard                        ║
║  F5             Restart scoreboard                        ║
║  Ctrl+b d       Detach from session                       ║
║  Ctrl+b z       Zoom current pane                         ║
║                                                            ║
║ WEB UI                                                    ║
║ ─────────────────────────────────────────────────────────║
║  Click task     Select task                               ║
║  Click ★        Toggle flag                               ║
║  Type in box    Search tasks                              ║
║  Click All      Show all tasks                            ║
║  Click Flagged  Show flagged only                         ║
║  Mouse wheel    Scroll                                    ║
╚═══════════════════════════════════════════════════════════╝

Reconnect to tmux session: tmux attach -t exam
Launch TUI standalone:     bun run tui
Launch Web UI:             bun run dev (http://localhost:4173)
```

## Tips & Tricks

### Terminal TUI

1. **Fast navigation:** Use `j`/`k` for single steps, `PageUp`/`PageDown` for large jumps
2. **Quick flagging:** Navigate to task and press `f` immediately (no confirmation needed)
3. **Search tips:** Search is case-insensitive and matches both title and body
4. **Clear filter:** Press `a` to quickly return to "all tasks" view
5. **Quit quickly:** `q` or `Esc` work from anywhere (no need to unfocus)

### Web UI

1. **Fast filtering:** Type in search box for instant filtering (no Enter needed)
2. **Keyboard navigation:** Use `Tab` to navigate without mouse
3. **Flag from list:** Click star in task list (no need to open task first)
4. **Responsive layout:** Resize browser to see mobile layout
5. **Refresh tasks:** Press `Ctrl+R` to reload if tasks file updated

### tmux Environment

1. **Quick pane switching:** Use F1/F2/F3 instead of `Ctrl+b` arrow keys
2. **Zoom for focus:** `Ctrl+b z` to maximize current pane, repeat to restore
3. **Copy mode:** `Ctrl+b [` to scroll back and copy text
4. **Detach safely:** Always use `Ctrl+b d` instead of closing terminal
5. **Restart scoreboard:** Press `F5` after completing tasks to see updated score

## Conflicts & Troubleshooting

### Terminal Emulator Conflicts

Some terminal emulators intercept certain keys:

| Terminal | Conflict | Solution |
|----------|----------|----------|
| iTerm2 | `Ctrl+Arrow` | Disable in Preferences → Keys |
| GNOME Terminal | `F10` | Disable menu bar shortcut |
| Windows Terminal | `Ctrl+Shift+F` | Remap in settings |
| tmux | `Ctrl+b` | Use F-keys instead |

### SSH Conflicts

When using SSH, some keys may not work:

| Key | Issue | Solution |
|-----|-------|----------|
| `F1-F12` | Not forwarded | Use `Ctrl+b` alternatives |
| `PageUp/Down` | Captured by terminal | Use `Ctrl+d`/`Ctrl+u` |
| Mouse | Not forwarded | Enable X11 forwarding |

### Browser Conflicts

Some browser extensions intercept shortcuts:

| Extension | Conflict | Solution |
|-----------|----------|----------|
| Vimium | `j/k` navigation | Disable on localhost |
| LastPass | `Ctrl+Shift+L` | No conflict (not used) |
| Tab Manager | `Ctrl+W` | No conflict (standard) |

## Learning Resources

- **vim tutorial:** `vimtutor` (for vim-style navigation)
- **tmux tutorial:** `man tmux` or https://tmuxcheatsheet.com
- **blessed docs:** https://github.com/chjj/blessed
- **Bun docs:** https://bun.sh/docs

## Feedback

If you have suggestions for additional shortcuts or improvements to the navigation:
1. Open an issue on the repository
2. Describe your use case and proposed shortcut
3. Consider contributing a pull request

---

*Print this page for quick reference during exam preparation!*

