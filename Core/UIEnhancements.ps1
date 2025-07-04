# um cabeçalho formatado e centralizado no console.
function Write-EitinHeader {
    [CmdletBinding()]
    param(
        [string]$ScriptTitle = "EITIN - Inventário de TI Elevado"
    )
    process {
        $lineLength = 70
        Write-Host ("=" * $lineLength) -ForegroundColor Cyan
        $paddingTitle = [math]::Max(0, ([int](($lineLength - $ScriptTitle.Length) / 2)))
        Write-Host (" " * $paddingTitle) -NoNewline
        Write-Host $ScriptTitle -ForegroundColor White
        Write-Host ("=" * $lineLength) -ForegroundColor Cyan
        Write-Host ""
    }
}

# Escreve o início de uma nova seção de coleta no console.
function Write-EitinSectionStart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SectionTitle
    )
    process {
        Write-Host ""
        Write-Host ("-" * 70) -ForegroundColor DarkGray
        Write-Host "⚙️ [COLETANDO] $($SectionTitle)..." -ForegroundColor Yellow
    }
}

# Escreve uma linha de status formatada (INFO, SUCCESS, WARN, ERROR).
function Write-EitinStep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $true)]
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR")]
        [string]$Status
    )
    process {
        $prefix = ""
        $color = "Gray"
        # Prefixo alinhado para melhor legibilidade no console
        switch ($Status) {
            "SUCCESS" { $prefix = "✅ [SUCESSO] "; $color = "Green" }
            "WARN"    { $prefix = "⚠️  [AVISO]   "; $color = "Yellow" }
            "ERROR"   { $prefix = "❌ [ERRO]    "; $color = "Red" }
            "INFO"    { $prefix = "ℹ️  [INFO]    "; $color = "Cyan" }
        }
        Write-Host "$($prefix)$Message" -ForegroundColor $color
    }
}

# Escreve a mensagem de finalização de uma seção, indicando sucesso ou falha.
function Write-EitinSectionEnd {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SectionTitle,
        [Parameter(Mandatory = $true)]
        [bool]$Success,
        [string]$ErrorMessage = ""
    )
    process {
        if ($Success) {
            Write-EitinStep -Message "Coleta para '$($SectionTitle)' finalizada." -Status "SUCCESS"
        } else {
            $fullMessage = "Falha na coleta de dados para: $($SectionTitle)."
            if (-not [string]::IsNullOrEmpty($ErrorMessage)) {
                $fullMessage += " Detalhes: $ErrorMessage"
            }
            Write-EitinStep -Message $fullMessage -Status "ERROR"
        }
    }
}

# Escreve o rodapé final do console, listando os caminhos dos relatórios gerados.
function Write-EitinFooter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.TimeSpan]$ExecutionTime,
        [Parameter(Mandatory = $true)]
        [string]$TxtLogPath,
        [Parameter(Mandatory = $true)]
        [string]$HtmlLogPath,
        [Parameter(Mandatory = $true)]
        [string]$PrintableHtmlPath,
        [Parameter(Mandatory = $true)]
        [string]$CsvLogPath
    )
    process {
        Write-Host ""
        Write-Host ("*" * 70) -ForegroundColor DarkGreen
        Write-EitinStep -Message "EXECUÇÃO DO SCRIPT EITIN E GERAÇÃO DE RELATÓRIOS CONCLUÍDAS" -Status "SUCCESS"
        Write-Host ("*" * 70) -ForegroundColor DarkGreen
        Write-Host ""

        if (-not [string]::IsNullOrWhiteSpace($TxtLogPath)) {
            Write-EitinStep -Message "Relatório TXT gerado em:" -Status "INFO"
            Write-Host "  $TxtLogPath" -ForegroundColor Gray
            Write-Host ""
        }
        if (-not [string]::IsNullOrWhiteSpace($HtmlLogPath)) {
            Write-EitinStep -Message "Relatório HTML Interativo gerado em:" -Status "INFO"
            Write-Host "  $HtmlLogPath" -ForegroundColor Gray
            Write-Host ""
        }
        if (-not [string]::IsNullOrWhiteSpace($PrintableHtmlPath)) {
            Write-EitinStep -Message "Relatório para Impressão/PDF gerado em:" -Status "INFO"
            Write-Host "  $PrintableHtmlPath" -ForegroundColor Gray
            Write-Host ""
        }
        if (-not [string]::IsNullOrWhiteSpace($CsvLogPath)) {
            Write-EitinStep -Message "Relatórios CSV gerados na pasta:" -Status "INFO"
            Write-Host "  $($CsvLogPath)" -ForegroundColor Gray
            Write-Host ""
        }
        
        # Formata e exibe o tempo total de execução.
        $formattedTime = ""
        if ($ExecutionTime.TotalHours -ge 1) {
            $formattedTime = "{0:0}h {1:0}m {2:0}s" -f $ExecutionTime.Hours, $ExecutionTime.Minutes, $ExecutionTime.Seconds
        }
        elseif ($ExecutionTime.TotalMinutes -ge 1) {
            $formattedTime = "{0:0}m {1:0}s" -f $ExecutionTime.Minutes, $ExecutionTime.Seconds
        }
        elseif ($ExecutionTime.TotalSeconds -ge 1) {
            $formattedTime = "{0:0.0}s" -f $ExecutionTime.TotalSeconds
        }
        else {
            $formattedTime = "$($ExecutionTime.TotalMilliseconds)ms"
        }
        Write-Host "⏱️  [TEMPO]   Tempo total de execução: $($formattedTime)" -ForegroundColor Gray
        
        Write-Host ""
        Write-Host "Para um inventário detalhado, por favor, consulte os relatórios gerados." -ForegroundColor Green
        Write-Host ("=" * 70) -ForegroundColor Cyan
        Write-Host ""
    }
}
