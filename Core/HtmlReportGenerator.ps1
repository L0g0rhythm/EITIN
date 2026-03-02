# Glossário e Funções Auxiliares (Escopo do Script)
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
        } elseif ($Data -is [System.Management.Automation.PSCustomObject] -and $null -ne $Data.PSObject.Properties['Error'] -and -not [string]::IsNullOrWhiteSpace($Data.Error)) {
            [void]$htmlBody.AppendLine("<p class='error-message'>Erro ao coletar dados: $([System.Security.SecurityElement]::Escape($Data.Error))</p>")
        } elseif ($Data -is [System.Management.Automation.PSCustomObject] -and $null -ne $Data.PSObject.Properties['Informação'] -and -not [string]::IsNullOrWhiteSpace($Data.Informação)) {
            [void]$htmlBody.AppendLine("<p>$([System.Security.SecurityElement]::Escape($Data.Informação))</p>")
        } elseif ($IsPreformatted.IsPresent -and $Data -is [string]) {
            [void]$htmlBody.AppendLine("<pre class='code'>$([System.Security.SecurityElement]::Escape($Data))</pre>")
        } elseif ($Data -is [string]) {
            [void]$htmlBody.AppendLine("<p>$([System.Security.SecurityElement]::Escape($Data) -replace '`r`n', '<br />')</p>")
        } elseif ($Data -is [array] -and $Data.Count -gt 0 -and ($Data[0] -is [hashtable] -or $Data[0] -is [System.Management.Automation.PSCustomObject])) {

            # Formatação adaptativa
            $tableClass = ""
            $columnCount = ($Data[0].PSObject.Properties | Where-Object { $_.Name -ne 'Error' }).Count

            if ($columnCount -ge 8) {
                $tableClass = " class='table-compact'"
            }
            elseif ($columnCount -in 6, 7) {
                $tableClass = " class='table-medium'"
            }
            #endregion

            [void]$htmlBody.Append("<table$($tableClass)><thead><tr>")

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
                    [void]$htmlBody.AppendLine((Format-EitinDataToHtmlSectionBody -Data $prop.Value -SectionTitleForContext $prop.Name))
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

        # Leitura do CSS com Fallback de Segurança
        $cssContent = ""
        $fallbackCss = @"
:root {
    --primary-font: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
    --text-primary-color: #1c1c1e;
    --text-secondary-color: #ecf0f1;
    --text-tertiary-color: #333;
    --text-table-header-color: #343a40;
    --text-footer-color: #6c757d;

    --accent-color-blue: #3498db;
    --accent-color-dark-blue: #005a9e;
    --accent-color-dark-blue-alpha: rgba(0, 90, 158, 0.5);
    --accent-color-blue-alpha-40: rgba(52, 152, 219, 0.4);
    --accent-color-blue-alpha-80: rgba(52, 152, 219, 0.8);

    --bg-gradient-start: #f5f7fa;
    --bg-gradient-end: #c3cfe2;
    --bg-sidebar: rgba(44, 62, 80, 0.75);
    --bg-section: rgba(255, 255, 255, 0.45);
    --bg-table-row-even: rgba(248, 249, 250, 0.5);
    --bg-table-row-hover: rgba(233, 245, 255, 0.8);
    --bg-table-header-sticky: rgba(248, 249, 250, 0.95);
    --bg-scrollable-container: rgba(255, 255, 255, 0.2);

    --scrollbar-thumb-color: rgba(136, 136, 136, 0.7);

    --border-color-sidebar: rgba(255, 255, 255, 0.1);
    --border-color-sidebar-header: rgba(236, 240, 241, 0.25);
    --border-color-section: rgba(255, 255, 255, 0.2);
    --border-color-table: rgba(0, 0, 0, 0.07);
    --border-color-footer: #dee2e6;
    --border-color-dashed: #ccc;

    --radius-small: 6px;
    --radius-medium: 8px;
    --radius-large: 16px;
}

html {
    scroll-behavior: smooth;
    overflow-y: scroll;
}

/* MELHORIA: Fundo com Movimento Sutil */
@keyframes gradient-flow {
    0% {
        background-position: 0% 50%;
    }

    50% {
        background-position: 100% 50%;
    }

    100% {
        background-position: 0% 50%;
    }
}

body {
    font-family: var(--primary-font);
    margin: 0;
    padding: 0;
    color: var(--text-primary-color);
    font-size: 14px;
    background-color: #dee9f7;
    background-image: linear-gradient(135deg,
            var(--bg-gradient-start) 0%,
            var(--bg-gradient-end) 100%);
    background-size: 200% 200%;
    animation: gradient-flow 15s ease infinite;
}

/* --- Sidebar Toggle Button --- */
.sidebar-toggle {
    position: fixed;
    left: 20px;
    top: 15px;
    z-index: 200;
    background: var(--accent-color-blue);
    color: white;
    border: none;
    border-radius: 50%;
    width: 40px;
    height: 40px;
    cursor: pointer;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.2);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.2em;
    transition: all 0.3s ease;
}

