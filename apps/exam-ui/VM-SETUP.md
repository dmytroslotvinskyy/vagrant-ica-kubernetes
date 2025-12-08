# VM Setup Instructions

Quick guide for setting up the Bun Task Navigator on the Vagrant VM.

## Prerequisites Check

```bash
vagrant ssh controlplane
```

Inside the VM, verify:
```bash
# Check if /vagrant is mounted
ls -la /vagrant/apps/exam-ui

# Should see:
# - src/
# - public/
# - package.json
# - README.md
```

## Install Bun

```bash
curl -fsSL https://bun.sh/install | bash

# Reload shell configuration
source ~/.bashrc

# Verify installation
bun --version
# Should output: bun 1.x.x
```

## Install Dependencies

```bash
cd /vagrant/apps/exam-ui
bun install

# Should install:
# - blessed@^0.1.81
# - @types/blessed@^0.1.25
```

## Make Scripts Executable

```bash
# From inside the VM (not Windows host)
chmod +x /vagrant/scripts/tasks-viewer-tui.sh
chmod +x /vagrant/scripts/exam-env-tui.sh

# Verify
ls -l /vagrant/scripts/*tui.sh
# Should show: -rwxr-xr-x (executable bit set)
```

## Test Web Server

```bash
cd /vagrant/apps/exam-ui
bun run dev

# Should output:
# [exam-ui] running on http://localhost:4173
# [exam-ui] reading tasks from /vagrant/exam-tasks.md
```

From your **host machine**, open a browser to:
- If using NAT: Set up port forwarding (see below)
- If using bridged network: `http://<vm-ip>:4173`

To test inside the VM:
```bash
curl http://localhost:4173/api/tasks | head -20
# Should return JSON with tasks
```

Stop the server: `Ctrl+C`

## Test Terminal TUI

```bash
cd /vagrant/apps/exam-ui
bun run tui
```

You should see:
- Split-pane layout
- Task list on left
- Task details on right
- Status bar at bottom
- Help bar at bottom

**Navigate:**
- `j` / `k` or arrow keys
- Press `f` to flag a task
- Press `q` to quit

## Test Full Exam Environment

```bash
sudo /vagrant/scripts/exam-env-tui.sh

# Should create a 3-pane tmux session:
# [Left] TUI task navigator
# [Top-right] Shell for kubectl commands
# [Bottom-right] Auto-refreshing scoreboard
```

**Tmux controls:**
- `F1` - Jump to task navigator
- `F2` - Jump to work shell
- `F3` - Jump to scoreboard
- `F5` - Restart scoreboard
- `Ctrl+b d` - Detach from session

**Reattach later:**
```bash
tmux attach -t exam
```

**Kill session:**
```bash
tmux kill-session -t exam
```

## Port Forwarding (NAT Network)

If your VM uses NAT networking, forward port 4173 to your host.

### Method 1: Vagrant configuration

Edit `Vagrantfile` and add:
```ruby
config.vm.network "forwarded_port", guest: 4173, host: 4173
```

Then reload:
```bash
vagrant reload
```

### Method 2: SSH tunnel

```bash
# From host machine
vagrant ssh controlplane -- -L 4173:localhost:4173

# In the SSH session:
cd /vagrant/apps/exam-ui
bun run dev

# On host: open http://localhost:4173
```

### Method 3: VirtualBox GUI

1. Open VirtualBox Manager
2. Select your VM
3. Settings → Network → Adapter 1 → Advanced → Port Forwarding
4. Add rule:
   - Name: `exam-ui`
   - Protocol: `TCP`
   - Host Port: `4173`
   - Guest Port: `4173`

## Troubleshooting

### Bun install fails

**Symptom:** `error: ENOSPC: no space left on device`

**Solution:**
```bash
# Check disk space
df -h

# Clean up if needed
sudo apt clean
sudo apt autoremove
```

### Blessed rendering issues

**Symptom:** Garbled characters, boxes don't display correctly

**Solution:**
```bash
# Set correct terminal type
export TERM=xterm-256color

# Or try:
export TERM=screen-256color

# Make permanent (add to ~/.bashrc):
echo 'export TERM=xterm-256color' >> ~/.bashrc
```

### Scripts not executable

**Symptom:** `Permission denied` when running scripts

**Solution:**
```bash
# Must be run inside VM (not from Windows host)
vagrant ssh controlplane
chmod +x /vagrant/scripts/tasks-viewer-tui.sh
chmod +x /vagrant/scripts/exam-env-tui.sh
```

### Task file not found

**Symptom:** `Error: Could not load tasks`

**Solution:**
```bash
# Verify task file exists
ls -la /vagrant/exam-tasks.md

# If missing, check your git branch
cd /vagrant
git status
git log --oneline -5

# The exam-tasks.md should be in the bun-task-viewer-ui branch
```

### Tmux session already exists

**Symptom:** `Session 'exam' already running`

**Solution:**
```bash
# Option 1: Attach to existing session
tmux attach -t exam

# Option 2: Kill and recreate
tmux kill-session -t exam
sudo /vagrant/scripts/exam-env-tui.sh

# Option 3: Use different session name
SESSION_NAME=exam2 /vagrant/scripts/exam-env-tui.sh
```

### Cannot connect to localhost:4173

**Symptom:** Browser shows "Connection refused" or "Unable to connect"

**Checklist:**
1. Is the server running? (Check for `bun run dev` process)
2. Is port forwarding configured? (See Port Forwarding section)
3. Firewall blocking? (Try `curl http://localhost:4173` from VM)
4. Wrong port? (Check `PORT` env var, default is 4173)

**Debug:**
```bash
# Check if server is listening
ss -tlnp | grep 4173

# Should show:
# LISTEN  0  128  *:4173  *:*  users:(("bun",pid=1234,...))
```

## Performance Tuning

### Reduce scoreboard refresh interval

Default is 180 seconds (3 minutes). Increase for less CPU usage:

```bash
SCOREBOARD_INTERVAL=300 /vagrant/scripts/exam-env-tui.sh  # 5 minutes
```

### Adjust TUI pane width

Default is 50 columns. Adjust based on your terminal:

```bash
VIEWER_WIDTH=40 /vagrant/scripts/exam-env-tui.sh  # Narrower
VIEWER_WIDTH=60 /vagrant/scripts/exam-env-tui.sh  # Wider
```

### Disable mouse in tmux

If mouse interferes with copy/paste:

```bash
# Inside tmux session
tmux set-option mouse off
```

## Cleanup

Remove all installed components:

```bash
# Remove Bun
rm -rf ~/.bun

# Remove installed packages
rm -rf /vagrant/apps/exam-ui/node_modules

# Remove flag file
rm ~/.ica-task-flags

# Kill tmux sessions
tmux kill-server
```

## Next Steps

After successful setup:
1. Read the [QUICKSTART.md](QUICKSTART.md) guide
2. Try the Web UI and TUI interfaces
3. Review the [IMPLEMENTATION.md](IMPLEMENTATION.md) for technical details
4. Start working through the exam tasks in `exam-tasks.md`

Happy learning! 🎓

