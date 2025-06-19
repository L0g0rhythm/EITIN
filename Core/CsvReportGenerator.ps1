# EITIN_Modular/Core/CsvReportGenerator.ps1

function Export-EitinSectionToCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyCollection()]
        $Data,
        [Parameter(Mandatory = $true)]
        [string]$SectionTitle,
        [Parameter(Mandatory = $true)]
        [string]$CsvDirectoryPath
    )

    process {
        if ($null -eq $Data -or $Data -is [string]) {
            Write-Verbose "Seção '$SectionTitle' não contém dados estruturados para exportação CSV. Pulando."
            return
        }

        # Sanitiza o título para um nome de arquivo válido e robusto
        $invalidChars = [System.IO.Path]::GetInvalidFileNameChars() -join ''
        $regexInvalidChars = [regex]::Escape($invalidChars)
        $fileNameFragment = ($SectionTitle -replace "[\s\(\)]+", "_" -replace "[,/\\:]", "_" -replace "_{2,}", "_").Trim("_")
        $fileName = ($fileNameFragment -split "[$regexInvalidChars]") -join ''
        if ($fileName.Length -gt 100) { $fileName = $fileName.Substring(0, 100) }
        $filePath = Join-Path -Path $CsvDirectoryPath -ChildPath "$($fileName).csv"

        try {
            $exportableData = $null
            if ($Data -is [array]) {
                # Se for um array, já está pronto para exportação
                $exportableData = $Data
            } 
            elseif ($Data -is [hashtable] -or $Data -is [System.Management.Automation.PSCustomObject]) {
                # Transforma um objeto simples (chave-valor) em uma tabela de duas colunas para o CSV
                $transformedData = New-Object System.Collections.ArrayList
                $Data.PSObject.Properties | ForEach-Object {
                    # Garante que não exporta propriedades de erro ou que sejam coleções (tratadas separadamente)
                    if ($_.Name -ne 'Error' -and $_.Value -isnot [array] -and $_.Value -isnot [psobject]) {
                        [void]$transformedData.Add([PSCustomObject]@{ Propriedade = $_.Name; Valor = $_.Value })
                    }
                }
                if ($transformedData.Count -gt 0) {
                    $exportableData = $transformedData.ToArray()
                }
            }

            if ($null -ne $exportableData) {
                # Exporta para CSV usando o delimitador ponto e vírgula para compatibilidade com Excel em português
                $exportableData | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8 -Delimiter ';' -ErrorAction Stop
                Write-Verbose "Seção '$SectionTitle' exportada para: $filePath"
            }
        }
        catch {
            # Lança um erro claro para ser capturado pelo Logger, se necessário
            throw "Falha ao exportar a seção '$SectionTitle' para CSV. Erro: $($_.Exception.Message)"
        }
    }
}