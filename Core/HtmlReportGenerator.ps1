# EITIN_Modular/Core/HtmlReportGenerator.ps1

#region Glossário e Funções Auxiliares (Escopo do Script)
$Global:EitinHtmlGlossary = @{
    "Tipo de Barramento" = "Indica a via de comunicação entre a placa-mãe e o dispositivo. NVMe é o mais moderno e rápido para SSDs."
    "Status de Proteção" = "Informa se o BitLocker (ferramenta de criptografia do Windows) está protegendo os dados do volume."
    "Controle de Conta de Usuário (UAC)" = "É uma camada de segurança do Windows que ajuda a prevenir alterações não autorizadas no computador, solicitando permissão ou senha antes de ações importantes."
    "Gateway IPv4 Padrão" = "É o 'portão de saída' da sua rede local para a internet. Geralmente, é o endereço do seu roteador."
    "Servidores DNS" = "Traduzem nomes de sites (como google.com) para endereços de IP que o computador entende."
    "DHCP Habilitado" = "Indica se o adaptador de rede está configurado para receber um endereço de IP automaticamente do roteador (DHCP)."
    "Tipo de Firmware" = "Informa a interface de software entre o hardware e o sistema operacional. UEFI é o padrão moderno e mais seguro que o BIOS Legado."
    "Secure Boot Ativado" = "Uma funcionalidade de segurança do UEFI que impede a execução de softwares mal-intencionados durante a inicialização do computador. 'Sim' é a configuração mais segura."
    "Licença Tipo KMS" = "Indica uma licença de volume ativada através de um servidor de gerenciamento de chaves (KMS), comum em ambientes corporativos."
}

function Add-TooltipIfAvailable {
    param($Term)
    if ($Global:EitinHtmlGlossary.ContainsKey($Term)) {
        $explanation = [System.Security.SecurityElement]::Escape($Global:EitinHtmlGlossary[$Term])
        return " <span class='tooltip-icon' title='$explanation'>&#8505;</span>"
    }
    return ""
}
#endregion

function Format-EitinDataToHtmlSectionBody {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowNull()][AllowEmptyCollection()]$Data,
        [Parameter(Mandatory = $false)][string]$SectionTitleForContext, 
        [switch]$IsPreformatted
    )
    process {
        $htmlBody = New-Object System.Text.StringBuilder

        if ($null -eq $Data) {
            [void]$htmlBody.AppendLine("<p>Nenhum dado coletado para esta seção.</p>")
        } elseif ($Data -is [System.Management.Automation.PSCustomObject] -and $Data.PSObject.Properties['Error'] -ne $null -and -not [string]::IsNullOrWhiteSpace($Data.Error)) {
            [void]$htmlBody.AppendLine("<p class='error-message'>Erro ao coletar dados: $([System.Security.SecurityElement]::Escape($Data.Error))</p>")
        } elseif ($Data -is [System.Management.Automation.PSCustomObject] -and $Data.PSObject.Properties['Informação'] -ne $null -and -not [string]::IsNullOrWhiteSpace($Data.Informação)) {
            [void]$htmlBody.AppendLine("<p>$([System.Security.SecurityElement]::Escape($Data.Informação))</p>")
        } elseif ($IsPreformatted.IsPresent -and $Data -is [string]) {
            [void]$htmlBody.AppendLine("<pre class='code'>$([System.Security.SecurityElement]::Escape($Data))</pre>")
        } elseif ($Data -is [string]) {
            [void]$htmlBody.AppendLine("<p>$([System.Security.SecurityElement]::Escape($Data) -replace '`r`n', '<br />')</p>")
        } elseif ($Data -is [array] -and $Data.Count -gt 0 -and ($Data[0] -is [hashtable] -or $Data[0] -is [System.Management.Automation.PSCustomObject])) {
            [void]$htmlBody.Append("<table><thead><tr>")
            if ($Data[0].PSObject.Properties) {
                $Data[0].PSObject.Properties | Where-Object { $_.Name -ne 'Error' } | ForEach-Object {
                    $headerText = [System.Security.SecurityElement]::Escape($_.Name)
                    $tooltipHtml = Add-TooltipIfAvailable -Term $_.Name
                    [void]$htmlBody.Append("<th>$($headerText)$($tooltipHtml)</th>")
                }
            }
            [void]$htmlBody.AppendLine("</tr></thead><tbody>")
            foreach ($rowItem in $Data) {
                [void]$htmlBody.Append("<tr>")
                if ($rowItem.PSObject.Properties) {
                    $rowItem.PSObject.Properties | Where-Object { $_.Name -ne 'Error' } | ForEach-Object {
                        [void]$htmlBody.Append("<td>$([System.Security.SecurityElement]::Escape($_.Value))</td>")
                    }
                }
                [void]$htmlBody.AppendLine("</tr>")
            }
            [void]$htmlBody.AppendLine("</tbody></table>")
        } elseif ($Data -is [hashtable] -or $Data -is [System.Management.Automation.PSCustomObject]) {
            $hasSubTables = $false
            if ($Data.psobject.Properties) { $hasSubTables = $Data.psobject.Properties.Where({$_.Value -is [array] -and $_.Value.Count -gt 0 -and ($_.Value[0] -is [hashtable] -or $_.Value[0] -is [System.Management.Automation.PSCustomObject])}).Count -gt 0 }

            if ($hasSubTables) {
                 foreach ($prop in $Data.psobject.Properties) {
                    if($prop.Name -in @('Error', 'Informação')) { continue }
                    $propName = [System.Security.SecurityElement]::Escape($prop.Name)
                    $tooltipHtml = Add-TooltipIfAvailable -Term $prop.Name
                    [void]$htmlBody.AppendLine("<h3>$($propName)$($tooltipHtml)</h3>") 
                    [void]$htmlBody.AppendLine((Format-EitinDataToHtmlSectionBody -Data $prop.Value))
                 }
            } else {
                [void]$htmlBody.Append("<table><tbody>")
                if($Data.PSObject.Properties){
                    $Data.PSObject.Properties | Where-Object { $_.Name -notin @('Error', 'Informação')} | ForEach-Object {
                        $label = [System.Security.SecurityElement]::Escape($_.Name)
                        $value = [System.Security.SecurityElement]::Escape($_.Value)
                        $tooltipHtml = Add-TooltipIfAvailable -Term $_.Name
                        [void]$htmlBody.AppendLine("<tr><td class='property-name'>$($label)$($tooltipHtml)</td><td class='property-value'>$($value)</td></tr>")
                    }
                }
                [void]$htmlBody.AppendLine("</tbody></table>")
            }
        } else {
            [void]$htmlBody.AppendLine("<p class='error-message'>Não foi possível renderizar dados para esta seção (formato não suportado).</p>")
        }
        return $htmlBody.ToString()
    }
}

