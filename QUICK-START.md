# Quick Start Guide - ICA Istio Lab Exam

## One-Command Exam Startup

After running `vagrant up`, start the exam with a single command:

### Linux/Mac/WSL:
```bash
./start-exam.sh
```

### Windows PowerShell:
```powershell
.\start-exam.ps1
```

## What the Script Does

1. ✅ Checks if the controlplane VM is running
2. ✅ Verifies Istio is installed
3. ✅ SSHs into the controlplane VM
4. ✅ Starts the exam TUI automatically

## What You Get

The exam TUI launches in a tmux session with 3 panes:

- **Left pane:** Task navigator (JavaScript TUI)
  - Navigate with `j`/`k` or arrow keys
  - Press `s` to view detailed solutions
  - Press `f` to flag tasks
  - Press `/` to search

- **Top-right pane:** Work shell
  - Run `kubectl` commands
  - Apply manifests
  - Test your solutions

- **Bottom-right pane:** Live scoreboard
  - Auto-refreshes every 3 minutes
  - Shows PASS/FAIL status for all tasks
  - Displays current score

## Reconnecting Later

If you disconnect from the tmux session:

```bash
vagrant ssh controlplane -c 'tmux attach -t exam'
```

## Manual Method (Alternative)

If you prefer manual control:

```bash
vagrant ssh controlplane
sudo /vagrant/scripts/exam-tui-bun.sh
```

## Troubleshooting

### Script says "VM is not running"
```bash
vagrant up controlplane
```

### Script says "Istio namespace not found"
Wait a few minutes for lab provisioning to complete, then try again.

### TUI doesn't start
Check that Bun is installed:
```bash
vagrant ssh controlplane -c 'which bun'
```

If not installed, it will be installed automatically on first TUI launch.

## Next Steps

1. Navigate through tasks using the TUI
2. View solutions by pressing `s` on any task
3. Apply manifests and test your solutions
4. Check your progress with the scoreboard
5. Run `/vagrant/check-exam.sh` for detailed verification

