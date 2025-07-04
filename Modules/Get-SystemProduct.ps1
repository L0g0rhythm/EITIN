function Invoke-EitinSystemProductInfo {
    [CmdletBinding()]
    param()

    process {
        $dadosProduto = [ordered]@{
            "Fabricante do Sistema"     = "Não Encontrado"
            "Modelo do Sistema"         = "Não Encontrado"
            "UUID do Sistema"           = "Não Encontrado"
            "Error"                     = $null
        }

        try {
            $csProduct = Get-CimInstance -ClassName Win32_ComputerSystemProduct -Property Name, Vendor, IdentifyingNumber, UUID -ErrorAction Stop
            $biosInfoForSerial = Get-CimInstance -ClassName Win32_BIOS -Property SerialNumber -ErrorAction SilentlyContinue 

            $fabricante = Get-SafeProperty -ObjectInstance $csProduct -PropertyName 'Vendor'
            $dadosProduto."Fabricante do Sistema" = $fabricante
            $dadosProduto."Modelo do Sistema"     = Get-SafeProperty -ObjectInstance $csProduct -PropertyName 'Name'
            $dadosProduto."UUID do Sistema"      = Get-SafeProperty -ObjectInstance $csProduct -PropertyName 'UUID'

            $identifyingNumFromCSP = Get-SafeProperty -ObjectInstance $csProduct -PropertyName 'IdentifyingNumber'
            $serialNumFromBios     = Get-SafeProperty -ObjectInstance $biosInfoForSerial -PropertyName 'SerialNumber'

            if ($fabricante -match "Dell") {
                $dadosProduto."Etiqueta de Serviço Dell (Service Tag)" = $serialNumFromBios
                
                if ($identifyingNumFromCSP -ne "Não Encontrado" -and $identifyingNumFromCSP -and $identifyingNumFromCSP -ne $serialNumFromBios) {
                    $dadosProduto."Número de Série Principal" = $identifyingNumFromCSP 
                    $dadosProduto."Observação do Serial (Dell)" = "Número de Série Principal (do Win32_ComputerSystemProduct) difere da Service Tag (do BIOS)."
                } elseif ($identifyingNumFromCSP -ne "Não Encontrado" -and $identifyingNumFromCSP -and $identifyingNumFromCSP -eq $serialNumFromBios) {
                    $dadosProduto."Número de Série Principal" = "Etiqueta de Serviço Dell"
                    $dadosProduto."Observação do Serial (Dell)" = "Número de Série Principal é idêntico à Etiqueta de Serviço Dell."
                } else {
                    $dadosProduto."Número de Série Principal" = $serialNumFromBios
                }
            } else {
                if ($identifyingNumFromCSP -ne "Não Encontrado" -and $identifyingNumFromCSP) {
                    $dadosProduto."Número de Série Principal" = $identifyingNumFromCSP
                } elseif ($serialNumFromBios -ne "Não Encontrado" -and $serialNumFromBios) {
                    $dadosProduto."Número de Série Principal" = $serialNumFromBios
                } else {
                    $dadosProduto."Número de Série Principal" = "Não Encontrado"
                }
            }
            $dadosProduto.Error = $null
        }
        catch {
            $errorMessage = "Erro ao coletar informações do produto do sistema: $($_.Exception.Message)"
            Write-Warning $errorMessage
            $dadosProduto."Fabricante do Sistema" = $errorMessage 
            $dadosProduto.Error = $errorMessage
        }

        if ($dadosProduto.PSObject.Properties['Error'] -ne $null -and $null -eq $dadosProduto.Error) {
            $propriedadesLimpas = [ordered]@{}
            foreach ($propriedade in $dadosProduto.PSObject.Properties) {
                if ($propriedade.Name -ne 'Error') {
                    $propriedadesLimpas[$propriedade.Name] = $propriedade.Value
                }
            }
            return [PSCustomObject]$propriedadesLimpas
        }

        return [PSCustomObject]$dadosProduto
    }
}