.sidebar-toggle:hover {
    background: var(--accent-color-dark-blue);
    transform: rotate(90deg);
}

.sidebar.closed {
    transform: translateX(-100%);
}

.sidebar-toggle.closed {
    left: 20px;
    /* Mantém visível mesmo com sidebar fechada */
}

.sidebar-toggle.scroll-hidden {
    opacity: 0;
    pointer-events: none;
    transform: scale(0.5);
}

/* --- Enhanced Glass Effect Sidebar --- */
.sidebar {
    width: 260px;
    height: 100vh;
    position: fixed;
    display: flex;
    flex-direction: column;
    padding: 0 15px 15px 15px;
    color: var(--text-secondary-color);
    background: var(--bg-sidebar);
    border-right: 1px solid var(--border-color-sidebar);
    border-top-right-radius: 20px;
    /* Canto Arredondado Elegante */
    border-bottom-right-radius: 20px;
    /* Canto Arredondado Elegante */
    box-shadow: 2px 0 25px rgba(0, 0, 0, 0.1);
    backdrop-filter: blur(18px);
    -webkit-backdrop-filter: blur(18px);
    z-index: 100;
    transition: transform 0.3s ease;
    /* Animação suave de entrada/saída */
}

.sidebar h2 {
    flex-shrink: 0;
    text-align: center;
    color: var(--accent-color-blue);
    font-size: 1.8em;
    margin: 0 -15px 15px -15px;
    padding: 20px 15px;
    border-bottom: 1px solid var(--border-color-sidebar-header);
    text-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
}

.sidebar ul {
    flex-grow: 1;
    list-style-type: none;
    padding: 0 5px 0 0;
    margin: 0;
    overflow-y: auto;
}

.sidebar ul li a {
    display: block;
    color: var(--text-secondary-color);
    padding: 12px 18px;
    text-decoration: none;
    border-radius: var(--radius-small);
    margin-bottom: 5px;
    transition: all 0.2s ease-in-out;
    font-size: 0.95em;
    background-color: transparent;
    position: relative;
}

.sidebar ul li a:hover,
.sidebar ul li a.active {
    background-color: var(--accent-color-blue-alpha-40);
    color: #ffffff;
    transform: translateX(4px);
}

/* --- Main Content and Dashboard Grid --- */
.main-content {
    margin-left: 280px;
    padding: 25px;
    transition: margin-left 0.3s ease;
    /* Animação suave ao expandir */
}

.main-content.expanded {
    margin-left: 0;
    /* Ocupa tudo quando sidebar fecha */
    max-width: 100%;
}

/* MASONRY LAYOUT ENGINE (CSS Columns) */
.report-grid {
    column-count: 3;
    column-gap: 25px;
    max-width: 1800px;
    margin: 0 auto;
}

