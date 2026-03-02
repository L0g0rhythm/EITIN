#region Global Variables for Logging
$Global:EitinLogTxtPath = $null
$Global:EitinLogHtmlPath = $null
$Global:EitinPrintableHtmlPath = $null
$Global:EitinLogCsvDir = $null
$Global:EitinComputerName = $null
$Global:EitinReportTimestamp = $null
$Global:EitinExecutingUser = "Usuário Desconhecido"
$Global:EitinExecutionTimeSpan = $null
$Global:EitinHtmlReportSections = [System.Collections.Specialized.OrderedDictionary]::new()
$Global:EitinHtmlSectionTitles = [System.Collections.ArrayList]::new()
$Global:EitinReportSettings = @{ # Default safe settings
    GenerateTxt = $true
    GenerateHtmlInteractive = $true
    GenerateHtmlPrintable = $true
    GenerateCsv = $true
}

function Initialize-EitinLogs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$OutputDirectory,
        [Parameter(Mandatory = $true)] [string]$ComputerName,
        [Parameter(Mandatory = $true)] [string]$ScriptUser,
        [Parameter(Mandatory = $false)] [hashtable]$ReportSettings
    )
    process {
        $Global:EitinComputerName = $ComputerName
        $Global:EitinReportTimestamp = (Get-Date).ToString('dd/MM/yyyy HH:mm:ss')
        $Global:EitinExecutingUser = $ScriptUser

        # Atualiza configurações globais se fornecidas
        if ($ReportSettings) {
            $Global:EitinReportSettings = $ReportSettings
        }

        # Extrai nome de usuário simples (remove domínio/maquina)
        $simpleUserName = ($ScriptUser -split '[\\/]')[-1]

        # Sanitização de caminhos (Allowlist)
        $safeComputerName = $ComputerName -replace '[^a-zA-Z0-9_\- ]', ''
        $safeUserName = $simpleUserName -replace '[^a-zA-Z0-9_\- \.]', ''

        # Fallback de segurança se a sanitização remover tudo (o que seria suspeito)
        if (-not $safeComputerName) { $safeComputerName = "UnknownIdentifier" }
        if (-not $safeUserName) { $safeUserName = "UnknownUser" }

        # MODULARIDADE E HISTÓRICO:
        # Adiciona Timestamp na pasta para garantir que CADA execução seja preservada isoladamente.
        $executionTimestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
        $executionFolderName = "${safeUserName}_${executionTimestamp}"

        # Caminho Base: Logs\Maquina\Usuario_DataHora
        $userAndMachineLogFolder = Join-Path -Path $OutputDirectory -ChildPath "Logs\$safeComputerName\$executionFolderName"

        try {
            if (-not (Test-Path $userAndMachineLogFolder)) {
                New-Item -Path $userAndMachineLogFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
        }
        catch {
            throw "FATAL: Não foi possível criar o diretório de log '$userAndMachineLogFolder'. Erro: $($_.Exception.Message)"
        }

        # Inicializa o Audit Logger (Módulo Separado)
        Initialize-EitinAuditLog -LogDirectory $userAndMachineLogFolder -ComputerName $safeComputerName -UserName $safeUserName

        # Mantém nomes de arquivos limpos
        $baseLogFileName = "Inventario_${safeComputerName}"
        $Global:EitinLogTxtPath = Join-Path -Path $userAndMachineLogFolder -ChildPath "$($baseLogFileName).txt"
        $Global:EitinLogHtmlPath = Join-Path -Path $userAndMachineLogFolder -ChildPath "$($baseLogFileName)_Interativo.html"
        $Global:EitinPrintableHtmlPath = Join-Path -Path $userAndMachineLogFolder -ChildPath "$($baseLogFileName)_Imprimivel.html"

        # Limpa coleções globais
        $Global:EitinHtmlReportSections.Clear(); [void]$Global:EitinHtmlSectionTitles.Clear()

        # Cria a subpasta para relatórios CSV (APENAS SE HABILITADO)
        if ($Global:EitinReportSettings.GenerateCsv) {
            $Global:EitinLogCsvDir = Join-Path -Path $userAndMachineLogFolder -ChildPath "CSV_Reports"
            try {
                New-Item -Path $Global:EitinLogCsvDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
            } catch {
                throw "FATAL: Não foi possível criar o diretório para CSVs: '$($Global:EitinLogCsvDir)'. Erro: $($_.Exception.Message)"
            }
        } else {
            $Global:EitinLogCsvDir = $null
        }

        # Inicializa o relatório TXT (APENAS SE HABILITADO)
        if ($Global:EitinReportSettings.GenerateTxt) {
            $txtHeader = Build-EitinTxtReportHeader -ComputerName $Global:EitinComputerName
            try {
                $txtHeader | Out-File -FilePath $Global:EitinLogTxtPath -Encoding UTF8 -Force -ErrorAction Stop
            }
            catch {
                throw "FATAL: Falha ao escrever no log TXT '$($Global:EitinLogTxtPath)'. Erro: $($_.Exception.Message)"
            }
        } else {
             $Global:EitinLogTxtPath = $null
        }
    }
}

