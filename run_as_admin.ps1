# Defines the current user's Desktop directory and the output file name.
# Retrieves the desktop path and concatenates it with the computer name and the suffix "_Inventory.txt".
$output_dir = [System.Environment]::GetFolderPath("Desktop")
$filename = "$output_dir\$($env:COMPUTERNAME)_Inventory.txt"

# Deletes the previous file, if it exists.
# This ensures that the report is not appended to old data, generating a clean inventory.
if (Test-Path $filename) { 
    Remove-Item $filename -Force
}

# Adds the header in a single call.
$header = @"
===============================
IT INVENTORY - $(Get-Date)
===============================

"@
Add-Content -Path $filename -Value $header -Encoding UTF8

# [IDENTIFICATION]
# Starts the identification section, displaying the computer name and listing active users.
Add-Content -Path $filename -Value "[IDENTIFICATION]" -Encoding UTF8
Add-Content -Path $filename -Value "Computer Name: $env:COMPUTERNAME" -Encoding UTF8

# List active users
$activeUsers = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty UserName
if ($activeUsers) {
    Add-Content -Path $filename -Value "Active Users: $activeUsers" -Encoding UTF8
} else {
    Add-Content -Path $filename -Value "Active Users: None" -Encoding UTF8
}

# Checks if the USERNAME environment variable exists before adding it to the file
if ($env:USERNAME) {
    Add-Content -Path $filename -Value "User Executing the Script: $env:USERNAME" -Encoding UTF8
} else {
    Add-Content -Path $filename -Value "User Executing the Script: Unknown" -Encoding UTF8
}

# Listed created users.
Add-Content -Path $filename -Value "Created Users:" -Encoding UTF8

# Retrieve and list local users, handling potential errors
try {
    $users = Get-LocalUser | Select-Object -ExpandProperty Name
    if ($users) {
        foreach ($user in $users) {
            Add-Content -Path $filename -Value $user -Encoding UTF8
        }
    } else {
        Add-Content -Path $filename -Value "No users found." -Encoding UTF8
    }
} catch {
    Add-Content -Path $filename -Value "Error retrieving users: $_" -Encoding UTF8
}

# Gets the active local users (not disabled) and ignores unwanted default accounts.
$users = Get-CimInstance Win32_UserAccount | Where-Object { 
    $_.LocalAccount -eq $true -and $_.Disabled -eq $false -and $_.Name -notmatch '^(Administrator|DefaultAccount|Guest|WDAGUtilityAccount)$'
}

# Filters out the current user (the user running the script) to avoid duplication.
$filteredUsers = $users | Where-Object { $_.Name -notin $env:USERNAME }

# Adds a header or separator before the list of users
Add-Content -Path $filename -Value "===============================" -Encoding UTF8
Add-Content -Path $filename -Value "List of Filtered Users:" -Encoding UTF8
Add-Content -Path $filename -Value "===============================" -Encoding UTF8

# For each filtered user, writes the name to the file, adding a newline.
$filteredUsers | ForEach-Object { 
    Add-Content -Path $filename -Value "$($_.Name)`r`n" -Encoding UTF8
}

# Adds an empty line to the file for better readability.
Add-Content -Path $filename -Value "" -Encoding UTF8

# [SYSTEM INFORMATION] - Unifies the operating system and windows specifications.
Add-Content -Path $filename -Value "[SYSTEM INFORMATION]" -Encoding UTF8
$os = Get-CimInstance Win32_OperatingSystem
$winSpec = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion"

# Unifying the system and specification details in a single section
Add-Content -Path $filename -Value "System: $($os.Caption)" -Encoding UTF8
Add-Content -Path $filename -Value "Edition: $($winSpec.EditionID)" -Encoding UTF8
Add-Content -Path $filename -Value "Version: $($os.Version) (Build $($winSpec.CurrentBuild))" -Encoding UTF8
Add-Content -Path $filename -Value "Architecture: $($os.OSArchitecture)" -Encoding UTF8

# Add installation date or other relevant information
Add-Content -Path $filename -Value "Install Date: $($os.InstallDate)" -Encoding UTF8

# Adding a blank line for better readability
Add-Content -Path $filename -Value "" -Encoding UTF8

