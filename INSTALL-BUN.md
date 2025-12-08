# Bun Installation Guide

Complete guide for installing Bun runtime in the Vagrant VM to enable the JavaScript-based Task Navigator TUI.

## Automated Installation Options

### Option 1: During VM Provisioning (Recommended)

Bun is **automatically installed** during `vagrant up` if the installation script is present.

The `scripts/master.sh` provisioner includes:
```bash
# Install Bun runtime for TUI (optional but recommended)
if [ -f /vagrant/scripts/install-bun.sh ]; then
  echo "[master] Installing Bun runtime for exam TUI..."
  bash /vagrant/scripts/install-bun.sh
fi
```

**To enable:**
1. Ensure `scripts/install-bun.sh` exists (it does!)
2. Run `vagrant up` or `vagrant provision controlplane`
3. Bun will be installed for both `root` and `vagrant` users

### Option 2: Post-Provisioning (Existing VM)

If your VM is already provisioned, run:

```bash
vagrant ssh controlplane
sudo /vagrant/scripts/post-provision-bun.sh
```

This will:
- ✅ Install `unzip` (prerequisite)
- ✅ Install Bun for `root` user
- ✅ Install Bun for `vagrant` user
- ✅ Add Bun to PATH in `.bashrc`
- ✅ Install TUI dependencies
- ✅ Test the installation

### Option 3: Quick Install (Manual)

```bash
vagrant ssh controlplane

# Install prerequisites
sudo apt-get update
sudo apt-get install -y unzip curl

# Install Bun for current user
curl -fsSL https://bun.sh/install | bash

# Add to PATH
echo 'export BUN_INSTALL="$HOME/.bun"' >> ~/.bashrc
echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify
bun --version
```

### Option 4: Use the Launcher Script

The easiest way - it handles everything:

```bash
vagrant ssh controlplane
sudo /vagrant/scripts/exam-tui-bun.sh
```

This script:
- ✅ Checks if Bun is installed
- ✅ Installs Bun if missing (including `unzip`)
- ✅ Installs TUI dependencies
- ✅ Launches the full tmux environment

## Installation Details

### What Gets Installed

**For root user:**
- Location: `/root/.bun/`
- Binary: `/root/.bun/bin/bun`
- Used by: `sudo` scripts

**For vagrant user:**
- Location: `/home/vagrant/.bun/`
- Binary: `/home/vagrant/.bun/bin/bun`
- Used by: Manual commands

### Prerequisites

Bun requires:
- **unzip** - For extracting the Bun binary
- **curl** - For downloading the installer
- **bash** - For running the install script

These are automatically installed by the automation scripts.

### File Modifications

The installation adds to `~/.bashrc`:
```bash
# Bun runtime
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
```

## Verification

### Check Installation

```bash
# As vagrant user
bun --version
# Should output: bun 1.x.x

# As root
sudo bun --version
# Should output: bun 1.x.x

# Check paths
which bun
# vagrant: /home/vagrant/.bun/bin/bun
# root: /root/.bun/bin/bun
```

### Test TUI

```bash
# Quick test
cd /vagrant/apps/exam-ui
bun run tui

# Should show the task navigator interface
# Press 'q' to quit
```

### Test Full Environment

```bash
sudo /vagrant/scripts/exam-tui-bun.sh

# Should create 3-pane tmux session:
# - Left: TUI task navigator
# - Top-right: Shell
# - Bottom-right: Scoreboard
```

## Troubleshooting

### "bun: command not found"

**Cause:** PATH not updated or wrong user

**Solution:**
```bash
# Reload bashrc
source ~/.bashrc

# Or manually add to PATH
export PATH="$HOME/.bun/bin:$PATH"

# For root
export PATH="/root/.bun/bin:$PATH"
```

### "unzip: command not found"

**Cause:** Missing prerequisite

**Solution:**
```bash
sudo apt-get update
sudo apt-get install -y unzip
```

### Installation Hangs

**Cause:** Network issues downloading Bun

**Solution:**
```bash
# Try with verbose output
curl -fsSL https://bun.sh/install | bash -x

# Or download manually
curl -fsSL https://bun.sh/install -o /tmp/install-bun.sh
bash /tmp/install-bun.sh
```

### Permission Denied

**Cause:** Installing in protected directory

**Solution:**
```bash
# Install to user home (default)
curl -fsSL https://bun.sh/install | bash

# Or specify custom location
BUN_INSTALL=/tmp/bun curl -fsSL https://bun.sh/install | bash
```

### Different Version Needed