.section {
    padding: 25px;
    margin-bottom: 25px; /* Importante para separação vertical no layout de colunas */
    display: flex;
    flex-direction: column;
    break-inside: avoid; /* CRUCIAL: Impede que o card seja cortado entre colunas */

    /* Glass Styling */
    background: linear-gradient(135deg,
            rgba(255, 255, 255, 0.6),
            rgba(255, 255, 255, 0.3));
    border: 1px solid rgba(255, 255, 255, 0.3);
    border-radius: var(--radius-large);
    box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.1);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);

    outline: 2px solid transparent;
    outline-offset: -2px;
    transition: transform 0.1s ease, box-shadow 0.4s ease-out, outline-color 0.4s ease-out;
    overflow: hidden; /* PROTEÇÃO: Impede que tabelas largas estourem o card */
}

/* SMART SPANNING */
.section.full-span {
    column-span: all;
    margin-bottom: 25px;
}

.section.highlight-section {
    box-shadow: 0 0 0 2px var(--accent-color-blue), 0 10px 40px rgba(52, 152, 219, 0.3);
    /* Glow elegante em vez de zoom */
    border-color: var(--accent-color-blue);
    z-index: 10;
    /* Transform removido para evitar colisão visual */
}

.section h2 {
    color: var(--accent-color-dark-blue);
    border-bottom: 2px solid var(--accent-color-dark-blue-alpha);
    padding-bottom: 12px;
    margin-top: 0;
    margin-bottom: 20px;
    font-size: 1.6em;
}

.section h3 {
    color: var(--text-tertiary-color);
    font-size: 1.3em;
    margin-top: 20px;
    margin-bottom: 12px;
    border-bottom: 1px dashed var(--border-color-dashed);
    padding-bottom: 8px;
}

/* --- Tables and Containers --- */
table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 10px;
    flex-grow: 1;
    /* Faz a tabela ocupar altura disponível se precisar */
}

th,
td {
    text-align: left;
    padding: 12px 15px;
    border-bottom: 1px solid var(--border-color-table);
    vertical-align: top;
    white-space: normal;
    word-wrap: break-word;
}

th {
    background-color: transparent;
    font-weight: 600;
    color: var(--text-table-header-color);
    border-bottom-width: 2px;
}

tr:nth-child(even) {
    background-color: var(--bg-table-row-even);
}

tr:hover {
    background-color: var(--bg-table-row-hover);
}

.property-name {
    font-weight: 600;
    width: 30%;
}

.scrollable-table-container {
    max-height: 600px;
    overflow: auto;
    border: 1px solid rgba(0, 0, 0, 0.05);
    border-radius: var(--radius-medium);
    background: var(--bg-scrollable-container);
}

.scrollable-table-container table {
    border: none;
    margin-top: 0;
}

.scrollable-table-container th {
    position: sticky;
    top: 0;
    background-color: var(--bg-table-header-sticky);
}

/* --- Scrollbar Styling --- */
.sidebar ul,
.scrollable-table-container {
    scrollbar-width: thin;
    scrollbar-color: var(--scrollbar-thumb-color) transparent;
}

.sidebar ul::-webkit-scrollbar,
.scrollable-table-container::-webkit-scrollbar {
    width: 8px;
    height: 8px;
}

.sidebar ul::-webkit-scrollbar-track,
.scrollable-table-container::-webkit-scrollbar-track {
    background: transparent;
}

.sidebar ul::-webkit-scrollbar-thumb,
.scrollable-table-container::-webkit-scrollbar-thumb {
    background-color: var(--scrollbar-thumb-color);
    border-radius: 10px;
}

.sidebar ul::-webkit-scrollbar-thumb:hover,
.scrollable-table-container::-webkit-scrollbar-thumb:hover {
    background-color: var(--accent-color-blue);
}

/* --- Miscellaneous Components --- */
.report-footer {
    grid-column: 1 / -1;
    /* Footer também ocupa largura total na Grid */
    text-align: center;
    padding: 25px;
    margin-top: 30px;
    font-size: 0.9em;
    color: var(--text-footer-color);
    border-top: 1px solid var(--border-color-footer);
}