# [EQUIPMENT TYPE]
# Determines if the equipment is Desktop or Notebook based on the PCSystemType property.
Add-Content -Path $filename -Value "[EQUIPMENT TYPE]" -Encoding UTF8
$equipmentType = (Get-CimInstance Win32_ComputerSystem).PCSystemType
if ($equipmentType -eq 1) {
    Add-Content -Path $filename -Value "Type: Desktop" -Encoding UTF8
} else {
    Add-Content -Path $filename -Value "Type: Notebook" -Encoding UTF8
}
Add-Content -Path $filename -Value "" -Encoding UTF8

# [PROCESSOR]
# Collects information about the processor: model, cores, and maximum speed.
Add-Content -Path $filename -Value "[PROCESSOR]" -Encoding UTF8
$processor = Get-CimInstance Win32_Processor
Add-Content -Path $filename -Value "Model: $($processor.Name)" -Encoding UTF8
Add-Content -Path $filename -Value "Cores: $($processor.NumberOfCores)" -Encoding UTF8
Add-Content -Path $filename -Value "Max Speed: $($processor.MaxClockSpeed) MHz" -Encoding UTF8
Add-Content -Path $filename -Value "" -Encoding UTF8

# [RAM MEMORY]
# Collects information from each physical memory module installed.
Add-Content -Path $filename -Value "[RAM MEMORY]" -Encoding UTF8
$memory = Get-CimInstance Win32_PhysicalMemory

# Iterating through each memory module and collecting relevant information
$memory | ForEach-Object {
    # Converts the numeric memory type code to a readable string (DDR, DDR2, etc.).
    $ddr = switch ($_.SMBIOSMemoryType) {
        20 { 'DDR' }
        21 { 'DDR2' }
        22 { 'DDR2 FB-DIMM' }
        24 { 'DDR3' }
        26 { 'DDR4' }
        34 { 'DDR5' }
        default { 'Unknown' }
    }

    # Safely checks if the values exist before adding them to the report.
    $manufacturer = if ($_.Manufacturer) { $_.Manufacturer } else { 'Unknown' }
    $partNumber = if ($_.PartNumber) { $_.PartNumber } else { 'Unknown' }
    $serialNumber = if ($_.SerialNumber) { $_.SerialNumber } else { 'Unknown' }
    $capacity = if ($_.Capacity) { [math]::round($_.Capacity / 1GB, 2) } else { 'Unknown' }
    $speed = if ($_.Speed) { $_.Speed } else { 'Unknown' }

    # Consolidates the data into one entry for each memory module.
    $memoryDetails = @(
        "Manufacturer: $manufacturer"
        "Part Number: $partNumber"
        "Serial Number: $serialNumber"
        "Capacity: $capacity GB"
        "Speed: $speed MHz"
        "Type: $ddr"
        ""
    )

    # Adds all collected information to the file in a single write operation.
    Add-Content -Path $filename -Value $memoryDetails -Encoding UTF8
}

# [STORAGE] - Information on physical disks (SSD, HDD, or USB Drive).
Add-Content -Path $filename -Value "[STORAGE]" -Encoding UTF8

$disks = Get-PhysicalDisk
foreach ($disk in $disks) {
    # Determines the media type based on the MediaType value.
    $media = switch ($disk.MediaType) {
        3 { "HDD" }
        4 { "SSD" }
        default {
            # Detects NVMe SSDs by checking for the term 'NVMe' in the model or friendly name
            if ($disk.Model -match "NVMe" -or $disk.FriendlyName -match "NVMe") {
                "SSD NVMe"
            }
            # Detects USB drives based on model, friendly name, or device ID
            elseif ($disk.Model -match "USB" -or $disk.FriendlyName -match "USB" -or $disk.DeviceID -match "USB" -or $disk.Model -match "Cruzer|Flash|Thumb|Stick|Pen|Drive") {
                "USB Drive"
            }
            # Detects SSDs
            elseif ($disk.Model -match "SSD" -or $disk.FriendlyName -match "SSD") {
                "SSD"
            }
            # Detects HDDs
            elseif ($disk.Model -match "HDD" -or $disk.FriendlyName -match "HDD") {
                "HDD"
            } else {
                "Unknown"
            }
        }
    }
    
    # Logs the disk's friendly name
    Add-Content -Path $filename -Value "Drive: $($disk.FriendlyName)" -Encoding UTF8
    # Logs the type of disk (SSD, HDD, NVMe, or USB Drive)
    Add-Content -Path $filename -Value "Type: $media" -Encoding UTF8
    
    # Displays the serial number if available.
    if ($disk.SerialNumber) {
        Add-Content -Path $filename -Value "Serial: $($disk.SerialNumber)" -Encoding UTF8
    }
    
    # Add a newline to separate each disk's information
    Add-Content -Path $filename -Value "" -Encoding UTF8
}

