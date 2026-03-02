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
            # Captura completa da exceção para diagnóstico (Stack Trace preservado no objeto de erro se necessário)
            $exception = $_.Exception
            $errorMessage = "FALHA CRÍTICA na coleta de sistema: $($exception.Message)"
            Write-Warning $errorMessage

            # Define valores nulos ou explícitos de erro, em vez de strings repetitivas que poluem o relatório
            $keys = $informacoesSistema.Keys | Where-Object { $_ -ne "Error" }
            foreach ($key in $keys) {
                $informacoesSistema[$key] = "N/A (Erro na Coleta)"
            }

            # Preserva o erro técnico detalhado
            $informacoesSistema.Error = "$errorMessage`r`nStack Trace: $($_.ScriptStackTrace)"
        }

        if ($null -eq $informacoesSistema.Error -and $null -ne $informacoesSistema.PSObject.Properties['Error']) {
            $tempObject = $informacoesSistema.PSObject.Copy()
            $tempObject.Properties.Remove('Error')
            return $tempObject
        }

        return [PSCustomObject]$informacoesSistema
    }
}
