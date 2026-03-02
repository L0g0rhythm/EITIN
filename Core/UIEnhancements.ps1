# um cabeçalho formatado e centralizado no console.
function Write-EitinHeader {
    [CmdletBinding()]
    param(
        [string]$ScriptTitle = "EITIN - Inventário de TI Elevado"
    )
    process {
        $lineLength = 70
        Write-Host ("=" * $lineLength) -ForegroundColor Cyan
        $paddingTitle = [math]::Max(0, ([int](($lineLength - $ScriptTitle.Length) / 2)))
        Write-Host (" " * $paddingTitle) -NoNewline
        Write-Host $ScriptTitle -ForegroundColor White
        Write-Host ("=" * $lineLength) -ForegroundColor Cyan
        Write-Host ""
    }
}

# Escreve o início de uma nova seção de coleta no console.
function Write-EitinSectionStart {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SectionTitle
    )
    process {
        $useModernIcons = $PSVersionTable.PSVersion.Major -ge 6
        $icon = if ($useModernIcons) { "⚙️ " } else { "[>]" }

        Write-Host ""
        Write-Host ("-" * 70) -ForegroundColor DarkGray
        Write-Host "$icon [COLETANDO] $($SectionTitle)..." -ForegroundColor Yellow
    }
}

# Escreve uma linha de status formatada (INFO, SUCCESS, WARN, ERROR).
function Write-EitinStep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $true)]
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR")]
        [string]$Status,
        [switch]$SkipAudit # Novo parâmetro para suprimir logs repetitivos
    )
    process {
        $prefix = ""
        $color = "Gray"

        # Verifica Versão do PowerShell para compatibilidade visual
        # PS Core (6+) suporta emojis bem. PS 5.1 (Legacy) frequentemente falha.
        $useModernIcons = $PSVersionTable.PSVersion.Major -ge 6

        # Prefixo alinhado para melhor legibilidade no console
        switch ($Status) {
            "SUCCESS" {
                $prefix = if ($useModernIcons) { "✅ [SUCESSO] " } else { "[OK] " }
                $color = "Green"
            }
            "WARN"    {
                $prefix = if ($useModernIcons) { "⚠️  [AVISO]   " } else { "[!]  " }
                $color = "Yellow"
            }
            "ERROR"   {
                $prefix = if ($useModernIcons) { "❌ [ERRO]    " } else { "[X]  " }
                $color = "Red"
            }
            "INFO"    {
                $prefix = if ($useModernIcons) { "ℹ️  [INFO]    " } else { "[i]  " }
                $color = "Cyan"
            }
        }
        Write-Host "$($prefix)$Message" -ForegroundColor $color

        # Integração com Auditoria
        if (-not $SkipAudit) {
            $auditSeveridade = switch ($Status) {
                "SUCCESS" { "INFO" }
                "WARN"    { "WARN" }
                "ERROR"   { "ERROR" }
                "INFO"    { "INFO" }
                Default   { "INFO" }
            }

            $auditResult = switch ($Status) {
                "SUCCESS" { "SUCCESS" }
                "ERROR"   { "FAILURE" }
                Default   { "NEUTRAL" }
            }

            Write-EitinAuditLog -EventId "UI_STEP" -Severity $auditSeveridade -Result $auditResult -Message $Message
        }
    }
}

# Escreve a mensagem de finalização de uma seção, indicando sucesso ou falha.
function Write-EitinSectionEnd {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SectionTitle,
        [Parameter(Mandatory = $true)]
        [bool]$Success,
        [string]$ErrorMessage = ""
    )
    process {
        if ($Success) {
            # Sucesso agora é "silencioso" no log de auditoria para reduzir ruído
            Write-EitinStep -Message "Coleta para '$($SectionTitle)' finalizada." -Status "SUCCESS" -SkipAudit
        } else {
            $fullMessage = "Falha na coleta de dados para: $($SectionTitle)."
            if (-not [string]::IsNullOrEmpty($ErrorMessage)) {
                $fullMessage += " Detalhes: $ErrorMessage"
            }
            # Erros continuam sendo auditados
            Write-EitinStep -Message $fullMessage -Status "ERROR"
        }
    }
}

