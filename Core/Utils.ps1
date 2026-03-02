function Get-SafeProperty {
    [CmdletBinding()]
    param(
        [AllowNull()] # Modificado: Permite que $ObjectInstance seja nulo
        $ObjectInstance,
        [Parameter(Mandatory = $true)]
        [string]$PropertyName,
        [string]$DefaultValue = "Não Encontrado"
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
            return "Não Disponível"
        }

        $outputDateFormatWithTime = "dd/MM/yyyy HH:mm:ss"
        $outputDateFormatNoTime = "dd/MM/yyyy"

        # WMI CIM DateTime (YYYYMMDDHHMMSS.mmmmmmsUUU)
        if ($WmiDate -match '^\d{14}\.\d{6}[\+\-]\d{3}$') {
            try { return ([System.Management.ManagementDateTimeConverter]::ToDateTime($WmiDate)).ToString($outputDateFormatWithTime) } catch {}
        }

        # WMI Compact (YYYYMMDDHHMMSS)
        if ($WmiDate -match '^\d{14}$') {
            try { return ([datetime]::ParseExact($WmiDate, "yyyyMMddHHmmss", $null)).ToString($outputDateFormatWithTime) } catch {}
        }

        # Legacy/Text Format (MM/dd/yyyy HH:mm:ss)
        if ($WmiDate -match '^\d{2}/\d{2}/\d{4}\s\d{2}:\d{2}:\d{2}$') {
            try {
                return ([datetime]::ParseExact($WmiDate, "MM/dd/yyyy HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture)).ToString($outputDateFormatWithTime)
            } catch {}
        }

        # InstallDate (YYYYMMDD)
        if ($WmiDate -match '^\d{8}$') {
            try { return ([datetime]::ParseExact($WmiDate, "yyyyMMdd", $null)).ToString($outputDateFormatNoTime) } catch {}
        }

        # Generic Fallback
        try {
            $parsedDate = Get-Date $WmiDate -ErrorAction Stop
            if ($WmiDate -match '\d{2}:\d{2}(:\d{2})?' ) {
                return $parsedDate.ToString($outputDateFormatWithTime)
            } else {
                return $parsedDate.ToString($outputDateFormatNoTime)
            }
        } catch {
            return "$WmiDate (Erro na Conversão)"
        }
    }
}
