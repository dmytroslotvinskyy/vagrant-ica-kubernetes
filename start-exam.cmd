@echo off
REM Windows batch file to launch the exam TUI
REM This bypasses PowerShell execution policy issues
REM Usage: start-exam.cmd

echo ==========================================
echo   Starting ICA Istio Lab Exam
echo ==========================================
echo.

REM Check if controlplane VM is running
vagrant status controlplane | findstr /C:"running" >nul
if errorlevel 1 (
    echo [ERROR] controlplane VM is not running
    echo.
    echo Please start the VM first:
    echo   vagrant up controlplane
    exit /b 1
)

echo [OK] Controlplane VM is running
echo.

REM Check if Istio is installed
echo Checking Istio installation...
vagrant ssh controlplane -c "kubectl get ns istio-system >nul 2>&1" >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Istio namespace not found. Lab may not be fully provisioned.
    echo    This is normal if you just ran 'vagrant up' - wait a few minutes for
    echo    the lab provisioning to complete, then run this script again.
    echo.
    set /p continue="Continue anyway? (y/N): "
    if /i not "%continue%"=="y" exit /b 1
)

echo [OK] Istio namespace found
echo.

REM Launch exam TUI
echo Launching exam TUI...
echo.
echo This will:
echo   1. SSH into the controlplane VM
echo   2. Start the exam TUI in tmux
echo.
echo To reconnect later: vagrant ssh controlplane -c "tmux attach -t exam"
echo.

vagrant ssh controlplane -c "sudo /vagrant/scripts/exam-tui-bun.sh"

