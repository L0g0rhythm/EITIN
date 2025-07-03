function Invoke-EitinBiosFirmwareInfo {
    [CmdletBinding()]
    param()

    process {
        $dadosFirmware = [ordered]@{
            "Fabricante do BIOS"         = "Não Encontrado"
            "Versão do BIOS"             = "Não Encontrado"
            "Data de Lançamento do BIOS" = "Não Encontrado"
            "Tipo de Chassi"             = "Não Determinado"
            "Tipo de Firmware"           = "Não Determinado"
            "Secure Boot Ativado"        = "Não Verificado"
            "Error"                      = $null
        }

        $mensagensErro = [System.Collections.Generic.List[string]]::new()
        $ePsLegado = $PSVersionTable.PSVersion.Major -lt 3

        # Helper function to execute WMI/CIM queries based on PowerShell version.
        function Get-InstanciaWmiOuCim {
            param(
                [string]$NomeClasse,
                [string[]]$Propriedade,
                [string]$Namespace = "root\cimv2"
            )
            
            if ($ePsLegado) {
                # Fallback for PowerShell versions < 3.0
                return Get-WmiObject -Class $NomeClasse -Property $Propriedade -Namespace $Namespace -ErrorAction SilentlyContinue | Select-Object -First 1
            } else {
                return Get-CimInstance -ClassName $NomeClasse -Property $Propriedade -Namespace $Namespace -ErrorAction SilentlyContinue | Select-Object -First 1
            }
        }

        # 1. Collect BIOS Information
        try {
            $bios = Get-InstanciaWmiOuCim -NomeClasse 'Win32_BIOS' -Propriedade 'SMBIOSBIOSVersion', 'Manufacturer', 'ReleaseDate'
            if ($bios) {
                $dadosFirmware."Fabricante do BIOS"         = Get-SafeProperty -ObjectInstance $bios -PropertyName 'Manufacturer'
                $dadosFirmware."Versão do BIOS"             = Get-SafeProperty -ObjectInstance $bios -PropertyName 'SMBIOSBIOSVersion'
                $releaseDateWmi                           = Get-SafeProperty -ObjectInstance $bios -PropertyName 'ReleaseDate' -DefaultValue ""
                $dadosFirmware."Data de Lançamento do BIOS" = Convert-WmiDate -WmiDate $releaseDateWmi
            }
            else {
                $dadosFirmware."Fabricante do BIOS" = "Informação do BIOS não encontrada via WMI/CIM."
            }
        }
        catch {
            $mensagensErro.Add("Falha na coleta de BIOS: $($_.Exception.Message)")
        }

        # 2. Collect Chassis Type Information
        try {
            $gabinete = Get-InstanciaWmiOuCim -NomeClasse 'Win32_SystemEnclosure' -Propriedade 'ChassisTypes'
            if ($gabinete -and $gabinete.ChassisTypes) {
                $valorTipoChassi = $gabinete.ChassisTypes | Select-Object -First 1
                $dadosFirmware."Tipo de Chassi" = switch ($valorTipoChassi) {
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
                    default { "Desconhecido (Cód WMI: $valorTipoChassi)" }
                }
            }
        }
        catch {
            $mensagensErro.Add("Falha na coleta do tipo de chassi: $($_.Exception.Message)")
        }

        # 3. Check Secure Boot Status (Requires Admin & PS 5.0+)
        $secureBootAtivado = $null
        if ($PSVersionTable.PSVersion.Major -lt 5) {
            $dadosFirmware."Secure Boot Ativado" = "Não Verificável (Versão PS < 5.0)"
        }
        elseif (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            $dadosFirmware."Secure Boot Ativado" = "Não Verificável (Requer Admin)"
        }
        elseif (-not (Get-Command Confirm-SecureBootUEFI -ErrorAction SilentlyContinue)) {
            $dadosFirmware."Secure Boot Ativado" = "Não Verificável (Cmdlet ausente)"
        }
        else {
            try {
                # This cmdlet can throw on non-UEFI systems or unsupported platforms.
                $secureBootAtivado = Confirm-SecureBootUEFI -ErrorAction Stop
                $dadosFirmware."Secure Boot Ativado" = if ($secureBootAtivado) { "Sim" } else { "Não" }
            }
            catch {
                # Catches errors if the cmdlet exists but fails to run (e.g., BIOS/platform issue).
                $dadosFirmware."Secure Boot Ativado" = "Falha na Verificação (Plataforma pode não suportar)"
                $mensagensErro.Add("Falha na checagem do SecureBoot: $($_.Exception.Message)")
            }
        }

        # 4. Check UEFI Firmware Status
        try {
            $firmwareTipoWmi = Get-InstanciaWmiOuCim -NomeClasse 'MSFT_Firmware' -Namespace 'root\cimv2\mdm\dmmap' -Propriedade 'FirmwareType'
            if ($firmwareTipoWmi) {
                $dadosFirmware."Tipo de Firmware" = switch ($firmwareTipoWmi.FirmwareType) {
                    1       { "BIOS Legado" }
                    2       { "UEFI" }
                    default { "Desconhecido (Tipo WMI: $($firmwareTipoWmi.FirmwareType))" }
                }
            }
            elseif ($secureBootAtivado -eq $true) {
                # If Secure Boot is confirmed enabled, firmware must be UEFI.
                $dadosFirmware."Tipo de Firmware" = "UEFI (Inferido pelo Secure Boot)"
            }
        }
        catch {
            $mensagensErro.Add("Falha na checagem do tipo de firmware: $($_.Exception.Message)")
        }
        
        # Finalize the object.
        if ($mensagensErro.Count -gt 0) {
            $dadosFirmware.Error = ($mensagensErro -join " | ").Trim()
        }
        
        # Remove the 'Error' property if it's empty, as in the original logic.
        if ($null -eq $dadosFirmware.Error) {
             $dadosFirmware.PSObject.Properties.Remove('Error')
        }

        return [PSCustomObject]$dadosFirmware
    }
}
