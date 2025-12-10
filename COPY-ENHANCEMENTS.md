# TUI Copy Functionality - Complete Implementation

## ✅ All Enhancements Completed

### 1. Vi-Style Copy Mode Keybindings
**File:** `scripts/exam-env-tui.sh`

Added full vi-mode navigation for power users:
```bash
tmux set-window-option -t "$SESSION_NAME" mode-keys vi
tmux bind-key -T copy-mode-vi v send-keys -X begin-selection
tmux bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
tmux bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
```

**Usage:**
- `Ctrl+b [` → Enter copy mode
- `v` → Start visual selection (like Vim)
- `y` → Yank (copy) and exit
- `Ctrl+v` → Rectangle selection mode

---

### 2. System Clipboard Integration
**File:** `scripts/exam-env-tui.sh`

Automatic clipboard tool detection with fallbacks:
```bash
# Detects and uses: xclip (X11) → xsel (X11 alt) → pbcopy (macOS)
if command -v xclip >/dev/null 2>&1; then
  tmux bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -in -selection clipboard"
elif command -v xsel >/dev/null 2>&1; then
  tmux bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xsel --clipboard --input"
elif command -v pbcopy >/dev/null 2>&1; then
  tmux bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"
fi
```

**Benefits:**
- ✅ Copy inside tmux pane
- ✅ Paste anywhere in the system (other terminals, browsers, editors)
- ✅ Works across SSH if client supports clipboard forwarding

---

### 3. Mouse Drag to Clipboard
**File:** `scripts/exam-env-tui.sh`

Mouse selection automatically copies to system clipboard:
```bash
if command -v xclip >/dev/null 2>&1; then
  tmux bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -in -selection clipboard"
fi
```

**Usage:**
- Hold `Shift` + Drag mouse to select text
- Release → Automatically copied to clipboard
- Paste anywhere with `Ctrl+V` or `Ctrl+Shift+V`

---

### 4. Visual Copy Instructions in TUI
**File:** `apps/exam-ui/src/tui.ts`

Added prominent copy hint in task detail footer:
```typescript
{gray-fg}💡 Copy: {yellow-fg}Shift+Mouse{/} or {yellow-fg}Ctrl+b [{/} then {yellow-fg}v{/}(select) {yellow-fg}y{/}(copy){/}
```

**Where it appears:**
- Bottom of every task detail pane
- Always visible while reading tasks
- Color-coded for easy scanning

---

### 5. Enhanced tmux Status Bar
**File:** `scripts/exam-env-tui.sh`

Updated status bar to show copy method:
```bash
tmux set-option -t "$SESSION_NAME" status-right "F1 tasks | F2 shell | F3 score | F5 restart | Shift+Mouse=copy"
```

**Visible at:** Bottom-right of tmux window at all times

---

### 6. Improved Startup Message
**File:** `scripts/exam-env-tui.sh`

Added copy instructions to welcome message:
```bash
tmux display-message "[exam-env] Copy: Shift+Mouse or Ctrl+b [ then v/y | TUI: j/k/f/F// | Panes: F1-F3"
```

**Shows:** When launching the exam environment, provides quick reference

---

## 📊 Copy Methods Summary

| Method | Keys | Clipboard | Difficulty | Best For |
|--------|------|-----------|------------|----------|
| **Shift+Mouse** | Hold Shift + Drag | System | ⭐ Easy | Quick single-line copy |
| **Vi Copy Mode** | `Ctrl+b [` → `v` → `y` | System | ⭐⭐ Medium | Multi-line blocks |
| **Rectangle Mode** | `Ctrl+b [` → `Ctrl+v` → `y` | System | ⭐⭐⭐ Advanced | Column selection |
| **Tmux Buffer** | `Ctrl+b [` → select → `Enter` | Tmux only | ⭐⭐ Medium | Fallback if no system clipboard |

---

## 🎯 Real-World Examples

### Example 1: Copy a kubectl command
**Scenario:** You need to run `kubectl get gateway -n default`

**Method A - Shift+Mouse:**
1. Hold `Shift`
2. Click before "kubectl", drag to end of line
3. Release → Copied!
4. Press `F2` to switch to work terminal
5. `Ctrl+Shift+V` to paste

**Method B - Vi Mode:**
1. `Ctrl+b [` to enter copy mode
2. Navigate to the line with arrow keys
3. `v` to start selection
4. `$` to go to end of line (or use arrow keys)
5. `y` to yank → Copied!
6. `F2` to work terminal
7. `Ctrl+Shift+V` to paste

---

### Example 2: Copy multi-line YAML
**Scenario:** Copy an entire Gateway manifest from task details

**Best Method - Vi Rectangle Mode:**
```
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: httpbin-gw
  namespace: default
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - httpbin.com
EOF
```

