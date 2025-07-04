function Invoke-EitinSecurityComplianceInfo {
    [CmdletBinding()]
    param()

    process {
        $complianceDataResult = [ordered]@{
            "Criptografia de Disco (BitLocker)"             = "Não Verificado"
            "Controle de Conta de Usuário (UAC)"            = "Não Verificado"
            "Atualizações Automáticas do Windows"           = "Não Verificado"
            "Nota sobre Coleta de Dados e Conformidade"     = "Este processo de inventário tem como objetivo coletar informações técnicas do sistema, destinadas exclusivamente ao gerenciamento, controle e suporte de ambientes de TI. Ressaltamos que são coletados apenas dados não sensíveis, sem conteúdo pessoal, conforme definido pelas legislações vigentes. O tratamento, armazenamento e uso das informações obtidas deverão obedecer rigorosamente às políticas internas de segurança da informação e às normas legais aplicáveis, como a Lei Geral de Proteção de Dados (LGPD) e o Regulamento Geral sobre a Proteção de Dados da União Europeia (GDPR)."
            "Error"                                         = $null
        }
        $moduleOverallError = $false

        # --- 1. Status do BitLocker ---
        $bitlockerInfoList = New-Object System.Collections.ArrayList
        Write-Verbose "Coletando status do BitLocker..."
        try {
            if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
                $bitlockerVolumes = Get-BitLockerVolume -ErrorAction SilentlyContinue
                if ($bitlockerVolumes) {
                    foreach ($volume in $bitlockerVolumes) {
                        $protectionStatusRaw = Get-SafeProperty $volume 'ProtectionStatus' 'Desconhecido'
                        $protectionStatusFriendly = switch ($protectionStatusRaw.ToString()) {
                            "0"             { "Desligada (Volume Não Criptografado)" } 
                            "1"             { "Ligada (Volume Criptografado)" }    
                            "Off"           { "Desligada (Volume Não Criptografado)" }
                            "On"            { "Ligada (Volume Criptografado)" }
                            default         { "Status Desconhecido (Cód/Valor: $($protectionStatusRaw))" }
                        }
                        $encryptionMethodRaw = Get-SafeProperty $volume 'EncryptionMethod' 'Desconhecido'
                        $encryptionMethodFriendly = switch ($encryptionMethodRaw.ToString()) {
                            "0"             { "Nenhum" } 1             { "AES 128 bits (com Difusor)" } 2             { "AES 256 bits (com Difusor)" }
                            "3"             { "AES 128 bits" } 4             { "AES 256 bits" } 5             { "Por Hardware (SED)" }
                            "6"             { "XTS-AES 128 bits" } "XtsAes128"     { "XTS-AES 128 bits" }
                            "7"             { "XTS-AES 256 bits" } "XtsAes256"     { "XTS-AES 256 bits" }
                            default         { "Desconhecido (Cód/Valor: $($encryptionMethodRaw))" }
                        }
                        $volumeTypeRaw = Get-SafeProperty $volume 'VolumeType' 'Desconhecido'
                        $volumeTypeFriendly = switch ($volumeTypeRaw.ToString()) {
                            "0"               { "Desconhecido" } 1               { "Volume do Sistema Operacional" } "OperatingSystem" { "Volume do Sistema Operacional" }
                            "2"               { "Volume de Dados Fixo" }  "Data"            { "Volume de Dados" } 
                            "3"               { "Volume de Dados Removível" } 
                            default           { "Tipo Desconhecido (Cód/Valor: $($volumeTypeRaw))"}
                        }
                        [void]$bitlockerInfoList.Add([PSCustomObject]@{
                            "Ponto de Montagem"           = Get-SafeProperty $volume 'MountPoint' 'N/A'
                            "Tipo de Volume"              = $volumeTypeFriendly
                            "Status de Proteção"          = $protectionStatusFriendly
                            "Método de Criptografia"      = $encryptionMethodFriendly
                            "Percentual Criptografado"    = Get-SafeProperty $volume 'EncryptionPercentage' 'N/A'
                        })
                    } 
                    if ($bitlockerInfoList.Count -gt 0) {
                        $complianceDataResult["Criptografia de Disco (BitLocker)"] = $bitlockerInfoList.ToArray()
                    } else {
                        $complianceDataResult["Criptografia de Disco (BitLocker)"] = "Nenhum volume com BitLocker configurado ou detectado."
                    }
                } else { 
                    $complianceDataResult["Criptografia de Disco (BitLocker)"] = "Nenhuma informação de volume BitLocker retornada pelo sistema (verifique se há volumes criptografados)." 
                }
            } else { 
                $complianceDataResult["Criptografia de Disco (BitLocker)"] = "Não Verificável (ferramenta Get-BitLockerVolume ausente ou inacessível)." 
            }
        } catch {
            $exceptionMessage = Get-SafeProperty $_.Exception 'Message' 'Detalhe indisponível'
            Write-Warning "Erro ao coletar status do BitLocker: $exceptionMessage"
            $complianceDataResult["Criptografia de Disco (BitLocker)"] = "Erro na Coleta: $exceptionMessage"
            $moduleOverallError = $true
        }

        # --- 2. Status do Controle de Conta de Usuário (UAC) ---
           Write-Verbose "Coletando status do UAC..."
        try {
            $uacKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            $uacFriendlyStatus = "Não Determinado (Verifique manualmente as configurações do UAC)." # Fallback amigável

            if (Test-Path $uacKeyPath) {
                $enableLUA = Get-ItemPropertyValue -Path $uacKeyPath -Name "EnableLUA" -ErrorAction SilentlyContinue
                
                if ($null -ne $enableLUA) {
                    if ($enableLUA -eq 1) {
                        $consentPromptBehaviorAdmin = Get-ItemPropertyValue -Path $uacKeyPath -Name "ConsentPromptBehaviorAdmin" -ErrorAction SilentlyContinue
                        if ($null -ne $consentPromptBehaviorAdmin) {
                            $uacLevelDescription = switch ($consentPromptBehaviorAdmin) {
                                0       { "Nunca notifica sobre alterações (Configuração de Baixa Segurança)." } 
                                1       { "Notifica apenas quando aplicativos tentam fazer alterações (sem escurecer a tela) e solicita credenciais." } 
                                2       { "Notifica apenas quando aplicativos tentam fazer alterações (Padrão - escurece a tela para segurança) e solicita consentimento." } 
                                3       { "Sempre notifica e solicita credenciais (sem escurecer a tela)." } 
                                4       { "Sempre notifica e solicita consentimento (sem escurecer a tela)." } 
                                5       { "Sempre notifica (Máxima Segurança - escurece a tela para segurança) e solicita consentimento." } 
                                default { "Nível de notificação com código interno '$($consentPromptBehaviorAdmin)' (Consulte documentação Microsoft para detalhes)." }
                            }
                            $uacFriendlyStatus = "Habilitado (Recomendado). O sistema irá: $uacLevelDescription"
                        } else {
                            $uacFriendlyStatus = "Habilitado (Recomendado), mas o nível detalhado de notificação não foi explicitamente definido por política (usa padrão do Windows)."
                        }
                    } else { # $enableLUA -eq 0 ou outro valor
                        $uacFriendlyStatus = "Desabilitado (Não Recomendado - Esta configuração reduz a segurança do sistema)."
                    }
                } else { 
                    $uacFriendlyStatus = "Configuração do UAC (EnableLUA) não encontrada no registro. O sistema pode estar usando o padrão." 
                }
            } else { 
                $uacFriendlyStatus = "Não foi possível verificar (chave de política do UAC não encontrada no registro)."
            }
            $complianceDataResult["Controle de Conta de Usuário (UAC)"] = $uacFriendlyStatus 
        } catch {
            $exceptionMessage = Get-SafeProperty $_.Exception 'Message' 'Detalhe indisponível'
            Write-Warning "Erro ao coletar status do UAC: $exceptionMessage"
            $complianceDataResult["Controle de Conta de Usuário (UAC)"] = "Erro na Coleta: $exceptionMessage"
            $moduleOverallError = $true # Assume que esta é uma verificação crítica
        }

        # --- 3. Configuração de Atualizações Automáticas do Windows ---
Write-Verbose "Coletando configuração de Atualizações Automáticas..."
        try {
            $auKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
            $autoUpdateStatus = "Padrão do Sistema (Recomendado: Manter atualizações automáticas habilitadas)"

            # Verifica primeiro se há políticas de grupo configuradas, pois elas têm precedência.
            if (Test-Path $auKeyPath) {
                $noAutoUpdate = Get-ItemPropertyValue -Path $auKeyPath -Name "NoAutoUpdate" -ErrorAction SilentlyContinue
                $auOptions = Get-ItemPropertyValue -Path $auKeyPath -Name "AUOptions" -ErrorAction SilentlyContinue

                if ($null -ne $noAutoUpdate -and $noAutoUpdate -eq 1) {
                    $autoUpdateStatus = "Desabilitadas via Política (Não Recomendado - Risco de Segurança)" 
                } elseif ($null -ne $auOptions) {
                    $autoUpdateStatus = switch ($auOptions) {
                        1       { "Desabilitadas via Política (Não Recomendado - Risco de Segurança)" } # AUOptions = 1
                        2       { "Configurado por Política: Notificar antes de baixar e instalar (Requer Ação do Usuário)" } 
                        3       { "Configurado por Política: Baixar automaticamente e notificar para instalar (Requer Ação do Usuário)" } 
                        4       { "Configurado por Política: Baixar automaticamente e agendar instalação (Boa Prática)" } 
                        5       { "Configurado por Política: Permitir que administrador local defina" } 
                        default { "Configuração via Política não reconhecida (Código AUOptions: $auOptions)" }
                    }
                } # Se $auOptions e $noAutoUpdate são nulos, mas a chave de política existe, pode haver outras configurações.
                  # Mantém o default "Padrão do Sistema..." se as chaves específicas não estiverem definidas.
            } else {
                # Se não há políticas explícitas, assume-se que o Windows está gerenciando.
                # A verificação do serviço 'wuauserv' pode ser mantida para indicar se o serviço em si está operacional,
                # mas a mensagem principal deve focar na recomendação.
                $wuService = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
                if ($wuService) {
                    if ($wuService.Status -eq 'Running') {
                        $autoUpdateStatus = "Ativas e gerenciadas pelo sistema (Serviço Windows Update em execução). Recomenda-se verificar as configurações para garantir downloads e instalações automáticas."
                    } else {
                        $autoUpdateStatus = "Serviço Windows Update: Status '$($wuService.Status)'. Verifique as configurações para garantir que as atualizações automáticas estejam funcionando."
                    }
                } else {
                    $autoUpdateStatus = "Serviço Windows Update (wuauserv) não encontrado. ATENÇÃO: Atualizações automáticas podem não estar funcionando." 
                }
            }
            $complianceDataResult["Atualizações Automáticas do Windows"] = $autoUpdateStatus 
        } catch {
            $exceptionMessage = Get-SafeProperty $_.Exception 'Message' 'Detalhe indisponível'
            Write-Warning "Erro ao coletar configuração de Atualizações Automáticas: $exceptionMessage"
            $complianceDataResult["Atualizações Automáticas do Windows"] = "Erro na Coleta: $exceptionMessage"
            $moduleOverallError = $true # Assume que esta é uma verificação crítica
        }

        # --- Coleta de Política de Senha e SMART REMOVIDAS ---
        # A chave "Política de Senha Local (Recomendações)" já está com texto estático.
        # A chave "Status SMART dos Discos" foi removida da inicialização de $complianceDataResult.
        
        # Define o erro geral do módulo
        if ($moduleOverallError) {
            $complianceDataResult.Error = "Uma ou mais verificações de segurança podem ter retornado erro ou não foram completadas."
        } else {
            $criticalChecksFailed = $false
            if (($complianceDataResult["Criptografia de Disco (BitLocker)"] -is [string] -and $complianceDataResult["Criptografia de Disco (BitLocker)"] -like "Erro*") -or
                ($complianceDataResult["Controle de Conta de Usuário (UAC)"] -is [string] -and $complianceDataResult["Controle de Conta de Usuário (UAC)"] -like "Erro*") -or
                ($complianceDataResult["Atualizações Automáticas do Windows"] -is [string] -and $complianceDataResult["Atualizações Automáticas do Windows"] -like "Erro*")) {
                $criticalChecksFailed = $true
            }

            if ($criticalChecksFailed) {
                 $complianceDataResult.Error = "Algumas verificações de conformidade de segurança não retornaram dados ou encontraram erros."
            } else {
                 $complianceDataResult.Error = $null 
            }
        }
        
        if ($complianceDataResult.PSObject.Properties['Error'] -ne $null -and $null -eq $complianceDataResult.Error ) {
            $propriedadesLimpasComp = [ordered]@{}
            foreach ($propriedadeComp in $complianceDataResult.PSObject.Properties) {
                if ($propriedadeComp.Name -ne 'Error') {
                    $propriedadesLimpasComp[$propriedadeComp.Name] = $propriedadeComp.Value
                }
            }
            return [PSCustomObject]$propriedadesLimpasComp
        }

        return [PSCustomObject]$complianceDataResult
    } 
}