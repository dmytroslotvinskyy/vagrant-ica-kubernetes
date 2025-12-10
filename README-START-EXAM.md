# Starting the Exam - Windows Users

## PowerShell Execution Policy Error

If you see this error:
```
.\start-exam.ps1 cannot be loaded. The file is not digitally signed.
```

## Solutions (Choose One)

### Option 1: Use Bypass Script (Easiest)
```powershell
.\start-exam-bypass.ps1
```

### Option 2: Use Batch File (No PowerShell Policy)
```cmd
start-exam.cmd
```

### Option 3: Bypass Policy for This Script
```powershell
powershell -ExecutionPolicy Bypass -File .\start-exam.ps1
```

### Option 4: Change Execution Policy (Permanent)
Run PowerShell as Administrator:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
Then you can run:
```powershell
.\start-exam.ps1
```

## Recommended: Use the Batch File

The `start-exam.cmd` file works on all Windows systems without any policy changes:
```cmd
start-exam.cmd
```

## Linux/Mac/WSL Users

Just use:
```bash
./start-exam.sh
```


