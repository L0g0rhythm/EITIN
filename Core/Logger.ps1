# EITIN_Modular/Core/Logger.ps1 - Versão Final Consolidada e Aprimorada

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
#endregion

#region Core Logging Functions

function Initialize-EitinLogs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$OutputDirectory,
        [Parameter(Mandatory = $true)] [string]$ComputerName,
        [Parameter(Mandatory = $true)] [string]$ScriptUser
    )
    process {
        $Global:EitinComputerName = $ComputerName
        $Global:EitinReportTimestamp = (Get-Date).ToString('dd/MM/yyyy HH:mm:ss')
        $Global:EitinExecutingUser = $ScriptUser
        $simpleUserName = ($ScriptUser -split '[\\/]')[-1]

        # Constrói o caminho completo para a pasta de logs do usuário
        $userAndMachineLogFolder = Join-Path -Path $OutputDirectory -ChildPath "Logs\$ComputerName\$simpleUserName"
        try {
            if (-not (Test-Path $userAndMachineLogFolder)) {
                New-Item -Path $userAndMachineLogFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
        }
        catch {
            throw "FATAL: Não foi possível criar o diretório de log '$userAndMachineLogFolder'. Erro: $($_.Exception.Message)"
        }
        
        # Cria a subpasta para relatórios CSV, limpando execuções anteriores
        $Global:EitinLogCsvDir = Join-Path -Path $userAndMachineLogFolder -ChildPath "CSV_Reports"
        try {
            if (Test-Path $Global:EitinLogCsvDir) { Remove-Item -Path $Global:EitinLogCsvDir -Recurse -Force }
            New-Item -Path $Global:EitinLogCsvDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        } catch {
            throw "FATAL: Não foi possível criar o diretório para CSVs: '$($Global:EitinLogCsvDir)'. Erro: $($_.Exception.Message)"
        }

        # Define os nomes de arquivo baseados na sua especificação
        $baseLogFileName = "$($ComputerName)_$($simpleUserName)"
        $Global:EitinLogTxtPath = Join-Path -Path $userAndMachineLogFolder -ChildPath "$($baseLogFileName).txt"
        $Global:EitinLogHtmlPath = Join-Path -Path $userAndMachineLogFolder -ChildPath "$($baseLogFileName)_Interativo.html"
        $Global:EitinPrintableHtmlPath = Join-Path -Path $userAndMachineLogFolder -ChildPath "$($baseLogFileName)_Imprimivel.html"

        # Limpa coleções e arquivos de execuções anteriores
        $Global:EitinHtmlReportSections.Clear(); [void]$Global:EitinHtmlSectionTitles.Clear()
        if (Test-Path $Global:EitinLogHtmlPath) { Remove-Item $Global:EitinLogHtmlPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path $Global:EitinPrintableHtmlPath) { Remove-Item $Global:EitinPrintableHtmlPath -Force -ErrorAction SilentlyContinue }
        
        # Inicializa o relatório TXT
        $txtHeader = Build-EitinTxtReportHeader -ComputerName $Global:EitinComputerName
        try {
            $txtHeader | Out-File -FilePath $Global:EitinLogTxtPath -Encoding UTF8 -Force -ErrorAction Stop
        }
        catch {
            throw "FATAL: Falha ao escrever no log TXT '$($Global:EitinLogTxtPath)'. Erro: $($_.Exception.Message)"
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
        # Adiciona ao log TXT
        $txtSectionString = Format-EitinDataToTxtSection -SectionTitle $SectionTitle -Data $Data
        if (-not [string]::IsNullOrWhiteSpace($txtSectionString)) {
            try { $txtSectionString | Add-Content -Path $Global:EitinLogTxtPath -Encoding UTF8 -ErrorAction Stop }
            catch { Write-Warning "Falha ao escrever seção TXT '$SectionTitle': $($_.Exception.Message)" }
        }

        # Prepara o corpo do HTML para ser usado em ambos os relatórios
        [void]$Global:EitinHtmlSectionTitles.Add($SectionTitle)
        $sectionBodyHtml = Format-EitinDataToHtmlSectionBody -Data $Data -SectionTitleForContext $SectionTitle -IsPreformatted:$IsPreformatted
        $Global:EitinHtmlReportSections[$SectionTitle] = $sectionBodyHtml

        # Exporta a seção para CSV
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

function Finalize-EitinLogs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.TimeSpan]$ExecutionTimeSpanForReport,
        [Parameter(Mandatory = $true)] [string]$ScriptRootPath
    )
    process {
        $Global:EitinExecutionTimeSpan = $ExecutionTimeSpanForReport
        
        # Finaliza o relatório TXT
        $txtFooter = Build-EitinTxtReportFooter -ComputerName $Global:EitinComputerName -ReportTimestamp $Global:EitinReportTimestamp -ExecutingUser $Global:EitinExecutingUser -ExecutionTimeSpan $Global:EitinExecutionTimeSpan
        try { $txtFooter | Add-Content -Path $Global:EitinLogTxtPath -Encoding UTF8 -ErrorAction Stop } catch { Write-Warning "Falha ao escrever rodapé TXT: $($_.Exception.Message)" }
        
        # Gera o relatório HTML Interativo
        try {
            $cssInteractivePath = Join-Path $ScriptRootPath "Assets\style.css"
            $htmlInteractive = Build-EitinHtmlReport -ComputerName $Global:EitinComputerName -ReportTimestamp $Global:EitinReportTimestamp -ScriptUser $Global:EitinExecutingUser -SectionTitlesForSidebar $Global:EitinHtmlSectionTitles -SectionHtmlBodies $Global:EitinHtmlReportSections -CssPath $cssInteractivePath -ExecutionTime $Global:EitinExecutionTimeSpan
            if (-not [string]::IsNullOrWhiteSpace($htmlInteractive)) { $htmlInteractive | Out-File -FilePath $Global:EitinLogHtmlPath -Encoding UTF8 -Force }
        } catch {
            Write-Warning "Falha ao gerar o relatório HTML Interativo: $($_.Exception.Message)"
        }

        # Gera o relatório HTML para Impressão
        try {
            $cssPrintPath = Join-Path $ScriptRootPath "Assets\print-style.css"
            $htmlPrintable = Build-EitinPrintableHtmlReport -ComputerName $Global:EitinComputerName -ReportTimestamp $Global:EitinReportTimestamp -ScriptUser $Global:EitinExecutingUser -SectionTitles $Global:EitinHtmlSectionTitles -SectionHtmlBodies $Global:EitinHtmlReportSections -PrintCssPath $cssPrintPath -ExecutionTime $Global:EitinExecutionTimeSpan
            if (-not [string]::IsNullOrWhiteSpace($htmlPrintable)) { $htmlPrintable | Out-File -FilePath $Global:EitinPrintableHtmlPath -Encoding UTF8 -Force }
        } catch {
            Write-Warning "Falha ao gerar o relatório HTML para Impressão: $($_.Exception.Message)"
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
#endregion