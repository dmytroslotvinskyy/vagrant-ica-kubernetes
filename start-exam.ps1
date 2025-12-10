# PowerShell script to launch the exam TUI after vagrant up
# Usage: .\start-exam.ps1
# 
# If you get an execution policy error, run:
#   powershell -ExecutionPolicy Bypass -File .\start-exam.ps1
# Or set execution policy (requires admin):
#   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Starting ICA Istio Lab Exam" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if controlplane VM is running
$status = vagrant status controlplane 2>&1 | Select-String "running"
if (-not $status) {
    Write-Host "❌ Error: controlplane VM is not running" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please start the VM first:" -ForegroundColor Yellow
    Write-Host "  vagrant up controlplane" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Controlplane VM is running" -ForegroundColor Green
Write-Host ""

# Check if Istio is installed
Write-Host "Checking Istio installation..."
$istioCheck = vagrant ssh controlplane -c "kubectl get ns istio-system >/dev/null 2>&1" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Warning: Istio namespace not found. Lab may not be fully provisioned." -ForegroundColor Yellow
    Write-Host "   This is normal if you just ran 'vagrant up' - wait a few minutes for" -ForegroundColor Yellow
    Write-Host "   the lab provisioning to complete, then run this script again." -ForegroundColor Yellow
    Write-Host ""
    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        exit 1
    }
}

Write-Host "✓ Istio namespace found" -ForegroundColor Green
Write-Host ""

# Launch exam TUI
Write-Host "Launching exam TUI..." -ForegroundColor Cyan
Write-Host ""
Write-Host "This will:" -ForegroundColor Yellow
Write-Host "  1. SSH into the controlplane VM" -ForegroundColor Yellow
Write-Host "  2. Start the exam TUI in tmux" -ForegroundColor Yellow
Write-Host ""
Write-Host "To reconnect later: vagrant ssh controlplane -c 'tmux attach -t exam'" -ForegroundColor Gray
Write-Host ""

# Launch the exam TUI
vagrant ssh controlplane -c "sudo /vagrant/scripts/exam-tui-bun.sh"

