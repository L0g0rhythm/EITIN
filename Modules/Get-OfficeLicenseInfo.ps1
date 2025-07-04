function Invoke-EitinOfficeLicenseInfoInfo {
    [CmdletBinding()]
    param()

    process {
        $licensesList = New-Object System.Collections.ArrayList
        $officeProductsReported = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $foundAnyOfficeInfo = $false

        # Nomes de campo amigáveis para o relatório
        $fieldProductName = "Produto Office"
        $fieldLicenseType = "Tipo de Licença (Office)"
        $fieldLicenseStatus = "Status da Licença (Office)"
        $fieldPartialKey = "Chave de Produto Parcial (Office)"
        $fieldInfoSource = "Fonte da Informação"

        #region Coleta via OSPP.VBS
        $osppProductInfo = @{
            "Office16ProPlusVL_KMS_Client" = "Microsoft Office Professional Plus 2016 (Volume)"
            "Office16StdVL_KMS_Client"     = "Microsoft Office Standard 2016 (Volume)"
            "Office19ProPlus2019VL_KMS_Client" = "Microsoft Office Professional Plus 2019 (Volume)"
            "Office19Std2019VL_KMS_Client" = "Microsoft Office Standard 2019 (Volume)"
            # Adicionar mais mapeamentos para Office LTSC 2021, etc., se necessário
            # Ex: "Office21ProPlus2021Volume_KMS_Client" = "Microsoft Office LTSC Professional Plus 2021 (Volume)"
        }

        $potentialOsppPaths = @(
            Join-Path ${env:ProgramFiles(x86)} "Microsoft Office\Office16\OSPP.VBS" 
            Join-Path $env:ProgramFiles "Microsoft Office\Office16\OSPP.VBS"        
            Join-Path ${env:ProgramFiles(x86)} "Microsoft Office\Office15\OSPP.VBS" 
            Join-Path $env:ProgramFiles "Microsoft Office\Office15\OSPP.VBS"        
            Join-Path ${env:ProgramFiles(x86)} "Microsoft Office\Office14\OSPP.VBS" 
            Join-Path $env:ProgramFiles "Microsoft Office\Office14\OSPP.VBS"        
        )
        $osppPath = $potentialOsppPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

        if ($osppPath) {
            Write-Verbose "Tentando executar OSPP.VBS em: $osppPath"
            try {
                $cscriptPath = Join-Path $env:SystemRoot "System32\cscript.exe"
                $statusResult = & $cscriptPath //Nologo $osppPath /dstatusall 2>&1
                
                if ($statusResult) {
                    $productEntries = ($statusResult -join "`n") -split '---Processing--------------------------' | Where-Object {$_ -match "LICENSE NAME"}
                    
                    foreach($entryText in $productEntries){
                        $currentProductNameOspp = "Produto Office Desconhecido (OSPP)"
                        $partialKeyOspp = "N/A"
                        $licenseStatusOspp = "Status Desconhecido (OSPP)"

                        if ($entryText -match "LICENSE NAME:\s*(.+?)(`r?`n|$)") {
                            $rawProductName = $matches[1].Trim()
                            $friendlyNameFound = $false
                            foreach($key in $osppProductInfo.Keys){
                                if($rawProductName -match $key){ # Usar -match para flexibilidade
                                    $currentProductNameOspp = $osppProductInfo[$key]
                                    $friendlyNameFound = $true
                                    break
                                }
                            }
                            if(-not $friendlyNameFound) { $currentProductNameOspp = $rawProductName }
                        }
                        if ($entryText -match "Last 5 characters of installed product key:\s*([A-Z0-9]{5})") {
                            $partialKeyOspp = $matches[1].Trim()
                        }
                        if ($entryText -match "LICENSE STATUS:\s*---\s*(LICENSED)\s*---") {
                            $licenseStatusOspp = "Licenciado"
                        } elseif ($entryText -match "LICENSE STATUS:\s*---(.+?)---") { 
                            $licenseStatusOspp = $matches[1].Trim()
                        } elseif ($entryText -match "Remaining grace:\s*(\d+\s*days?)") { 
                            $licenseStatusOspp = "Período de Tolerância ($($matches[1].Trim()))"
                        }

                        if ($currentProductNameOspp -notmatch "Produto Office Desconhecido"){
                            $signatureOspp = "$($currentProductNameOspp)_$($partialKeyOspp)_OSPP"
                            if ($officeProductsReported.Add($signatureOspp)) {
                                $licenseDetails = [ordered]@{
                                    $fieldProductName   = $currentProductNameOspp
                                    $fieldLicenseType   = "Licença de Volume (OSPP)"
                                    $fieldLicenseStatus = $licenseStatusOspp
                                    $fieldPartialKey    = $partialKeyOspp
                                    $fieldInfoSource    = "OSPP.VBS"
                                }
                                [void]$licensesList.Add([PSCustomObject]$licenseDetails)
                                $foundAnyOfficeInfo = $true
                            }
                        }
                    }
                } else { 
                    Write-Warning "OSPP.VBS não retornou saída ou a saída foi capturada como erro."
                }
            }
            catch {
                Write-Warning "Erro ao executar OSPP.VBS: $($_.Exception.Message)"
            }
        } else { 
            Write-Verbose "OSPP.VBS não encontrado nos caminhos padrão."
        }
        #endregion

        #region Coleta via WMI
        try {
            # Filtro WQL otimizado para Get-CimInstance
            $wmiFilter = "ApplicationID <> '00000000-0000-0000-0000-000000000000' AND PartialProductKey IS NOT NULL AND (" +
                         "Name LIKE '%Office%' OR Description LIKE '%Office%' OR " +
                         "Name LIKE '%Microsoft 365%' OR Description LIKE '%Microsoft 365%' OR " +
                         "Name LIKE '%Project%' OR Description LIKE '%Project%' OR " +
                         "Name LIKE '%Visio%' OR Description LIKE '%Visio%'" +
                         ")"
            
            $officeWmiProducts = Get-CimInstance SoftwareLicensingProduct -Filter $wmiFilter -ErrorAction SilentlyContinue
                                 
            if ($officeWmiProducts) {
                foreach ($product in $officeWmiProducts) {
                    $productNameWmi = Get-SafeProperty $product 'Name' "Produto Microsoft Desconhecido (WMI)"
                    $licenseStatusNumeric = Get-SafeProperty $product 'LicenseStatus' -1 
                    $partialKeyWmi = Get-SafeProperty $product 'PartialProductKey' "N/A"
                    
                    $licenseStatusWmi = switch ($licenseStatusNumeric) {
                        0       { "Não Licenciado" }
                        1       { "Licenciado (Ativado)" }
                        2       { "Período de Tolerância Inicial" }
                        3       { "Período de Tolerância Adicional (Não Genuíno)" }
                        4       { "Notificação (Não Genuíno)" }
                        5       { "Período de Tolerância Estendido" }
                        default { "Status Desconhecido (Cód WMI: $licenseStatusNumeric)" }
                    }
                    
                    $licenseTypeWmi = "Não Determinado (WMI)"
                    if (Get-SafeProperty $product 'IsKeyManagementServiceLicense' $false) { 
                        $licenseTypeWmi = "Volume (KMS - WMI)"
                    } elseif ((Get-SafeProperty $product 'LicenseFamily' "") -match "OEM") { # Verifica se LicenseFamily contém OEM
                        $licenseTypeWmi = "OEM (WMI)"
                    } elseif ($productNameWmi -match "365|Subscription|Assinatura") { # Adicionada "Assinatura"
                        $licenseTypeWmi = "Assinatura (WMI)"
                    } else {
                        $licenseTypeWmi = "Varejo ou Outro (WMI)"
                    }

                    $signatureWmi = "$($productNameWmi)_$($partialKeyWmi)_WMI"
                    if ($officeProductsReported.Add($signatureWmi)) {
                        $licenseDetails = [ordered]@{
                            $fieldProductName   = $productNameWmi
                            $fieldLicenseType   = $licenseTypeWmi
                            $fieldLicenseStatus = $licenseStatusWmi
                            $fieldPartialKey    = $partialKeyWmi
                            $fieldInfoSource    = "WMI (SoftwareLicensingProduct)"
                        }
                        [void]$licensesList.Add([PSCustomObject]$licenseDetails)
                        $foundAnyOfficeInfo = $true
                    }
                }
            }
        }
        catch {
            Write-Warning "Erro ao consultar WMI para licenças do Office: $($_.Exception.Message)"
        }
        #endregion
        
        if (-not $foundAnyOfficeInfo) {
            return $null # Retorna $null se nenhuma informação do Office foi encontrada
        }
        
        return $licensesList.ToArray() | Sort-Object -Property $fieldProductName
    }
}