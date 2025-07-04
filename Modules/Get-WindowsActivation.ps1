function Invoke-EitinWindowsActivationInfo {
    [CmdletBinding()]
    param()

    process {
        # Estrutura de dados de saída simplificada e amigável
        $dadosAtivacao = [ordered]@{
            "Status da Ativação" = "Não Determinado"
            "Tipo de Licença"    = "Desconhecido"
            "Chave Parcial"      = "N/A"
            "Detalhes da Ativação" = "N/A"
            "Error"              = $null
        }

        try {
            $licensingProduct = Get-CimInstance -ClassName SoftwareLicensingProduct `
                -Filter "PartialProductKey IS NOT NULL AND ApplicationID = '55c92734-d682-4d71-983e-d6ec3f16059f'" `
                -ErrorAction SilentlyContinue | Select-Object -First 1
            
            $licensingService = Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction SilentlyContinue | Select-Object -First 1

            if ($licensingProduct) {
                # Traduz o status numérico para um texto amigável
                $statusNumeric = Get-SafeProperty -ObjectInstance $licensingProduct -PropertyName 'LicenseStatus' -DefaultValue -1
                $dadosAtivacao."Status da Ativação" = switch ($statusNumeric) {
                    0       { "Não Licenciado" }
                    1       { "Licenciado (Ativado)" }
                    2       { "Em Período de Tolerância Inicial (OOB Grace)" }
                    3       { "Em Período de Tolerância Adicional (Pode não ser Genuíno)" }
                    4       { "Em Notificação (Não Genuíno)" }
                    5       { "Em Período de Tolerância Estendido" }
                    default { "Status Desconhecido (Código WMI: $statusNumeric)" }
                }

                $dadosAtivacao."Chave Parcial" = Get-SafeProperty -ObjectInstance $licensingProduct -PropertyName 'PartialProductKey'
                
                # Lógica aprimorada para determinar o tipo de licença e os detalhes
                $isKms = Get-SafeProperty -ObjectInstance $licensingProduct -PropertyName 'IsKeyManagementServiceLicense' -DefaultValue $false
                $oemKeyInfo = if ($licensingService) { Get-SafeProperty -ObjectInstance $licensingService -PropertyName 'OA3xOriginalProductKeyDescription' } else { "Não Encontrado" }

                if ($isKms) {
                    $dadosAtivacao."Tipo de Licença" = "Volume (KMS)"
                    $kmsHost = if ($licensingService) { Get-SafeProperty -ObjectInstance $licensingService 'KeyManagementServiceHost' } else { "Não Encontrado" }
                    if ($kmsHost -ne "Não Encontrado" -and -not [string]::IsNullOrWhiteSpace($kmsHost)) {
                        $dadosAtivacao."Detalhes da Ativação" = "Ativação gerenciada pelo servidor KMS: $($kmsHost)"
                    } else {
                        $dadosAtivacao."Detalhes da Ativação" = "Licença de volume aguardando contato com servidor KMS."
                    }
                } elseif ($oemKeyInfo -ne "Não Encontrado" -and -not [string]::IsNullOrWhiteSpace($oemKeyInfo)) {
                    $dadosAtivacao."Tipo de Licença" = "OEM"
                    $dadosAtivacao."Detalhes da Ativação" = "Licença pré-instalada pelo fabricante do equipamento."
                } else {
                    $dadosAtivacao."Tipo de Licença" = "Varejo ou Digital"
                    $dadosAtivacao."Detalhes da Ativação" = "Ativado com uma licença digital vinculada à conta ou uma chave de varejo."
                }
                
            } else {
                $dadosAtivacao."Status da Ativação" = "Produto Windows principal não encontrado via WMI."
            }

            $dadosAtivacao.Error = $null 
        }
        catch {
            $errorMessage = "Erro ao coletar informações de ativação do Windows: $($_.Exception.Message)" 
            Write-Warning $errorMessage
            $dadosAtivacao."Status da Ativação" = "Erro na Coleta" 
            $dadosAtivacao."Detalhes da Ativação" = $errorMessage 
            $dadosAtivacao.Error = $errorMessage
        }
        
        # Limpa a propriedade de erro se nenhum erro ocorreu
        if ($dadosAtivacao.PSObject.Properties['Error'] -ne $null -and $null -eq $dadosAtivacao.Error) {
            $propriedadesLimpas = [ordered]@{}
            foreach ($propriedade in $dadosAtivacao.PSObject.Properties) {
                if ($propriedade.Name -ne 'Error') {
                    $propriedadesLimpas[$propriedade.Name] = $propriedade.Value
                }
            }
            return [PSCustomObject]$propriedadesLimpas
        }

        return [PSCustomObject]$dadosAtivacao
    }
}