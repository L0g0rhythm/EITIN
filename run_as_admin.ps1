# Define o diretório da Área de Trabalho do usuário atual e o nome do arquivo de saída.
# Recupera o caminho da área de trabalho e concatena com o nome do computador e o sufixo "_Inventario.txt".
$output_dir = [System.Environment]::GetFolderPath("Desktop")
$filename = "$output_dir\$env:COMPUTERNAME`_Inventario.txt"

# Apaga o arquivo anterior, caso exista.
# Isso garante que o relatório não seja acrescido a dados antigos, gerando um inventário limpo.
if (Test-Path $filename) { 
    Remove-Item $filename 
}

# Cabeçalho do relatório.
# Adiciona linhas de separação, título com data/hora e uma linha em branco para melhor formatação.
Add-Content -Path $filename -Value "==============================="
Add-Content -Path $filename -Value "INVENTÁRIO DE TI - $(Get-Date)"
Add-Content -Path $filename -Value "==============================="
Add-Content -Path $filename -Value ""

# [IDENTIFICAÇÃO]
# Inicia a seção de identificação, exibindo o nome do computador e listando os usuários ativos.
Add-Content -Path $filename -Value "[IDENTIFICAÇÃO]"
Add-Content -Path $filename -Value "Nome do Computador: $env:COMPUTERNAME"
Add-Content -Path $filename -Value "Usuários Criados:"

# Obtém os usuários locais ativos (não desabilitados) e ignora contas padrão indesejadas.
$usuarios = Get-WmiObject Win32_UserAccount | Where-Object { 
    $_.LocalAccount -eq $true -and $_.Disabled -eq $false -and $_.Name -notmatch '^(Administrador|DefaultAccount|Guest|WDAGUtilityAccount)$'
}
# Para cada usuário filtrado, escreve o nome no arquivo.
$usuarios | ForEach-Object { 
    Add-Content -Path $filename -Value $_.Name 
}
Add-Content -Path $filename -Value ""

# [SISTEMA OPERACIONAL]
# Coleta informações do sistema operacional através do CIM (a abordagem recomendada atualmente).
Add-Content -Path $filename -Value "[SISTEMA OPERACIONAL]"
$os = Get-CimInstance Win32_OperatingSystem
Add-Content -Path $filename -Value "Sistema: $($os.Caption)"
Add-Content -Path $filename -Value "Versão: $($os.Version)"
Add-Content -Path $filename -Value "Arquitetura: $($os.OSArchitecture)"
Add-Content -Path $filename -Value ""

# [ESPECIFICAÇÕES DO WINDOWS] - seção onde são exibidas datas adicionais

Add-Content -Path $filename -Value "[ESPECIFICAÇÕES DO WINDOWS]"
$winSpec = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion"
Add-Content -Path $filename -Value "Produto: $($winSpec.ProductName)"
Add-Content -Path $filename -Value "Edição: $($winSpec.EditionID)"
Add-Content -Path $filename -Value "Versão: $($winSpec.CurrentVersion) (Build $($winSpec.CurrentBuild))"

# Tratamento da data de instalação
if ($os.InstallDate -and $os.InstallDate -match '^\d{14}\.\d{6}[\+\-]\d{3}$') {
    try {
        $installDate = [Management.ManagementDateTimeConverter]::ToDateTime($os.InstallDate)
        Add-Content -Path $filename -Value "Data de Instalação: $installDate"
    } catch {
        Add-Content -Path $filename -Value "Data de Instalação: Erro na conversão"
    }
} else {
    Add-Content -Path $filename -Value "Data de Instalação: Não Disponível"
}