.error-message {
    color: #721c24;
    background-color: #f8d7da;
    border: 1px solid #f5c6cb;
    padding: 10px 15px;
    margin-top: 10px;
    border-radius: var(--radius-small);
}

.tooltip-icon {
    cursor: help;
    color: #0078d4;
    font-weight: bold;
    margin-left: 5px;
    font-size: 0.8em;
    vertical-align: super;
}

@media (max-width: 1200px) {
    .report-grid {
        column-count: 2;
    }
}

@media (max-width: 768px) {
    .sidebar {
        width: 100%;
        height: auto;
        position: relative;
    }

    .main-content {
        margin-left: 0;
        padding: 15px;
    }
}
"@

        try {
            if (Test-Path $CssPath) {
                $cssContent = Get-Content -Path $CssPath -Raw -ErrorAction Stop
            } else {
                Write-Warning "Arquivo CSS não encontrado em '$CssPath'. Usando estilo padrão incorporado."
                $cssContent = $fallbackCss
            }
        } catch {
            Write-Warning "Erro ao ler CSS externo. Usando estilo padrão. Detalhe: $($_.Exception.Message)"
            $cssContent = $fallbackCss
        }

        # --- Construção do Cabeçalho HTML ---
        [void]$fullHtml.AppendLine("<!DOCTYPE html><html lang='pt-BR'><head>")
        [void]$fullHtml.AppendLine("    <meta charset='UTF-8'><meta name='viewport' content='width=device-width, initial-scale=1.0'><title>Relatório de Inventário de TI - $($ComputerName)</title>")
        [void]$fullHtml.AppendLine("    <style>")
        [void]$fullHtml.AppendLine($cssContent)
        [void]$fullHtml.AppendLine("    </style>")
        [void]$fullHtml.AppendLine("</head><body>")

        # --- Botão de Toggle Sidebar ---
        [void]$fullHtml.AppendLine("    <button id='sidebar-toggle' class='sidebar-toggle' title='Alternar Menu'>&#9776;</button>")

        # --- Barra Lateral ---
        [void]$fullHtml.AppendLine("    <div class='sidebar'><h2>EITIN</h2><ul id='sidebar-nav'>")
        if ($null -ne $SectionTitlesForSidebar) { foreach ($title in $SectionTitlesForSidebar) { if (-not [string]::IsNullOrWhiteSpace($title)) { $sectionId = $title -replace '[^a-zA-Z0-9_]+', '-' -replace '_$', ''; [void]$fullHtml.AppendLine("            <li><a href='#$sectionId'>$([System.Security.SecurityElement]::Escape($title))</a></li>") } } }
        [void]$fullHtml.AppendLine("        </ul></div>")

        # --- Conteúdo Principal ---
        [void]$fullHtml.AppendLine("    <div class='main-content'>")
        [void]$fullHtml.AppendLine("        <div class='report-grid'>")

        # Define as seções que terão contêineres de rolagem.
        $scrollableSections = @(
            "Softwares Instalados (Não-Microsoft)",
            "Últimas 15 Atualizações do Windows",
            "Rede",
            "Processos em Execução",
            "Licenças Microsoft Office"
        )

        # Define as seções que devem ocupar a largura total (Full Span)
        $fullSpanSections = @(
            "Softwares Instalados (Não-Microsoft)",
            "Últimas 15 Atualizações do Windows",
            "Rede",
            "Armazenamento",
            "Processos em Execução",
            "Licenças Microsoft Office",
            "Memória RAM",
            "Placa de Vídeo (GPU)",
            "Verificação de Conformidade de Segurança"
        )

        # Itera e anexa cada seção de conteúdo
        $renderedSections = New-Object System.Collections.Generic.HashSet[string]

        if ($null -ne $SectionTitlesForSidebar -and $null -ne $SectionHtmlBodies) {
            foreach ($title in $SectionTitlesForSidebar) {
                if (-not [string]::IsNullOrWhiteSpace($title) -and -not $renderedSections.Contains($title)) {

                    # LOGICA ESPECIAL: Agrupamento Vertical (Identificação + Tipo de Equipamento)
                    if ($title -eq "Identificação") {
                        [void]$fullHtml.AppendLine("        <div style='display: flex; flex-direction: column; gap: 25px;'>")

                        # Renderiza Identificação
                        $sectionId = $title -replace '[^a-zA-Z0-9_]+', '-' -replace '_$', ''
                        [void]$fullHtml.AppendLine("            <section id='$($sectionId)' class='section'>")
                        [void]$fullHtml.AppendLine("                <h2>$([System.Security.SecurityElement]::Escape($title))$(Add-TooltipIfAvailable -Term $title)</h2>")
                        if ($SectionHtmlBodies.Contains($title)) { [void]$fullHtml.AppendLine($SectionHtmlBodies[$title]) }
                        [void]$fullHtml.AppendLine("            </section>")
                        [void]$renderedSections.Add($title)

                        # Renderiza Tipo de Equipamento (se existir) imediatamente abaixo
                        $subTitle = "Tipo de Equipamento"
                        if ($SectionHtmlBodies.Contains($subTitle)) {
                            $subSectionId = $subTitle -replace '[^a-zA-Z0-9_]+', '-' -replace '_$', ''
                            [void]$fullHtml.AppendLine("            <section id='$($subSectionId)' class='section'>")
                            [void]$fullHtml.AppendLine("                <h2>$([System.Security.SecurityElement]::Escape($subTitle))$(Add-TooltipIfAvailable -Term $subTitle)</h2>")
                            [void]$fullHtml.AppendLine($SectionHtmlBodies[$subTitle])
                            [void]$fullHtml.AppendLine("            </section>")
                            [void]$renderedSections.Add($subTitle)
                        }

                        [void]$fullHtml.AppendLine("        </div>")
                        continue
                    }

                    # LOGICA ESPECIAL: Agrupamento Vertical (Processador + Produto do Sistema)
                    if ($title -eq "Processador") {
                        [void]$fullHtml.AppendLine("        <div style='display: flex; flex-direction: column; gap: 25px;'>")

                        # Renderiza Processador
                        $sectionId = $title -replace '[^a-zA-Z0-9_]+', '-' -replace '_$', ''
                        [void]$fullHtml.AppendLine("            <section id='$($sectionId)' class='section'>")
                        [void]$fullHtml.AppendLine("                <h2>$([System.Security.SecurityElement]::Escape($title))$(Add-TooltipIfAvailable -Term $title)</h2>")
                        if ($SectionHtmlBodies.Contains($title)) { [void]$fullHtml.AppendLine($SectionHtmlBodies[$title]) }
                        [void]$fullHtml.AppendLine("            </section>")
                        [void]$renderedSections.Add($title)

                        # Renderiza Produto do Sistema (se existir) imediatamente abaixo
                        $subTitle = "Produto do Sistema (Fabricante/Modelo)"
                        if ($SectionHtmlBodies.Contains($subTitle)) {
                            $subSectionId = $subTitle -replace '[^a-zA-Z0-9_]+', '-' -replace '_$', ''
                            [void]$fullHtml.AppendLine("            <section id='$($subSectionId)' class='section'>")
                            [void]$fullHtml.AppendLine("                <h2>$([System.Security.SecurityElement]::Escape($subTitle))$(Add-TooltipIfAvailable -Term $subTitle)</h2>")
                            [void]$fullHtml.AppendLine($SectionHtmlBodies[$subTitle])
                            [void]$fullHtml.AppendLine("            </section>")
                            [void]$renderedSections.Add($subTitle)
                        }

                        [void]$fullHtml.AppendLine("        </div>")
                        continue
                    }

                    $sectionId = $title -replace '[^a-zA-Z0-9_]+', '-' -replace '_$', ''
                    [void]$renderedSections.Add($title)

                    # Lógica Dashboard: Verifica se deve ser Full Span
                    $spanClass = if ($fullSpanSections -contains $title) { " full-span" } else { "" }

                    [void]$fullHtml.AppendLine("        <section id='$($sectionId)' class='section$spanClass'>")
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
        [void]$fullHtml.AppendLine("        </div>") # Fim .report-grid
        [void]$fullHtml.AppendLine("    </div>") # Fim .main-content

        # --- Bloco de Script JavaScript (sem setTimeout) ---
        [void]$fullHtml.AppendLine("    <script>")
        [void]$fullHtml.AppendLine(@"
        document.addEventListener('DOMContentLoaded', function() {
            const sidebarLinks = document.querySelectorAll('#sidebar-nav a');
            const toggleButton = document.getElementById('sidebar-toggle');
            const sidebar = document.querySelector('.sidebar');
            const mainContent = document.querySelector('.main-content');

            // Toggle Sidebar Logic
            if (toggleButton) {
                toggleButton.addEventListener('click', function() {
                    sidebar.classList.toggle('closed');
                    mainContent.classList.toggle('expanded');
                });

                // Auto-Hide on Scroll Logic
                let isScrolling;
                const onScroll = function ( event ) {
                    toggleButton.classList.add('scroll-hidden');

                    window.clearTimeout( isScrolling );

                    isScrolling = setTimeout(function() {
                        toggleButton.classList.remove('scroll-hidden');
                    }, 300); // Reaparece após 300ms parado
                };

                window.addEventListener('scroll', onScroll, { passive: true });
                document.addEventListener('scroll', onScroll, { passive: true });
            }

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

        # Leitura do CSS com Fallback de Segurança
        $cssContent = ""
        $fallbackPrintCss = @"
            body { font-family: 'Times New Roman', Times, serif; color: #000; line-height: 1.4; margin: 0; padding: 2cm; background: #fff; }
            .print-container { width: 100%; max-width: 100%; margin: 0 auto; }
            h1 { text-align: center; border-bottom: 2px solid #000; padding-bottom: 10px; margin-bottom: 30px; font-size: 24pt; }
            h2 { font-size: 16pt; border-bottom: 1px solid #666; margin-top: 25px; margin-bottom: 15px; padding-bottom: 5px; page-break-after: avoid; }
            .section { margin-bottom: 20px; page-break-inside: avoid; }
            table { width: 100%; border-collapse: collapse; margin-bottom: 15px; page-break-inside: auto; }
            tr { page-break-inside: avoid; page-break-after: auto; }
            th, td { border: 1px solid #000; padding: 6px 10px; text-align: left; font-size: 10pt; }
            th { background-color: #eee; font-weight: bold; }
            .report-footer-printable { margin-top: 40px; border-top: 1px solid #000; padding-top: 10px; text-align: center; font-size: 9pt; font-style: italic; }
            a { text-decoration: none; color: #000; }
            @media print { body { padding: 0; } .section { page-break-inside: avoid; } }
"@

        try {
            if (Test-Path $PrintCssPath) {
                $cssContent = Get-Content -Path $PrintCssPath -Raw -ErrorAction Stop
            } else {
                Write-Warning "Arquivo CSS de impressão não encontrado em '$PrintCssPath'. Usando estilo padrão."
                $cssContent = $fallbackPrintCss
            }
        } catch {
            Write-Warning "Erro ao ler CSS de impressão. Detalhe: $($_.Exception.Message)"
            $cssContent = $fallbackPrintCss
        }

        # --- Construção do HTML para Impressão (Layout Corrigido) ---
        [void]$fullHtml.AppendLine("<!DOCTYPE html><html lang='pt-BR'><head>")
        [void]$fullHtml.AppendLine("    <meta charset='UTF-8'><title>Relatório Imprimível - $($ComputerName)</title>")
        [void]$fullHtml.AppendLine("    <style>$($cssContent)</style>")
        [void]$fullHtml.AppendLine("</head><body>")

        [void]$fullHtml.AppendLine("    <div class='print-container'>")

        # Título principal no topo do documento.
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

        # Rodapé com as informações de geração, movido para o final do documento
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
