function Invoke-EitinPeripheralsInfo {
    [CmdletBinding()]
    param()

    process {
        # Estrutura de dados de saída, organizada por tipo de periférico
        $peripheralsData = [ordered]@{
            "Impressoras Instaladas" = @()
            "Dispositivos de Áudio"  = @()
            "Dispositivos de Entrada e Mídia" = @()
        }

        # --- 1. Coleta de Impressoras com Detalhes de Rede ---
        try {
            $printersList = New-Object System.Collections.ArrayList
            $printers = Get-CimInstance -ClassName Win32_Printer -ErrorAction Stop
            if ($printers) {
                foreach ($printer in $printers) {
                    $ipAddress = "N/A"
                    $portName = Get-SafeProperty -ObjectInstance $printer -PropertyName 'PortName'
                    
                    if ($portName -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') {
                        $ipAddress = $matches[0]
                    } elseif ($portName -like "WSD*") {
                        $ipAddress = "Porta WSD"
                    } elseif ($portName -like "USB*") {
                        $ipAddress = "Porta USB"
                    }

                    [void]$printersList.Add([PSCustomObject]@{
                        "Nome da Impressora" = Get-SafeProperty $printer 'Name'
                        "Driver"             = Get-SafeProperty $printer 'DriverName'
                        "Endereço (IP ou Porta)" = if ($ipAddress -ne "N/A") { $ipAddress } else { $portName }
                        "Compartilhada"      = if (Get-SafeProperty $printer 'Shared' $false) { 'Sim' } else { 'Não' }
                        "Impressora Padrão"  = if (Get-SafeProperty $printer 'Default' $false) { 'Sim' } else { 'Não' }
                        "Status Detalhado"   = Get-SafeProperty $printer 'Status'
                    })
                }
                $peripheralsData."Impressoras Instaladas" = $printersList.ToArray()
            } else {
                $peripheralsData."Impressoras Instaladas" = @([PSCustomObject]@{"Informação" = "Nenhuma impressora encontrada."})
            }
        } catch {
            $peripheralsData."Impressoras Instaladas" = @([PSCustomObject]@{ "Erro na Coleta" = "Falha ao consultar impressoras: $($_.Exception.Message)" })
        }

        # --- 2. Coleta de Dispositivos de Áudio ---
        try {
            $audioList = New-Object System.Collections.ArrayList
            $soundDevices = Get-CimInstance -ClassName Win32_SoundDevice -ErrorAction Stop
            if ($soundDevices) {
                foreach ($device in $soundDevices) {
                    [void]$audioList.Add([PSCustomObject]@{
                        "Nome do Produto" = Get-SafeProperty $device 'ProductName'
                        "Fabricante"      = Get-SafeProperty $device 'Manufacturer'
                        "Status"          = Get-SafeProperty $device 'Status'
                    })
                }
                $peripheralsData."Dispositivos de Áudio" = $audioList.ToArray()
            } else {
                $peripheralsData."Dispositivos de Áudio" = @([PSCustomObject]@{"Informação" = "Nenhum dispositivo de áudio encontrado."})
            }
        } catch {
            $peripheralsData."Dispositivos de Áudio" = @([PSCustomObject]@{ "Erro na Coleta" = "Falha ao consultar dispositivos de áudio: $($_.Exception.Message)" })
        }
        
        # --- 3. Coleta de Dispositivos de Entrada (Método Robusto com Get-PnpDevice) ---
        try {
            $inputList = New-Object System.Collections.ArrayList
            # Consultando um leque mais amplo de classes para capturar mouses/teclados/fones wireless
            $classesToQuery = @('Mouse', 'Keyboard', 'HIDClass', 'Bluetooth', 'AudioEndpoint', 'Image', 'Media', 'USB')
            
            $pnpDevices = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object {
                $_.Class -in $classesToQuery -and $_.Status -eq 'OK'
            }
            if ($pnpDevices) {
                # Filtro inteligente para remover hubs e controladores de sistema genéricos
                $filteredDevices = $pnpDevices | Where-Object {
                    $_.FriendlyName -and
                    $_.Manufacturer -ne "(Standard system devices)" -and
                    $_.FriendlyName -notmatch "(Host Controller|Root Hub|Composite Device|Generic SuperSpeed|Controller Host)"
                }

                # Agrupa por nome para remover duplicatas (ex: headset que aparece como Áudio e Bluetooth)
                $uniqueDevices = $filteredDevices | Group-Object -Property FriendlyName | ForEach-Object {
                    $_.Group | Select-Object -First 1
                }

                foreach ($device in $uniqueDevices) {
                    [void]$inputList.Add([PSCustomObject]@{
                        "Tipo"       = Get-SafeProperty $device 'Class' 'Desconhecido'
                        "Nome Amigável" = Get-SafeProperty $device 'FriendlyName'
                        "Fabricante" = Get-SafeProperty $device 'Manufacturer'
                    })
                }
            }
            
            if ($inputList.Count > 0) {
                $peripheralsData."Dispositivos de Entrada e Mídia" = $inputList.ToArray() | Sort-Object -Property Tipo, "Nome Amigável"
            } else {
                 $peripheralsData."Dispositivos de Entrada e Mídia" = @([PSCustomObject]@{"Informação" = "Nenhum dispositivo de entrada ou mídia específico (ex: mouse/fone wireless) detectado via PnP."})
            }
        } catch {
            $peripheralsData."Dispositivos de Entrada e Mídia" = @([PSCustomObject]@{ "Erro na Coleta" = "Falha ao consultar dispositivos PnP: $($_.Exception.Message)" })
        }

        return [PSCustomObject]$peripheralsData
    }
}