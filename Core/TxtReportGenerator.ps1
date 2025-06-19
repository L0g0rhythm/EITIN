# EITIN_Modular/Core/TxtReportGenerator.ps1

function Build-EitinTxtReportHeader {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$ComputerName)
    process {
        $titleLine = "EITIN - Inventário de TI Elevado"
        $lineLength = 70
        $paddingTitle = [math]::Max(0, ([int](($lineLength - $titleLine.Length) / 2)))
        $centeredTitle = (" " * $paddingTitle) + $titleLine
        return @"
$($("=" * $lineLength))
$($centeredTitle)
$($("=" * $lineLength))

"@
    }
}

function Format-EitinDataToTxtSection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$SectionTitle,
        [Parameter(Mandatory = $true)][AllowNull()][AllowEmptyCollection()]$Data
    )
    process {
        $output = New-Object System.Text.StringBuilder
        $lineLength = 70
        $labelWidth = 45
        $sectionTitleUpper = $SectionTitle.ToUpper()
        $paddingTitle = [math]::Max(0, ([int](($lineLength - $sectionTitleUpper.Length - 4) / 2)))
        [void]$output.AppendLine($("-" * $lineLength))
        [void]$output.AppendLine((" " * $paddingTitle) + "[ $($sectionTitleUpper) ]")
        [void]$output.AppendLine($("-" * $lineLength))

        $indentUnit = "  "

        # Função auxiliar interna para formatar um objeto simples (chave-valor)
        function Format-ObjectProperties {
            param($ItemObject, $CurrentIndent, $LocalLabelWidth)
            $propOutput = New-Object System.Text.StringBuilder
            if ($null -eq $ItemObject -or $null -eq $ItemObject.PSObject -or $null -eq $ItemObject.PSObject.Properties) {
                [void]$propOutput.AppendLine("${CurrentIndent}Erro: Objeto de dados inválido ou nulo recebido para formatação.")
                return $propOutput.ToString()
            }
            $props = $ItemObject.PSObject.Properties
            if ($props['Error'] -ne $null -and -not [string]::IsNullOrWhiteSpace($ItemObject.Error)) {
                $errorLabel = "Erro"; $errorValue = $ItemObject.Error
                if ($props['Detalhe'] -ne $null -and -not [string]::IsNullOrWhiteSpace($ItemObject.Detalhe)) { $errorValue += " (Detalhe: $($ItemObject.Detalhe))" }
                $padding = "." * [math]::Max(1, $LocalLabelWidth - $errorLabel.Length - 2)
                [void]$propOutput.AppendLine("${CurrentIndent}$($errorLabel)$padding : $($errorValue)")
            } elseif ($props['Informação'] -ne $null -and -not [string]::IsNullOrWhiteSpace($ItemObject.Informação)) {
                $infoLabel = "Informação"; $infoValue = $ItemObject.Informação
                $padding = "." * [math]::Max(1, $LocalLabelWidth - $infoLabel.Length - 2)
                [void]$propOutput.AppendLine("${CurrentIndent}$($infoLabel)$padding : $($infoValue)")
            } else {
                foreach ($prop in $props) {
                    if ($prop.Name -in @('Error', 'Informação')) { continue }
                    $lbl = "$($prop.Name)"
                    $val = if ($null -eq $prop.Value) { "N/A" } elseif ($prop.Value -is [array]) { $prop.Value -join "; " } else { "$($prop.Value)" }
                    $padding = "." * [math]::Max(1, $LocalLabelWidth - $lbl.Length - 2)
                    [void]$propOutput.AppendLine("${CurrentIndent}$($lbl)$padding : $($val)")
                }
            }
            return $propOutput.ToString()
        }

        if ($null -eq $Data) {
            [void]$output.AppendLine("${indentUnit}Nenhum dado coletado para esta seção.")
        } elseif ($Data -is [string]) {
            [void]$output.AppendLine("${indentUnit}$Data")
        } elseif ($Data -is [array]) {
            if ($Data.Count -eq 0) { [void]$output.AppendLine("${indentUnit}(Nenhum item para exibir nesta seção)") }
            else {
                $itemIndex = 0
                foreach ($item in $Data) {
                    $itemIndex++
                    $itemIndent = $indentUnit
                    if ($Data.Count -gt 1) {
                        if ($itemIndex -gt 1) { [void]$output.AppendLine() }
                        [void]$output.AppendLine("${indentUnit}Item ${itemIndex}:")
                        $itemIndent = $indentUnit + "  "
                    }
                    if ($item -is [System.Management.Automation.PSCustomObject]) {
                        [void]$output.Append((Format-ObjectProperties -ItemObject $item -CurrentIndent $itemIndent -LocalLabelWidth ($labelWidth - $itemIndent.Length)))
                    } else { [void]$output.AppendLine("${itemIndent}$item") }
                }
            }
        } elseif ($Data -is [hashtable] -or $Data -is [System.Management.Automation.PSCustomObject]) {
            [void]$output.Append((Format-ObjectProperties -ItemObject $Data -CurrentIndent $indentUnit -LocalLabelWidth ($labelWidth - $indentUnit.Length)))
        } else {
            [void]$output.AppendLine("${indentUnit}(Formato de dados não processável para TXT)")
        }
        [void]$output.AppendLine()
        return $output.ToString()
    }
}

