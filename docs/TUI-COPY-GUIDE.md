# TUI Text Copying Guide

## 🎯 All Copy Methods Available

### Method 1: Shift + Mouse (Easiest!)
1. **Hold Shift** while in the task detail pane
2. **Click and drag** to select text
3. **Release** - text is automatically copied to clipboard
4. **Paste** anywhere with Ctrl+V (or Ctrl+Shift+V in terminal)

### Method 2: Vi-Style Copy Mode (Power Users)
1. Press `Ctrl+b` then `[` to enter copy mode
2. Navigate with arrow keys or vim keys (h/j/k/l)
3. Press `v` to start visual selection
4. Move cursor to select text
5. Press `y` to yank (copy) - automatically copies to system clipboard
6. Press `Ctrl+b` then `]` to paste in tmux

### Method 3: Rectangle Selection
1. `Ctrl+b` then `[` to enter copy mode
2. Press `Ctrl+v` to toggle rectangle selection mode
3. Select a rectangular block of text
4. Press `y` to copy

---

## 📋 What Gets Copied

The TUI uses **system clipboard integration** with:
- `xclip` (Linux X11)
- `xsel` (Linux alternative)
- `pbcopy` (macOS)

If these aren't available, text is copied to **tmux buffer** (paste with `Ctrl+b ]`).

---

## 🎨 Example: How Task Text Appears in TUI

### Raw Task (exam-tasks.md):
```markdown
### Task 3 (9 pts) – Istio Gateway + VirtualService

Create (or update) `httpbin-gw` and `httpbin-vs` in `default` so that 
traffic for host `httpbin.com` via the Istio ingress gateway routes to 
`httpbin.default.svc.cluster.local:8000`.
```

### Rendered in TUI (with highlighting):

```
Task 03 (9 pts)              ★ FLAGGED
Istio Gateway + VirtualService

────────────────────────────────────────────────────────────

Create (or update) `httpbin-gw` and `httpbin-vs` in namespace 
default so that traffic for host httpbin.com via the Istio 
ingress gateway routes to httpbin.default.svc.cluster.local:8000.

Test the endpoint:

kubectl exec -n default deploy/curl -- curl -H "Host: httpbin.com" \
  http://istio-ingressgateway.istio-system.svc.cluster.local

Verify resources created:

kubectl get gateway -n default
kubectl get virtualservice -n default

────────────────────────────────────────────────────────────
Press 'f' to unflag | Press 's' for solution
💡 Copy: Shift+Mouse or Ctrl+b [ then v(select) y(copy)
```

### Color Coding:
- **Task 03** - White bold
- **(9 pts)** - Bright cyan
- **★ FLAGGED** - Yellow
- **Istio Gateway + VirtualService** - Cyan bold (subtitle)
- **`httpbin-gw`** - Green (resource name with dash)
- **`default`** - Magenta bold (namespace)
- **`httpbin.com`** - Bright green (hostname)
- **`8000`** - Bright yellow (port number)
- **`Gateway`** / **`VirtualService`** - Cyan bold (Kubernetes resource types)
- **kubectl** / **curl** - Bright blue bold (commands)
- Copy hint - Gray with yellow highlights

---

## 🎬 Full Example: Task with Solution

### When You Press 's' for Solution:

