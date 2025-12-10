# Wrapper script that bypasses execution policy
# This script calls start-exam.ps1 with execution policy bypassed
# Usage: .\start-exam-bypass.ps1

powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\start-exam.ps1"