function Add-EitinLogSection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$SectionTitle,
        [Parameter(Mandatory = $true)] [AllowNull()][AllowEmptyCollection()] $Data,
        [switch]$IsPreformatted
    )
    process {
        # Adiciona ao log TXT (APENAS SE HABILITADO)
        if ($Global:EitinReportSettings.GenerateTxt) {
            $txtSectionString = Format-EitinDataToTxtSection -SectionTitle $SectionTitle -Data $Data
            if (-not [string]::IsNullOrWhiteSpace($txtSectionString)) {
                try { $txtSectionString | Add-Content -Path $Global:EitinLogTxtPath -Encoding UTF8 -ErrorAction Stop }
                catch { Write-Warning "Falha ao escrever seção TXT '$SectionTitle': $($_.Exception.Message)" }
            }
        }

        # Prepara o corpo do HTML (Sempre processa pois é usado para ambos os HTMLs)
        # Se NENHUM HTML estiver habilitado, poderiamos pular, mas o custo é baixo e simplifica a lógica.
        [void]$Global:EitinHtmlSectionTitles.Add($SectionTitle)
        $sectionBodyHtml = Format-EitinDataToHtmlSectionBody -Data $Data -SectionTitleForContext $SectionTitle -IsPreformatted:$IsPreformatted
        $Global:EitinHtmlReportSections[$SectionTitle] = $sectionBodyHtml

        # Exporta a seção para CSV (APENAS SE HABILITADO)
        if ($Global:EitinReportSettings.GenerateCsv) {
            try {
                if ($Data -is [hashtable] -or $Data -is [System.Management.Automation.PSCustomObject]) {
                    $hasSubTables = $false
                    foreach ($prop in $Data.psobject.properties) {
                        if ($prop.Value -is [array] -and $prop.Value.Count -gt 0 -and ($prop.Value[0] -is [hashtable] -or $prop.Value[0] -is [System.Management.Automation.PSCustomObject])) {
                            $hasSubTables = $true
                            Export-EitinSectionToCsv -Data $prop.Value -SectionTitle "$($SectionTitle)_$($prop.Name)" -CsvDirectoryPath $Global:EitinLogCsvDir
                        }
                    }
                    if (-not $hasSubTables) {
                        Export-EitinSectionToCsv -Data $Data -SectionTitle $SectionTitle -CsvDirectoryPath $Global:EitinLogCsvDir
                    }
                } elseif ($Data -is [array]) {
                    Export-EitinSectionToCsv -Data $Data -SectionTitle $SectionTitle -CsvDirectoryPath $Global:EitinLogCsvDir
                }
            } catch {
                Write-Warning "Falha ao exportar seção '$SectionTitle' para CSV: $($_.Exception.Message)"
            }
        }
    }
}

