@echo off
:: Hides commands during execution for cleaner output.

setlocal EnableExtensions
:: Enables command extensions for better compatibility.

:: Define variables for the script path
set "SCRIPT_PATH=%~dp0"
set "SCRIPT_NAME=%~dpn0.ps1"
set "POWERSHELL=powershell.exe"

:: Ensure we are in the script directory
cd /d "%SCRIPT_PATH%" || (
    echo [ERROR] Failed to access the script directory.
    exit /b 1
)

:: Check if the PowerShell script exists
if not exist "%SCRIPT_NAME%" (
    echo [ERROR] PowerShell script "%SCRIPT_NAME%" not found.
    exit /b 1
)

:: Execute the PowerShell script with administrative privileges
%POWERSHELL% -NoProfile -ExecutionPolicy Bypass -Command ^
    "Start-Process -FilePath '%POWERSHELL%' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%SCRIPT_NAME%\"' -Verb RunAs" || (
    echo [ERROR] Failed to start the script with administrative privileges.
    exit /b 1
)

:: Success message
echo [INFO] Script started successfully.
exit /b 0