# Tratamento da última inicialização
if ($os.LastBootUpTime -and $os.LastBootUpTime -match '^\d{14}\.\d{6}[\+\-]\d{3}$') {
    try {
        $lastBoot = [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
        Add-Content -Path $filename -Value "Última Inicialização: $lastBoot"
    } catch {
        Add-Content -Path $filename -Value "Última Inicialização: Erro na conversão"
    }
} else {
    Add-Content -Path $filename -Value "Última Inicialização: Não Disponível"
}

Add-Content -Path $filename -Value ""


# [TIPO DE EQUIPAMENTO]
# Determina se o equipamento é Desktop ou Notebook com base na propriedade PCSystemType.
Add-Content -Path $filename -Value "[TIPO DE EQUIPAMENTO]"
$tipoEquipamento = (Get-CimInstance Win32_ComputerSystem).PCSystemType
if ($tipoEquipamento -eq 1) {
    Add-Content -Path $filename -Value "Tipo: Desktop"
} else {
    Add-Content -Path $filename -Value "Tipo: Notebook"
}
Add-Content -Path $filename -Value ""

# [PROCESSADOR]
# Coleta informações sobre o processador: modelo, núcleos e velocidade máxima.
Add-Content -Path $filename -Value "[PROCESSADOR]"
$processador = Get-CimInstance Win32_Processor
Add-Content -Path $filename -Value "Modelo: $($processador.Name)"
Add-Content -Path $filename -Value "Núcleos: $($processador.NumberOfCores)"
Add-Content -Path $filename -Value "Velocidade Máxima: $($processador.MaxClockSpeed) MHz"
Add-Content -Path $filename -Value ""

# [MEMÓRIA RAM]
# Coleta informações de cada módulo físico de memória instalado.
Add-Content -Path $filename -Value "MEMORIA RAM"
$memoria = Get-CimInstance Win32_PhysicalMemory
$memoria | ForEach-Object {
    # Converte o código numérico do tipo de memória para uma string legível (DDR, DDR2, etc.).
    $ddr = switch ($_.SMBIOSMemoryType) {
        20 { 'DDR' }
        21 { 'DDR2' }
        22 { 'DDR2 FB-DIMM' }
        24 { 'DDR3' }
        26 { 'DDR4' }
        34 { 'DDR5' }
        default { 'Desconhecido' }
    }
    Add-Content -Path $filename -Value "Fabricante: $($_.Manufacturer)"
    Add-Content -Path $filename -Value "Capacidade: $([math]::round($_.Capacity / 1GB, 2)) GB"
    Add-Content -Path $filename -Value "Velocidade: $($_.Speed) MHz"
    Add-Content -Path $filename -Value "Tipo: $ddr"
    Add-Content -Path $filename -Value ""
}

# [ARMAZENAMENTO] - Informações dos discos físicos (SSD ou HDD).
Add-Content -Path $filename -Value "[ARMAZENAMENTO]"
$discos = Get-PhysicalDisk
foreach ($disco in $discos) {
    # Determina o tipo de mídia com base no valor de MediaType.
    $media = switch ($disco.MediaType) {
        3 { "HDD" }
        4 { "SSD" }
        default { "Desconhecido" }
    }
    Add-Content -Path $filename -Value "Unidade: $($disco.FriendlyName)"
    Add-Content -Path $filename -Value "Tipo: $media"
    # Exibe o serial se disponível.
    if ($disco.SerialNumber) {
        Add-Content -Path $filename -Value "Serial: $($disco.SerialNumber)"
    }
    Add-Content -Path $filename -Value ""
}
# Relatório do espaço em disco por volume.
Add-Content -Path $filename -Value 'Espaço por Unidade (Volumes):'
$volumes = Get-Volume | Where-Object { $_.FileSystem -ne $null }
foreach ($volume in $volumes) {
    $total = [math]::round($volume.Size / 1GB, 2)
    $usado = [math]::round(($volume.Size - $volume.SizeRemaining) / 1GB, 2)
    $disponivel = [math]::round($volume.SizeRemaining / 1GB, 2)
    # Formata a mensagem com drive, total, usado e disponível.
    $message = "Unidade {0}: Total: {1} GB `| Usado: {2} GB `| Disponível: {3} GB" -f $volume.DriveLetter, $total, $usado, $disponivel
    Add-Content -Path $filename -Value $message
}
Add-Content -Path $filename -Value ""

# [REDE] – Informações de rede.
Add-Content -Path $filename -Value "[REDE]"

# Obtém todos os adaptadores de rede ativos
$netAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

# Filtra adaptadores sem fio (Wi‑Fi)
$wifiAdapters = $netAdapters | Where-Object { 
    $_.Name -match 'Wireless|Wi[-]?Fi' -or $_.InterfaceDescription -match 'Wireless|Wi[-]?Fi'
}

# Filtra adaptadores Ethernet
$ethernetAdapters = $netAdapters | Where-Object { 
    $_.Name -match 'Ethernet' -or $_.InterfaceDescription -match 'Ethernet'
}

# Exibe os adaptadores Wi‑Fi ativos
if ($wifiAdapters) {
    foreach ($wifi in $wifiAdapters) {
        Add-Content -Path $filename -Value "Wi‑Fi - Placa: $($wifi.Name) | Endereço Físico (MAC): $($wifi.MacAddress)"
    }
} else {
    Add-Content -Path $filename -Value "Nenhuma interface Wi‑Fi ativa encontrada."
}

# Exibe os adaptadores Ethernet ativos
if ($ethernetAdapters) {
    foreach ($eth in $ethernetAdapters) {
        Add-Content -Path $filename -Value "Ethernet - Placa: $($eth.Name) | Endereço Físico (MAC): $($eth.MacAddress)"
    }
} else {
    Add-Content -Path $filename -Value "Nenhuma interface Ethernet ativa encontrada."
}

# Adiciona uma listagem de todas as placas de rede ativas (independentemente do tipo)
if ($netAdapters) {
    Add-Content -Path $filename -Value "[TODOS OS ADAPTADORES DE REDE ATIVOS]"
    foreach ($adapter in $netAdapters) {
        Add-Content -Path $filename -Value "Placa: $($adapter.Name) | Endereço Físico (MAC): $($adapter.MacAddress) | Descrição: $($adapter.InterfaceDescription)"
    }
} else {
    Add-Content -Path $filename -Value "Nenhum adaptador de rede ativo encontrado."
}

# Seleciona o primeiro endereço IPv4 válido, ignorando os de link-local (169.254.x.x)
$ipPrincipal = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch "^169\.254\." } | Select-Object -First 1).IPAddress
if ($ipPrincipal) {
    Add-Content -Path $filename -Value "IP Principal: $ipPrincipal"
}
Add-Content -Path $filename -Value ""