function Complete-EitinLogs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.TimeSpan]$ExecutionTimeSpanForReport,
        [Parameter(Mandatory = $true)] [string]$ScriptRootPath,
        [Parameter(Mandatory = $false)] [hashtable]$ReportSettings
    )
    process {
        $Global:EitinExecutionTimeSpan = $ExecutionTimeSpanForReport

        # Define defaults if settings not provided
        if (-not $ReportSettings) {
            $ReportSettings = @{
                GenerateTxt = $true
                GenerateHtmlInteractive = $true
                GenerateHtmlPrintable = $true
                GenerateCsv = $true
            }
        }

        # Finaliza o relatório TXT (Se habilitado)
        if ($ReportSettings.GenerateTxt) {
            $txtFooter = Build-EitinTxtReportFooter -ComputerName $Global:EitinComputerName -ReportTimestamp $Global:EitinReportTimestamp -ExecutingUser $Global:EitinExecutingUser -ExecutionTimeSpan $Global:EitinExecutionTimeSpan
            try { $txtFooter | Add-Content -Path $Global:EitinLogTxtPath -Encoding UTF8 -ErrorAction Stop } catch { Write-Warning "Falha ao escrever rodapé TXT: $($_.Exception.Message)" }
        } else {
             # Se desabilitado, limpa o caminho do retorno para não confundir o footer
             $Global:EitinLogTxtPath = $null
        }

        # Gera o relatório HTML Interativo (Se habilitado)
        if ($ReportSettings.GenerateHtmlInteractive) {
            try {
                $cssInteractivePath = Join-Path $ScriptRootPath "Assets\style.css"
                $htmlInteractive = Build-EitinHtmlReport -ComputerName $Global:EitinComputerName -ReportTimestamp $Global:EitinReportTimestamp -ScriptUser $Global:EitinExecutingUser -SectionTitlesForSidebar $Global:EitinHtmlSectionTitles -SectionHtmlBodies $Global:EitinHtmlReportSections -CssPath $cssInteractivePath -ExecutionTime $Global:EitinExecutionTimeSpan
                if (-not [string]::IsNullOrWhiteSpace($htmlInteractive)) { $htmlInteractive | Out-File -FilePath $Global:EitinLogHtmlPath -Encoding UTF8 -Force }
            } catch {
                Write-Warning "Falha ao gerar o relatório HTML Interativo: $($_.Exception.Message)"
            }
        } else {
            $Global:EitinLogHtmlPath = $null
        }

        # Gera o relatório HTML para Impressão (Se habilitado)
        if ($ReportSettings.GenerateHtmlPrintable) {
            try {
                $cssPrintPath = Join-Path $ScriptRootPath "Assets\print-style.css"
                $htmlPrintable = Build-EitinPrintableHtmlReport -ComputerName $Global:EitinComputerName -ReportTimestamp $Global:EitinReportTimestamp -ScriptUser $Global:EitinExecutingUser -SectionTitles $Global:EitinHtmlSectionTitles -SectionHtmlBodies $Global:EitinHtmlReportSections -PrintCssPath $cssPrintPath -ExecutionTime $Global:EitinExecutionTimeSpan
                if (-not [string]::IsNullOrWhiteSpace($htmlPrintable)) { $htmlPrintable | Out-File -FilePath $Global:EitinPrintableHtmlPath -Encoding UTF8 -Force }
            } catch {
                Write-Warning "Falha ao gerar o relatório HTML para Impressão: $($_.Exception.Message)"
            }
        } else {
            $Global:EitinPrintableHtmlPath = $null
        }

        # Retorna todos os caminhos de relatório para o script principal
        return [PSCustomObject]@{
            TxtLogPath         = $Global:EitinLogTxtPath
            HtmlLogPath        = $Global:EitinLogHtmlPath
            PrintableHtmlPath  = $Global:EitinPrintableHtmlPath
            CsvLogPath         = $Global:EitinLogCsvDir
        }
    }
}
