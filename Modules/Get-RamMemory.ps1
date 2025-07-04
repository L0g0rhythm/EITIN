function Invoke-EitinRamMemoryInfo {
    [CmdletBinding()]
    param()

    process {
        $ramModulesList = New-Object System.Collections.ArrayList
        $errorMessage = $null 

        try {
            $memoryModulesWmi = Get-CimInstance Win32_PhysicalMemory -Property DeviceLocator, Manufacturer, PartNumber, SerialNumber, Capacity, Speed, SMBIOSMemoryType -ErrorAction Stop 

            if ($memoryModulesWmi) {
                foreach ($mem in $memoryModulesWmi) {
                    $ddrType = switch (Get-SafeProperty $mem 'SMBIOSMemoryType' 0) { 
                        20 { 'DDR' }            
                        21 { 'DDR2' }           
                        22 { 'DDR2 FB-DIMM' }   
                        24 { 'DDR3' }           
                        26 { 'DDR4' }           
                        30 { 'DDR4' }           
                        34 { 'DDR5' }           
                        default { "Desconhecido (SMBIOS: $(Get-SafeProperty $mem 'SMBIOSMemoryType' 'N/A'))" } 
                    }

                    $capacityBytes = [long](Get-SafeProperty $mem 'Capacity' 0) 
                    $capacityGBVal = if ($capacityBytes -gt 0) { [math]::Round($capacityBytes / 1GB, 2) } else { 'N/A' } 

                    $moduleDetails = [ordered]@{
                        "Slot da Memória"             = Get-SafeProperty $mem 'DeviceLocator' 'Não Encontrado'
                        "Fabricante do Módulo"        = Get-SafeProperty $mem 'Manufacturer' 'Não Encontrado'
                        "Part Number (Cód. Peça)"     = Get-SafeProperty $mem 'PartNumber' 'Não Encontrado'
                        "Número de Série (Módulo)"    = Get-SafeProperty $mem 'SerialNumber' 'Não Encontrado'
                        "Capacidade (GB)"             = $capacityGBVal
                        "Velocidade (MHz)"            = Get-SafeProperty $mem 'Speed' 'Não Encontrado'
                        "Tipo de Memória"             = $ddrType
                    }
                    [void]$ramModulesList.Add([PSCustomObject]$moduleDetails)
                }
            } else {
                $errorMessage = "Nenhum módulo de memória física encontrado via WMI."
                [void]$ramModulesList.Add([PSCustomObject]@{ 
                    "Nome"    = "Nenhum Módulo Encontrado"
                    "Detalhe" = $errorMessage
                    "Error"   = $errorMessage 
                })
            }
        }
        catch {
            $errorMessage = "Erro ao coletar informações de RAM: $($_.Exception.Message)" 
            Write-Warning $errorMessage
            return @([PSCustomObject]@{ Error = $errorMessage })
        }

        if ($ramModulesList.Count -eq 0 -and -not $errorMessage) {
            $errorMessage = "Nenhum módulo de memória detectado."
             [void]$ramModulesList.Add([PSCustomObject]@{ 
                "Nome"    = "Nenhum Módulo Detectado"
                "Detalhe" = $errorMessage
                "Error"   = $errorMessage 
            })
        }
        
        if ($ramModulesList.Count -eq 1 -and $ramModulesList[0].PSObject.Properties['Error'] -ne $null -and $ramModulesList[0].Error) {
            return $ramModulesList.ToArray()
        }

        return $ramModulesList.ToArray()
    }
}