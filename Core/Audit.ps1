# Core/Audit.ps1
# Módulo de Auditoria: Registra eventos em formato JSONL (append-only).

$Global:EitinAuditLogPath = $null

function Initialize-EitinAuditLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$LogDirectory,
        [Parameter(Mandatory = $true)] [string]$ComputerName,
        [Parameter(Mandatory = $true)] [string]$UserName
    )
    process {
        # Cria o diretório de auditoria dentro da pasta de logs da execução atual
        $auditDir = Join-Path -Path $LogDirectory -ChildPath "Audit"

        if (-not (Test-Path $auditDir)) {
            New-Item -Path $auditDir -ItemType Directory -Force | Out-Null
        }

        # Nome do arquivo de auditoria com timestamp para garantir unicidade
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $fileName = "EITIN_Audit_${ComputerName}_${UserName}_${timestamp}.jsonl"
        $Global:EitinAuditLogPath = Join-Path -Path $auditDir -ChildPath $fileName

        # Evento inicial de criação do log
        Write-EitinAuditLog -EventId "AUDIT_INIT" -Severity "INFO" -Result "SUCCESS" -Message "Log de auditoria inicializado."
    }
}

function Write-EitinAuditLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$EventId,
        [Parameter(Mandatory = $true)] [ValidateSet("DEBUG", "INFO", "WARN", "ERROR", "CRITICAL")] [string]$Severity,
        [Parameter(Mandatory = $true)] [ValidateSet("SUCCESS", "FAILURE", "NEUTRAL")] [string]$Result,
        [Parameter(Mandatory = $true)] [string]$Message,
        [hashtable]$Metadata = @{}
    )
    process {
        # Se o caminho do log não estiver definido, não faz nada (segurança contra chamada prematura)
        if ([string]::IsNullOrWhiteSpace($Global:EitinAuditLogPath)) { return }

        $logEntry = [ordered]@{
            schema_ver = "1.0"
            timestamp  = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
            event_id   = $EventId
            severity   = $Severity
            actor      = $Global:EitinExecutingUser
            device     = $Global:EitinComputerName
            result     = $Result
            message    = $Message
            metadata   = $Metadata
        }

        # Converte para JSON compactado (uma linha por evento)
        $jsonLine = $logEntry | ConvertTo-Json -Compress -Depth 5

        # Gravação atômica (Append)
        try {
            $jsonLine | Out-File -FilePath $Global:EitinAuditLogPath -Append -Encoding UTF8 -ErrorAction Stop
        } catch {
            # Falha silenciosa no console para não interromper fluxo, mas crítico em termos de auditoria.
            # Em um cenário real, poderia tentar um fallback (EventLog do Windows), mas aqui apenas seguimos.
        }
    }
}
