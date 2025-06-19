function Invoke-EitinBiosFirmwareInfo {
    [CmdletBinding()]
    param()

    process {
        $dadosFirmware = [ordered]@{
            "Fabricante do BIOS"         = "Não Encontrado"
            "Versão do BIOS"             = "Não Encontrado"
            "Data de Lançamento do BIOS" = "Não Encontrado"
            "Tipo de Chassi"             = "Não Disponível" 
            "Tipo de Firmware"           = "Não Determinado" 
            "Secure Boot Ativado"        = "Não Verificado" 
            "Error"                      = $null
        }
        $moduleOverallError = $null

        # Collect BIOS Information
        try {
            $bios = Get-CimInstance -ClassName Win32_BIOS -Property SMBIOSBIOSVersion, Manufacturer, ReleaseDate -ErrorAction Stop | Select-Object -First 1

            if ($bios) {
                $dadosFirmware."Fabricante do BIOS"         = Get-SafeProperty -ObjectInstance $bios -PropertyName 'Manufacturer'
                $dadosFirmware."Versão do BIOS"             = Get-SafeProperty -ObjectInstance $bios -PropertyName 'SMBIOSBIOSVersion'
                $releaseDateWmi                           = Get-SafeProperty -ObjectInstance $bios -PropertyName 'ReleaseDate' -DefaultValue ""
                $dadosFirmware."Data de Lançamento do BIOS" = Convert-WmiDate -WmiDate $releaseDateWmi
            } else {
                $dadosFirmware."Fabricante do BIOS" = "Informação do BIOS não encontrada via WMI."
            }
        }
        catch {
            $errorMessage = "Erro ao coletar informações do BIOS: $($_.Exception.Message)"
            Write-Warning $errorMessage
            $dadosFirmware."Fabricante do BIOS" = "Erro na Coleta" 
            if (-not $moduleOverallError) { $moduleOverallError = "Falha BIOS. " } else { $moduleOverallError += "Falha BIOS. "}
        }

        # Collect Chassis Type Information
        try {
            $enclosure = Get-CimInstance -ClassName Win32_SystemEnclosure -Property ChassisTypes -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($enclosure -and $enclosure.ChassisTypes) {
                $chassisTypeValue = $enclosure.ChassisTypes | Select-Object -First 1 
                $dadosFirmware."Tipo de Chassi" = switch ($chassisTypeValue) {
                    1  { "Outro" } 2  { "Desconhecido" } 3  { "Desktop" } 4  { "Desktop de Baixo Perfil" } 
                    5  { "Pizza Box" } 6  { "Mini Torre" } 7  { "Torre" } 8  { "Portátil (Genérico)" } 
                    9  { "Laptop" } 10 { "Notebook" } 11 { "Dispositivo Portátil de Mão" } 
                    12 { "Estação de Acoplamento" } 13 { "Computador Tudo-em-Um" } 
                    14 { "Sub-Notebook" } 15 { "PC Compacto" } 
                    16 { "PC Portátil Robusto (Lunch Box)" } 17 { "Chassi de Servidor Principal" } 
                    18 { "Chassi de Expansão" } 19 { "Sub-Chassi" } 20 { "Chassi de Expansão de Barramento" } 
                    21 { "Chassi Periférico" } 22 { "Chassi de Armazenamento (RAID)" } 
                    23 { "Chassi para Montagem em Rack" } 24 { "PC com Gabinete Selado" } 
                    30 { "Tablet" } 31 { "Conversível" } 32 { "Destacável" } 
                    default { "Desconhecido (Cód WMI: $chassisTypeValue)" }
                }
            } else {
                $dadosFirmware."Tipo de Chassi" = "Não Determinado"
            }
        }
        catch {
            $chassisErrorMessage = "Erro ao coletar tipo de chassi: $($_.Exception.Message)"
            Write-Warning $chassisErrorMessage
            $dadosFirmware."Tipo de Chassi" = "Erro na Coleta"
            if (-not $moduleOverallError) { $moduleOverallError = "Falha Chassi. " } else { $moduleOverallError += "Falha Chassi. "}
        }

        # Check Secure Boot Status (requires Admin & PS 5.0+)
        $secureBootEnabled = $null 
        try {
            $secureBootStatusCmdletOutput = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue 
            if ($null -ne $secureBootStatusCmdletOutput) { 
                $secureBootEnabled = $secureBootStatusCmdletOutput 
                $dadosFirmware."Secure Boot Ativado" = if ($secureBootEnabled) { "Sim" } else { "Não" }
            } else {
                if (Get-Command Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
                    $dadosFirmware."Secure Boot Ativado" = "Não Suportado ou Erro na Verificação" 
                } else {
                    $dadosFirmware."Secure Boot Ativado" = "Não Verificável (Cmdlet Ausente)" 
                }
            }
        } catch { 
            Write-Warning "Erro ao verificar status do Secure Boot: $($_.Exception.Message)"
            $dadosFirmware."Secure Boot Ativado" = "Erro na Verificação"
            if (-not $moduleOverallError) { $moduleOverallError = "Falha SecureBoot. " } else { $moduleOverallError += "Falha SecureBoot. "}
        }

        # Check UEFI Firmware Status
        try {
            if (Test-Path "variable:UEFI") { 
                 $dadosFirmware."Tipo de Firmware" = "UEFI (Detectado via Variável de Firmware)"
            } else {
                $firmwareTypeWmi = Get-CimInstance -ClassName MSFT_Firmware -Namespace root\cimv2\mdm\dmmap -Property FirmwareType -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($firmwareTypeWmi) {
                    $dadosFirmware."Tipo de Firmware" = switch ($firmwareTypeWmi.FirmwareType) {
                        1       { "BIOS Legado" } 
                        2       { "UEFI" }        
                        default { "Desconhecido (Tipo WMI: $($firmwareTypeWmi.FirmwareType))" }
                    }
                } elseif ($secureBootEnabled -eq $true) {
                    $dadosFirmware."Tipo de Firmware" = "UEFI (Inferido pelo Secure Boot Ativado)"
                } else {
                    $dadosFirmware."Tipo de Firmware" = "Não Determinado" 
                }
            }
        } catch {
            Write-Warning "Erro ao verificar tipo de firmware: $($_.Exception.Message)"
            $dadosFirmware."Tipo de Firmware" = "Erro na Verificação"
            if (-not $moduleOverallError) { $moduleOverallError = "Falha Tipo Firmware. " } else { $moduleOverallError += "Falha Tipo Firmware. "}
        }
        
        if ($moduleOverallError) {
            $dadosFirmware.Error = $moduleOverallError.Trim()
        } else {
            $dadosFirmware.Error = $null 
        }
        
        if ($dadosFirmware.PSObject.Properties['Error'] -ne $null -and $null -eq $dadosFirmware.Error ) {
            $propriedadesLimpasFirmware = [ordered]@{}
            foreach ($propriedadeFw in $dadosFirmware.PSObject.Properties) {
                if ($propriedadeFw.Name -ne 'Error') {
                    $propriedadesLimpasFirmware[$propriedadeFw.Name] = $propriedadeFw.Value
                }
            }
            return [PSCustomObject]$propriedadesLimpasFirmware
        }

        return [PSCustomObject]$dadosFirmware
    }
}