# [SOFTWARES INSTALADOS] – Lista de aplicativos instalados (excluindo os da Microsoft).
Add-Content -Path $filename -Value "[SOFTWARES INSTALADOS]"
$apps1 = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue | 
    Where-Object { $_.DisplayName -and $_.DisplayName -notmatch "Microsoft" }
$apps2 = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue | 
    Where-Object { $_.DisplayName -and $_.DisplayName -notmatch "Microsoft" }
# Junta as duas listas (aplicativos 64 e 32 bits).
$softwares = $apps1 + $apps2
$softwares | ForEach-Object {
    Add-Content -Path $filename -Value "$($_.DisplayName) - Versão: $($_.DisplayVersion)"
}
Add-Content -Path $filename -Value ""

# [MEC] – Informações do produto (Modelo, Fabricante, e, para Dell, exibe a Service Tag).
Add-Content -Path $filename -Value "[MEC]"
$mec = Get-CimInstance -ClassName Win32_ComputerSystemProduct
Add-Content -Path $filename -Value "Modelo: $($mec.Name)"
Add-Content -Path $filename -Value "Fabricante: $($mec.Vendor)"
if ($mec.Vendor -match "Dell") {
    # Para sistemas Dell, obtém o Serial da BIOS que representa a Service Tag.
    $dellSerial = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
    Add-Content -Path $filename -Value "Dell Service Tag: $dellSerial"
} else {
    Add-Content -Path $filename -Value "Número de Identificação: $($mec.IdentifyingNumber)"
}