# Disk space report by volume.
Add-Content -Path $filename -Value 'Space by Drive (Volumes):' -Encoding UTF8

$volumes = Get-Volume | Where-Object { $_.FileSystem -ne $null -and $_.DriveLetter -ne $null }

foreach ($volume in $volumes) {
    # Calculate total, used, and available space in GB and round to 2 decimal places.
    $total = [math]::round($volume.Size / 1GB, 2)
    $used = [math]::round(($volume.Size - $volume.SizeRemaining) / 1GB, 2)
    $available = [math]::round($volume.SizeRemaining / 1GB, 2)

    # Only include drives with letters and a minimum total size of 1 GB to filter out small or unimportant drives.
    if ($total -gt 0.1) {
        # Format the message with drive letter, total, used, and available space in GB
        $message = "Drive {0}: Total: {1} GB | Used: {2} GB | Available: {3} GB" -f $volume.DriveLetter, $total, $used, $available
        Add-Content -Path $filename -Value $message -Encoding UTF8
    }
}

Add-Content -Path $filename -Value "" -Encoding UTF8



# [NETWORK] – Network information.
Add-Content -Path $filename -Value "[NETWORK]" -Encoding UTF8

# Gets all active network adapters
$netAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

# Filters wireless adapters (Wi-Fi)
$wifiAdapters = $netAdapters | Where-Object { 
    $_.Name -match 'Wireless|Wi[-]?Fi' -or $_.InterfaceDescription -match 'Wireless|Wi[-]?Fi'
}

# Filters Ethernet adapters
$ethernetAdapters = $netAdapters | Where-Object { 
    $_.Name -match 'Ethernet' -or $_.InterfaceDescription -match 'Ethernet'
}

# Displays active Wi-Fi adapters
if ($wifiAdapters) {
    foreach ($wifi in $wifiAdapters) {
        Add-Content -Path $filename -Value "Wi‑Fi - Adapter: $($wifi.Name) | Physical Address (MAC): $($wifi.MacAddress)" -Encoding UTF8
    }
} else {
    Add-Content -Path $filename -Value "No active Wi‑Fi interfaces found." -Encoding UTF8
}

# Displays active Ethernet adapters
if ($ethernetAdapters) {
    foreach ($eth in $ethernetAdapters) {
        Add-Content -Path $filename -Value "Ethernet - Adapter: $($eth.Name) | Physical Address (MAC): $($eth.MacAddress)" -Encoding UTF8
    }
} else {
    Add-Content -Path $filename -Value "No active Ethernet interfaces found." -Encoding UTF8
}

# Adds a listing of all active network adapters (regardless of type)
if ($netAdapters) {
    Add-Content -Path $filename -Value "[ALL ACTIVE NETWORK ADAPTERS]" -Encoding UTF8
    foreach ($adapter in $netAdapters) {
        Add-Content -Path $filename -Value "Adapter: $($adapter.Name) | Physical Address (MAC): $($adapter.MacAddress) | Description: $($adapter.InterfaceDescription)" -Encoding UTF8
    }
} else {
    Add-Content -Path $filename -Value "No active network adapters found." -Encoding UTF8
}

# Selects the first valid IPv4 address, ignoring link-local addresses (169.254.x.x)
$mainIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch "^169\.254\." } | Select-Object -First 1).IPAddress
if ($mainIP) {
    Add-Content -Path $filename -Value "Main IP: $mainIP" -Encoding UTF8
}
Add-Content -Path $filename -Value "" -Encoding UTF8

# [INSTALLED SOFTWARES] – List of installed applications (excluding Microsoft ones).
Add-Content -Path $filename -Value "[INSTALLED SOFTWARES]" -Encoding UTF8
$apps1 = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue | 
    Where-Object { $_.DisplayName -and $_.DisplayName -notmatch "Microsoft" }
$apps2 = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue | 
    Where-Object { $_.DisplayName -and $_.DisplayName -notmatch "Microsoft" }
# Merges the two lists (64-bit and 32-bit applications).
$softwares = $apps1 + $apps2
$softwares | ForEach-Object {
    Add-Content -Path $filename -Value "$($_.DisplayName) - Version: $($_.DisplayVersion)" -Encoding UTF8
}
Add-Content -Path $filename -Value "" -Encoding UTF8

