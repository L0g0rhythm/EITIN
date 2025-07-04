function Invoke-EitinSystemInfoInfo {
    [CmdletBinding()]
    param()

    process {
        $informacoesSistema = [ordered]@{
            "Nome do Produto (SO)"             = "Não Encontrado"
            "Descrição do SO"                  = "Não Encontrado"
            "Edição do SO"                     = "Não Encontrado"
            "Versão do SO"                     = "Não Encontrado"
            "Build (Compilação) do SO"         = "Não Encontrado"
            "Arquitetura do SO"                = "Não Encontrado"
            "Data de Instalação do SO"         = "Não Encontrado"
            "Sistema Operacional (Completo)"   = "Não Encontrado"
            "Error"                            = $null 
        }

        try {
            $os = Get-CimInstance Win32_OperatingSystem -Property Caption, Version, OSArchitecture, InstallDate -ErrorAction Stop
            $winSpecRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            $winSpec = Get-ItemProperty -Path $winSpecRegPath -Name EditionID, CurrentBuild, ProductName -ErrorAction Stop

            $nomeProdutoSO = Get-SafeProperty -ObjectInstance $winSpec -PropertyName 'ProductName'
            $descricaoSO   = Get-SafeProperty -ObjectInstance $os -PropertyName 'Caption'

            $informacoesSistema."Nome do Produto (SO)"         = $nomeProdutoSO
            $informacoesSistema."Descrição do SO"              = $descricaoSO
            $informacoesSistema."Edição do SO"                 = Get-SafeProperty -ObjectInstance $winSpec -PropertyName 'EditionID'
            $informacoesSistema."Versão do SO"                 = Get-SafeProperty -ObjectInstance $os -PropertyName 'Version'
            $informacoesSistema."Build (Compilação) do SO"     = Get-SafeProperty -ObjectInstance $winSpec -PropertyName 'CurrentBuild'
            $informacoesSistema."Arquitetura do SO"            = Get-SafeProperty -ObjectInstance $os -PropertyName 'OSArchitecture'
            
            $rawInstallDate = Get-SafeProperty -ObjectInstance $os -PropertyName 'InstallDate' -DefaultValue ""
            $informacoesSistema."Data de Instalação do SO"     = Convert-WmiDate -WmiDate $rawInstallDate

            if ($nomeProdutoSO -ne "Não Encontrado" -and $nomeProdutoSO -ne "Error" -and $descricaoSO -ne "Não Encontrado" -and $descricaoSO -ne "Error") {
                $informacoesSistema."Sistema Operacional (Completo)" = "$($nomeProdutoSO) ($($descricaoSO))"
            } elseif ($nomeProdutoSO -ne "Não Encontrado" -and $nomeProdutoSO -ne "Error") {
                $informacoesSistema."Sistema Operacional (Completo)" = $nomeProdutoSO
            } elseif ($descricaoSO -ne "Não Encontrado" -and $descricaoSO -ne "Error") {
                $informacoesSistema."Sistema Operacional (Completo)" = $descricaoSO
            }
            
            $informacoesSistema.Error = $null 
        }
        catch {
            $errorMessage = "Erro ao coletar informações do sistema: $($_.Exception.Message)"
            Write-Warning $errorMessage
            $informacoesSistema."Nome do Produto (SO)"             = $errorMessage 
            $informacoesSistema."Descrição do SO"                  = "Erro na coleta"
            $informacoesSistema."Edição do SO"                     = "Erro na coleta"
            $informacoesSistema."Versão do SO"                     = "Erro na coleta"
            $informacoesSistema."Build (Compilação) do SO"         = "Erro na coleta"
            $informacoesSistema."Arquitetura do SO"                = "Erro na coleta"
            $informacoesSistema."Data de Instalação do SO"         = "Erro na coleta"
            $informacoesSistema."Sistema Operacional (Completo)"   = "Erro na coleta"
            $informacoesSistema.Error = $errorMessage 
        }

        if ($null -eq $informacoesSistema.Error -and $informacoesSistema.PSObject.Properties['Error'] -ne $null) {
            $tempObject = $informacoesSistema.PSObject.Copy()
            $tempObject.Properties.Remove('Error')
            return $tempObject
        }

        return [PSCustomObject]$informacoesSistema
    }
}