function Invoke-EitinNetworkInfo {
    [CmdletBinding()]
    param()

    process {
        $networkAdaptersList = New-Object System.Collections.ArrayList
        
        try {
            # Considera apenas adaptadores que estão "Up" (ativos)
            $activeAdapters = Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq "Up" }

            if ($activeAdapters) {
                $allIpConfigurations = Get-NetIPConfiguration -ErrorAction SilentlyContinue
                $allNetIPInterfaces = Get-NetIPInterface -ErrorAction SilentlyContinue # Necessário para o status do DHCP

                foreach ($adapter in $activeAdapters) {
                    $interfaceIndex = $adapter.InterfaceIndex
                    $ipv4AddressesInfo = New-Object System.Collections.ArrayList
                    $ipv4GatewayInfo = "Não Configurado"
                    $dhcpEnabledInfo = "Não Aplicável"

                    $ipConfig = $allIpConfigurations | Where-Object { $_.InterfaceIndex -eq $interfaceIndex } | Select-Object -First 1
                    
                    if ($ipConfig) {
                        # Coleta apenas os endereços IPv4
                        $validIPv4 = $ipConfig.IPv4Address | Where-Object { $_.AddressFamily -eq 'IPv4' -and $_.Address -notmatch "^169\.254\." }
                        if ($validIPv4) {
                            foreach ($ip in $validIPv4) {
                                [void]$ipv4AddressesInfo.Add("$($ip.IPAddress) / $($ip.PrefixLength)") 
                            }
                        }
                        
                        # Coleta apenas o Gateway IPv4
                        $ipv4DefaultGatewayObject = Get-SafeProperty -ObjectInstance $ipConfig -PropertyName 'IPv4DefaultGateway' -DefaultValue $null
                        if ($ipv4DefaultGatewayObject) {
                            $gatewayAddress = Get-SafeProperty -ObjectInstance $ipv4DefaultGatewayObject -PropertyName 'NextHop'
                            if ($gatewayAddress -ne "Não Encontrado" -and $gatewayAddress) { $ipv4GatewayInfo = $gatewayAddress }
                        }
                    } 

                    # Lógica para verificar o status do DHCP
                    $netIPInterface = $allNetIPInterfaces | Where-Object { $_.InterfaceIndex -eq $interfaceIndex } | Select-Object -First 1
                    if ($netIPInterface) {
                        $dhcpStatusNetIP = Get-SafeProperty -ObjectInstance $netIPInterface -PropertyName 'Dhcp' -DefaultValue 'Disabled'
                        $dhcpEnabledInfo = switch ($dhcpStatusNetIP) {
                            "Enabled"  { "Sim" }
                            "Disabled" { "Não" }
                            default    { $dhcpStatusNetIP }
                        }
                    }
                    
                    # Lógica robusta e corrigida para a velocidade do link
                    $linkSpeedValueRaw = Get-SafeProperty -ObjectInstance $adapter -PropertyName 'LinkSpeed'
                    $friendlyLinkSpeed = "Não Encontrado"
                    if ($linkSpeedValueRaw -ne "Não Encontrado" -and $null -ne $linkSpeedValueRaw) {
                        try {
                            $speedBits = [System.Convert]::ToUInt64($linkSpeedValueRaw) # Usa UInt64 para números grandes
                            if ($speedBits -gt 0) {
                                if ($speedBits -ge 1000000000) { # Gbps
                                    $friendlyLinkSpeed = "{0:N0} Gbps" -f ($speedBits / 1GB)
                                } elseif ($speedBits -ge 1000000) { # Mbps
                                    $friendlyLinkSpeed = "{0:N0} Mbps" -f ($speedBits / 1MB)
                                } else { # Kbps ou menos
                                    $friendlyLinkSpeed = "{0:N0} Kbps" -f ($speedBits / 1KB)
                                }
                            }
                        } catch {
                             $friendlyLinkSpeed = "$($linkSpeedValueRaw)"
                        }
                    }

                    $adapterDetails = [ordered]@{
                        "Nome do Adaptador"                = Get-SafeProperty $adapter 'Name'
                        "Descrição da Interface"           = Get-SafeProperty $adapter 'InterfaceDescription'
                        "Status"                           = Get-SafeProperty $adapter 'Status'
                        "Endereço MAC"                     = Get-SafeProperty $adapter 'MacAddress'
                        "Velocidade do Link"               = $friendlyLinkSpeed
                        "Endereços IPv4"                   = if ($ipv4AddressesInfo.Count -gt 0) { $ipv4AddressesInfo.ToArray() -join "; " } else { "Não Configurado" } 
                        "Gateway IPv4 Padrão"              = $ipv4GatewayInfo
                        "DHCP Habilitado"                  = $dhcpEnabledInfo
                    }
                    [void]$networkAdaptersList.Add([PSCustomObject]$adapterDetails)
                }
            } else {
                return [PSCustomObject]@{ "Informação" = "Nenhum adaptador de rede ativo encontrado." }
            }
        }
        catch {
            $errorMessage = "Erro ao coletar informações de rede: $($_.Exception.Message)"
            Write-Warning $errorMessage
            return [PSCustomObject]@{ Error = $errorMessage }
        }

        return $networkAdaptersList.ToArray()
     } 
}