# [MAC] – Product information (Model, Manufacturer, and for Dell, displays the Service Tag).
Add-Content -Path $filename -Value "[MAC]" -Encoding UTF8
$mec = Get-CimInstance -ClassName Win32_ComputerSystemProduct
Add-Content -Path $filename -Value "Model: $($mec.Name)" -Encoding UTF8
Add-Content -Path $filename -Value "Manufacturer: $($mec.Vendor)" -Encoding UTF8
if ($mec.Vendor -match "Dell") {
    # For Dell systems, retrieves the BIOS Serial which represents the Service Tag.
    $dellSerial = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
    Add-Content -Path $filename -Value "Dell Service Tag: $dellSerial" -Encoding UTF8
} else {
    Add-Content -Path $filename -Value "Identification Number: $($mec.IdentifyingNumber)" -Encoding UTF8
}

# Adds new options: Device ID and Product ID.
Add-Content -Path $filename -Value "Device ID: $($mec.UUID)" -Encoding UTF8
$productID = (Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion').ProductID
Add-Content -Path $filename -Value "Product ID: $productID" -Encoding UTF8
Add-Content -Path $filename -Value "" -Encoding UTF8

# [BIOS & FIRMWARE] – BIOS details and chassis information.
Add-Content -Path $filename -Value "[BIOS & FIRMWARE]" -Encoding UTF8
$bios = Get-CimInstance -ClassName Win32_BIOS
# Joins BIOS versions (if more than one) separated by commas.
Add-Content -Path $filename -Value "BIOS - Version: $($bios.BIOSVersion -join ', ')" -Encoding UTF8
# Checks if the BIOS date is in a specific format; if so, converts it to a readable date.
if ($bios.ReleaseDate -and $bios.ReleaseDate -match '^\d{14}\.\d{6}[\+\-]\d{3}$') {
    $biosDate = [Management.ManagementDateTimeConverter]::ToDateTime($bios.ReleaseDate)
    Add-Content -Path $filename -Value "BIOS - Release Date: $biosDate" -Encoding UTF8
} else {
    Add-Content -Path $filename -Value "BIOS - Release Date: Not Available" -Encoding UTF8
}
# Retrieves system enclosure (chassis) information.
$enclosure = Get-CimInstance -ClassName Win32_SystemEnclosure
if ($enclosure.ChassisTypes) {
    # Displays the first listed chassis type.
    Add-Content -Path $filename -Value "Chassis Type: $($enclosure.ChassisTypes[0])" -Encoding UTF8
}
Add-Content -Path $filename -Value "" -Encoding UTF8

# [MONITORS] – Information about connected monitors via WMI (WmiMonitorID class).
Add-Content -Path $filename -Value "[MONITORS]" -Encoding UTF8
$monitors = Get-WmiObject -Namespace root\wmi -Class WmiMonitorID
if ($monitors) {
    foreach ($monitor in $monitors) {
        # Local function to decode byte arrays into strings (e.g., manufacturer name, model, serial).
        function Decode-Array($array) {
            if ($array -and ($array -is [array])) {
                return ([System.Text.Encoding]::ASCII.GetString($array)).Trim([char]0)
            } else { 
                return "Not Found" 
            }
        }
        $mManufacturer = Decode-Array $monitor.ManufacturerName
        $mName = Decode-Array $monitor.UserFriendlyName
        $mSerial = Decode-Array $monitor.SerialNumberID
        Add-Content -Path $filename -Value "Monitor: $mName" -Encoding UTF8
        Add-Content -Path $filename -Value "  Manufacturer: $mManufacturer" -Encoding UTF8
        Add-Content -Path $filename -Value "  Serial: $mSerial" -Encoding UTF8
        Add-Content -Path $filename -Value "" -Encoding UTF8
    }
} else {
    Add-Content -Path $filename -Value "No monitors found via WmiMonitorID." -Encoding UTF8
}
Add-Content -Path $filename -Value "" -Encoding UTF8

# [WINDOWS UPDATES] – Last 10 installed updates.
Add-Content -Path $filename -Value "[WINDOWS UPDATES]" -Encoding UTF8

try {
    # Creates the session and update searcher object
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    
    # Gets the total count of installed updates
    $historyCount = $updateSearcher.GetTotalHistoryCount()
    
    # Sets the desired amount (10 or fewer, if there are less updates)
    $numUpdates = [Math]::Min(10, $historyCount)
    
    # Retrieves the update history (from index 0 to $numUpdates)
    $updates = $updateSearcher.QueryHistory(0, $numUpdates) | Sort-Object -Property Date -Descending
    
    foreach ($update in $updates) {
        $title = $update.Title
        # Classifies the update based on keywords in the title.
        if ($title -match 'Quality|Cumulative') {
            $category = "Quality Update"
        } elseif ($title -match 'Driver') {
            $category = "Driver Update"
        } elseif ($title -match 'Definition|Antivirus') {
            $category = "Definition Update"
        } else {
            $category = "Other Updates"
        }
        # Formats the date and adds the information to the file.
        $updateDate = $update.Date.ToString("dd/MM/yyyy HH:mm")
        Add-Content -Path $filename -Value "$updateDate - [$category] $title" -Encoding UTF8
    }
} catch {
    Add-Content -Path $filename -Value "Unable to retrieve Windows update history." -Encoding UTF8
}
Add-Content -Path $filename -Value "" -Encoding UTF8

# [ACTIVE DIRECTORY] – Collects Active Directory information if the module is available.
Add-Content -Path $filename -Value "[ACTIVE DIRECTORY]" -Encoding UTF8
if (Get-Command -Name Get-ADComputer -ErrorAction SilentlyContinue) {
    Import-Module ActiveDirectory
    $adComputer = Get-ADComputer $env:COMPUTERNAME -Properties DistinguishedName
    Add-Content -Path $filename -Value "DistinguishedName: $($adComputer.DistinguishedName)" -Encoding UTF8
} else {
    Add-Content -Path $filename -Value "ActiveDirectory module not found. Skipping AD collection." -Encoding UTF8
}
Add-Content -Path $filename -Value "" -Encoding UTF8

# [GRAPHIC CARD] - Information about the graphic card.
Add-Content -Path $filename -Value "[GRAPHIC CARD]" -Encoding UTF8
$gpu = Get-CimInstance Win32_VideoController
foreach ($g in $gpu) {
    Add-Content -Path $filename -Value "Name: $($g.Name)" -Encoding UTF8
    Add-Content -Path $filename -Value "Driver Version: $($g.DriverVersion)" -Encoding UTF8
    Add-Content -Path $filename -Value "Video Processor: $($g.VideoProcessor)" -Encoding UTF8
    Add-Content -Path $filename -Value "" -Encoding UTF8
}

# Firewall status check
Add-Content -Path $filename -Value "[FIREWALL STATUS]" -Encoding UTF8
$firewallStatus = Get-NetFirewallProfile -Profile Domain,Public,Private
foreach ($profile in $firewallStatus) {
    Add-Content -Path $filename -Value "$($profile.Name): $($profile.Enabled)" -Encoding UTF8
}
Add-Content -Path $filename -Value "" -Encoding UTF8

# Antivirus handling
$antivirusList = Get-WmiObject -Namespace "root\SecurityCenter2" -Class AntiVirusProduct

# Check Windows Defender status
$defenderStatus = Get-Service -Name "WinDefend"
if ($defenderStatus.Status -eq "Running") {
    Add-Content -Path $filename -Value "Antivirus: Windows Defender" -Encoding UTF8
    Add-Content -Path $filename -Value "Status: Active" -Encoding UTF8
} else {
    Add-Content -Path $filename -Value "Antivirus: Windows Defender" -Encoding UTF8
    Add-Content -Path $filename -Value "Status: Inactive" -Encoding UTF8
}

# Check for third-party antivirus (like Kaspersky)
foreach ($av in $antivirusList) {
    # We check for a third-party antivirus that is not Windows Defender
    if ($av.displayName -ne "Windows Defender") {
        if ($av.productState -match ".*(397568).*") {  # 397568 means antivirus is active
            Add-Content -Path $filename -Value "Antivirus: $($av.displayName)" -Encoding UTF8
            Add-Content -Path $filename -Value "Status: Active" -Encoding UTF8
        } else {
            # If we can't verify the antivirus status, we mention that it might be active, but cannot confirm
            Add-Content -Path $filename -Value "Antivirus: $($av.displayName) (Status: Unable to Verify)" -Encoding UTF8
        }
    }
}

# Final message displayed on the console.
Write-Host "Report generated at: $filename"
