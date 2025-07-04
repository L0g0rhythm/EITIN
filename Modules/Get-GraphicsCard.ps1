function Invoke-EitinGraphicsCardInfo {
    [CmdletBinding()]
    param()

    process {
        $gpuList = New-Object System.Collections.ArrayList
        $errorMessage = $null # Para armazenar uma mensagem de erro principal da coleta

        try {
            # Seleciona apenas as propriedades necessárias para otimização, incluindo AdapterCompatibility
            $gpusWmi = Get-CimInstance -ClassName Win32_VideoController `
                -Property Name, DriverVersion, DriverDate, VideoProcessor, AdapterRAM, `
                          CurrentHorizontalResolution, CurrentVerticalResolution, Status, PNPDeviceID, AdapterCompatibility `
                -ErrorAction Stop 
            
            if ($gpusWmi) {
                $gpuIndex = 1
                foreach ($gpu in $gpusWmi) {
                    $gpuNameValue = Get-SafeProperty -ObjectInstance $gpu -PropertyName 'Name'
                    $wmiDriverVersion = Get-SafeProperty -ObjectInstance $gpu -PropertyName 'DriverVersion'
                    $finalDriverVersion = $wmiDriverVersion # Começa com a versão WMI

                    # Tenta obter uma versão de driver "marketing" mais amigável para NVIDIA
                    if ($gpuNameValue -match "NVIDIA") {
                        $nvidiaRegistryPath = "HKLM:\SOFTWARE\NVIDIA Corporation\Global\NVTweak"
                        $nvidiaInstallerPath = "HKLM:\SOFTWARE\NVIDIA Corporation\Installer2" # Caminho alternativo
                        $marketingVersion = $null
                        try {
                            # Tenta o primeiro caminho do registro
                            if (Test-Path $nvidiaRegistryPath) {
                                $marketingVersion = (Get-ItemProperty -Path $nvidiaRegistryPath -Name DispDrvrVer -ErrorAction SilentlyContinue).DispDrvrVer
                            }
                            # Se não encontrou, tenta o caminho do instalador (mais complexo, mas pode ter info mais recente)
                            if (-not $marketingVersion -and (Test-Path $nvidiaInstallerPath)) {
                                # Busca recursivamente por chaves que contenham Display.Driver
                                $driverKeys = Get-ChildItem -Path $nvidiaInstallerPath -Recurse -ErrorAction SilentlyContinue | 
                                              Where-Object {$_.Name -match "Display.Driver"}
                                # Ordena pela data de modificação da chave (mais recente primeiro)
                                $latestDriverKey = $driverKeys | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
                                if ($latestDriverKey) {
                                    $marketingVersion = (Get-ItemProperty -Path $latestDriverKey.PSPath -Name DisplayDriverVersion -ErrorAction SilentlyContinue).DisplayDriverVersion
                                }
                            }
                        } catch {
                            # Silencia erros de acesso ao registro, O WMI DriverVersion já é um fallback
                            Write-Verbose "Não foi possível acessar o registro NVIDIA para versão de marketing do driver: $($_.Exception.Message)"
                        }
                        if (-not [string]::IsNullOrWhiteSpace($marketingVersion)) {
                            $finalDriverVersion = $marketingVersion # Usa a versão de marketing se encontrada
                        }
                    }

                    $adapterRamBytes = Get-SafeProperty -ObjectInstance $gpu -PropertyName 'AdapterRAM' -DefaultValue 0 
                    $ramMBVal = if ($adapterRamBytes -gt 0) { [math]::Round($adapterRamBytes / 1MB) } else { "N/A" } 

                    $rawDriverDate = Get-SafeProperty -ObjectInstance $gpu -PropertyName 'DriverDate'
                    # Convert-WmiDate (do Utils.ps1) deve retornar no formato dd/MM/yyyy ou "Não Disponível"/"Erro na Conversão"
                    $driverDateFormattedVal = Convert-WmiDate -WmiDate $rawDriverDate 

                    $resH_val = Get-SafeProperty -ObjectInstance $gpu -PropertyName 'CurrentHorizontalResolution' 
                    $resV_val = Get-SafeProperty -ObjectInstance $gpu -PropertyName 'CurrentVerticalResolution' 
                    $currentResolutionVal = "Não Disponível" # Default traduzido
                    
                    # Garante que ambos os valores de resolução são numéricos e maiores que zero
                    $hResNum = 0
                    $vResNum = 0
                    $hResIsNum = [int]::TryParse($resH_val, [ref]$hResNum)
                    $vResIsNum = [int]::TryParse($resV_val, [ref]$vResNum)

                    if ($hResIsNum -and $vResIsNum -and $hResNum -gt 0 -and $vResNum -gt 0) {
                        $currentResolutionVal = "$($hResNum)x$($vResNum)"
                    }
                    
                    $gpuDetails = [ordered]@{
                        "Identificador da GPU"        = "GPU $($gpuIndex)"
                        "Nome da GPU"                 = $gpuNameValue
                        "Fabricante do Chipset Gráfico" = Get-SafeProperty -ObjectInstance $gpu -PropertyName 'AdapterCompatibility' # Novo campo
                        "Versão do Driver"            = $finalDriverVersion
                        "Data do Driver"              = $driverDateFormattedVal
                        "Processador de Vídeo"        = Get-SafeProperty -ObjectInstance $gpu -PropertyName 'VideoProcessor'
                        "Memória da Placa (MB)"       = $ramMBVal
                        "Resolução Atual (GPU)"       = $currentResolutionVal
                        "Status do Dispositivo (GPU)" = Get-SafeProperty -ObjectInstance $gpu -PropertyName 'Status'
                    }
                    [void]$gpuList.Add([PSCustomObject]$gpuDetails)
                    $gpuIndex++ 
                }
            } else {
                $errorMessage = "Nenhuma placa de vídeo encontrada via Win32_VideoController." # Traduzido
                # Adiciona um objeto informativo à lista em vez de apenas definir a mensagem de erro
                [void]$gpuList.Add([PSCustomObject]@{ 
                    "Identificador da GPU"        = "N/A"
                    "Nome da GPU"                 = "Nenhuma Encontrada" # Traduzido
                    "Detalhe"                     = $errorMessage
                    "Error"                       = $errorMessage # Para o logger, se necessário
                })
            }
        }
        catch {
            $errorMessage = "Erro ao coletar informações da placa de vídeo: $($_.Exception.Message)" # Traduzido
            Write-Warning $errorMessage
            # Retorna um objeto de erro único para ser tratado pelo coletor principal
            return [PSCustomObject]@{ Error = $errorMessage } 
        }

        # Se a lista estiver vazia e não houve um erro de exceção capturado
        if ($gpuList.Count -eq 0 -and -not $errorMessage) {
            $errorMessage = "Nenhuma placa de vídeo detectada após processamento." # Traduzido
             [void]$gpuList.Add([PSCustomObject]@{ 
                "Identificador da GPU"        = "N/A"
                "Nome da GPU"                 = "Nenhuma Detectada" # Traduzido
                "Detalhe"                     = $errorMessage
                "Error"                       = $errorMessage 
            })
        }
        
        # Garante que, se houver um erro e a lista tiver apenas esse erro, ele seja retornado como um objeto único
        # Isso evita que o EITIN.ps1 tente processar um array contendo apenas um objeto de erro como se fosse um dado válido.
        if ($gpuList.Count -eq 1 -and $gpuList[0].PSObject.Properties['Error'] -ne $null -and $gpuList[0].Error) {
            return $gpuList[0] 
        }

        return $gpuList.ToArray()
    }
}