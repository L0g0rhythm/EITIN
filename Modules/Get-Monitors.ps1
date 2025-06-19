function Invoke-EitinMonitorsInfo {
    [CmdletBinding()]
    param()

    process {
        $monitorsList = New-Object System.Collections.ArrayList

        function Decode-MonitorByteArray {
            param($ByteArray)
            if ($ByteArray -and ($ByteArray -is [array]) -and $ByteArray.Count -gt 0) {
                $decodedString = ([System.Text.Encoding]::Default.GetString($ByteArray).Trim([char]0).Trim())
                if ($decodedString -eq "0" -or [string]::IsNullOrWhiteSpace($decodedString)) { return $null }
                return $decodedString
            } else { return $null }
        }

        try {
            $wmiMonitors = Get-WmiObject -Namespace root\wmi -Class WmiMonitorID -ErrorAction Stop 
            $videoControllers = Get-CimInstance -ClassName Win32_VideoController -Property CurrentHorizontalResolution, CurrentVerticalResolution, DeviceID, Name, CurrentRefreshRate -ErrorAction SilentlyContinue 
            
            if ($wmiMonitors) {
                $monitorIndex = 0
                foreach ($monitorWmiInstance in $wmiMonitors) {
                    $manufacturerDecoded = Decode-MonitorByteArray $monitorWmiInstance.ManufacturerName 
                    $nameDecoded = Decode-MonitorByteArray $monitorWmiInstance.UserFriendlyName 
                    $serialDecoded = Decode-MonitorByteArray $monitorWmiInstance.SerialNumberID 
                    
                    $finalName = if (-not [string]::IsNullOrWhiteSpace($nameDecoded)) { $nameDecoded } else { "Monitor $($monitorIndex + 1)" }
                    $finalManufacturer = if (-not [string]::IsNullOrWhiteSpace($manufacturerDecoded)) { $manufacturerDecoded } else { "Não Encontrado" }
                    $finalSerial = if (-not [string]::IsNullOrWhiteSpace($serialDecoded)) { $serialDecoded } else { "Não Encontrado" }

                    $resolutionString = "Resolução Indisponível" 
                    $resolutionNote = "*Verificação inicial WMI para resolução indisponível."
                    $refreshRateString = "Não Encontrada"
                    $sizeInchesString = "Não Encontrado"

                    $hSizeCmVal = $monitorWmiInstance.MaxHorizontalImageSize; $vSizeCmVal = $monitorWmiInstance.MaxVerticalImageSize
                    if ($hSizeCmVal -and $vSizeCmVal -and $hSizeCmVal -gt 0 -and $vSizeCmVal -gt 0) {
                        try {
                            $diagonalCm = [Math]::Sqrt([Math]::Pow([double]$hSizeCmVal, 2) + [Math]::Pow([double]$vSizeCmVal, 2))
                            $diagonalInches = [Math]::Round($diagonalCm / 2.54, 1)
                            $sizeInchesString = "$($diagonalInches) polegadas ($($hSizeCmVal)cm x $($vSizeCmVal)cm)"
                        } catch { $sizeInchesString = "Erro ao Calcular Tamanho"}
                    }

                    $foundResViaVC = $false
                    if ($videoControllers) {
                        if ($monitorIndex -lt $videoControllers.Count) {
                            $vc = $videoControllers[$monitorIndex]
                            $resH_vc = Get-SafeProperty $vc 'CurrentHorizontalResolution' ""; $resV_vc = Get-SafeProperty $vc 'CurrentVerticalResolution' ""; $currentRefreshRate_vc = Get-SafeProperty $vc 'CurrentRefreshRate' ""
                            if ($resH_vc -and $resV_vc -and $resH_vc -ne "0" -and $resV_vc -ne "0" -and $resH_vc -ne "Not Found" -and $resV_vc -ne "Not Found") {
                                $resolutionString = "$($resH_vc)x$($resV_vc)"; $resolutionNote = "*Resolução de Win32_VideoController (por índice)."; $foundResViaVC = $true
                                if ($currentRefreshRate_vc -and $currentRefreshRate_vc -ne "0" -and $currentRefreshRate_vc -ne "Not Found") {
                                    $refreshRateString = "$($currentRefreshRate_vc) Hz"
                                }
                            }
                        }
                        if (-not $foundResViaVC) { 
                            foreach ($vc_alt in $videoControllers) {
                                $resH_alt = Get-SafeProperty $vc_alt 'CurrentHorizontalResolution' ""; $resV_alt = Get-SafeProperty $vc_alt 'CurrentVerticalResolution' ""; $currentRefreshRate_alt = Get-SafeProperty $vc_alt 'CurrentRefreshRate' ""
                                if ($resH_alt -and $resV_alt -and $resH_alt -ne "0" -and $resV_alt -ne "0" -and $resH_alt -ne "Not Found" -and $resV_alt -ne "Not Found") {
                                    $resolutionString = "$($resH_alt)x$($resV_alt)"; $resolutionNote = "*Resolução da GPU ativa '$($vc_alt.Name)'."; $foundResViaVC = $true
                                    if ($currentRefreshRate_alt -and $currentRefreshRate_alt -ne "0" -and $currentRefreshRate_alt -ne "Not Found") {
                                        $refreshRateString = "$($currentRefreshRate_alt) Hz"
                                    }
                                    break 
                                }
                            }
                        }
                    }

                    if (($resolutionString -eq "Resolução Indisponível")) {
                        try {
                            $desktopMonitors = Get-CimInstance Win32_DesktopMonitor -ErrorAction SilentlyContinue
                            if ($desktopMonitors) {
                                $targetDm = $null
                                if ($wmiMonitors.Count -eq 1 -and $desktopMonitors.Count -ge 1) {
                                    $targetDm = $desktopMonitors | Where-Object { $_.PNPDeviceID -eq $monitorWmiInstance.InstanceName } | Select-Object -First 1
                                    if (-not $targetDm -and $desktopMonitors.Count -eq 1) { $targetDm = $desktopMonitors | Select-Object -First 1} 
                                    if (-not $targetDm) { $targetDm = $desktopMonitors | Sort-Object -Property DeviceID | Select-Object -First 1 }
                                } elseif ($desktopMonitors.Count -eq 1) { $targetDm = $desktopMonitors | Select-Object -First 1 }
                                if ($targetDm) {
                                    $resH_dm = Get-SafeProperty $targetDm 'ScreenWidth' ""; $resV_dm = Get-SafeProperty $targetDm 'ScreenHeight' ""
                                    if ($resH_dm -and $resV_dm -and $resH_dm -ne "0" -and $resV_dm -ne "0" -and $resH_dm -ne "Not Found" -and $resV_dm -ne "Not Found") {
                                        $resolutionString = "$($resH_dm)x$($resV_dm)"; $resolutionNote = "*Resolução de Win32_DesktopMonitor."
                                    } else {
                                        $resolutionString = "Dados de resolução do Desktop incompletos"; $resolutionNote = "*Win32_DesktopMonitor alvo mas Larg/Alt ausentes/zero para $($targetDm.DeviceID). L: '$resH_dm', A: '$resV_dm'"
                                    }
                                } elseif ($desktopMonitors.Count -gt 1 -and $wmiMonitors.Count -gt 1) { 
                                     $allResolutions = $desktopMonitors | ForEach-Object { "$($_.ScreenWidth)x$($_.ScreenHeight)" } | Get-Unique
                                     if ($allResolutions.Count -eq 1 -and $allResolutions[0] -notmatch "0x0|x0|^\s*x\s*$|^Not FoundxNot Found$|^x$") { 
                                         $resolutionString = $allResolutions[0]; $resolutionNote = "*Resolução de Win32_DesktopMonitor (todos lógicos iguais)."
                                     } else {
                                        $resolutionString = "Ver Seção GPU ou Múltiplas Resoluções"; $resolutionNote = "*Múltiplas resoluções via Win32_DesktopMonitor ($($allResolutions -join '; ')). Ver seção GPU."
                                     }
                                }
                            }
                        } catch { Write-Warning "DEBUG MONITOR: Erro ao consultar Win32_DesktopMonitor: $($_.Exception.Message)" }
                    }
                    
                    $monitorDetails = [ordered]@{
                        "Nome do Monitor"              = $finalName
                        "Fabricante do Monitor"        = $finalManufacturer
                        "Número de Série (Monitor)"    = $finalSerial
                        "Resolução Detectada"          = $resolutionString
                        "Taxa de Atualização"          = $refreshRateString 
                        "Tamanho Físico"               = $sizeInchesString  
                        "Observação sobre Resolução"   = $resolutionNote
                    }
                    [void]$monitorsList.Add([PSCustomObject]$monitorDetails)
                    $monitorIndex++ 
                }
            } else {
                 [void]$monitorsList.Add([PSCustomObject]@{ 
                    "Nome do Monitor" = "Nenhuma Instância WMI de Monitor Encontrada"
                    "Observação"      = "Não foi possível obter detalhes do monitor via WMI (WmiMonitorID)."
                    "Error"           = "WmiMonitorID não retornou dados."
                })
            }
        }
        catch {
            $errorMessage = "Erro ao coletar informações do monitor: $($_.Exception.Message)" 
            Write-Warning $errorMessage
            return @([PSCustomObject]@{ 
                "Nome do Monitor" = "Erro na Coleta" 
                "Observação"      = $errorMessage 
                "Error"           = $errorMessage 
            })
        }

        if ($monitorsList.Count -eq 0) {
            [void]$monitorsList.Add([PSCustomObject]@{
                    "Nome do Monitor" = "Nenhum Monitor Detectado"
                    "Observação"      = "Nenhum monitor foi detectado pelo script após todas as tentativas."
                })
        }
        return $monitorsList.ToArray()
    }    
}