function Build-EitinHtmlReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$ComputerName,
        [Parameter(Mandatory = $true)] [string]$ReportTimestamp,
        [Parameter(Mandatory = $true)] [string]$ScriptUser,
        [Parameter(Mandatory = $true)] [System.Collections.ArrayList]$SectionTitlesForSidebar,
        [Parameter(Mandatory = $true)] [System.Collections.Specialized.OrderedDictionary]$SectionHtmlBodies,
        [Parameter(Mandatory = $true)] [string]$CssPath,
        [Parameter(Mandatory = $false)] [System.TimeSpan]$ExecutionTime
    )
    process {
        $fullHtml = New-Object System.Text.StringBuilder
        
        # Leitura do CSS
        $cssContent = ""
        try {
            if (Test-Path $CssPath) { $cssContent = Get-Content -Path $CssPath -Raw -ErrorAction Stop } 
            else { Write-Warning "Arquivo CSS não encontrado em '$CssPath'." }
        } catch { Write-Warning "Erro ao ler o arquivo CSS em '$CssPath': $($_.Exception.Message)" }

        # --- Construção do Cabeçalho HTML ---
        [void]$fullHtml.AppendLine("<!DOCTYPE html><html lang='pt-BR'><head>")
        [void]$fullHtml.AppendLine("    <meta charset='UTF-8'><meta name='viewport' content='width=device-width, initial-scale=1.0'><title>Relatório de Inventário de TI - $($ComputerName)</title>")
        [void]$fullHtml.AppendLine("    <style>")
        [void]$fullHtml.AppendLine($cssContent)
        [void]$fullHtml.AppendLine("    </style>")
        [void]$fullHtml.AppendLine("</head><body>")

        # --- Barra Lateral ---
        [void]$fullHtml.AppendLine("    <div class='sidebar'><h2>EITIN</h2><ul id='sidebar-nav'>")
        if ($null -ne $SectionTitlesForSidebar) { foreach ($title in $SectionTitlesForSidebar) { if (-not [string]::IsNullOrWhiteSpace($title)) { $sectionId = $title -replace '[^a-zA-Z0-9_]+', '-' -replace '_$', ''; [void]$fullHtml.AppendLine("            <li><a href='#$sectionId'>$([System.Security.SecurityElement]::Escape($title))</a></li>") } } }
        [void]$fullHtml.AppendLine("        </ul></div>")
        
        # --- Conteúdo Principal ---
        [void]$fullHtml.AppendLine("    <div class='main-content'>")

        # Define as seções que terão contêineres de rolagem.
        $scrollableSections = @(
            "Softwares Instalados (Não-Microsoft)",
            "Últimas 15 Atualizações do Windows",
            "Rede"
        )

        # Itera e anexa cada seção de conteúdo
        if ($null -ne $SectionTitlesForSidebar -and $null -ne $SectionHtmlBodies) { 
            foreach ($title in $SectionTitlesForSidebar) { 
                 if (-not [string]::IsNullOrWhiteSpace($title)) {
                    $sectionId = $title -replace '[^a-zA-Z0-9_]+', '-' -replace '_$', ''
                    [void]$fullHtml.AppendLine("        <section id='$($sectionId)' class='section'>")
                    $titleHtml = [System.Security.SecurityElement]::Escape($title)
                    $tooltipHtmlTitle = Add-TooltipIfAvailable -Term $title
                    [void]$fullHtml.AppendLine("            <h2>$($titleHtml)$($tooltipHtmlTitle)</h2>")
                    if ($SectionHtmlBodies.Contains($title)) {
                        $sectionBodyHtml = $SectionHtmlBodies[$title]
                        if ($scrollableSections -contains $title) {
                            [void]$fullHtml.AppendLine("         <div class='scrollable-table-container'>$($sectionBodyHtml)</div>")
                        } else {
                            [void]$fullHtml.AppendLine($sectionBodyHtml)
                        }
                    } else { [void]$fullHtml.AppendLine("            <p class='error-message'>Conteúdo para esta seção ('$([System.Security.SecurityElement]::Escape($title))') não foi gerado ou está ausente.</p>") }
                    [void]$fullHtml.AppendLine("        </section>")
                }
            }
        }
        
        # --- Rodapé ---
        # Lógica para formatar o tempo de execução
        $footerExecutionTimeInfo = ""
        if ($ExecutionTime -is [timespan]) {
            $formattedTime = ""
            if ($ExecutionTime.TotalHours -ge 1) { $formattedTime = "{0:0}h {1:0}m {2:0}s" -f $ExecutionTime.Hours, $ExecutionTime.Minutes, $ExecutionTime.Seconds }
            elseif ($ExecutionTime.TotalMinutes -ge 1) { $formattedTime = "{0:0}m {1:0}s" -f $ExecutionTime.Minutes, $ExecutionTime.Seconds }
            elseif ($ExecutionTime.TotalSeconds -ge 1) { $formattedTime = "{0:0.0}s" -f $ExecutionTime.TotalSeconds }
            else { $formattedTime = "$($ExecutionTime.TotalMilliseconds)ms" }
            $footerExecutionTimeInfo = "<p>Tempo de Execução do Script: $formattedTime</p>"
        }
        # Monta o bloco de rodapé usando here-string para legibilidade
        $footerBlock = @"
        <footer class='report-footer'>
           <p>EITIN - Inventário de TI Elevado &copy; $(Get-Date -Format 'yyyy')</p>
           <p>Gerado para $([System.Security.SecurityElement]::Escape($ComputerName)) em $($ReportTimestamp) por $([System.Security.SecurityElement]::Escape($ScriptUser))</p>
           $($footerExecutionTimeInfo)
           <p>Desenvolvido por <a href='https://www.l0g0rhythm.com.br/' target='_blank' rel='noopener noreferrer' style='color: #3498db; text-decoration: none;'>L0g0rhythm</a></p>
        </footer>
"@
        [void]$fullHtml.AppendLine($footerBlock)
        [void]$fullHtml.AppendLine("    </div>") # Fim .main-content

        # --- Bloco de Script JavaScript (sem setTimeout) ---
        [void]$fullHtml.AppendLine("    <script>")
        [void]$fullHtml.AppendLine(@"
        document.addEventListener('DOMContentLoaded', function() {
            const sidebarLinks = document.querySelectorAll('#sidebar-nav a');
            
            sidebarLinks.forEach(link => {
                link.addEventListener('click', function(e) {
                    e.preventDefault();
                    const targetId = this.getAttribute('href').substring(1);
                    const targetSection = document.getElementById(targetId);

                    if (targetSection) {
                        // Ação de destaque é instantânea e suave, controlada 100% pelo CSS
                        document.querySelectorAll('.section.highlight-section').forEach(s => s.classList.remove('highlight-section'));
                        document.querySelectorAll('#sidebar-nav a.active').forEach(a => a.classList.remove('active'));
                        
                        targetSection.classList.add('highlight-section');
                        this.classList.add('active');

                        targetSection.scrollIntoView({ behavior: 'smooth', block: 'center' });
                    }
                });
            });
        });
"@)
        [void]$fullHtml.AppendLine("    </script>")
        [void]$fullHtml.AppendLine("</body></html>")

        return $fullHtml.ToString()
    }
}

