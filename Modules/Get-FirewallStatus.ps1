function Invoke-EitinFirewallStatusInfo {
    [CmdletBinding()]
    param()

    process {
        $firewallStatuses = New-Object System.Collections.ArrayList
        $errorMessage = $null 

        try {
            $fwProfiles = Get-NetFirewallProfile -Name Domain, Public, Private -ErrorAction Stop |
                          Select-Object -Property Name, Enabled, DefaultInboundAction, DefaultOutboundAction
            
            if ($fwProfiles) {
                foreach ($profile in $fwProfiles) { 
                    $statusString = if ($profile.Enabled) { "Habilitado (Ativo)" } else { "Desabilitado (Inativo)" }
                    
                    $profileNamePtBr = switch ($profile.Name) {
                        "Domain"  { "Domínio" }
                        "Private" { "Particular" }
                        "Public"  { "Público" }
                        default   { Get-SafeProperty -ObjectInstance $profile -PropertyName 'Name' } 
                    }

                    $inboundActionRaw = Get-SafeProperty -ObjectInstance $profile -PropertyName 'DefaultInboundAction'
                    $inboundActionFriendly = switch ($inboundActionRaw) {
                        "Block"         { "Bloquear (Padrão Recomendado)" } # Traduzido e com explicação
                        "Allow"         { "Permitir (Não Recomendado)" }    # Traduzido e com explicação
                        "NotConfigured" { "Bloquear (Padrão do Sistema)" } # Explicação amigável
                        default         { $inboundActionRaw }
                    }

                    $outboundActionRaw = Get-SafeProperty -ObjectInstance $profile -PropertyName 'DefaultOutboundAction'
                    $outboundActionFriendly = switch ($outboundActionRaw) {
                        "Block"         { "Bloquear (Restritivo)" }           # Traduzido e com explicação
                        "Allow"         { "Permitir (Padrão Recomendado)" }   # Traduzido e com explicação
                        "NotConfigured" { "Permitir (Padrão do Sistema)" }  # Explicação amigável
                        default         { $outboundActionRaw }
                    }

                    $profileStatus = [ordered]@{
                        "Nome do Perfil (Firewall)" = $profileNamePtBr
                        "Status do Perfil"          = $statusString
                        "Ação Padrão de Entrada"    = $inboundActionFriendly   
                        "Ação Padrão de Saída"      = $outboundActionFriendly    
                    }
                    [void]$firewallStatuses.Add([PSCustomObject]$profileStatus)
                }
            } else {
                throw "Get-NetFirewallProfile não retornou perfis."
            }
        }
        catch {
            $warningMessage = "Get-NetFirewallProfile falhou. Tentando método COM legado. Erro: $($_.Exception.Message)"
            Write-Warning $warningMessage 

            try {
                $legacyFwMgr = New-Object -ComObject HNetCfg.FwMgr -ErrorAction Stop 
                $currentProfile = $legacyFwMgr.LocalPolicy.CurrentProfile 
                $legacyStatusString = if ($currentProfile.FirewallEnabled) { "Habilitado (Ativo)" } else { "Desabilitado (Inativo)" } 
                $legacyProfileName = "Perfil Atual (Método Legado COM)"

                $legacyStatus = [ordered]@{
                    "Nome do Perfil (Firewall)" = $legacyProfileName
                    "Status do Perfil"          = $legacyStatusString
                    "Ação Padrão de Entrada"    = "Não disponível via método legado" 
                    "Ação Padrão de Saída"      = "Não disponível via método legado" 
                }
                [void]$firewallStatuses.Add([PSCustomObject]$legacyStatus)
            }
            catch {
                $errorMessage = "Erro ao buscar status do firewall (ambos os métodos falharam): $($_.Exception.Message)" 
                Write-Warning $errorMessage 
                [void]$firewallStatuses.Clear() 
                [void]$firewallStatuses.Add([PSCustomObject]@{
                    "Nome do Perfil (Firewall)" = "Erro na Coleta"
                    "Status do Perfil"          = $errorMessage
                    "Error"                     = $errorMessage 
                })
            }
        }

        if ($firewallStatuses.Count -eq 0 -and -not $errorMessage) {
             [void]$firewallStatuses.Add([PSCustomObject]@{
                "Nome do Perfil (Firewall)" = "Não Determinado"
                "Status do Perfil"          = "Não foi possível determinar o status do firewall."
                "Error"                     = "Nenhuma informação de status do firewall pôde ser determinada."
            })
        }
        
        if ($firewallStatuses.Count -eq 1 -and $firewallStatuses[0].PSObject.Properties['Error'] -ne $null -and $firewallStatuses[0].Error) {
            return $firewallStatuses[0] 
        }

        return $firewallStatuses.ToArray()
    }
}