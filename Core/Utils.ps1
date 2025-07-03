function Get-SafeProperty {
    [CmdletBinding()]
    param(
        [AllowNull()] # Modificado: Permite que $ObjectInstance seja nulo
        $ObjectInstance,
        [Parameter(Mandatory = $true)]
        [string]$PropertyName,
        [string]$DefaultValue = "Não Encontrado" # Modificado: Valor padrão traduzido
    )

    process {
        if ($null -eq $ObjectInstance) {
            return $DefaultValue
        }

        # Tenta obter a propriedade. Silencia o erro se a propriedade não existir.
        $propertyValue = $ObjectInstance | Select-Object -ExpandProperty $PropertyName -ErrorAction SilentlyContinue

        if ($null -ne $propertyValue) {
            # Se a propriedade existir, mas seu valor for uma string que consiste apenas de espaços em branco,
            # ou for uma string vazia, retorna o valor padrão.
            if ($propertyValue -is [string] -and [string]::IsNullOrWhiteSpace($propertyValue)) {
                return $DefaultValue 
            }
            # Caso contrário, retorna o valor da propriedade (pode ser $false, 0 ou uma string populada)
            return $propertyValue
        } else {
            # Propriedade não encontrada ou seu valor era explicitamente $null
            return $DefaultValue 
        }
    }
}

function Convert-WmiDate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WmiDate 
    )

    process {
        if (-not $WmiDate -or [string]::IsNullOrWhiteSpace($WmiDate)) {
            return "Não Disponível" # Traduzido
        }

        # Define os formatos de saída desejados (padrão brasileiro)
        $outputDateFormatWithTime = "dd/MM/yyyy HH:mm:ss"
        $outputDateFormatNoTime = "dd/MM/yyyy"

        # Tenta o formato padrão WMI CIM DateTime (ex: 20230515103000.123456-180)
        if ($WmiDate -match '^\d{14}\.\d{6}[\+\-]\d{3}$') {
            try {
                return ([System.Management.ManagementDateTimeConverter]::ToDateTime($WmiDate)).ToString($outputDateFormatWithTime)
            } catch { /* Silencia e tenta o próximo formato se este falhar */ }
        }

        # Tenta o formato WMI comum yyyyMMddHHmmss (sem separadores ou sub-segundos)
        if ($WmiDate -match '^\d{14}$') {
            try {
                return ([datetime]::ParseExact($WmiDate, "yyyyMMddHHmmss", $null)).ToString($outputDateFormatWithTime)
            } catch { /* Silencia e tenta o próximo formato */ }
        }
        
        # Tenta o formato MM/dd/yyyy HH:mm:ss (observado em algumas saídas de debug anteriores)
        # Útil como fallback se outras conversões WMI diretas falharem e a data vier neste formato
        if ($WmiDate -match '^\d{2}/\d{2}/\d{4}\s\d{2}:\d{2}:\d{2}$') {
            try {
                # Usa CultureInfo.InvariantCulture para garantir que '/' seja o separador de data
                $culture = [System.Globalization.CultureInfo]::InvariantCulture 
                return ([datetime]::ParseExact($WmiDate, "MM/dd/yyyy HH:mm:ss", $culture)).ToString($outputDateFormatWithTime)
            } catch { /* Silencia e tenta o próximo formato */ }
        }

        # Tenta o formato yyyyMMdd (comum para InstallDate de software no registro)
        if ($WmiDate -match '^\d{8}$') {
            try {
                return ([datetime]::ParseExact($WmiDate, "yyyyMMdd", $null)).ToString($outputDateFormatNoTime)
            } catch { /* Silencia e tenta o próximo formato */ }
        }
        
        # Última tentativa com Get-Date para formatos mais genéricos que ele possa reconhecer
        # Se a data original continha informações de hora, tenta manter. Caso contrário, só data.
        try {
            $parsedDate = Get-Date $WmiDate -ErrorAction Stop # Tenta parsear diretamente
            if ($WmiDate -match '\d{2}:\d{2}(:\d{2})?' ) { # Verifica se a string original continha HH:mm ou HH:mm:ss
                return $parsedDate.ToString($outputDateFormatWithTime)
            } else {
                return $parsedDate.ToString($outputDateFormatNoTime)
            }
        } catch {
            # Se todas as tentativas de parsing falharem
            return "$WmiDate (Erro na Conversão)" # Traduzido
        }
    }
}