# Escreve o rodapé final do console, listando os caminhos dos relatórios gerados.
function Write-EitinFooter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.TimeSpan]$ExecutionTime,
        [Parameter(Mandatory = $false)]
        [string]$TxtLogPath,
        [Parameter(Mandatory = $false)]
        [string]$HtmlLogPath,
        [Parameter(Mandatory = $false)]
        [string]$PrintableHtmlPath,
        [Parameter(Mandatory = $false)]
        [string]$CsvLogPath
    )
    process {
        $useModernIcons = $PSVersionTable.PSVersion.Major -ge 6

        Write-Host ""
        Write-Host ("*" * 70) -ForegroundColor DarkGreen
        Write-EitinStep -Message "EXECUÇÃO DO SCRIPT EITIN E GERAÇÃO DE RELATÓRIOS CONCLUÍDAS" -Status "SUCCESS"
        Write-Host ("*" * 70) -ForegroundColor DarkGreen
        Write-Host ""

        if (-not [string]::IsNullOrWhiteSpace($TxtLogPath)) {
            Write-EitinStep -Message "Relatório TXT gerado em: $TxtLogPath" -Status "INFO"
            Write-Host ""
        }
        if (-not [string]::IsNullOrWhiteSpace($HtmlLogPath)) {
            Write-EitinStep -Message "Relatório HTML Interativo gerado em: $HtmlLogPath" -Status "INFO"
            Write-Host ""
        }
        if (-not [string]::IsNullOrWhiteSpace($PrintableHtmlPath)) {
            Write-EitinStep -Message "Relatório para Impressão/PDF gerado em: $PrintableHtmlPath" -Status "INFO"
            Write-Host ""
        }
        if (-not [string]::IsNullOrWhiteSpace($CsvLogPath)) {
            Write-EitinStep -Message "Relatórios CSV gerados na pasta: $CsvLogPath" -Status "INFO"
            Write-Host ""
        }

        # Formata e exibe o tempo total de execução.
        $formattedTime = ""
        if ($ExecutionTime.TotalHours -ge 1) {
            $formattedTime = "{0:0}h {1:0}m {2:0}s" -f $ExecutionTime.Hours, $ExecutionTime.Minutes, $ExecutionTime.Seconds
        }
        elseif ($ExecutionTime.TotalMinutes -ge 1) {
            $formattedTime = "{0:0}m {1:0}s" -f $ExecutionTime.Minutes, $ExecutionTime.Seconds
        }
        elseif ($ExecutionTime.TotalSeconds -ge 1) {
            $formattedTime = "{0:0.0}s" -f $ExecutionTime.TotalSeconds
        }
        else {
            $formattedTime = "$($ExecutionTime.TotalMilliseconds)ms"
        }

        $timeIcon = if ($useModernIcons) { "⏱️ " } else { "[T]" }
        Write-Host "$timeIcon [TEMPO]   Tempo total de execução: $($formattedTime)" -ForegroundColor Gray

        Write-Host ""
        Write-Host "Para um inventário detalhado, por favor, consulte os relatórios gerados." -ForegroundColor Green
        Write-Host ("=" * 70) -ForegroundColor Cyan
        Write-Host ""
    }
}

function Update-EitinConsoleWindow {
    try {
        # Pequeno delay para garantir que a janela foi totalmente renderizada pelo Windows
        Start-Sleep -Milliseconds 250

        # Verifica se o tipo já existe de forma segura (avoiding GetType exceptions)
        if (-not ("EITIN.ConsoleUtils" -as [type])) {
            $code = @"
            using System;
            using System.Runtime.InteropServices;
            public class ConsoleUtils {
                [DllImport("user32.dll")] public static extern IntPtr GetConsoleWindow();
                [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
                [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
                [DllImport("user32.dll")] public static extern int GetSystemMetrics(int nIndex);
                public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

                public static void Center() {
                    IntPtr hwnd = GetConsoleWindow();
                    if (hwnd != IntPtr.Zero) {
                        RECT rect;
                        if (GetWindowRect(hwnd, out rect)) {
                            int width = rect.Right - rect.Left;
                            int height = rect.Bottom - rect.Top;
                            int screenWidth = GetSystemMetrics(0); // SM_CXSCREEN
                            int screenHeight = GetSystemMetrics(1); // SM_CYSCREEN

                            // Centraliza apenas se a janela for menor que a tela
                            if (width < screenWidth && height < screenHeight) {
                                int x = (screenWidth - width) / 2;
                                int y = (screenHeight - height) / 2;
                                MoveWindow(hwnd, x, y, width, height, true);
                            }
                        }
                    }
                }
            }
"@
            Add-Type -TypeDefinition $code -Language CSharp -Namespace "EITIN" -IgnoreWarnings
        }
        [EITIN.ConsoleUtils]::Center()
    } catch {
        # Falha silenciosa para não atrapalhar o usuário, mas visível se depurar
        Write-Verbose "Falha ao centralizar janela (Update-EitinConsoleWindow): $_"
    }
}
