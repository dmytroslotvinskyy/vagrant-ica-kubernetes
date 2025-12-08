# Troubleshooting Guide

Common issues and solutions for the ICA Task Navigator.

## Task File Not Found

### Symptom
```
Failed to read /vagrant/apps/exam-tasks.md: Error: ENOENT: no such file or directory
```

or

```
Could not load tasks
Error • ?pts
```

### Cause
The TUI is looking for the task file in the wrong location. This typically happens when:
1. Running from a copied directory (e.g., `/tmp/exam-ui`)
2. Relative path resolution fails
3. The `TASK_FILE` environment variable is not set

### Solution

The TUI now automatically searches multiple locations:
1. `$TASK_FILE` (if environment variable is set)
2. `/vagrant/exam-tasks.md` (absolute path)
3. `../../exam-tasks.md` (relative from src/tui.ts)
4. `./exam-tasks.md` (current directory)

**Quick fix:** Set the environment variable explicitly:
```bash
export TASK_FILE=/vagrant/exam-tasks.md
bun run tui
```

**For the wrapper script:** The `exam-tui-bun.sh` script now sets this automatically.

## Bun Command Not Found

### Symptom
```
-bash: bun: command not found
```

### Cause
Bun is installed for root user (`/root/.bun/bin/bun`) but not in the current user's PATH.

### Solution

**Option 1: Use root's Bun install**
```bash
export PATH="/root/.bun/bin:$PATH"
echo 'export PATH="/root/.bun/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**Option 2: Install Bun for current user**
```bash
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc
```

## CIFS/SMB Symlink Errors

### Symptom
```
error: ENOSYS: function not implemented, symlink
```

or

```
error: Failed to create symlink in node_modules
```

### Cause
VirtualBox shared folders (CIFS/SMB) don't support symlinks by default.

### Solution

Use the `BUN_INSTALL=copyfile` flag:
```bash
BUN_INSTALL=copyfile bun install
```

This copies files instead of symlinking them.

**The wrapper scripts already do this automatically.**

## TUI Displays Garbled Characters

### Symptom
- Boxes don't line up
- Unicode characters show as question marks
- Colors don't work

### Cause
Terminal doesn't support UTF-8 or 256 colors.

### Solution

```bash
export TERM=xterm-256color
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
```

Add to `~/.bashrc` to make permanent:
```bash
echo 'export TERM=xterm-256color' >> ~/.bashrc
source ~/.bashrc
```

## tmux Session Already Exists

### Symptom
```
[exam-env] Session 'exam' already running. Attaching...
```

Then immediately exits.

### Cause
Previous session is still running.

### Solution

**Option 1: Attach to existing session**
```bash
tmux attach -t exam
```

**Option 2: Kill and recreate**
```bash
tmux kill-session -t exam
sudo /vagrant/scripts/exam-tui-bun.sh
```

**Option 3: Use different session name**
```bash
SESSION_NAME=exam2 /vagrant/scripts/exam-env-tui.sh
```

## Flags Not Saving

### Symptom
Flags disappear after restarting the TUI.

### Cause
1. Permission issue with `~/.ica-task-flags`
2. Running as different user
3. File gets deleted/cleared

### Solution

**Check file permissions:**
```bash
ls -la ~/.ica-task-flags
```

**Manually create with proper permissions:**
```bash
touch ~/.ica-task-flags
chmod 644 ~/.ica-task-flags
```

**Verify flag storage:**
```bash
cat ~/.ica-task-flags
# Should show task IDs, one per line:
# 1
# 5
# 12
```

## Port 4173 Already in Use (Web UI)

### Symptom
```
error: Failed to start server: EADDRINUSE: address already in use :::4173
```

### Cause
Another process is using port 4173.

### Solution

**Option 1: Use different port**
```bash
PORT=8080 bun run dev
```

**Option 2: Find and kill the process**
```bash
lsof -ti:4173 | xargs kill
# or
sudo netstat -tlnp | grep 4173
# Then: sudo kill <PID>
```

## Cannot Read exam-tasks.md (Permission Denied)

### Symptom
```
Failed to read /vagrant/exam-tasks.md: Error: EACCES: permission denied
```

### Cause
File permissions are too restrictive.

### Solution

```bash
# Make readable by all users
sudo chmod 644 /vagrant/exam-tasks.md