**Steps:**
1. `Ctrl+b [` to enter copy mode
2. Navigate to "kubectl apply" line
3. `v` to start visual selection
4. Press `j` repeatedly to select all lines down to "EOF"
5. `y` to yank → Entire block copied!
6. Switch to work terminal and paste

---

### Example 3: Copy just a resource name
**Scenario:** Need to copy "httpbin-gw" without the backticks

**Method - Shift+Mouse:**
1. Hold `Shift`
2. Select just: `httpbin-gw` (between the backticks)
3. Release → Copied as plain text
4. Paste in your command

---

## 🔧 Technical Implementation Details

### Clipboard Tool Priority
1. **xclip** (most common on Linux X11)
   - Package: `sudo apt-get install xclip`
   - Command: `xclip -in -selection clipboard`

2. **xsel** (alternative for X11)
   - Package: `sudo apt-get install xsel`
   - Command: `xsel --clipboard --input`

3. **pbcopy** (macOS native)
   - Built-in on macOS
   - Command: `pbcopy`

4. **Fallback: tmux buffer**
   - Always available
   - Paste with `Ctrl+b ]`
   - Not shared with system clipboard

### SSH Clipboard Forwarding
For copying from VM to host Windows clipboard:

**PuTTY:**
- Default: Shift+Mouse copies to Windows clipboard ✅

**MobaXterm:**
- Settings → Configuration → Terminal → Enable "Paste using right-click"
- Shift+Mouse selection auto-copies ✅

**Windows Terminal (WSL):**
- Auto-forwards clipboard via interop ✅

**VSCode Remote SSH:**
- Clipboard forwarding enabled by default ✅

---

## 🎨 Syntax Highlighting for Easy Copying

The TUI applies smart highlighting to help identify what to copy:

| Element | Color | Example |
|---------|-------|---------|
| Commands | Bright Blue Bold | `kubectl`, `istioctl`, `curl` |
| Namespaces | Magenta Bold | `default`, `istio-system` |
| Resource Types | Cyan Bold | `Gateway`, `VirtualService` |
| Resource Names | Green | `httpbin-gw`, `httpbin-vs` |
| Hostnames | Bright Green | `httpbin.com` |
| Port Numbers | Bright Yellow | `8000`, `80` |
| Steps | Cyan | `1.`, `2.`, `3.` |

**Benefit:** Your eye immediately finds what needs to be copied!

---

## 📚 Documentation Files Created

1. **`docs/TUI-COPY-GUIDE.md`** - Complete copy methods guide
2. **`docs/TUI-SCREENSHOT-EXAMPLE.txt`** - ASCII visual example of TUI layout
3. **`COPY-ENHANCEMENTS.md`** (this file) - Implementation summary

---

## ✨ Before vs After

### Before (Original):
- ❌ No vi-mode keybindings
- ❌ No system clipboard integration
- ❌ No visual copy hints
- ❌ Mouse copy to tmux buffer only
- ❌ No copy instructions in UI

### After (v1 Complete):
- ✅ Full vi-mode copy mode (`v`, `y`, `Ctrl+v`)
- ✅ Automatic system clipboard (xclip/xsel/pbcopy)
- ✅ Mouse drag copies to system clipboard
- ✅ Visual copy hint in every task
- ✅ Status bar shows copy method
- ✅ Startup message with copy instructions
- ✅ Complete documentation

---

## 🚀 Testing the Copy Functionality

**Inside the VM:**

```bash
# 1. Launch exam TUI
vagrant ssh controlplane
sudo /vagrant/scripts/exam-tui-bun.sh

# 2. In the TUI (F1 pane):
#    - Navigate to any task
#    - Hold Shift and select a kubectl command
#    - Release mouse

# 3. Switch to work terminal (F2)
# 4. Paste with Ctrl+Shift+V
# 5. Verify command was copied correctly

# 6. Test vi-mode:
#    - In F1 pane, press Ctrl+b [
#    - Navigate with arrows
#    - Press 'v' to start selection
#    - Select text with arrows
#    - Press 'y' to copy
#    - Switch to F2
#    - Paste with Ctrl+Shift+V
```

---

## 💡 Pro Tips

1. **Fast workflow:** Read task (F1) → Copy → Switch (F2) → Paste → Run
2. **Compare commands:** Copy from solution (press `s`) and compare with task description
3. **Build manifests:** Copy YAML snippets and combine in your editor
4. **Verify resources:** Copy resource names for quick kubectl describe/get commands
5. **Reuse commands:** Copy once, paste multiple times with modifications

---

## 🎓 For Exam Simulation

This copy functionality mimics the real ICA exam where you can:
- ✅ Copy from question panel
- ✅ Paste into work terminal
- ✅ Copy from provided documentation
- ✅ Use multiple terminals

**Practice with the same tools you'll use in the actual exam!**

