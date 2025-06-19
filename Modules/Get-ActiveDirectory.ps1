function Invoke-EitinActiveDirectoryInfo {
    [CmdletBinding()]
    param()

    process {
        $statusMessage = $null

        try {
            $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -Property PartOfDomain -ErrorAction Stop
            if (-not $computerSystem.PartOfDomain) {
                $statusMessage = "Computador não está ingressado em um domínio."
                Write-Verbose "Get-ActiveDirectoryInfo: $statusMessage"
                return $null
            }
        } catch {
            $statusMessage = "Não foi possível determinar o status de ingresso no domínio (falha na consulta Win32_ComputerSystem): $($_.Exception.Message)"
            Write-Warning $statusMessage
            return [PSCustomObject]@{ Error = $statusMessage } 
        }

        if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
            $statusMessage = "Módulo ActiveDirectory (RSAT) não instalado. Informações do AD não podem ser coletadas."
            Write-Warning $statusMessage
            return $null
        }

        $dadosAD = [ordered]@{
            "Status de Ingresso no Domínio"          = "Sim"
            "Nome DNS do Host (no AD)"               = "Não Coletado"
            "Nome da Conta SAM (no AD)"              = "Não Coletado"
            "Nome Distinto (DN no AD)"               = "Não Coletado"
            "Sistema Operacional (Registrado no AD)" = "Não Coletado"
            "Último Logon (Registrado no AD)"        = "Não Coletado"
            "Status da Conta (no AD)"                = "Não Coletado"
            "Endereço IPv4 (Registrado no AD)"       = "Não Coletado"
            "Error"                                  = $null
        }

        try {
            Import-Module ActiveDirectory -ErrorAction Stop -WarningAction SilentlyContinue
            
            $adComputer = Get-ADComputer $env:COMPUTERNAME -Properties DistinguishedName, OperatingSystem, LastLogonDate, Enabled, IPv4Address, DNSHostName, SamAccountName -ErrorAction Stop

            if ($adComputer) {
                $dadosAD."Nome DNS do Host (no AD)"               = Get-SafeProperty $adComputer 'DNSHostName'
                $dadosAD."Nome da Conta SAM (no AD)"              = Get-SafeProperty $adComputer 'SamAccountName'
                $dadosAD."Nome Distinto (DN no AD)"               = Get-SafeProperty $adComputer 'DistinguishedName'
                $dadosAD."Sistema Operacional (Registrado no AD)" = Get-SafeProperty $adComputer 'OperatingSystem'
                
                $lastLogonDateRaw = Get-SafeProperty $adComputer 'LastLogonDate' $null
                if ($lastLogonDateRaw -and $lastLogonDateRaw -is [datetime]) {
                    $dadosAD."Último Logon (Registrado no AD)" = $lastLogonDateRaw.ToString('yyyy-MM-dd HH:mm:ss')
                } elseif ($null -ne $lastLogonDateRaw -and $lastLogonDateRaw -ne 0) {
                    $dadosAD."Último Logon (Registrado no AD)" = "Data Inválida ou Não Registrada ($lastLogonDateRaw)"
                } else {
                    $dadosAD."Último Logon (Registrado no AD)" = "Não Registrado"
                }
                
                $isEnabled = Get-SafeProperty $adComputer 'Enabled' $null
                $dadosAD."Status da Conta (no AD)"  = if ($null -ne $isEnabled) { if ($isEnabled) {'Habilitada'} else {'Desabilitada'} } else { "Status Desconhecido" }
                $dadosAD."Endereço IPv4 (Registrado no AD)" = Get-SafeProperty $adComputer 'IPv4Address'
                
                $dadosAD.Error = $null
            } else {
                $dadosAD.Error = "Get-ADComputer não retornou dados para $env:COMPUTERNAME."
                $dadosAD."Status de Ingresso no Domínio" = "Sim (mas dados não encontrados)"
            }
        }
        catch {
            $errorMessage = "Erro ao coletar informações do Active Directory: $($_.Exception.Message)"
            Write-Warning $errorMessage
            $dadosAD."Status de Ingresso no Domínio" = "Erro na Consulta ao AD"
            $dadosAD.Error = $errorMessage
        }
        
        if ($null -eq $dadosAD.Error -and $dadosAD.PSObject.Properties['Error'] -ne $null) {
            $tempObject = $dadosAD.PSObject.Copy()
            $tempObject.Properties.Remove('Error')
            return [PSCustomObject]$tempObject
        }

        return [PSCustomObject]$dadosAD
    }
}