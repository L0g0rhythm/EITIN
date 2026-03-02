function Invoke-EitinPeripheralsInfo {
    [CmdletBinding()]
    param()

    begin {
        $isLegacyPS = $PSVersionTable.PSVersion.Major -lt 3

        # LISTA DE EXCLUSÃO CIRÚRGICA E DEFINITIVA
        $pnpIgnoreKeywords = @(
            'ACPI','Compliant','Fan','Lid','Power Button','Sleep Button','Thermal Zone','System Firmware',
            'AgileVpn','Aggregator','Controller Host','Host Bridge/DRAM','Host Controller','Composite Device',
        'CMOS','System timer','Direct memory access controller','downstream switch port','upstream switch port',
        'Enumerator','Generic SuperSpeed USB Hub','Generic USB Hub','High Definition Audio Controller','High precision event timer',
            'Intel(R) iCLS Client','Intel(R) MEI WMI Provider','Intel(R) SGX','Intel(R) Power Engine Plug-in',
            'Intel(R) SMBus','Intel(R) Thermal Subsystem','Intel(R) Dynamic Platform and Thermal Framework','Kernel Debug',
            'Legacy device','Mainboard','Motherboard resources','NDIS Virtual Network','Numeric data processor',
            'PCI-to-PCI Bridge','PCI standard RAM Controller','Programmable interrupt controller','Remote Desktop',
            'Root Enumerator','Root Port','Storage Spaces Controller','System board','System speaker','System Management BIOS Driver',
            'UEFI-Compliant System','UMBus','Volume','VSP','Virtual','WAN Miniport','WSD Print Device',
            'Windows Management Interface for ACPI','Generic Monitor','Integrated Monitor','Microsoft GS Wavetable Synth',
            'Driver de Renderização Básico da Microsoft','Driver de Vídeo Básico da Microsoft','HID-compliant consumer control device',
            'Microsoft Input Configuration Device','Device Association Root Enumerator','Print to PDF','Killer Networking Software',
            'NVIDIA Virtual Audio Device','Realtek Audio Universal Service','Waves Audio Effects Component','Kaspersky VPN',
            'Adaptador de CA da Microsoft','Bateria de Método de Controle','Recursos da placa-mãe',
            'Dispositivo HID I2C', 'Processador de dados numéricos','Controlador Padrão NVM Express','Tampa ACPI',
            'Trusted Platform Module 2.0','Driver de Arbitragem de Carregamento','Dispositivo UCM-UCSI ACPI',
            'Microsoft-System','Microsoft-Gerät','Controlador de sistema compatível com HID',
            'Dispositivo de Controle de Dispositivo Portátil','Dispositivo definido pelo fornecedor',
            'Fila de Impressão da Raiz', 'Serviço de Hipervisor da Microsoft', 'Servidor PCI do Hyper-V',
            'Intel HD Audio','NVIDIA High Definition Audio','Áudio Intel para telas','Proxy de serviço de stream Microsoft',
            'Transporte de Avrcp','A2DP SNK','Hands-Free','Standard PS/2','compatível com PS/2',
            'Alto-falantes','Speakers/Headphones','Realtek Audio','Qualcomm QCA61x4A Bluetooth','Bluetooth Device'
        )

        $manufacturerIgnoreKeywords = @(
            '(Standard system devices)', '(Tipos de monitor padrão)', '(Unidades de disco padrão)',
            '(Computadores padrão)', '(teclados padrões)'
        )
    }

    process {
        $finalPeripheralsList = New-Object System.Collections.ArrayList
        $processedNames = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

        # --- FASE 1: COLETA, FILTRAGEM E NORMALIZAÇÃO ---
        try {
            $pnpDevices = if ($isLegacyPS) {
                Get-WmiObject -Class Win32_PnPEntity | Where-Object { $_.Name -and $_.ConfigManagerErrorCode -eq 0 }
            } else {
                Get-PnpDevice -PresentOnly | Where-Object { $_.Status -eq 'OK' }
            }

            $internalInventory = $pnpDevices | ForEach-Object {
                $deviceName = if ($isLegacyPS) { $_.Name } else { $_.FriendlyName }
                $manufacturer = $_.Manufacturer

                # Filtro inicial por palavra-chave e fabricante
                $isIgnored = $false
                foreach ($keyword in $pnpIgnoreKeywords) { if ($deviceName -like "*$keyword*") { $isIgnored = $true; break } }
                if ($isIgnored) { return }
                foreach ($keyword in $manufacturerIgnoreKeywords) { if ($manufacturer -eq $keyword) { $isIgnored = $true; break } }
                if ($isIgnored) { return }

                # Normalização agressiva para agrupar dispositivos
                $normalizedName = $deviceName -replace 'Microsoft ', '' -replace '\s*\(.+\)', '' -replace ' compatível com HID', ''
                $normalizedName = $normalizedName -replace 'Headset - ', '' -replace 'Microfone - ', ''
                $normalizedName = $normalizedName.Trim()

                if ($normalizedName) {
                    [PSCustomObject]@{
                        NormalizedName = $normalizedName
                        Manufacturer   = $manufacturer
                        Class          = if ($isLegacyPS) { $_.Service } else { $_.Class }
                    }
                }
            }
            
            # --- FASE 2: CONSOLIDAÇÃO, CATEGORIZAÇÃO E FORMATAÇÃO ---
            foreach ($group in ($internalInventory | Group-Object -Property NormalizedName)) {
                $mainDevice = $group.Group | Select-Object -First 1
                $name = $mainDevice.NormalizedName
                
                if ($name -eq "" -or $processedNames.Contains($name)) { continue }
                
                $manufacturer = $mainDevice.Manufacturer
                $class = $mainDevice.Class
                $type = "Periférico"
                $details = $manufacturer

                # Lógica de categorização aprimorada
                if ($name -match 'Havit|H2002YG') { $type = 'Headset'; $name = "Headset Havit H2002YG" }
                elseif ($name -match 'HyperX') { $type = 'Teclado'; $name = "Teclado HyperX" }
                elseif ($name -match 'Logitech.*Mouse|LIGHTSPEED') { $type = 'Mouse Wireless'; $name = "Mouse Logitech LIGHTSPEED" }
                elseif ($class -like '*image*' -or $name -like '*webcam*') { $type = 'Webcam' }
                elseif ($name -match 'Receiver' -and $name -notlike '*logitech*') { $type = "Receptor Wireless" }
                elseif ($name -match 'Echo Dot') { $type = 'Dispositivo de Áudio (Smart Speaker)'; $name = "Amazon Echo Dot" }
                
                if ($type -ne "Periférico") {
                    [void]$processedNames.Add($name)
                    [void]$finalPeripheralsList.Add([PSCustomObject]@{
                        "Nome do Periférico"  = $name
                        "Tipo"                = $type
                        "Fabricante/Detalhes" = $details
                    })
                }
            }
        } catch { Write-Warning "Falha na coleta de dispositivos PnP: $($_.Exception.Message)" }

        # --- COLETA DE IMPRESSORAS COM DETALHES COMPLETOS ---
        try {
            $printers = if ($isLegacyPS) { Get-WmiObject -Class Win32_Printer } else { Get-CimInstance -ClassName Win32_Printer }
            $physicalPrinters = $printers | Where-Object { $_.Name -notmatch "PDF|Fax|OneNote|XPS|Microsoft" }
            
            foreach ($printer in $physicalPrinters) {
                $portName = $printer.PortName
                $type = "Impressora"
                $details = "Porta: $portName"

                if ($portName -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') {
                    $type = "Impressora (Rede)"
                    $details = "IP: $($matches[0])"
                } elseif ($portName -like "WSD*") {
                    $type = "Impressora (Rede)"
                    $details = "Porta WSD"
                } elseif ($portName -like "USB*") {
                    $type = "Impressora (USB)"
                    $details = "Conexão USB"
                }

                if ($printer.Shared) {
                    $details += ", Compartilhada na rede"
                }

                [void]$finalPeripheralsList.Add([PSCustomObject]@{
                    "Nome do Periférico"  = $printer.Name
                    "Tipo"                = $type
                    "Fabricante/Detalhes" = $details
                })
            }
        } catch { Write-Warning "Falha na coleta de impressoras: $($_.Exception.Message)" }

        # --- RETORNO FINAL ORGANIZADO E LIMPO ---
        if ($finalPeripheralsList.Count -eq 0) {
            return [PSCustomObject]@{ "Informação" = "Nenhum periférico físico relevante foi detetado." }
        } else {
            return $finalPeripheralsList.ToArray() | Select-Object "Nome do Periférico", "Tipo", "Fabricante/Detalhes" | Sort-Object -Property Tipo, "Nome do Periférico"
        }
    }
}