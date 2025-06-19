param()
#region Self-Elevation Check
$currentUserIdentity = [Security.Principal.WindowsIdentity]::GetCurrent(); $windowsPrincipal = [Security.Principal.WindowsPrincipal]$currentUserIdentity
if (-not $windowsPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try { $scriptPath = $MyInvocation.MyCommand.Path; $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""; $PSBoundParameters.GetEnumerator() | ForEach-Object {$paramName = $_.Key; $paramValue = $_.Value; if ($paramValue -is [System.Management.Automation.SwitchParameter]) { if ($paramValue.IsPresent) { $arguments += " -$paramName" } } elseif ($paramValue -is [string]) { $arguments += " -$paramName `"$($paramValue -replace '"', '\`"')`"" } else { $arguments += " -$paramName `"$($paramValue)`"" }}; Start-Process powershell.exe -ArgumentList $arguments.Trim() -Verb RunAs -ErrorAction Stop
    } catch { Write-Error "ELEVAÇÃO FALHOU: Incapaz de reiniciar com privilégios de Administrador. $($_.Exception.Message)"; Exit 1 }; Exit 0
}
#endregion
try { [System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8; $OutputEncoding = [System.Text.Encoding]::UTF8 } catch { Write-Warning "Não foi possível definir a codificação UTF-8." }
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition; $Global:EITIN_SCRIPT_START_TIME = Get-Date
$coreScripts = @( "Core\Utils.ps1", "Core\Logger.ps1", "Core\UIEnhancements.ps1", "Core\HtmlReportGenerator.ps1", "Core\TxtReportGenerator.ps1", "Core\CsvReportGenerator.ps1" )
try { foreach ($coreScript in $coreScripts) { . (Join-Path $PSScriptRoot $coreScript) } } catch { Write-Error "FATAL: Falha ao carregar scripts Core. $($_.Exception.Message)"; Exit 1 }
$configFilePath = Join-Path $PSScriptRoot "Config\config.json"
try { $collectionModules = Get-Content -Path $configFilePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Write-Error "FATAL: Falha ao carregar 'config.json'. Erro: $($_.Exception.Message)"; Exit 1 }
Write-EitinHeader -ScriptTitle "EITIN - Inventário de TI Elevado"; $ExecutingUser = $currentUserIdentity.Name
Write-EitinStep -Message "Inicializando arquivos de log do inventário..." -Status "INFO"
try { Initialize-EitinLogs -OutputDirectory $PSScriptRoot -ComputerName $env:COMPUTERNAME -ScriptUser $ExecutingUser; Write-EitinStep -Message "Arquivos de log inicializados com sucesso." -Status "SUCCESS"
} catch { Write-EitinStep -Message "FATAL: Falha ao inicializar arquivos de log. $($_.Exception.Message)" -Status "ERROR"; Exit 1 }
foreach ($module in $collectionModules) {
    if ($null -ne $module.enabled -and -not $module.enabled) { continue }
    $sectionTitle = $module.title; $moduleScriptName = $module.script; $modulePath = Join-Path $PSScriptRoot "Modules\$moduleScriptName"; $moduleData = $null; $moduleError = $null; $sectionExecutionSuccess = $true
    Write-EitinSectionStart -SectionTitle $sectionTitle
    if (-not (Test-Path $modulePath)) { $moduleError = "Script do módulo '$moduleScriptName' não encontrado."; $moduleData = [PSCustomObject]@{ Error = $moduleError }; $sectionExecutionSuccess = $false
    } else {
        try { . $modulePath; $invokeFunctionName = "Invoke-Eitin" + ($moduleScriptName -replace "^Get-", "" -replace ".ps1$", "") + "Info"
            if (Get-Command $invokeFunctionName -ErrorAction SilentlyContinue) {
                $moduleData = Invoke-Expression $invokeFunctionName
                if (($moduleScriptName -eq "Get-ActiveDirectory.ps1" -or $moduleScriptName -eq "Get-OfficeLicenseInfo.ps1") -and $null -eq $moduleData) {
                    $logMessage = if ($moduleScriptName -eq "Get-ActiveDirectory.ps1") { "Seção '$sectionTitle' ignorada (Não aplicável)." } else { "Seção '$sectionTitle' ignorada (Não aplicável)." }
                    Write-EitinStep -Message $logMessage -Status "INFO"; $moduleData = $null
                } elseif ($moduleData -is [PSCustomObject] -and $moduleData.PSObject.Properties['Error'] -ne $null -and $moduleData.Error) { $moduleError = "O módulo '$sectionTitle' reportou erro: $($moduleData.Error)"; $sectionExecutionSuccess = $false }
            } else { $moduleError = "Função '$invokeFunctionName' não encontrada."; $moduleData = [PSCustomObject]@{ Error = $moduleError }; $sectionExecutionSuccess = $false }
        } catch { $moduleError = "Erro crítico ao executar módulo '$moduleScriptName': $($_.Exception.Message)"; $moduleData = [PSCustomObject]@{ Error = $moduleError }; $sectionExecutionSuccess = $false }
    }
    if ($null -ne $moduleData) { Add-EitinLogSection -SectionTitle $sectionTitle -Data $moduleData }
    Write-EitinSectionEnd -SectionTitle $sectionTitle -Success $sectionExecutionSuccess -ErrorMessage $moduleError
}
Write-EitinStep -Message "Finalizando relatórios do inventário..." -Status "INFO"
$CurrentEndTime = Get-Date; $ExecutionTimeSpan = if ($Global:EITIN_SCRIPT_START_TIME -is [datetime]) { $CurrentEndTime - $Global:EITIN_SCRIPT_START_TIME } else { New-TimeSpan -Seconds 0 }
$logFilePaths = $null; try { $logFilePaths = Finalize-EitinLogs -ExecutionTimeSpanForReport $ExecutionTimeSpan -ScriptRootPath $PSScriptRoot; Write-EitinStep -Message "Relatórios finalizados com sucesso." -Status "SUCCESS"
} catch { Write-EitinStep -Message "CRÍTICO: Falha ao finalizar arquivos de log. $($_.Exception.Message)" -Status "ERROR" }
# Chamada final ao rodapé, passando todos os caminhos de log
Write-EitinFooter -ExecutionTime $ExecutionTimeSpan -TxtLogPath $logFilePaths.TxtLogPath -HtmlLogPath $logFilePaths.HtmlLogPath -PrintableHtmlPath $logFilePaths.PrintableHtmlPath -CsvLogPath $logFilePaths.CsvLogPath