# Or make entire vagrant directory readable
sudo chmod -R a+r /vagrant
```

## Slow Performance / High CPU

### Symptom
- TUI feels sluggish
- Keyboard input is delayed
- CPU usage is high

### Cause
1. Scoreboard refreshing too frequently
2. Terminal emulator performance issues
3. VM resource constraints

### Solution

**Increase scoreboard interval:**
```bash
SCOREBOARD_INTERVAL=300 /vagrant/scripts/exam-tui-bun.sh  # 5 minutes
```

**Or disable scoreboard pane:**
Edit `exam-env-tui.sh` and comment out the scoreboard split:
```bash
# tmux split-window -v -t "${SESSION_NAME}:0.1" "..."
```

**Check VM resources:**
```bash
free -h          # Check memory
top              # Check CPU usage
df -h            # Check disk space
```

## Dependencies Installation Fails

### Symptom
```
error: Failed to install blessed@0.1.81
```

### Cause
1. Network issues
2. NPM registry down
3. Corrupted cache

### Solution

**Clear cache and retry:**
```bash
rm -rf ~/.bun-cache
rm -rf node_modules
BUN_INSTALL=copyfile bun install
```

**Use specific registry:**
```bash
bun install --registry https://registry.npmjs.org/
```

## Task Content Shows Raw Markdown

### Symptom
Task details show `**bold**` and `` `code` `` literally instead of formatted.

### Cause
1. blessed tags not being processed
2. Markdown conversion failed

### Solution

This is expected in the TUI (limited markdown support). The TUI converts:
- `**bold**` → bold text
- `` `code` `` → colored text
- `[link](url)` → shown as plain text
- `- list` → `• list`

If you need rich formatting, use the **Web UI** instead (`bun run dev`).

## F-keys Don't Work in tmux

### Symptom
Pressing F1/F2/F3 doesn't switch panes.

### Cause
1. Terminal emulator intercepts F-keys
2. SSH doesn't forward F-keys
3. tmux key bindings not set

### Solution

**Use Ctrl+b alternatives:**
- `Ctrl+b ←/→/↑/↓` - Navigate panes
- `Ctrl+b o` - Cycle through panes
- `Ctrl+b q` - Show pane numbers

**Fix terminal F-key forwarding:**
For iTerm2/Terminal.app:
- Preferences → Keys → Map F-keys to escape sequences

For PuTTY:
- Configuration → Keyboard → Function keys: Xterm R6

## VM Crashes or Hangs

### Symptom
VM becomes unresponsive while running TUI.

### Cause
Insufficient VM resources.

### Solution

**Check Vagrantfile settings:**
```ruby
config.vm.provider "virtualbox" do |vb|
  vb.memory = "2048"  # Increase if needed
  vb.cpus = 2         # Allocate more CPUs
end
```

Then reload:
```bash
vagrant reload
```

## Getting Help

If none of these solutions work:

1. **Check logs:**
   ```bash
   # TUI errors
   bun run tui 2>&1 | tee tui.log
   
   # tmux session logs
   tmux capture-pane -t exam:0.0 -p > tui-pane.log
   ```

2. **Test with minimal setup:**
   ```bash
   # Test task file directly
   cat /vagrant/exam-tasks.md | head -50
   
   # Test TUI with explicit path
   TASK_FILE=/vagrant/exam-tasks.md bun run tui
   ```

3. **Verify environment:**
   ```bash
   # Check all relevant vars
   echo "TASK_FILE: $TASK_FILE"
   echo "FLAG_FILE: $FLAG_FILE"
   echo "TUI_DIR: $TUI_DIR"
   echo "PATH: $PATH"
   bun --version
   ```

4. **Fall back to bash viewer:**
   ```bash
   /vagrant/scripts/tasks-viewer.sh
   ```

5. **Use Web UI instead:**
   ```bash
   cd /vagrant/apps/exam-ui
   bun run dev
   # Access from host: http://localhost:4173
   ```

## Quick Diagnostic Commands

Run these to gather debug information:

```bash
#!/bin/bash
echo "=== Environment ==="
which bun
bun --version
echo "TASK_FILE: ${TASK_FILE:-not set}"
echo "FLAG_FILE: ${FLAG_FILE:-not set}"
echo "TUI_DIR: ${TUI_DIR:-not set}"

echo -e "\n=== Files ==="
ls -la /vagrant/exam-tasks.md
ls -la ~/.ica-task-flags

echo -e "\n=== Dependencies ==="
cd /vagrant/apps/exam-ui
[ -d node_modules ] && echo "node_modules exists" || echo "node_modules missing"
[ -f node_modules/.bin/blessed ] && echo "blessed installed" || echo "blessed missing"

echo -e "\n=== tmux ==="
tmux ls 2>/dev/null || echo "No tmux sessions"

echo -e "\n=== Processes ==="
pgrep -a bun || echo "No bun processes"
```

Save as `debug.sh`, run with `bash debug.sh`, and include output when reporting issues.

## Known Limitations

These are expected behaviors, not bugs:

1. **Flag sync:** Web UI and TUI flags don't automatically sync
2. **Markdown:** Limited support (no tables, images, complex formatting)
3. **Windows:** Scripts require WSL or Git Bash (PowerShell not fully supported)
4. **Hot reload:** TUI requires restart to see task file changes (Web UI auto-reloads)
5. **Shared folders:** Performance may be slower on CIFS/SMB mounts
6. **Concurrency:** Multiple TUI instances may race when saving flags

---

*For additional help, see the [README.md](README.md), [QUICKSTART.md](QUICKSTART.md), or [IMPLEMENTATION.md](IMPLEMENTATION.md).*

