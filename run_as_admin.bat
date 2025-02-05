@echo off
:: Prevents commands from being displayed in the prompt while the script is running, making the execution cleaner.

cd /d "%~dp0"
:: Changes the current working directory to the directory where the BAT file is located.
:: The /d parameter allows switching drives if necessary.
:: %~dp0 is a variable that returns the full path of the directory where the script is running.

powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dpn0.ps1""' -Verb RunAs"
:: Runs PowerShell with elevated permissions (administrator mode).
:: -NoProfile prevents loading custom PowerShell profiles, ensuring faster and cleaner execution.
:: -ExecutionPolicy Bypass overrides execution policy restrictions, allowing the script to run even on restricted systems.
:: Start-Process starts a new PowerShell process with:
::   -FilePath 'powershell.exe': specifies the PowerShell executable to be launched.
::   -ArgumentList: defines the arguments to be passed to the new process:
::       -NoProfile and -ExecutionPolicy Bypass (again) ensure the PS1 script runs with the same settings.
::       -File "%~dpn0.ps1": runs the PS1 file that has the same name and path as the current BAT file.
::   -Verb RunAs: requests execution with administrator privileges.
