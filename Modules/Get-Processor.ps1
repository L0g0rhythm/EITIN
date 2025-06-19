function Invoke-EitinProcessorInfo {
    [CmdletBinding()]
    param()

    process {
        $dadosProcessador = [ordered]@{
            "Fabricante do Processador"       = "Não Encontrado" 
            "Modelo do Processador"           = "Não Encontrado"
            "Número de Núcleos Físicos"       = "Não Encontrado" 
            "Número de Processadores Lógicos" = "Não Encontrado" 
            "Velocidade Máxima (MHz)"         = "Não Encontrado"
            "Arquitetura do Processador (bits)" = "Não Encontrado" 
            "Designação do Socket"            = "Não Encontrado"
            "Error"                           = $null 
        }

        try {
            # Seleciona todas as propriedades necessárias, incluindo SocketDesignation
            $proc = Get-CimInstance -ClassName Win32_Processor `
                -Property Name, Manufacturer, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed, AddressWidth, SocketDesignation `
                -ErrorAction SilentlyContinue | Select-Object -First 1 

            if ($proc) {
                $dadosProcessador."Fabricante do Processador"       = Get-SafeProperty -ObjectInstance $proc -PropertyName 'Manufacturer'
                $dadosProcessador."Modelo do Processador"           = Get-SafeProperty -ObjectInstance $proc -PropertyName 'Name'
                $dadosProcessador."Número de Núcleos Físicos"       = Get-SafeProperty -ObjectInstance $proc -PropertyName 'NumberOfCores'
                $dadosProcessador."Número de Processadores Lógicos" = Get-SafeProperty -ObjectInstance $proc -PropertyName 'NumberOfLogicalProcessors'
                $dadosProcessador."Velocidade Máxima (MHz)"         = Get-SafeProperty -ObjectInstance $proc -PropertyName 'MaxClockSpeed'
                $dadosProcessador."Arquitetura do Processador (bits)" = Get-SafeProperty -ObjectInstance $proc -PropertyName 'AddressWidth'
                $dadosProcessador."Designação do Socket"            = Get-SafeProperty -ObjectInstance $proc -PropertyName 'SocketDesignation'
                
                $dadosProcessador.Error = $null 
            } else {
                $errorMessage = "Nenhuma informação de processador encontrada via WMI (Win32_Processor)."
                $dadosProcessador.Error = $errorMessage
            }
        }
        catch {
            $errorMessage = "Erro ao coletar informações do processador: $($_.Exception.Message)"
            Write-Warning $errorMessage
            $dadosProcessador."Modelo do Processador"   = "Erro na Coleta" 
            $dadosProcessador."Número de Núcleos Físicos" = $errorMessage 
            $dadosProcessador.Error = $errorMessage
        }

        if ($dadosProcessador.PSObject.Properties['Error'] -ne $null -and $null -eq $dadosProcessador.Error) {
            $propriedadesLimpas = [ordered]@{}
            foreach ($propriedade in $dadosProcessador.PSObject.Properties) {
                if ($propriedade.Name -ne 'Error') {
                    $propriedadesLimpas[$propriedade.Name] = $propriedade.Value
                }
            }
            return [PSCustomObject]$propriedadesLimpas
        }

        return [PSCustomObject]$dadosProcessador
    }
}