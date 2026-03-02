param()

#region Self-Elevation
# Checks if the script is running with Administrator privileges and restarts it if not.
function Confirm-AdministratorPrivilege {
    $currentUserIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = [Security.Principal.WindowsPrincipal]$currentUserIdentity

    if (-not $windowsPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        try {
            $scriptPath = $MyInvocation.MyCommand.Path
            # Use an array for arguments to avoid injection vulnerabilities. Start-Process handles quoting.
            $arguments = @(
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                $scriptPath
            )

            $PSBoundParameters.GetEnumerator() | ForEach-Object {
                $arguments += "-$($_.Key)"
                # Add parameter value unless it's a switch parameter.
                if (-not ($_.Value -is [System.Management.Automation.SwitchParameter] -and $_.Value.IsPresent)) {
                    # CORREÇÃO: Garante que argumentos nulos não quebrem e filtra tipos complexos não suportados na CLI.
                    if ($null -ne $_.Value -and $_.Value -is [string] -or $_.Value -is [System.ValueType]) {
                        $arguments += $_.Value
                    }
                }
            }

            Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs -ErrorAction Stop
        }
        catch {
            Write-Error "ELEVATION FAILED: Unable to restart with Administrator privileges. Error: $($_.Exception.Message)"
            Exit 1
        }
        # Exit the current non-elevated process.
        Exit 0
    }
    return $currentUserIdentity
}
#endregion

#region Module Execution
# Securely invokes a collection module and handles its execution lifecycle.
function Invoke-EitinCollectionModule {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Module,
        [Parameter(Mandatory = $true)]
        [string]$ModulesRootPath
    )

    $sectionTitle = $Module.title
    $moduleScriptName = $Module.script
    $modulePath = Join-Path $ModulesRootPath $moduleScriptName
    $moduleData = $null
    $moduleError = $null
    $sectionExecutionSuccess = $true

    Write-EitinSectionStart -SectionTitle $sectionTitle

    if (-not (Test-Path $modulePath)) {
        $moduleError = "Module script '$moduleScriptName' not found."
        $sectionExecutionSuccess = $false
    } else {
        try {
            # Source the module script to load its functions.
            . $modulePath

            # LÓGICA ATUALIZADA: Usa o nome da função definido explicitamente na configuração.
            # Isso evita fragilidade se o arquivo for renomeado mas a função não.
            if ($Module.PSObject.Properties['function'] -and -not [string]::IsNullOrWhiteSpace($Module.function)) {
                $invokeFunctionName = $Module.function
            } else {
                # Fallback legado (com aviso) ou erro se preferir zero-trust estrito.
                # Mantendo fallback por compatibilidade durante migração, mas logando aviso se fosse implementado log verbose aqui.
                $invokeFunctionName = "Invoke-Eitin" + ($moduleScriptName -replace "^Get-", "" -replace ".ps1$", "") + "Info"
            }

            $functionCmd = Get-Command $invokeFunctionName -ErrorAction SilentlyContinue

            if ($functionCmd) {
                # CHAMADA SEGURA: Usa o operador de chamada '&' em vez de Invoke-Expression.
                $moduleData = & $functionCmd

                # RESTORED LOGIC: Special handling for modules that might be "Not Applicable".
                if (($moduleScriptName -eq "Get-ActiveDirectory.ps1" -or $moduleScriptName -eq "Get-OfficeLicenseInfo.ps1") -and $null -eq $moduleData) {
                    Write-EitinStep -Message "Section '$sectionTitle' skipped (Not Applicable)." -Status "INFO"
                    $moduleData = $null # Ensure nothing is logged for this section.
                } elseif ($moduleData -is [PSCustomObject] -and $null -ne $moduleData.PSObject.Properties['Error'] -and $moduleData.Error) {
                    $moduleError = "Module '$sectionTitle' reported an error: $($moduleData.Error)"
                    $sectionExecutionSuccess = $false
                }
            } else {
                $moduleError = "Function '$invokeFunctionName' not found in module '$moduleScriptName'."
                $sectionExecutionSuccess = $false
            }
        } catch {
            $moduleError = "Critical error executing module '$moduleScriptName': $($_.Exception.Message)"
            $sectionExecutionSuccess = $false
        }
    }

    # If an error occurred, structure the error data for logging.
    if ($moduleError) {
        $moduleData = [PSCustomObject]@{
            Error = $moduleError
        }
    }

    if ($null -ne $moduleData) {
        Add-EitinLogSection -SectionTitle $sectionTitle -Data $moduleData
    }

    Write-EitinSectionEnd -SectionTitle $sectionTitle -Success $sectionExecutionSuccess -ErrorMessage $moduleError
}
#endregion

# --- Main Script Execution ---

$Global:EITIN_SCRIPT_START_TIME = Get-Date

# 1. Ensure administrator privileges and get user identity.
$currentUserIdentity = Confirm-AdministratorPrivilege

