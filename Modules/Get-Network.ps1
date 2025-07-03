function Invoke-EitinNetworkInfo {
    [CmdletBinding()]
    param()

    process {
        $networkAdaptersList = New-Object System.Collections.ArrayList
        
        try {
            $activeAdapterConfigs = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'TRUE'"
            
            if ($activeAdapterConfigs) {
                foreach ($config in $activeAdapterConfigs) {
                    $adapter = Get-CimInstance -ClassName Win32_NetworkAdapter -Filter "Index = $($config.Index)" | Select-Object -First 1
                    
                    if (-not $adapter) { continue }

                    # This ensures that the code functions correctly even with a single IP address.
                    $ipv4Addresses = @($config.IPAddress | Where-Object { $_ -like '*.*' -and $_ -notlike '169.254.*' })
                    $subnets = @($config.IPSubnet)
                    
                    $ipv4AddressesInfo = New-Object System.Collections.ArrayList
                    if ($ipv4Addresses.Count -gt 0) {
                        for ($i = 0; $i -lt $ipv4Addresses.Count; $i++) {
                            # It ensures that we have a corresponding subnet to prevent errors.
                            if ($i -lt $subnets.Count) {
                                [void]$ipv4AddressesInfo.Add("$($ipv4Addresses[$i]) / $($subnets[$i])")
                            }
                        }
                    }

                    $ipv4GatewayInfo = "Não Configurado"
                    if ($config.DefaultIPGateway) {
                        $firstIpv4Gateway = $config.DefaultIPGateway | Where-Object { $_ -like '*.*' } | Select-Object -First 1
                        if ($firstIpv4Gateway) {
                            $ipv4GatewayInfo = $firstIpv4Gateway
                        }
                    }

                    $dhcpEnabledInfo = if ($config.DHCPEnabled) { "Sim" } else { "Não" }

                    $friendlyLinkSpeed = "Não Disponível"
                    if ($adapter.Speed) {
                        try {
                            $speedBits = [System.Convert]::ToUInt64($adapter.Speed)
                            if ($speedBits -gt 0) {
                                if ($speedBits -ge 1000000000) { # Gbps
                                    $friendlyLinkSpeed = "{0:N0} Gbps" -f ($speedBits / 1GB)
                                } elseif ($speedBits -ge 1000000) { # Mbps
                                    $friendlyLinkSpeed = "{0:N0} Mbps" -f ($speedBits / 1MB)
                                } else { # Kbps
                                    $friendlyLinkSpeed = "{0:N0} Kbps" -f ($speedBits / 1KB)
                                }
                            }
                        } catch {
                            $friendlyLinkSpeed = "$($adapter.Speed)"
                        }
                    }

                    $adapterDetails = [ordered]@{
                        "Nome do Adaptador"                = $adapter.Name
                        "Descrição da Interface"           = $adapter.Description
                        "Status"                           = "Up"
                        # Improvement: Handles cases where the MAC address is missing.
                        "Endereço MAC"                     = if ([string]::IsNullOrWhiteSpace($adapter.MACAddress)) { "N/A" } else { $adapter.MACAddress }
                        "Velocidade do Link"               = $friendlyLinkSpeed
                        "Endereços IPv4"                   = if ($ipv4AddressesInfo.Count -gt 0) { $ipv4AddressesInfo.ToArray() -join "; " } else { "Não Configurado" }
                        "Gateway IPv4 Padrão"              = $ipv4GatewayInfo
                        "DHCP Habilitado"                  = $dhcpEnabledInfo
                    }
                    [void]$networkAdaptersList.Add([PSCustomObject]$adapterDetails)
                }
            } 
            
            if ($networkAdaptersList.Count -eq 0) {
                return [PSCustomObject]@{ "Informação" = "Nenhum adaptador de rede ativo encontrado." }
            }
        }
        catch {
            $errorMessage = "Erro ao coletar informações de rede via WMI: $($_.Exception.Message)"
            Write-Warning $errorMessage
            return [PSCustomObject]@{ Error = $errorMessage }
        }

        return $networkAdaptersList.ToArray()
    }
}
