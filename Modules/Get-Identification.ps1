function Invoke-EitinIdentificationInfo {
    [CmdletBinding()]
    param()

    process {
        # Campo "Todas as Contas de Usuário Locais" foi removido
        $dadosIdentificacao = [ordered]@{
            "Nome do Computador"              = $env:COMPUTERNAME
            "Usuário(s) Logado(s) no Sistema" = "Não Coletado" 
            #"Inventário Executado Por"        = "Não Coletado" 
            "Contas Locais Ativas (Usuais)"   = "Não Coletado" # Alterado de @() para string de fallback
        }

        #try {
            #$dadosIdentificacao."Inventário Executado Por" = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        #}
        #catch {
            #$dadosIdentificacao."Inventário Executado Por" = "Erro ao coletar usuário executor: $($_.Exception.Message)"
        #}

        try {
            # Coleta usuários logados interativamente
            $activeUsersCim = Get-CimInstance -ClassName Win32_LogonSession -Filter "LogonType = 2" -ErrorAction Stop | 
                              ForEach-Object { Get-CimAssociatedInstance -InputObject $_ -ResultClassName Win32_Account -ErrorAction SilentlyContinue } |
                              Where-Object { $_.Name -ne $null } |
                              Select-Object -ExpandProperty Name -Unique
            if ($activeUsersCim) { 
                $dadosIdentificacao."Usuário(s) Logado(s) no Sistema" = $activeUsersCim -join ', ' 
            } else {
                $dadosIdentificacao."Usuário(s) Logado(s) no Sistema" = "Nenhum usuário interativo detectado" # Mensagem mais clara
            }
        }
        catch {
            $dadosIdentificacao."Usuário(s) Logado(s) no Sistema" = "Erro ao coletar usuários interativos: $($_.Exception.Message)"
        }

        # Lógica para "Todas as Contas de Usuário Locais" REMOVIDA
        # try {
        #     $localUsers = Get-LocalUser -ErrorAction Stop 
        #     if ($localUsers) {
        #         $localUsersList = [System.Collections.ArrayList]::new()
        #         foreach ($user in $localUsers) {
        #             [void]$localUsersList.Add($user.Name)
        #         }
        #         # $dadosIdentificacao."Todas as Contas de Usuário Locais" = $localUsersList.ToArray() -join ', ' # Exemplo de melhoria se fosse manter
        #     } else {
        #         # $dadosIdentificacao."Todas as Contas de Usuário Locais" = "Nenhum usuário local encontrado." 
        #     }
        # }
        # catch {
        #     # $dadosIdentificacao."Todas as Contas de Usuário Locais" = "Erro ao buscar usuários locais: $($_.Exception.Message)" 
        # }

        try {
            # Filtra para contas locais que são de usuários "comuns" e estão ativas
            $filteredUserNames = Get-CimInstance Win32_UserAccount -Filter "LocalAccount = TRUE AND Disabled = FALSE" -ErrorAction Stop | 
                Where-Object { $_.Name -notmatch '^(Administrator|DefaultAccount|Guest|WDAGUtilityAccount|Administrador|Convidado|IUSR_.*|IWAM_.*|ASPNET|SQL.*|SM_.*|SUPPORT_.*|krbtgt)$' } | 
                Select-Object -ExpandProperty Name -Unique | Sort-Object
            
            if ($filteredUserNames) {
                 $dadosIdentificacao."Contas Locais Ativas (Usuais)" = $filteredUserNames -join ', ' # Junta com vírgula e espaço
            } else {
                $dadosIdentificacao."Contas Locais Ativas (Usuais)" = "Nenhum usuário local ativo (usual) encontrado." # Mensagem mais clara
            }
        }
        catch {
            $dadosIdentificacao."Contas Locais Ativas (Usuais)" = "Erro ao buscar usuários ativos/filtrados: $($_.Exception.Message)"
        }

        return [PSCustomObject]$dadosIdentificacao
    }
}