try {
    # Set console encoding to handle special characters correctly.
    [System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
}
catch {
    Write-Warning "Could not set UTF-8 encoding."
}

# 2. Load core dependency scripts.
$coreScripts = @(
    "Core\Utils.ps1",
    "Core\Audit.ps1",
    "Core\HtmlReportGenerator.ps1",
    "Core\TxtReportGenerator.ps1",
    "Core\CsvReportGenerator.ps1",
    "Core\Logger.ps1",
    "Core\UIEnhancements.ps1"
)
try {
    foreach ($coreScript in $coreScripts) { . (Join-Path $PSScriptRoot $coreScript) }
}
catch {
    Write-Error "FATAL: Failed to load Core scripts. Error: $($_.Exception.Message)"
    Exit 1
}

# Tenta centralizar a janela do console (UX)
# Tenta centralizar a janela do console (UX)
Update-EitinConsoleWindow

# 3. Load module configuration from JSON.
$configFilePath = Join-Path $PSScriptRoot "Config\config.json"
$Global:EitinSettings = @{
    AutoCloseConsole = $false
    Reports = @{
        GenerateTxt = $true
        GenerateHtmlInteractive = $true
        GenerateHtmlPrintable = $true
        GenerateCsv = $true
    }
}
try {
    $configContent = Get-Content -Path $configFilePath -Raw -Encoding UTF8 | ConvertFrom-Json

    # Suporte Híbrido: Se for array (formato antigo), trata como lista de módulos.
    # Se for objeto (novo formato), extrai Settings e Modules.
    if ($configContent -is [System.Array]) {
        $collectionModules = $configContent
    } else {
        if ($configContent.PSObject.Properties['Settings']) {
            $Global:EitinSettings.AutoCloseConsole = $configContent.Settings.AutoCloseConsole
            if ($configContent.Settings.Reports) {
                $Global:EitinSettings.Reports.GenerateTxt = $configContent.Settings.Reports.GenerateTxt
                $Global:EitinSettings.Reports.GenerateHtmlInteractive = $configContent.Settings.Reports.GenerateHtmlInteractive
                $Global:EitinSettings.Reports.GenerateHtmlPrintable = $configContent.Settings.Reports.GenerateHtmlPrintable
                $Global:EitinSettings.Reports.GenerateCsv = $configContent.Settings.Reports.GenerateCsv
            }
        }
        $collectionModules = $configContent.Modules
    }
}
catch {
    Write-Error "FATAL: Failed to load 'config.json'. Error: $($_.Exception.Message)"
    Exit 1
}

# 4. Initialize script execution environment and logs.
Write-EitinHeader -ScriptTitle "EITIN - Elevated IT Inventory"
$ExecutingUser = $currentUserIdentity.Name

Write-EitinStep -Message "Initializing inventory logs..." -Status "INFO"
try {
    Initialize-EitinLogs -OutputDirectory $PSScriptRoot -ComputerName $env:COMPUTERNAME -ScriptUser $ExecutingUser -ReportSettings $Global:EitinSettings.Reports
    Write-EitinStep -Message "Log files initialized successfully." -Status "SUCCESS"
}
catch {
    Write-EitinStep -Message "FATAL: Failed to initialize log files. Error: $($_.Exception.Message)" -Status "ERROR"
    Exit 1
}

# 5. Process all enabled collection modules.
$modulesRoot = Join-Path $PSScriptRoot "Modules"
foreach ($module in $collectionModules) {
    if ($module.enabled -eq $false) {
        continue
    }
    # Delegate module execution to the specialized function.
    Invoke-EitinCollectionModule -Module $module -ModulesRootPath $modulesRoot
}

# 6. Finalize reports and calculate execution time.
Write-EitinStep -Message "Finalizing inventory reports..." -Status "INFO"
$CurrentEndTime = Get-Date
$ExecutionTimeSpan = $CurrentEndTime - $Global:EITIN_SCRIPT_START_TIME

$logFilePaths = $null
try {
    $logFilePaths = Complete-EitinLogs -ExecutionTimeSpanForReport $ExecutionTimeSpan -ScriptRootPath $PSScriptRoot -ReportSettings $Global:EitinSettings.Reports
    Write-EitinStep -Message "Reports finalized successfully." -Status "SUCCESS"
}
catch {
    Write-EitinStep -Message "CRITICAL: Failed to finalize log files. Error: $($_.Exception.Message)" -Status "ERROR"
}

# Final footer call.
Write-EitinFooter -ExecutionTime $ExecutionTimeSpan -TxtLogPath $logFilePaths.TxtLogPath -HtmlLogPath $logFilePaths.HtmlLogPath -PrintableHtmlPath $logFilePaths.PrintableHtmlPath -CsvLogPath $logFilePaths.CsvLogPath

if (-not $Global:EitinSettings.AutoCloseConsole) {
    Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