```
╭─ Solution ──────────────────────────────────────────────────╮
│                                                              │
│ Objective: Route external traffic to httpbin service        │
│                                                              │
│ Step 1: Apply Gateway and VirtualService                    │
│ kubectl apply -f /vagrant/manifests/task-03-12.yaml         │
│                                                              │
│ What this creates:                                           │
│   • Gateway httpbin-gw - Listens on port 80 for             │
│     host httpbin.com                                         │
│   • VirtualService httpbin-vs - Routes traffic to           │
│     httpbin.default.svc.cluster.local:8000                  │
│                                                              │
│ Step 2: Verify resources created                            │
│ kubectl get gateway -n default                               │
│ kubectl get virtualservice -n default                        │
│                                                              │
│ Step 3: Test the endpoint                                   │
│ kubectl exec -n default deploy/curl -- curl -H \             │
│   "Host: httpbin.com" \                                      │
│   http://istio-ingressgateway.istio-system.svc.cluster.local│
│                                                              │
│ Key concepts:                                                │
│   • Gateway defines entry point (ingress gateway)           │
│   • VirtualService defines routing rules                    │
│   • Host header must match for routing to work              │
│                                                              │
│ ──────────────────────────────────────────────────────────  │
│                                                              │
│ How to copy commands:                                        │
│ 1. Use tmux copy mode: Ctrl+b then [                        │
│ 2. Navigate with arrow keys                                 │
│ 3. Press Space to start selection                           │
│ 4. Move to end and press Enter to copy                      │
│ 5. Paste with Ctrl+b then ]                                 │
│                                                              │
│ Or view in file:                                             │
│ cat /vagrant/TASK-SOLUTIONS.txt                             │
│                                                              │
│ Press 'Esc' or 'q' to close | Use arrow keys to scroll      │
╰──────────────────────────────────────────────────────────────╯
```

---

## 🚀 Quick Reference Card

| Action | Keys |
|--------|------|
| **Select text** | `Shift + Mouse Drag` |
| **Copy mode** | `Ctrl+b [` |
| **Start select** | `v` (in copy mode) |
| **Copy text** | `y` (in copy mode) |
| **Paste** | `Ctrl+b ]` (tmux) or `Ctrl+V` (system) |
| **Rectangle select** | `Ctrl+v` (in copy mode) |
| **Exit copy mode** | `Esc` or `q` |

---

## 🛠️ Enhancements Implemented

### 1. Vi-Style Keybindings
```bash
# In exam-env-tui.sh
tmux set-window-option -t "$SESSION_NAME" mode-keys vi
tmux bind-key -T copy-mode-vi v send-keys -X begin-selection
tmux bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
```

### 2. System Clipboard Integration
```bash
# Automatic clipboard tool detection (xclip/xsel/pbcopy)
tmux bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -in -selection clipboard"
```

### 3. Mouse Drag to Clipboard
```bash
# Mouse selection automatically copies to system clipboard
tmux bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip"
```

### 4. Visual Copy Hints
```typescript
// Added to task detail footer in tui.ts
{gray-fg}💡 Copy: {yellow-fg}Shift+Mouse{/} or {yellow-fg}Ctrl+b [{/} then {yellow-fg}v{/}(select) {yellow-fg}y{/}(copy){/}
```

### 5. Updated Status Bar
```bash
# In exam-env-tui.sh
tmux set-option status-right "F1 tasks | F2 shell | F3 score | F5 restart | Shift+Mouse=copy"
```

---

## 💡 Pro Tips

1. **Copy kubectl commands directly**: Just select the command line and it copies with proper formatting
2. **Copy resource names**: Select just the resource name (e.g., `httpbin-gw`) without quotes
3. **Copy multi-line commands**: Use rectangle mode (`Ctrl+v` in copy mode) to grab command blocks
4. **Persistent clipboard**: Text copied with system clipboard tools persists outside tmux
5. **Quick paste in work terminal**: After copying, switch to F2 (shell pane) and paste immediately

---

## 🔍 Troubleshooting

**Q: Shift+Mouse doesn't work**
- A: Make sure you're holding Shift BEFORE clicking. Try mouse mode status: `tmux show -g mouse`

**Q: Text copies but won't paste outside tmux**
- A: Install clipboard tool in VM: `sudo apt-get install xclip` or `xsel`

**Q: Vi mode keys don't work**
- A: Verify mode-keys setting: `tmux show-window-options -g mode-keys` should show `vi`

**Q: Want to copy to Windows clipboard from VM?**
- A: In your SSH client (PuTTY/MobaXterm), enable clipboard integration, then Shift+Mouse will copy to Windows clipboard automatically

