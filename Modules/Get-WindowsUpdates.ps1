function Invoke-EitinWindowsUpdatesInfo {
    [CmdletBinding()]
    param()

    process {
        $updatesList = New-Object System.Collections.ArrayList
        $errorMessage = $null 

        try {
            $updateSession = New-Object -ComObject Microsoft.Update.Session -ErrorAction Stop 
            $updateSearcher = $updateSession.CreateUpdateSearcher() 
            $historyCount = $updateSearcher.GetTotalHistoryCount() 

            if ($historyCount -gt 0) {
                $updatesToFetch = [Math]::Min(15, $historyCount)
                $queryStartIndex = $historyCount - $updatesToFetch
                
                $rawUpdates = $updateSearcher.QueryHistory($queryStartIndex, $updatesToFetch) | 
                              Sort-Object -Property Date -Descending 

                foreach ($update in $rawUpdates) {
                    $titleValue = Get-SafeProperty -ObjectInstance $update -PropertyName 'Title' -DefaultValue 'Título Desconhecido'
                    $updateDateObj = Get-SafeProperty -ObjectInstance $update -PropertyName 'Date' -DefaultValue $null
                    $updateDateFormatted = "Data Inválida" 
                    if ($updateDateObj -is [datetime]) {
                        $updateDateFormatted = $updateDateObj.ToString("dd/MM/yyyy HH:mm:ss")
                    } elseif ($null -ne $updateDateObj) { 
                        $updateDateFormatted = "Objeto de Data Inválido ($($updateDateObj))"
                    }
                    
                    $updateDetails = [ordered]@{
                        "Data da Instalação"      = $updateDateFormatted
                        "Título da Atualização"   = $titleValue
                    }
                    [void]$updatesList.Add([PSCustomObject]$updateDetails)
                } 
            } else { 
                $errorMessage = "Nenhum histórico de atualização encontrado." 
            }
        } 
        catch { 
            $errorMessage = "Erro ao buscar histórico do Windows Update: $($_.Exception.Message)" 
            Write-Warning $errorMessage
            return [PSCustomObject]@{ Error = $errorMessage } 
        }

        if ($updatesList.Count -eq 0) {
            $finalMessage = if (-not [string]::IsNullOrWhiteSpace($errorMessage)) { $errorMessage } else { "Nenhum histórico de atualização encontrado ou aplicável." }
            return [PSCustomObject]@{ "Informação" = $finalMessage }
        }
        
        return $updatesList.ToArray()
    } 
}