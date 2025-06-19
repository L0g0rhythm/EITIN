@echo off

setlocal EnableExtensions

set "SCRIPT_PATH=%~dp0"
set "POWERSHELL_EXE=powershell.exe"
set "SCRIPT_FULL_PATH=%SCRIPT_PATH%EITIN.ps1"

where %POWERSHELL_EXE% >nul 2>nul || (exit /b 1)
if not exist "%SCRIPT_FULL_PATH%" (exit /b 1)

chcp 65001 > nul

set "PS_ARGS=-NoProfile -ExecutionPolicy Bypass -File \"%SCRIPT_FULL_PATH%\" %*"

%POWERSHELL_EXE% -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%POWERSHELL_EXE%' -ArgumentList '%PS_ARGS%' -Verb RunAs" || (
    exit /b 1
)

exit /b 0