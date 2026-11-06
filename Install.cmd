@echo off
setlocal
set "ARTCRAFT_CONTEXT_SCRIPT=%~dp0ArtCraftContext.ps1"
powershell.exe -NoProfile -Command "try { $p = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File ' + [char]34 + $env:ARTCRAFT_CONTEXT_SCRIPT + [char]34 + ' -Action Install'); exit $p.ExitCode } catch { Write-Host $_; exit 1 }"
if errorlevel 1 (echo Installation did not complete. See the PowerShell instructions in the README.) else (echo Done. Reopen the New menu.)
pause
