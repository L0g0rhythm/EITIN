@echo off
:: ============================================================================
:: Description: Silently launches the corresponding PowerShell script (EITIN.ps1)
::              with administrative privileges using UAC prompt.
::              Supports passing arguments (%*) to the PowerShell script.
::              Minimal features for compatibility. NO CONSOLE OUTPUT.
:: ============================================================================
setlocal EnableExtensions

:: --- Configuration ---
:: Define variables for the script path
set "SCRIPT_PATH=%~dp0"
:: Uses original method to include full path in SCRIPT_NAME based on this BAT file's name
set "SCRIPT_NAME=%~dpn0.ps1"
set "POWERSHELL=powershell.exe"

:: --- Pre-checks ---
:: 1. Change to script directory (Attempt silently)
cd /d "%SCRIPT_PATH%" || (
    :: Exit silently on error
    exit /b 1
)

:: 2. Check if PowerShell executable exists (Silently)
where %POWERSHELL% >nul 2>nul || (
    :: Exit silently on error
    exit /b 1
)

:: 3. Check if the target PowerShell script exists (Silently)
if not exist "%SCRIPT_NAME%" (
    :: Exit silently on error
    exit /b 1
)

:: --- Argument Preparation & Elevation ---
:: Prepare arguments including any passed to this batch file (%*)
set "ELEVATED_ARGS=-NoProfile -ExecutionPolicy Bypass -File \"%SCRIPT_NAME%\" %*"

:: Execute PowerShell to trigger Start-Process with elevation (Silently)
%POWERSHELL% -NoProfile -ExecutionPolicy Bypass -Command ^
    "Start-Process -FilePath '%POWERSHELL%' -ArgumentList '%ELEVATED_ARGS%' -Verb RunAs" || (
    :: Exit silently on error (e.g., user cancelled UAC)
    exit /b 1
)

:: --- Completion ---
:: Exit successfully if elevation request was sent
exit /b 0