function Build-EitinPrintableHtmlReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$ComputerName,
        [Parameter(Mandatory = $true)] [string]$ReportTimestamp,
        [Parameter(Mandatory = $true)] [string]$ScriptUser,
        [Parameter(Mandatory = $true)] [System.Collections.ArrayList]$SectionTitles,
        [Parameter(Mandatory = $true)] [System.Collections.Specialized.OrderedDictionary]$SectionHtmlBodies,
        [Parameter(Mandatory = $true)] [string]$PrintCssPath,
        [Parameter(Mandatory = $false)] [System.TimeSpan]$ExecutionTime
    )
    process {
        $fullHtml = New-Object System.Text.StringBuilder
        
        $cssContent = ""
        try {
            if (Test-Path $PrintCssPath) { $cssContent = Get-Content -Path $PrintCssPath -Raw -ErrorAction Stop } 
            else { Write-Warning "Arquivo CSS de impressão não encontrado em '$PrintCssPath'." }
        } catch { Write-Warning "Erro ao ler o arquivo CSS de impressão em '$PrintCssPath': $($_.Exception.Message)" }

        # --- Construção do HTML para Impressão (Layout Corrigido) ---
        [void]$fullHtml.AppendLine("<!DOCTYPE html><html lang='pt-BR'><head>")
        [void]$fullHtml.AppendLine("    <meta charset='UTF-8'><title>Relatório Imprimível - $($ComputerName)</title>")
        [void]$fullHtml.AppendLine("    <style>$($cssContent)</style>")
        [void]$fullHtml.AppendLine("</head><body>")
        
        [void]$fullHtml.AppendLine("    <div class='print-container'>")
        
        # MANTIDO: Título principal no topo do documento.
        [void]$fullHtml.AppendLine("        <div class='report-title-printable'><h1>EITIN - Inventário de TI Elevado</h1></div>")
        
        # Itera e anexa cada seção verticalmente
        if ($null -ne $SectionTitles) { 
            foreach ($title in $SectionTitles) { 
                if (-not [string]::IsNullOrWhiteSpace($title) -and $SectionHtmlBodies.Contains($title)) {
                    [void]$fullHtml.AppendLine("        <section class='section'>")
                    [void]$fullHtml.AppendLine("            <h2>$([System.Security.SecurityElement]::Escape($title))</h2>")
                    [void]$fullHtml.AppendLine($SectionHtmlBodies[$title])
                    [void]$fullHtml.AppendLine("        </section>")
                }
            }
        }
        
        # NOVO: Rodapé com as informações de geração, movido para o final do documento
        $footerExecutionTimeInfo = ""
        if ($ExecutionTime -is [timespan]) {
            $formattedTime = ""
            if ($ExecutionTime.TotalHours -ge 1) { $formattedTime = "{0:0}h {1:0}m {2:0}s" -f $ExecutionTime.Hours, $ExecutionTime.Minutes, $ExecutionTime.Seconds }
            elseif ($ExecutionTime.TotalMinutes -ge 1) { $formattedTime = "{0:0}m {1:0}s" -f $ExecutionTime.Minutes, $ExecutionTime.Seconds }
            elseif ($ExecutionTime.TotalSeconds -ge 1) { $formattedTime = "{0:0.0}s" -f $ExecutionTime.TotalSeconds }
            else { $formattedTime = "$($ExecutionTime.TotalMilliseconds)ms" }
            $footerExecutionTimeInfo = "<p>Tempo de Execução do Script: $formattedTime</p>"
        }

        [void]$fullHtml.AppendLine("        <footer class='report-footer-printable'>")
        [void]$fullHtml.AppendLine("            <p>EITIN - Inventário de TI Elevado &copy; $(Get-Date -Format 'yyyy')</p>")
        [void]$fullHtml.AppendLine("            <p>Gerado para $([System.Security.SecurityElement]::Escape($ComputerName)) em $($ReportTimestamp) por $([System.Security.SecurityElement]::Escape($ScriptUser))</p>")
        [void]$fullHtml.AppendLine("           $($footerExecutionTimeInfo)")
        [void]$fullHtml.AppendLine("            <p style='font-size: 9pt; margin-top: 10px;'>Desenvolvido por <a href='https://www.l0g0rhythm.com.br/'>L0g0rhythm</a></p>")
        [void]$fullHtml.AppendLine("        </footer>")

        [void]$fullHtml.AppendLine("    </div>") # Fim .print-container
        [void]$fullHtml.AppendLine("</body></html>")

        return $fullHtml.ToString()
    }
}