**Cause:** Want specific Bun version

**Solution:**
```bash
# Install specific version
curl -fsSL https://bun.sh/install | bash -s "bun-v1.0.0"

# Or use canary
curl -fsSL https://bun.sh/install | bash -s "bun-canary"
```

## Uninstallation

### Remove Bun

```bash
# For vagrant user
rm -rf ~/.bun
sed -i '/# Bun runtime/,+2d' ~/.bashrc

# For root
sudo rm -rf /root/.bun
sudo sed -i '/# Bun runtime/,+2d' /root/.bashrc
```

### Remove TUI Dependencies

```bash
# Remove cached deps
rm -rf /tmp/exam-ui
rm -rf ~/.bun-cache
rm -rf /root/.bun-cache

# Remove node_modules
rm -rf /vagrant/apps/exam-ui/node_modules
```

## Integration with Vagrant

### Automatic Installation

To enable automatic Bun installation during provisioning, ensure `scripts/install-bun.sh` is present. The `master.sh` script will detect and run it.

### Disable Automatic Installation

Comment out in `scripts/master.sh`:
```bash
# Install Bun runtime for TUI (optional but recommended)
# if [ -f /vagrant/scripts/install-bun.sh ]; then
#   echo "[master] Installing Bun runtime for exam TUI..."
#   bash /vagrant/scripts/install-bun.sh
# fi
```

### Custom Installation Location

Set environment variable before provisioning:
```bash
BUN_INSTALL=/opt/bun vagrant up
```

Or in `Vagrantfile`:
```ruby
config.vm.provision "shell", inline: <<-SHELL
  export BUN_INSTALL=/opt/bun
  bash /vagrant/scripts/install-bun.sh
SHELL
```

## Performance Notes

### Installation Time

- **First install:** ~30 seconds (download + extract)
- **Subsequent runs:** <1 second (already installed)

### Disk Space

- Bun binary: ~90 MB
- TUI dependencies: ~15 MB
- Cache: ~5-10 MB
- **Total:** ~110 MB

### Memory Usage

- Bun runtime: ~30 MB
- TUI app: ~20 MB
- **Total:** ~50 MB

## Alternative: Use Web UI Without Bun

If you don't want to install Bun, you can still use the **Web UI** from your host machine:

```bash
# On host (not in VM)
cd vagrant-ica-kubernetes/apps/exam-ui

# Install Bun on host
curl -fsSL https://bun.sh/install | bash

# Run web server
bun run dev

# Open browser
# http://localhost:4173
```

Or use the **original bash viewer**:
```bash
vagrant ssh controlplane
/vagrant/scripts/tasks-viewer.sh
```

## Security Considerations

### Installation Source

Bun is installed from the official source:
```
https://bun.sh/install
```

This script downloads from:
```
https://github.com/oven-sh/bun/releases
```

### Verification

The installer verifies checksums automatically. To manually verify:
```bash
# Check binary signature
file ~/.bun/bin/bun
# Should show: ELF 64-bit LSB executable

# Check version
bun --version
# Should match latest release
```

### Network Requirements

Installation requires:
- HTTPS access to `bun.sh`
- HTTPS access to `github.com`
- Port 443 outbound

## FAQ

**Q: Is Bun required for the exam?**  
A: No, it's optional. You can use the bash viewer or web UI from host.

**Q: Can I install Bun on Windows host?**  
A: Yes! Use WSL or download from https://bun.sh

**Q: Does Bun work on Mac Silicon?**  
A: Yes, Bun has native Apple Silicon support.

**Q: Can I use npm/node instead?**  
A: The TUI is designed for Bun, but you could adapt it for Node.js.

**Q: Will Bun interfere with kubectl/istioctl?**  
A: No, Bun is completely separate from Kubernetes tools.

**Q: Can multiple users share one Bun install?**  
A: Each user needs their own install in their home directory.

**Q: How do I update Bun?**  
A: Run `bun upgrade` or re-run the install script.

## Additional Resources

- **Bun Official Site:** https://bun.sh
- **Bun Documentation:** https://bun.sh/docs
- **Bun GitHub:** https://github.com/oven-sh/bun
- **TUI Documentation:** `/vagrant/apps/exam-ui/README.md`

---

**Quick Commands Summary:**

```bash
# Automated install (recommended)
sudo /vagrant/scripts/post-provision-bun.sh

# Manual install
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc

# Verify
bun --version

# Test TUI
cd /vagrant/apps/exam-ui && bun run tui

# Launch full environment
sudo /vagrant/scripts/exam-tui-bun.sh
```

