function Invoke-EitinEquipmentTypeInfo {
    [CmdletBinding()]
    param()

    process {
        $tipoEquipamentoValor = "Desconhecido" 
        $errorMessage = $null
        $dadosEquipamento = [ordered]@{
            "Tipo de Equipamento" = "Desconhecido"
            "Error"               = $null
        }

        try {
            $csSystem = Get-CimInstance Win32_ComputerSystem -Property PCSystemType -ErrorAction Stop
            $systemTypeObject = Get-SafeProperty -ObjectInstance $csSystem -PropertyName 'PCSystemType' -DefaultValue 0
            $systemTypeNumeric = 0 

            if ($systemTypeObject -match '^\d+$') { 
                $systemTypeNumeric = [int]$systemTypeObject
            } elseif ($systemTypeObject -is [int]) {
                $systemTypeNumeric = $systemTypeObject
            }
            
            $tipoEquipamentoValor = switch ($systemTypeNumeric) {
                1  { "Computador de Mesa (Desktop)" }
                2  { "Portátil (Notebook / Laptop)" }
                3  { "Estação de Trabalho (Desktop)" }
                4  { "Servidor Corporativo" }
                5  { "Servidor SOHO (Pequeno Escritório/Doméstico)" }
                6  { "PC Aparelho (Appliance)" }
                7  { "Servidor de Alto Desempenho" }
                8  { "Tablet" }
                9  { "Laptop" } 
                10 { "Notebook" } 
                11 { "Dispositivo Portátil de Mão (Hand Held)" }
                12 { "Estação de Acoplamento (Docking Station)" }
                13 { "Computador Tudo-em-Um (All-in-One)" }
                14 { "Sub-Notebook" }
                15 { "PC Compacto (Space-Saving)" }
                16 { "PC Portátil Robusto (Lunch Box)" }
                17 { "Chassi de Servidor Principal" }
                18 { "Chassi de Expansão" }
                19 { "Sub-Chassi" }
                20 { "Chassi de Expansão de Barramento" }
                21 { "Chassi Periférico" }
                22 { "Chassi de Armazenamento (RAID)" }
                23 { "Chassi para Montagem em Rack" }
                24 { "PC com Gabinete Selado" }
                25 { "Chassi Multi-Sistema" }
                26 { "Blade (Servidor Lâmina)" }
                27 { "Gabinete de Lâminas (Blade Enclosure)" }
                29 { "Conversível (Portátil)" } 
                30 { "Tablet Destacável" } 
                31 { "Conversível (Portátil)" } 
                32 { "Destacável (Portátil)" } 
                0  { "Não Especificado" } 
                default { "Desconhecido (Código WMI: $systemTypeNumeric)" }
            }
            $dadosEquipamento."Tipo de Equipamento" = $tipoEquipamentoValor
            $dadosEquipamento.Error = $null
        }
        catch {
            $errorMessage = "Erro ao determinar o tipo de equipamento: $($_.Exception.Message)"
            Write-Warning $errorMessage
            $dadosEquipamento."Tipo de Equipamento" = $errorMessage 
            $dadosEquipamento.Error = $errorMessage
        }
        
        if ($null -eq $dadosEquipamento.Error -and $dadosEquipamento.PSObject.Properties['Error'] -ne $null) {
            $tempObject = $dadosEquipamento.PSObject.Copy()
            $tempObject.Properties.Remove('Error')
            return $tempObject
        }

        return [PSCustomObject]$dadosEquipamento
    }
}