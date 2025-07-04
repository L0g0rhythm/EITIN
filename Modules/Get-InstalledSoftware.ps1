function Invoke-EitinInstalledSoftwareInfo {
    [CmdletBinding()]
    param()

    process {
        $installedSoftwareList = New-Object System.Collections.ArrayList
        $errorMessage = $null # Para armazenar uma mensagem de erro principal da coleta

        try {
            $registryKeysToSearch = @(
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
                # Futuramente, pode-se considerar adicionar HKCU para instalações por usuário, se necessário:
                # "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )

            $rawSoftwareEntries = foreach ($keyPath in $registryKeysToSearch) {
                # O -ErrorAction SilentlyContinue em Get-ItemProperty lida com chaves que podem não existir (ex: em sistemas 32-bit não haverá Wow6432Node)
                Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue |
                    Where-Object {
                        ($_.PSObject.Properties['DisplayName'] -ne $null -and -not [string]::IsNullOrWhiteSpace($_.DisplayName)) -and
                        # Filtro de Fabricante: Exclui explicitamente "Microsoft Corporation" e "Microsoft" como único fabricante
                        ($_.PSObject.Properties['Publisher'] -ne $null -and $_.Publisher -notmatch 'Microsoft Corporation' -and $_.Publisher -notmatch '^Microsoft$') -and 
                        # Filtro de Nome: Exclui atualizações comuns do Windows, hotfixes e componentes .NET/VC++
                        # Ajustado para ser mais preciso e evitar falsos positivos.
                        ($_.DisplayName -notmatch '^(KB\d{6,})|(Update for Microsoft)|(Security Update for Microsoft)|(Hotfix for Microsoft)|(Update Rollup)|(Language Pack)|(Language Support)') -and
                        ($_.DisplayName -notmatch '^Microsoft .NET Framework \d') -and
                        ($_.DisplayName -notmatch '^Microsoft Visual C\+\+ \d{4} Redistributable') -and
                        # Filtro de Componente do Sistema: Exclui componentes marcados como do sistema
                        ($_.PSObject.Properties['SystemComponent'] -eq $null -or $_.SystemComponent -ne 1) -and
                        # Evita subcomponentes de outros aplicativos que podem ter entradas separadas
                        ($_.PSObject.Properties['ParentKeyName'] -eq $null -or [string]::IsNullOrWhiteSpace($_.ParentKeyName)) -and
                        # Filtro WindowsInstaller foi problemático e removido; a maioria dos apps usa MSI.
                        ($_.PSObject.Properties['ReleaseType'] -eq $null -or ($_.ReleaseType -notin @('Hotfix', 'Update Rollup', 'Security Update', 'LanguagePack')))
                    } | Select-Object -Property DisplayName, DisplayVersion, Publisher, InstallDate 
            }
            
            # Agrupa por um DisplayName normalizado e Publisher para melhor deduplicação
            # Ordena por DisplayName para uma lista consistente.
            $uniqueSoftware = $rawSoftwareEntries | 
                Where-Object { $_.DisplayName } | # Garante que DisplayName não seja nulo antes de agrupar
                Group-Object -Property @{Expression={$_.DisplayName.Trim().ToLowerInvariant()}}, @{Expression={ ($_.Publisher -replace '[^a-zA-Z0-9]', '').ToLowerInvariant() }} | 
                ForEach-Object { $_.Group | Select-Object -First 1 } | 
                Sort-Object -Property DisplayName

            if ($uniqueSoftware) {
                foreach ($app in $uniqueSoftware) {
                    $installDateRaw = Get-SafeProperty -ObjectInstance $app -PropertyName 'InstallDate'
                    $installDateFormatted = "Não Encontrado" # Valor padrão

                    # Tenta converter apenas se $installDateRaw for uma string válida e não for "Não Encontrado"
                    if ($installDateRaw -ne "Não Encontrado" -and -not [string]::IsNullOrWhiteSpace($installDateRaw)) {
                        # A função Convert-WmiDate (do Utils.ps1) deve tratar o formato yyyyMMdd e retornar dd/MM/yyyy
                        $installDateFormatted = Convert-WmiDate -WmiDate $installDateRaw 
                    }

                    $appDetails = [ordered]@{
                        "Nome do Software"       = Get-SafeProperty -ObjectInstance $app -PropertyName 'DisplayName'
                        "Versão"                 = Get-SafeProperty -ObjectInstance $app -PropertyName 'DisplayVersion'
                        "Fabricante do Software" = Get-SafeProperty -ObjectInstance $app -PropertyName 'Publisher'
                        "Data de Instalação"     = $installDateFormatted # Usa a data formatada
                    }
                    [void]$installedSoftwareList.Add([PSCustomObject]$appDetails)
                }
            } 
            
            if ($installedSoftwareList.Count -eq 0) { 
                $errorMessage = "Nenhum software (não-Microsoft e não-componente de sistema) detectado com os filtros atuais."
            }

        }
        catch {
            $errorMessage = "Erro ao coletar informações de software instalado: $($_.Exception.Message)" 
            Write-Warning $errorMessage
            return [PSCustomObject]@{ Error = $errorMessage } 
        }

        if ($installedSoftwareList.Count -eq 0) {
            $finalMessage = if (-not [string]::IsNullOrWhiteSpace($errorMessage)) { $errorMessage } else { "Nenhum software instalado (relevante) encontrado." }
            # Retorna um objeto informativo em vez de um array vazio, para melhor apresentação
            return [PSCustomObject]@{ "Informação" = $finalMessage }
        }
        
        return $installedSoftwareList.ToArray()
    }
}