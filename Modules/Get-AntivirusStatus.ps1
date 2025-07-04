function Invoke-EitinAntivirusStatusInfo {
    [CmdletBinding()]
    param()

    process {
        $collectedAvList = New-Object System.Collections.ArrayList
        $errorMessage = $null

        try {
            $avProductsWmi = Get-CimInstance -Namespace "root\SecurityCenter2" -ClassName AntiVirusProduct -ErrorAction SilentlyContinue 

            if ($avProductsWmi) {
                foreach ($av in $avProductsWmi) { 
                    $avNameValue = Get-SafeProperty $av 'displayName' "Antivírus Desconhecido"
                    $productStateRaw = Get-SafeProperty $av 'productState' 0
                    
                    $stateHex = ($productStateRaw -band 0xFFF0).ToString('X4') 
                    $statusDescTraduzido = switch ($stateHex) { 
                        "1000" { "Ativo e Atualizado" }  
                        "1100" { "Ativo (Modo Adiado/Silencioso)" } 
                        "0100" { "Inativo ou Desatualizado" } 
                        default { "Estado Desconhecido (WMI Hex: $stateHex, Decimal: $productStateRaw)" } 
                    }
                    
                    $avDetails = [ordered]@{
                        "Nome do Antivírus"         = $avNameValue
                        "Situação Registrada (WMI)" = $statusDescTraduzido
                    }
                    [void]$collectedAvList.Add([PSCustomObject]$avDetails)
                }
            }

            $defenderListedByWMI = $collectedAvList | Where-Object { $_."Nome do Antivírus" -match "Windows Defender" }
            if ($collectedAvList.Count -eq 0 -or -not $defenderListedByWMI) {
                $defenderService = Get-Service -Name "WinDefend" -ErrorAction SilentlyContinue 
                if ($defenderService) { 
                    $statusServicoDefender = switch($defenderService.Status){
                        "Running" {"Em Execução"}
                        "Stopped" {"Parado"}
                        "Paused"  {"Pausado"}
                        default   {$defenderService.Status}
                    }
                    $defenderDetails = [ordered]@{
                        "Nome do Antivírus"         = "Windows Defender (Status do Serviço)" 
                        "Situação Registrada (WMI)" = $statusServicoDefender
                    }
                    [void]$collectedAvList.Add([PSCustomObject]$defenderDetails)
                }
            }
            
            if ($collectedAvList.Count -eq 0) {
                $errorMessage = "Nenhum antivírus encontrado via WMI/SecurityCenter2 e serviço WinDefend não detectado."
                return @([PSCustomObject]@{ 
                    "Nome do Antivírus" = "Não Encontrado"; 
                    "Detalhe"           = $errorMessage;
                    "Error"             = $errorMessage 
                })
            }

        }
        catch {
            $errorMessage = "Erro ao coletar status do antivírus: $($_.Exception.Message)" 
            Write-Warning $errorMessage
            return @([PSCustomObject]@{ 
                "Nome do Antivírus" = "Erro na Coleta";
                "Detalhe"           = $errorMessage;
                "Error"             = $errorMessage 
            }) 
        }

        $uniqueAvList = $collectedAvList | Sort-Object "Nome do Antivírus", "Situação Registrada (WMI)" | Get-Unique -AsString

        $finalList = New-Object System.Collections.ArrayList
        $seen = New-Object System.Collections.Generic.HashSet[string]
        
        foreach ($item in $collectedAvList) {
            $signature = "$($item."Nome do Antivírus")|$($item."Situação Registrada (WMI)")"
            if ($seen.Add($signature)) {
                [void]$finalList.Add($item)
            }
        }

        if ($finalList.Count -eq 0) {
             $errorMessage = "Nenhum antivírus único detectado após processamento."
             return @([PSCustomObject]@{ 
                "Nome do Antivírus" = "Nenhum Antivírus Único" 
                "Detalhe"           = $errorMessage
                "Error"             = $errorMessage 
            })
        }

        return $finalList.ToArray()
    }
}