function Build-EitinTxtReportFooter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ComputerName,
        [Parameter(Mandatory = $true)][string]$ReportTimestamp,
        [Parameter(Mandatory = $true)][string]$ExecutingUser,
        [Parameter(Mandatory = $true)][System.TimeSpan]$ExecutionTimeSpan
    )
    process {
        $lineLength = 70; $labelWidthFooter = 35; $footerIndent = "  "
        $timeString = "Não calculado"
        if ($ExecutionTimeSpan) {
            if ($ExecutionTimeSpan.TotalHours -ge 1) { $timeString = "{0:0}h {1:0}m {2:0}s" -f $ExecutionTimeSpan.Hours, $ExecutionTimeSpan.Minutes, $ExecutionTimeSpan.Seconds }
            elseif ($ExecutionTimeSpan.TotalMinutes -ge 1) { $timeString = "{0:0}m {1:0}s" -f $ExecutionTimeSpan.Minutes, $ExecutionTimeSpan.Seconds }
            elseif ($ExecutionTimeSpan.TotalSeconds -ge 1) { $timeString = "{0:0.0}s" -f $ExecutionTimeSpan.TotalSeconds }
            else { $timeString = "$($ExecutionTimeSpan.TotalMilliseconds)ms" }
        }
        
        $details = New-Object System.Text.StringBuilder
        [void]$details.AppendLine($("-" * $lineLength))
        [void]$details.AppendLine("EITIN - Inventário de TI Elevado © $(Get-Date -Format 'yyyy')")
        
        # Bloco formatado com os créditos
        $labelsAndValues = @{
            "Gerado para"         = $ComputerName
            "Gerado em"           = $ReportTimestamp
            "Executado por"       = $ExecutingUser
            "Tempo de Execução"   = $timeString
            "Desenvolvido por"    = "L0g0rhythm (https://www.l0g0rhythm.com.br/)"
        }
        foreach($entry in $labelsAndValues.GetEnumerator() | Sort-Object Name){
            $lbl = $entry.Name; $val = $entry.Value
            $paddingDots = "." * [math]::Max(1, $labelWidthFooter - $lbl.Length - 2)
            [void]$details.AppendLine("${footerIndent}$($lbl)$paddingDots : $($val)")
        }
        [void]$details.AppendLine($("-" * $lineLength))
        return $details.ToString() + "`n=================================================`n            FIM DO RELATÓRIO DE INVENTÁRIO`n================================================="
    }
}