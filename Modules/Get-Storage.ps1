function Invoke-EitinStorageInfo {
    [CmdletBinding()]
    param()

    process {
        $physicalDisksList = New-Object System.Collections.ArrayList
        $volumesList = New-Object System.Collections.ArrayList
        $moduleOverallError = $null 

        # --- Coleta de Informações de Discos Físicos ---
        try {
            $disksWmi = Get-PhysicalDisk -ErrorAction Stop 
            
            if ($disksWmi) {
                foreach ($disk in $disksWmi) {
                    $mediaTypeFromWmi = Get-SafeProperty -ObjectInstance $disk -PropertyName 'MediaType'
                    $mediaTypeCalculated = "Desconhecido" 

                    if (($disk.Model -match "NVMe" -or $disk.FriendlyName -match "NVMe") -and ($mediaTypeFromWmi -eq 4 -or $mediaTypeFromWmi -eq "SSD" -or $mediaTypeFromWmi -eq 0)) {
                        $mediaTypeCalculated = "SSD NVMe"
                    } elseif (($disk.Model -match "SSD" -or $disk.FriendlyName -match "SSD") -and ($mediaTypeFromWmi -is [string] -and $mediaTypeFromWmi -eq "SSD" -or $mediaTypeFromWmi -eq 4)) {
                         $mediaTypeCalculated = "SSD"
                    } elseif ($disk.BusType -eq 'USB') {
                        $mediaTypeCalculated = "Unidade USB"
                    } elseif ($mediaTypeFromWmi -eq 3 -or ($disk.Model -match "HDD" -or $disk.FriendlyName -match "HDD")) { 
                        $mediaTypeCalculated = "HDD"
                    } elseif ($mediaTypeFromWmi -eq 0 -or $mediaTypeFromWmi -eq "Unspecified") { 
                        if ($disk.Model -match "NVMe" -or $disk.FriendlyName -match "NVMe") { $mediaTypeCalculated = "SSD NVMe" }
                        elseif ($disk.BusType -eq 'USB') { $mediaTypeCalculated = "Unidade USB" }
                        elseif ($disk.Model -match "SSD" -or $disk.FriendlyName -match "SSD") { $mediaTypeCalculated = "SSD" }
                        elseif ($disk.Model -match "HDD" -or $disk.FriendlyName -match "HDD") { $mediaTypeCalculated = "HDD" }
                        else { $mediaTypeCalculated = "Não Especificado (Cód: $mediaTypeFromWmi)" }
                    } elseif ($mediaTypeFromWmi -eq 5 ) { 
                        $mediaTypeCalculated = "SCM (Memória de Classe de Armazenamento)"
                    } else {
                        $mediaTypeCalculated = "Outro Tipo (Cód. WMI: $($mediaTypeFromWmi))"
                    }
                    
                    $diskSizeBytes = [long](Get-SafeProperty -ObjectInstance $disk -PropertyName 'Size' -DefaultValue 0) 
                    $sizeGBVal = if ($diskSizeBytes -gt 0) { [math]::Round($diskSizeBytes / 1GB, 2) } else { 'N/A' } 
                    
                    $allocatedSizeBytes = [long](Get-SafeProperty -ObjectInstance $disk -PropertyName 'AllocatedSize' -DefaultValue 0)
                    $allocatedSizeGBVal = if ($allocatedSizeBytes -gt 0) { [math]::Round($allocatedSizeBytes / 1GB, 2) } else { 'N/A' }

                    $healthStatusRawDisk = Get-SafeProperty -ObjectInstance $disk -PropertyName 'HealthStatus'
                    $healthStatusDiskTraduzido = switch ($healthStatusRawDisk) {
                        "Healthy"   { "Saudável" }
                        "Warning"   { "Aviso" }
                        "Unhealthy" { "Não Íntegro" } 
                        default     { $healthStatusRawDisk } 
                    }

                    $operationalStatusRawDisk = Get-SafeProperty -ObjectInstance $disk -PropertyName 'OperationalStatus'
                    
                    $diskDetails = [ordered]@{
                        "Nome do Disco"             = Get-SafeProperty -ObjectInstance $disk -PropertyName 'FriendlyName'
                        "Tipo de Mídia Calculado"   = $mediaTypeCalculated 
                        "Modelo do Disco"           = Get-SafeProperty -ObjectInstance $disk -PropertyName 'Model'
                        "Número de Série (Disco)"   = Get-SafeProperty -ObjectInstance $disk -PropertyName 'SerialNumber'
                        "Tamanho Total (GB)"        = $sizeGBVal
                        "Tamanho Alocado (GB)"      = $allocatedSizeGBVal
                        "Status de Saúde (Disco)"   = $healthStatusDiskTraduzido 
                        "Status Operacional (Disco)"= $operationalStatusRawDisk 
                        "Tipo de Barramento"        = Get-SafeProperty -ObjectInstance $disk -PropertyName 'BusType'
                    }
                    [void]$physicalDisksList.Add([PSCustomObject]$diskDetails)
                }
            } 
        }
        catch {
            $errorMessage = "Erro ao coletar informações dos discos físicos: $($_.Exception.Message)" 
            Write-Warning $errorMessage
            [void]$physicalDisksList.Add([PSCustomObject]@{ "Erro na Coleta de Discos" = $errorMessage })
            if (-not $moduleOverallError) { $moduleOverallError = "Falha parcial: Discos Físicos. " } else { $moduleOverallError += "Falha parcial: Discos Físicos. "}
        }

        # --- Coleta de Informações de Volumes ---
        try {
            $volumesWmi = Get-Volume -ErrorAction Stop | 
                          Where-Object { $_.DriveLetter -ne $null -and (-not [string]::IsNullOrWhiteSpace($_.FileSystem)) } 
            
            if ($volumesWmi) {
                foreach ($volume in $volumesWmi) {
                    $totalSizeBytes = Get-SafeProperty -ObjectInstance $volume -PropertyName 'Size' -DefaultValue 0 
                    $freeSpaceBytes = Get-SafeProperty -ObjectInstance $volume -PropertyName 'SizeRemaining' -DefaultValue 0 
                    
                    $totalGBVal = if ($totalSizeBytes -gt 0) { [math]::Round($totalSizeBytes / 1GB, 2) } else { 0 } 
                    $freeGBVal  = if ($freeSpaceBytes -gt 0) { [math]::Round($freeSpaceBytes / 1GB, 2) } else { 0 } 
                    $usedGBVal  = if ($totalGBVal -ge $freeGBVal) { [math]::Round($totalGBVal - $freeGBVal, 2) } else { 0 } 
                    $percentFreeVal = if ($totalGBVal -gt 0) { [math]::Round(($freeGBVal / $totalGBVal) * 100, 1) } else { 0 } 
                    
                    $lowSpaceWarningText = "Não" 
                    if (($totalGBVal -gt 1 -and $percentFreeVal -lt 10) -or ($totalGBVal -gt 20 -and $freeGBVal -lt 15)) { 
                        $lowSpaceWarningText = "SIM! ($($percentFreeVal)% livre)" 
                    }

                    if ($totalGBVal -gt 0.5) { 
                        $driveTypeRaw = Get-SafeProperty -ObjectInstance $volume -PropertyName 'DriveType'
                        $driveTypeFriendly = switch ($driveTypeRaw) {
                            0       { "Desconhecido" } 
                            1       { "Não Especificado" } 
                            2       { "Removível" }      
                            3       { "Fixo" } # Para o valor numérico 3
                            "Fixed" { "Fixo" } # <<< ADICIONADO: Para a string literal "Fixed"
                            4       { "Rede" }           
                            5       { "CD-ROM" }         
                            6       { "RAM Disk" }       
                            default { "$($driveTypeRaw) (Código/Valor Não Mapeado)" } # Fallback ajustado
                        }

                        $healthStatusRawVolume = Get-SafeProperty -ObjectInstance $volume -PropertyName 'HealthStatus'
                        $healthStatusVolumeTraduzido = switch ($healthStatusRawVolume) {
                            "Healthy"   { "Saudável" } 
                            "Warning"   { "Aviso" }    
                            "Unhealthy" { "Não Íntegro" } 
                            default     { $healthStatusRawVolume }
                        }

                        $volumeDetails = [ordered]@{
                            "Letra da Unidade"        = Get-SafeProperty -ObjectInstance $volume -PropertyName 'DriveLetter'
                            "Rótulo do Volume"        = Get-SafeProperty -ObjectInstance $volume -PropertyName 'FileSystemLabel' -DefaultValue "Sem Rótulo"
                            "Sistema de Arquivos"     = Get-SafeProperty -ObjectInstance $volume -PropertyName 'FileSystem'
                            "Tipo de Unidade"         = $driveTypeFriendly 
                            "Tamanho Total (GB)"      = $totalGBVal
                            "Espaço Usado (GB)"       = $usedGBVal
                            "Espaço Livre (GB)"       = $freeGBVal
                            "Percentual Livre (%)"    = $percentFreeVal
                            "Status de Saúde (Volume)"= $healthStatusVolumeTraduzido 
                            "Pouco Espaço (Aviso)"    = $lowSpaceWarningText 
                        }
                        [void]$volumesList.Add([PSCustomObject]$volumeDetails)
                    }
                }
            } 
        }
        catch {
            $errorMessage = "Erro ao coletar informações dos volumes: $($_.Exception.Message)" 
            Write-Warning $errorMessage
            [void]$volumesList.Add([PSCustomObject]@{ "Erro na Coleta de Volumes" = $errorMessage })
            if (-not $moduleOverallError) { $moduleOverallError += "Falha parcial: Volumes. " } else { $moduleOverallError += "Falha parcial: Volumes. "}
        }

        $storageInfoOutput = [ordered]@{}
        if ($physicalDisksList.Count -gt 0) {
            $storageInfoOutput["Discos Físicos"] = $physicalDisksList.ToArray()
        } else {
            if (!($physicalDisksList | Where-Object { $_.PSObject.Properties["Erro na Coleta de Discos"] -ne $null })) {
                 $storageInfoOutput["Discos Físicos"] = "Nenhum disco físico encontrado."
            } else { 
                 $storageInfoOutput["Discos Físicos"] = $physicalDisksList.ToArray()
            }
        }
        
        if ($volumesList.Count -gt 0) {
            $storageInfoOutput["Volumes e Partições"] = $volumesList.ToArray() 
        } else {
            if (!($volumesList | Where-Object { $_.PSObject.Properties["Erro na Coleta de Volumes"] -ne $null })) {
                $storageInfoOutput["Volumes e Partições"] = "Nenhuma informação de volume/partição encontrada."
            } else {
                $storageInfoOutput["Volumes e Partições"] = $volumesList.ToArray()
            }
        }
        
        if ($moduleOverallError) {
            $storageInfoOutput.Error = $moduleOverallError.Trim()
        } elseif (($storageInfoOutput["Discos Físicos"] -is [string] -and $storageInfoOutput["Discos Físicos"] -like "Nenhum*encontrado*") -and 
                    ($storageInfoOutput["Volumes e Partições"] -is [string] -and $storageInfoOutput["Volumes e Partições"] -like "Nenhum*encontrada*")) { 
             $storageInfoOutput.Error = "Nenhuma informação de disco ou volume pôde ser encontrada ou coletada."
        }

        if ($storageInfoOutput.PSObject.Properties['Error'] -ne $null -and $null -eq $storageInfoOutput.Error ) {
            $propriedadesLimpasStorage = [ordered]@{}
            foreach ($propriedadeS in $storageInfoOutput.PSObject.Properties) {
                if ($propriedadeS.Name -ne 'Error') {
                    $propriedadesLimpasStorage[$propriedadeS.Name] = $propriedadeS.Value
                }
            }
            return [PSCustomObject]$propriedadesLimpasStorage
        }

        return [PSCustomObject]$storageInfoOutput
    }
}