# Adiciona as novas opções: ID do dispositivo e ID do produto.
Add-Content -Path $filename -Value "ID do Dispositivo: $($mec.UUID)"
$productID = (Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion').ProductID
Add-Content -Path $filename -Value "ID do Produto: $productID"
Add-Content -Path $filename -Value ""

# [BIOS & FIRMWARE] – Detalhes da BIOS e informações do chassi.
Add-Content -Path $filename -Value "[BIOS & FIRMWARE]"
$bios = Get-CimInstance -ClassName Win32_BIOS
# Junta as versões da BIOS (se houver mais de uma) separadas por vírgula.
Add-Content -Path $filename -Value "BIOS - Versão: $($bios.BIOSVersion -join ', ')"
# Verifica se a data da BIOS está em um formato específico; se sim, converte para data legível.
if ($bios.ReleaseDate -and $bios.ReleaseDate -match '^\d{14}\.\d{6}[\+\-]\d{3}$') {
    $biosDate = [Management.ManagementDateTimeConverter]::ToDateTime($bios.ReleaseDate)
    Add-Content -Path $filename -Value "BIOS - Data de Lançamento: $biosDate"
} else {
    Add-Content -Path $filename -Value "BIOS - Data de Lançamento: Não Disponível"
}
# Obtém informações do chassi (enclosure) do sistema.
$enclosure = Get-CimInstance -ClassName Win32_SystemEnclosure
if ($enclosure.ChassisTypes) {
    # Exibe o primeiro tipo de chassi listado.
    Add-Content -Path $filename -Value "Tipo de Chassi: $($enclosure.ChassisTypes[0])"
}
Add-Content -Path $filename -Value ""

# [MONITORES] – Informações dos monitores conectados via WMI (classe WmiMonitorID).
Add-Content -Path $filename -Value "[MONITORES]"
$monitores = Get-WmiObject -Namespace root\wmi -Class WmiMonitorID
if ($monitores) {
    foreach ($monitor in $monitores) {
        # Função local para decodificar arrays de bytes em strings (ex.: nome do fabricante, modelo, serial).
        function Decode-Array($array) {
            if ($array -and ($array -is [array])) {
                return ([System.Text.Encoding]::ASCII.GetString($array)).Trim([char]0)
            } else { 
                return "Não Encontrado" 
            }
        }
        $mManufacturer = Decode-Array $monitor.ManufacturerName
        $mName = Decode-Array $monitor.UserFriendlyName
        $mSerial = Decode-Array $monitor.SerialNumberID
        Add-Content -Path $filename -Value "Monitor: $mName"
        Add-Content -Path $filename -Value "  Fabricante: $mManufacturer"
        Add-Content -Path $filename -Value "  Serial: $mSerial"
        Add-Content -Path $filename -Value ""
    }
} else {
    Add-Content -Path $filename -Value "Nenhum monitor encontrado via WmiMonitorID."
}
Add-Content -Path $filename -Value ""

# [ATUALIZAÇÕES DO WINDOWS] – Últimas 10 atualizações instaladas.
Add-Content -Path $filename -Value "[ATUALIZAÇÕES DO WINDOWS]"

try {
    # Cria a sessão e o objeto de busca de atualizações
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    
    # Obtém a contagem total de atualizações instaladas
    $historyCount = $updateSearcher.GetTotalHistoryCount()
    
    # Define a quantidade desejada (10 ou menos, se houver menos atualizações)
    $numUpdates = [Math]::Min(10, $historyCount)
    
    # Recupera o histórico das atualizações (do índice 0 até $numUpdates)
    $updates = $updateSearcher.QueryHistory(0, $numUpdates) | Sort-Object -Property Date -Descending
    
    foreach ($update in $updates) {
        $title = $update.Title
        # Classifica a atualização com base em palavras-chave presentes no título.
        if ($title -match 'Qualidade|Cumulativa') {
            $category = "Atualização de Qualidade"
        } elseif ($title -match 'Driver') {
            $category = "Atualização de Drivers"
        } elseif ($title -match 'Definição|Antivírus') {
            $category = "Atualização de Definições"
        } else {
            $category = "Outras Atualizações"
        }
        # Formata a data e adiciona a informação ao arquivo.
        $updateDate = $update.Date.ToString("dd/MM/yyyy HH:mm")
        Add-Content -Path $filename -Value "$updateDate - [$category] $title"
    }
} catch {
    Add-Content -Path $filename -Value "Não foi possível recuperar o histórico de atualizações do Windows."
}
Add-Content -Path $filename -Value ""

# [ACTIVE DIRECTORY] – Coleta informações do Active Directory, se o módulo estiver disponível.
Add-Content -Path $filename -Value "[ACTIVE DIRECTORY]"
if (Get-Command -Name Get-ADComputer -ErrorAction SilentlyContinue) {
    Import-Module ActiveDirectory
    $adComputer = Get-ADComputer $env:COMPUTERNAME -Properties DistinguishedName
    Add-Content -Path $filename -Value "DistinguishedName: $($adComputer.DistinguishedName)"
} else {
    Add-Content -Path $filename -Value "Módulo ActiveDirectory não encontrado. Pulando coleta de AD."
}
Add-Content -Path $filename -Value ""

# Mensagem final exibida no console.
Write-Host "Relatório gerado em: $filename"
