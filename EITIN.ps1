<#
.SYNOPSIS
    Generates a detailed IT inventory report for the local machine.
    Requires administrative privileges and will attempt to self-elevate if needed.
.DESCRIPTION
    This script collects hardware, software, OS, network, security, and update information
    and saves it to a text file named HOSTNAME_Inventory.txt on the user's Desktop.
    If not run with administrative privileges, it will trigger a UAC prompt to relaunch itself elevated.
#>

#region Self-Elevation Check

param() # Define parameters here if your script needs any

# Check if running with Administrator privileges
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$windowsPrincipal = [Security.Principal.WindowsPrincipal]$currentUser

if (-not $windowsPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Not running as Admin - Attempt to relaunch self with elevation
    try {
        $powershellPath = $PSCommandPath # Get the path to the current script
        # Prepare arguments, securely re-passing any bound parameters
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$powershellPath`""
        # Add bound parameters back to the argument list if any were passed
        $psBoundParameters.GetEnumerator() | ForEach-Object {
            $paramName = $_.Key
            $paramValue = $_.Value
            # Handle different parameter types appropriately, simple quoting for basic cases
            if ($paramValue -is [System.Management.Automation.SwitchParameter]) {
                if ($paramValue.IsPresent) { $arguments += " -$paramName" }
            } elseif ($paramValue -is [string]) {
                 # Basic quoting, might need refinement for complex strings
                $arguments += " -$paramName `"$($paramValue -replace '"','\`"')`""
            } else {
                 # Handle other types like arrays, numbers etc. if needed
                 # For simplicity here, just convert to string - adjust if necessary
                 $arguments += " -$paramName `"$($paramValue)`""
            }
        }

        Start-Process powershell.exe -ArgumentList $arguments.Trim() -Verb RunAs -ErrorAction Stop
    } catch {
        # Write error to console (useful if run interactively and elevation fails)
        Write-Error "Failed to elevate privileges: $($_.Exception.Message)"
        # Pause briefly to allow user to see the error if run interactively by double-click
        # Start-Sleep -Seconds 10
        Exit 1 # Exit with an error code
    }
    # Exit the current non-elevated instance successfully
    Exit 0
}

# If script reaches this point, it IS running with Administrator privileges.

#endregion

#region Inventory Script Logic (Requires Elevation)

# --- Configuration ---
# Define the output directory (default: Current User's Desktop)
# Note: If run as SYSTEM via Task Scheduler, this might point elsewhere. Consider a fixed path like C:\Logs if needed.
$outputDir = [System.Environment]::GetFolderPath("Desktop")
# Define the inventory filename
$filename = Join-Path -Path $outputDir -ChildPath "$($env:COMPUTERNAME)_Inventory.txt"
# Define the file encoding (as a string name)
$fileEncoding = "UTF8"

# --- Helper Functions ---

# Function to write content to the log file
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [AllowNull()]
        $Content
    )
    # Use -ErrorAction SilentlyContinue or add specific error handling if file access fails
    Add-Content -Path $filename -Value $Content -Encoding $fileEncoding -ErrorAction SilentlyContinue
}

# Function to write formatted section headers
function Write-SectionHeader {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SectionName
    )
    Write-Log "--- [ $($SectionName.ToUpper()) ] ---"
}

# Function to safely get a property value
function Get-SafeProperty {
    param(
        [Parameter(Mandatory=$true)]
        $ObjectInstance,
        [Parameter(Mandatory=$true)]
        [string]$PropertyName,
        [string]$DefaultValue = "Not Found"
    )
    # Check specifically for $null before accessing property to avoid errors on null objects
    if ($ObjectInstance -eq $null) { return $DefaultValue }
    $propValue = $ObjectInstance.$PropertyName
    if ($propValue -ne $null -and $propValue -ne "") {
        return $propValue
    } else {
        return $DefaultValue
    }
}

# Function to convert WMI date to readable format
function Convert-WmiDate {
    param(
        [Parameter(Mandatory=$true)]
        $WmiDate
    )
    if ($WmiDate -match '^\d{14}\.\d{6}[\+\-]\d{3}$') {
        try {
            return ([Management.ManagementDateTimeConverter]::ToDateTime($WmiDate)).ToString("yyyy-MM-dd HH:mm:ss")
        } catch {
            return "Invalid Date Format"
        }
    } elseif ($WmiDate) {
         try {
             # Attempt parsing common alternative format without timezone/milliseconds
             $dateTime = [datetime]::ParseExact($WmiDate.Split('.')[0], "yyyyMMddHHmmss", $null)
             return $dateTime.ToString("yyyy-MM-dd HH:mm:ss")
         } catch {
            return "$WmiDate (Unrecognized Format)"
         }
    }
     else {
        return "Not Available"
    }
}

# --- Report Generation ---

# Delete previous file if it exists, ensuring a clean report
if (Test-Path $filename) {
    Remove-Item $filename -Force -ErrorAction SilentlyContinue
}

# --- Main Header ---
$header = @"
=================================================
        IT INVENTORY - $($env:COMPUTERNAME)
=================================================
Report Generated On: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
(Executed with Administrator privileges)
"@
Write-Log $header

# --- [ IDENTIFICATION ] ---
Write-SectionHeader "Identification"
try {
    $identificationInfo = @(
        "Computer Name: $($env:COMPUTERNAME)"
    )
    # Active (Logged-in) User(s) - Using CIM
    $activeUsersCim = Get-CimInstance -ClassName Win32_LogonSession -Filter "LogonType = 2" | # Interactive users
                      ForEach-Object { Get-CimAssociatedInstance -InputObject $_ -ResultClassName Win32_Account -ErrorAction SilentlyContinue } |
                      Where-Object { $_.Name -ne $null } |
                      Select-Object -ExpandProperty Name -Unique
    $identificationInfo += "Logged-in User(s) (Interactive): $(if ($activeUsersCim) { $activeUsersCim -join ', ' } else { 'None Detected' })"

    # User Running the Script (Effective User)
    $executingUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $identificationInfo += "Script Executing User (Effective): $($executingUser)"

    # Local Users (All)
    $identificationInfo += "`n  Local Users (All):"
    try {
        $localUsers = Get-LocalUser -ErrorAction Stop | Select-Object -ExpandProperty Name
        if ($localUsers) {
            $identificationInfo += ($localUsers | ForEach-Object { "    - $_" })
        } else {
            $identificationInfo += "    No local users found."
        }
    } catch {
        $identificationInfo += "    Error fetching local users: $($_.Exception.Message)"
    }

    # Active Local Users (Filtered)
    $identificationInfo += "`n  Active Local Users (Excluding Default/Disabled):"
    $filteredUsers = Get-CimInstance Win32_UserAccount -Filter "LocalAccount = TRUE AND Disabled = FALSE" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '^(Administrator|DefaultAccount|Guest|WDAGUtilityAccount)$' } |
        Select-Object -ExpandProperty Name
    if ($filteredUsers) {
         $identificationInfo += ($filteredUsers | ForEach-Object { "    - $_" })
    } else {
        $identificationInfo += "    No active filtered users found."
    }

    Write-Log $identificationInfo
} catch {
    Write-Log "Error collecting identification information: $($_.Exception.Message)"
}
Write-Log "" # Blank line for separation

# --- [ SYSTEM INFORMATION ] ---
Write-SectionHeader "System Information"
try {
    $os = Get-CimInstance Win32_OperatingSystem -Property Caption, Version, OSArchitecture, InstallDate -ErrorAction Stop
    $winSpec = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name EditionID, CurrentBuild, ProductName -ErrorAction Stop

    $systemInfo = @(
        "Operating System: $(Get-SafeProperty $winSpec 'ProductName') ($(Get-SafeProperty $os 'Caption'))"
        "Edition: $(Get-SafeProperty $winSpec 'EditionID')"
        "Version: $(Get-SafeProperty $os 'Version') (Build $(Get-SafeProperty $winSpec 'CurrentBuild'))"
        "Architecture: $(Get-SafeProperty $os 'OSArchitecture')"
        "Install Date: $(Convert-WmiDate (Get-SafeProperty $os 'InstallDate'))"
    )
    Write-Log $systemInfo
} catch {
    Write-Log "Error collecting system information: $($_.Exception.Message)"
}
Write-Log ""

# --- [ EQUIPMENT TYPE ] ---
Write-SectionHeader "Equipment Type"
try {
    $systemType = (Get-CimInstance Win32_ComputerSystem -Property PCSystemType -ErrorAction Stop).PCSystemType
    $equipmentType = switch ($systemType) {
        1 { "Desktop" }
        2 { "Notebook / Laptop" }
        3 { "Workstation Desktop" }
        4 { "Enterprise Server" }
        5 { "SOHO Server" }
        6 { "Appliance PC" }
        7 { "Performance Server" }
        8 { "Tablet" }
        9 { "Laptop" }
        10 { "Notebook" }
        12 { "Docking Station" }
        14 { "Sub Notebook" }
        30 { "Tablet" } 31 { "Convertible" } 32 { "Detachable" }
        default { "Unknown ($systemType)" }
    }
    Write-Log "Type: $equipmentType"
} catch {
    Write-Log "Error determining equipment type: $($_.Exception.Message)"
}
Write-Log ""

# --- [ PROCESSOR ] ---
Write-SectionHeader "Processor"
try {
    # Get only needed properties
    $proc = Get-CimInstance Win32_Processor -Property Name, NumberOfCores, MaxClockSpeed -ErrorAction Stop
    $procInfo = @(
        "Model: $(Get-SafeProperty $proc 'Name')"
        "Cores: $(Get-SafeProperty $proc 'NumberOfCores')"
        "Max Speed: $(Get-SafeProperty $proc 'MaxClockSpeed') MHz"
    )
    Write-Log $procInfo
} catch {
    Write-Log "Error collecting processor information: $($_.Exception.Message)"
}
Write-Log ""

# --- [ RAM MEMORY ] ---
Write-SectionHeader "RAM Memory"
try {
    # Get only needed properties
    $memoryModules = Get-CimInstance Win32_PhysicalMemory -Property Manufacturer, PartNumber, SerialNumber, Capacity, Speed, SMBIOSMemoryType -ErrorAction Stop
    if ($memoryModules) {
        $ramInfo = @()
        $moduleIndex = 1
        foreach ($mem in $memoryModules) {
            $ddrType = switch ($mem.SMBIOSMemoryType) {
                20 { 'DDR' } 21 { 'DDR2' } 22 { 'DDR2 FB-DIMM' } 24 { 'DDR3' }
                26 { 'DDR4' } 30 { 'DDR4' } # Include 30 per some specs
                34 { 'DDR5' }
                default { "Unknown ($($mem.SMBIOSMemoryType))" }
            }
            # Use safe property access for capacity before calculation
            $capacityBytes = Get-SafeProperty $mem 'Capacity' 0
            $capacityGB = if ($capacityBytes -gt 0) { [math]::Round($capacityBytes / 1GB, 2) } else { 'N/A' }

            $ramInfo += "`n  Module $($moduleIndex):"
            $ramInfo += "    Manufacturer: $(Get-SafeProperty $mem 'Manufacturer')"
            $ramInfo += "    Part Number: $(Get-SafeProperty $mem 'PartNumber')"
            $ramInfo += "    Serial Number: $(Get-SafeProperty $mem 'SerialNumber')"
            $ramInfo += "    Capacity: $capacityGB GB"
            $ramInfo += "    Speed: $(Get-SafeProperty $mem 'Speed') MHz"
            $ramInfo += "    Type: $ddrType"
            $moduleIndex++
        }
        Write-Log $ramInfo
    } else {
        Write-Log "No physical memory modules found."
    }
} catch {
    Write-Log "Error collecting RAM information: $($_.Exception.Message)"
}
Write-Log ""

# --- [ STORAGE ] ---
Write-SectionHeader "Storage"
try {
    # Physical Disks
    $disks = Get-PhysicalDisk -ErrorAction Stop
    if ($disks) {
        $diskInfo = @("  Physical Disks:")
        foreach ($disk in $disks) {
             $mediaType = switch ($disk.MediaType) {
                3 { "HDD" } 4 { "SSD" } 5 { "SCM" }
                0 { # Unspecified
                    if ($disk.Model -match "NVMe" -or $disk.FriendlyName -match "NVMe") { "SSD NVMe" }
                    elseif ($disk.BusType -eq 'USB') { "USB Drive" }
                    elseif ($disk.Model -match "SSD" -or $disk.FriendlyName -match "SSD") { "SSD" }
                    elseif ($disk.Model -match "HDD" -or $disk.FriendlyName -match "HDD") { "HDD" }
                    else { "Unknown (Media:0)" }
                }
                default { # Other
                     if ($disk.BusType -eq 'USB') { "USB Drive" }
                     elseif ($disk.Model -match "NVMe") { "SSD NVMe" }
                     else {"Unknown (Media:$($disk.MediaType))"}
                }
            }
            $diskSize = Get-SafeProperty $disk 'Size' 0
            $sizeGB = if ($diskSize -gt 0) { [math]::Round($diskSize / 1GB, 2) } else { 'N/A' }

            $diskInfo += "`n    Drive: $(Get-SafeProperty $disk 'FriendlyName')"
            $diskInfo += "      Type: $mediaType"
            $diskInfo += "      Model: $(Get-SafeProperty $disk 'Model')"
            $diskInfo += "      Serial: $(Get-SafeProperty $disk 'SerialNumber')"
            $diskInfo += "      Size: $sizeGB GB"
            $diskInfo += "      Status: $(Get-SafeProperty $disk 'OperationalStatus')"
            $diskInfo += "      Bus Type: $(Get-SafeProperty $disk 'BusType')"
        }
         Write-Log $diskInfo
    } else {
        Write-Log "  No physical disks found."
    }

    # Space by Volume
    $volumes = Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter -ne $null -and $_.FileSystem -ne $null }
    if ($volumes) {
        $volumeInfo = @("`n  Space by Volume:")
        foreach ($volume in $volumes) {
            $totalSize = Get-SafeProperty $volume 'Size' 0
            $freeSpace = Get-SafeProperty $volume 'SizeRemaining' 0
            $totalGB = if ($totalSize -gt 0) { [math]::Round($totalSize / 1GB, 2) } else { 0 }
            $freeGB = if ($freeSpace -gt 0) { [math]::Round($freeSpace / 1GB, 2) } else { 0 }
            $usedGB = $totalGB - $freeGB
            $percentFree = if ($totalGB -gt 0) { [math]::Round(($freeGB / $totalGB) * 100, 1) } else { 0 }

             if ($totalGB -gt 0.1) { # Ignore very small volumes
                $volumeInfo += "    Drive $($volume.DriveLetter): `"$($volume.FileSystemLabel)`" ($($volume.FileSystem))"
                $volumeInfo += "      Total: $totalGB GB | Used: $usedGB GB | Free: $freeGB GB ($percentFree % free)"

                if (($freeGB -lt 15 -and $totalGB -gt 20) -or ($percentFree -lt 10 -and $totalGB -gt 1)) {
                     $volumeInfo += "      >> WARNING: Low free space remaining!"
                }
             }
        }
         Write-Log $volumeInfo
    } else {
        Write-Log "`n  No volumes with drive letters found."
    }
} catch {
    Write-Log "Error collecting storage information: $($_.Exception.Message)"
}
Write-Log ""

# --- [ NETWORK ] ---
Write-SectionHeader "Network"
try {
    $netAdapters = Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq "Up" }
    $netInfo = @()

    if ($netAdapters) {
        $ipConfigurations = Get-NetIPConfiguration -ErrorAction SilentlyContinue

        foreach ($adapter in $netAdapters) {
            $netInfo += "`n  Adapter: $(Get-SafeProperty $adapter 'Name') ($($adapter.InterfaceDescription))"
            $netInfo += "    Status: $(Get-SafeProperty $adapter 'Status')"
            $netInfo += "    MAC Address: $(Get-SafeProperty $adapter 'MacAddress')"
            $netInfo += "    Speed: $($adapter.LinkSpeed)"

            $ipConfig = $ipConfigurations | Where-Object { $_.InterfaceIndex -eq $adapter.InterfaceIndex } | Select-Object -First 1

            if ($ipConfig) {
                $ipv4Addresses = $ipConfig.IPv4Address | Where-Object { $_.Address -notmatch "^169\.254\."}
                $ipv6Addresses = $ipConfig.IPv6Address | Where-Object { $_.Address -notmatch "^fe80::"}
                $ipv4Gateway = $ipConfig.IPv4DefaultGateway.NextHop

                if ($ipv4Addresses) {
                    foreach ($ip in $ipv4Addresses) { $netInfo += "    IPv4: $($ip.Address) / $($ip.PrefixLength)" }
                    if($ipv4Gateway){ $netInfo += "      Gateway: $ipv4Gateway" }
                }
                if ($ipv6Addresses) {
                    foreach ($ip in $ipv6Addresses) { $netInfo += "    IPv6: $($ip.Address) / $($ip.PrefixLength)" }
                }
            }
        }
    } else {
        $netInfo += "No active network adapters found."
    }
    Write-Log $netInfo

} catch {
    Write-Log "Error collecting network information: $($_.Exception.Message)"
}
Write-Log ""

# --- [ INSTALLED SOFTWARE (NON-MICROSOFT) ] ---
Write-SectionHeader "Installed Software (Non-Microsoft)"
try {
    $softwareKeys = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $installedSoftware = @()
    foreach ($keyPath in $softwareKeys) {
        $installedSoftware += Get-ItemProperty $keyPath -ErrorAction SilentlyContinue |
            Where-Object { $_.PSObject.Properties['DisplayName'] -ne $null -and
                           $_.DisplayName -notmatch '^(Microsoft|Update for|Security Update|Hotfix for|\(KB\d+\))' -and
                           $_.PSObject.Properties['SystemComponent'] -ne $null -and $_.SystemComponent -ne 1 -and
                           $_.PSObject.Properties['ParentKeyName'] -eq $null } | # Avoid patches listed under main apps
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
    }

    # Select unique based on DisplayName and Publisher to avoid duplicates from 32/64bit keys sometimes
    $uniqueSoftware = $installedSoftware | Sort-Object DisplayName, Publisher -Unique

    if ($uniqueSoftware) {
        $softwareList = @()
        # Sort final list by DisplayName
        foreach ($app in ($uniqueSoftware | Sort-Object DisplayName)) {
             $softwareList += "  - $(Get-SafeProperty $app 'DisplayName')"
             $details = @()
             $version = Get-SafeProperty $app 'DisplayVersion'
             $publisher = Get-SafeProperty $app 'Publisher'
             $installDate = Get-SafeProperty $app 'InstallDate'

             if ($version -ne 'Not Found') { $details += "Version: $version" }
             if ($publisher -ne 'Not Found') { $details += "Publisher: $publisher" }
             if ($installDate -ne 'Not Found') { $details += "Installed On: $installDate" }

             if ($details) {
                 $softwareList += "    ($($details -join ' | '))"
             }
        }
        Write-Log $softwareList
    } else {
        Write-Log "No non-Microsoft/non-update software detected in standard uninstall keys."
    }
} catch {
    Write-Log "Error listing installed software: $($_.Exception.Message)"
}
Write-Log ""


# --- [ SYSTEM PRODUCT (MANUFACTURER/MODEL) ] ---
Write-SectionHeader "System Product (Manufacturer/Model)"
try {
    $csProduct = Get-CimInstance -ClassName Win32_ComputerSystemProduct -Property Name, Vendor, IdentifyingNumber, UUID -ErrorAction Stop
    $biosInfoForSerial = Get-CimInstance -ClassName Win32_BIOS -Property SerialNumber -ErrorAction SilentlyContinue

    $productInfo = @(
        "Manufacturer: $(Get-SafeProperty $csProduct 'Vendor')"
        "Model: $(Get-SafeProperty $csProduct 'Name')"
    )

    $vendor = Get-SafeProperty $csProduct 'Vendor'
    $identifyingNum = Get-SafeProperty $csProduct 'IdentifyingNumber'
    $biosSerial = Get-SafeProperty $biosInfoForSerial 'SerialNumber'

    if ($vendor -match "Dell") {
        $productInfo += "Dell Service Tag: $biosSerial"
        if ($identifyingNum -ne 'Not Found') { $productInfo += "Identifying Number (Express Code): $identifyingNum" }
    } else {
        if ($identifyingNum -ne 'Not Found') {
            $productInfo += "Serial/Identifying Number: $identifyingNum"
        } elseif ($biosSerial -ne 'Not Found') {
             # Fallback to BIOS serial if IdentifyingNumber is missing for non-Dell
             $productInfo += "Serial Number (BIOS): $biosSerial"
        } else {
             $productInfo += "Serial/Identifying Number: Not Found"
        }
    }

    $productInfo += "UUID (Device ID): $(Get-SafeProperty $csProduct 'UUID')"

    Write-Log $productInfo
} catch {
    Write-Log "Error collecting system product information: $($_.Exception.Message)"
}
Write-Log ""

# --- [ BIOS & FIRMWARE ] ---
Write-SectionHeader "BIOS & Firmware"
try {
    $bios = Get-CimInstance -ClassName Win32_BIOS -Property SMBIOSBIOSVersion, Manufacturer, ReleaseDate -ErrorAction Stop
    $enclosure = Get-CimInstance -ClassName Win32_SystemEnclosure -Property ChassisTypes -ErrorAction SilentlyContinue

    $firmwareInfo = @(
        "BIOS Manufacturer: $(Get-SafeProperty $bios 'Manufacturer')"
        "BIOS Version: $(Get-SafeProperty $bios 'SMBIOSBIOSVersion')"
        "BIOS Release Date: $(Convert-WmiDate (Get-SafeProperty $bios 'ReleaseDate'))"
    )

    if ($enclosure -and $enclosure.ChassisTypes) {
        # Handle potential array or single value for ChassisTypes
        $chassisTypeValue = $enclosure.ChassisTypes | Select-Object -First 1
        $chassisTypeDescription = switch ($chassisTypeValue) {
            1 {"Other"} 2 {"Unknown"} 3 {"Desktop"} 4 {"Low Profile Desktop"} 5 {"Pizza Box"}
            6 {"Mini Tower"} 7 {"Tower"} 8 {"Portable"} 9 {"Laptop"} 10 {"Notebook"}
            11 {"Hand Held"} 12 {"Docking Station"} 13 {"All in One"} 14 {"Sub Notebook"}
            15 {"Space-Saving"} 16 {"Lunch Box"} 17 {"Main System Chassis"} 18 {"Expansion Chassis"}
            19 {"SubChassis"} 20 {"Bus Expansion Chassis"} 21 {"Peripheral Chassis"} 22 {"RAID Chassis"}
            23 {"Rack Mount Chassis"} 24 {"Sealed-Case PC"} 30 {"Tablet"} 31 {"Convertible"} 32 {"Detachable"}
            default { "Unknown ($chassisTypeValue)" }
        }
        $firmwareInfo += "Chassis Type: $chassisTypeDescription"
    } else {
        $firmwareInfo += "Chassis Type: Not Available"
    }

    Write-Log $firmwareInfo
} catch {
    Write-Log "Error collecting BIOS/Firmware information: $($_.Exception.Message)"
}
Write-Log ""

# --- [ MONITORS ] ---
Write-SectionHeader "Monitors"
try {
    function Decode-MonitorString {
        param($ByteArray)
        if ($ByteArray -and ($ByteArray -is [array]) -and $ByteArray.Count -gt 0) {
            return ([System.Text.Encoding]::Default.GetString($ByteArray).Trim([char]0))
        } else { return $null }
    }

    $monitors = Get-WmiObject -Namespace root\wmi -Class WmiMonitorID -ErrorAction SilentlyContinue
    $videoControllers = Get-CimInstance -ClassName Win32_VideoController -Property CurrentHorizontalResolution, CurrentVerticalResolution -ErrorAction SilentlyContinue

    if ($monitors) {
        $monitorInfo = @()
        $monitorIndex = 0
        foreach ($monitor in $monitors) {
            $manufacturer = Decode-MonitorString $monitor.ManufacturerName
            $name = Decode-MonitorString $monitor.UserFriendlyName
            $serial = Decode-MonitorString $monitor.SerialNumberID

            $resolution = "Resolution Unavailable"
            # Try matching based on InstanceName if possible (more reliable than index, but complex)
            # Basic index fallback:
            if ($videoControllers -and $monitorIndex -lt $videoControllers.Count) {
                 $resH = $videoControllers[$monitorIndex].CurrentHorizontalResolution
                 $resV = $videoControllers[$monitorIndex].CurrentVerticalResolution
                 if ($resH -and $resV) { $resolution = "$($resH) x $($resV)" }
            }

            $monitorInfo += "`n  Monitor $(if ($name){$name} else {'#' + ($monitorIndex+1)})"
            $monitorInfo += "    Manufacturer: $(if ($manufacturer) {$manufacturer} else {'Not Found'})"
            $monitorInfo += "    Serial Number: $(if ($serial) {$serial} else {'Not Found'})"
            $monitorInfo += "    Resolution (Detected*): $resolution"
            $monitorIndex++
        }
        $monitorInfo += "`n    *Resolution based on index matching with Win32_VideoController, may not be accurate."
        Write-Log $monitorInfo

    } else {
        Write-Log "No monitors found via WmiMonitorID."
    }
} catch {
    Write-Log "Error collecting monitor information: $($_.Exception.Message)"
}
Write-Log ""

# --- [ WINDOWS UPDATES (LAST 10) ] ---
Write-SectionHeader "Windows Updates (Last 10)"
try {
    $updateSession = New-Object -ComObject Microsoft.Update.Session -ErrorAction Stop
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    $historyCount = $updateSearcher.GetTotalHistoryCount()

    if ($historyCount -gt 0) {
        $numUpdates = [Math]::Min(10, $historyCount)
        $updates = $updateSearcher.QueryHistory($historyCount - $numUpdates, $numUpdates) | Sort-Object -Property Date -Descending

        $updateList = @()
        foreach ($update in $updates) {
             $title = Get-SafeProperty $update 'Title' 'Unknown Title'
             $kbArticles = ($update.KBArticleIDs | Where-Object {$_}) -join ', '
             $updateDateObj = Get-SafeProperty $update 'Date'
             $updateDate = if ($updateDateObj -is [datetime]) {$updateDateObj.ToString("yyyy-MM-dd HH:mm:ss")} else {"Invalid Date"}

             $category = if ($title -match 'Quality|Cumulative') { "Quality" }
                         elseif ($title -match 'Driver') { "Driver" }
                         elseif ($title -match 'Definition|Antivirus') { "Definition (Security)" }
                         elseif ($title -match 'Feature') { "Feature" }
                         else { "Other" }

            $updateList += "  - [$($updateDate)] [$category] $title"
            if ($kbArticles) { $updateList += "      KB Article(s): $kbArticles" }
        }
         Write-Log $updateList
    } else {
        Write-Log "No update history found."
    }
} catch {
    Write-Log "Error fetching Windows Update history: $($_.Exception.Message)"
}
Write-Log ""

# --- [ ACTIVE DIRECTORY ] ---
Write-SectionHeader "Active Directory"
if (Get-Module -Name ActiveDirectory -ListAvailable) {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop -WarningAction SilentlyContinue
        # Get only needed properties
        $adComputer = Get-ADComputer $env:COMPUTERNAME -Properties DistinguishedName, OperatingSystem, LastLogonDate, Enabled, IPv4Address, DNSHostName, SamAccountName -ErrorAction Stop

        $adInfo = @(
            "Domain Joined: Yes"
            "DNS Name: $(Get-SafeProperty $adComputer 'DNSHostName')"
            "SAM Account Name: $(Get-SafeProperty $adComputer 'SamAccountName')"
            "DistinguishedName: $(Get-SafeProperty $adComputer 'DistinguishedName')"
            "Operating System (from AD): $(Get-SafeProperty $adComputer 'OperatingSystem')"
            "Last Logon (from AD): $(if($adComputer.LastLogonDate){($adComputer.LastLogonDate).ToString('yyyy-MM-dd HH:mm:ss')} else {'Not Recorded'})"
            "Account Status (in AD): $(if($adComputer.Enabled){'Enabled'}else{'Disabled'})"
            "IPv4 (Registered in AD): $(Get-SafeProperty $adComputer 'IPv4Address')"
        )
        Write-Log $adInfo
    } catch {
        Write-Log "Error collecting Active Directory information: $($_.Exception.Message)"
        Write-Log "(Verify domain join and AD module functionality)"
    }
} else {
    Write-Log "ActiveDirectory module (RSAT) not installed or computer not domain-joined."
}
Write-Log ""

# --- [ GRAPHIC CARD (GPU) ] ---
Write-SectionHeader "Graphic Card (GPU)"
try {
    $gpus = Get-CimInstance Win32_VideoController -Property Name, DriverVersion, DriverDate, VideoProcessor, AdapterRAM, CurrentHorizontalResolution, CurrentVerticalResolution, Status -ErrorAction Stop
    if ($gpus) {
        $gpuInfo = @()
        $gpuIndex = 1
        foreach ($gpu in $gpus) {
             $adapterRam = Get-SafeProperty $gpu 'AdapterRAM' 0
             $ramMB = if ($adapterRam -gt 0) { [math]::Round($adapterRam / 1MB) } else { 'N/A' }
             $gpuInfo += "`n  GPU $($gpuIndex): $(Get-SafeProperty $gpu 'Name')"
             $gpuInfo += "    Driver Version: $(Get-SafeProperty $gpu 'DriverVersion')"
             $gpuInfo += "    Driver Date: $(Convert-WmiDate (Get-SafeProperty $gpu 'DriverDate'))"
             $gpuInfo += "    Video Processor: $(Get-SafeProperty $gpu 'VideoProcessor')"
             $gpuInfo += "    Adapter RAM: $ramMB MB"
             $gpuInfo += "    Current Resolution: $(Get-SafeProperty $gpu 'CurrentHorizontalResolution') x $(Get-SafeProperty $gpu 'CurrentVerticalResolution')"
             $gpuInfo += "    Status: $(Get-SafeProperty $gpu 'Status')"
             $gpuIndex++
        }
        Write-Log $gpuInfo
    } else {
        Write-Log "No graphic cards found via Win32_VideoController."
    }
} catch {
    Write-Log "Error collecting graphic card information: $($_.Exception.Message)"
}
Write-Log ""

# --- [ FIREWALL STATUS ] ---
Write-SectionHeader "Firewall Status"
try {
    $fwProfiles = Get-NetFirewallProfile -Name Domain, Public, Private -ErrorAction Stop
    $fwInfo = @()
    foreach ($profile in $fwProfiles) {
        $status = if ($profile.Enabled) { "Enabled (Active)" } else { "Disabled (Inactive)" }
        $fwInfo += "  Profile $($profile.Name): $status"
    }
    Write-Log $fwInfo
} catch {
     try { # Fallback to legacy COM
         $legacyFw = New-Object -ComObject HNetCfg.FwMgr
         $currentProfile = $legacyFw.LocalPolicy.CurrentProfile
         $legacyStatus = if ($currentProfile.FirewallEnabled) { "Enabled (Active)" } else { "Disabled (Inactive)" }
         Write-Log "  Status (Legacy COM Method): $legacyStatus"
     } catch {
         Write-Log "Error fetching firewall status (both methods failed): $($_.Exception.Message)"
     }
}
Write-Log ""

# --- [ ANTIVIRUS STATUS ] ---
Write-SectionHeader "Antivirus Status"
try {
    $avList = Get-CimInstance -Namespace "root\SecurityCenter2" -ClassName AntiVirusProduct -ErrorAction SilentlyContinue
    $avInfo = @()

    if ($avList) {
        foreach ($av in $avList) {
            $avName = Get-SafeProperty $av 'displayName'
            $stateHex = ($av.productState -band 0xFFF0).ToString('X4')
            $stateDesc = switch ($stateHex) {
                "1000" { "Active and Updated" }
                "1100" { "Active (Snoozed/Silent Mode)" }
                "0100" { "Inactive" }
                default { "State Unknown ($($av.productState))" }
            }
            $isEnabled = ($av.productState -band 0x0010) -ne 0

            $avInfo += "  - Antivirus: $avName"
            $avInfo += "      Registered Status: $stateDesc"
            $avInfo += "      Is Enabled (Bit Check): $($isEnabled)"
        }
    } else {
        $defenderService = Get-Service -Name "WinDefend" -ErrorAction SilentlyContinue
        if ($defenderService) {
             $avInfo += "  - Antivirus: Windows Defender (via Service)"
             $avInfo += "      Service Status: $($defenderService.Status)"
        } else {
            $avInfo += "No antivirus products found via WMI/SecurityCenter2 and WinDefend service not detected."
        }
    }
    Write-Log $avInfo
} catch {
    Write-Log "Error fetching antivirus status: $($_.Exception.Message)"
}
Write-Log ""

# --- [ WINDOWS ACTIVATION STATUS ] ---
Write-SectionHeader "Windows Activation Status"
try {
    $licensingProduct = Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL" | Select-Object -First 1 -ErrorAction SilentlyContinue
    $licensingService = Get-CimInstance SoftwareLicensingService -ErrorAction SilentlyContinue

    $activationInfo = @()

    if ($licensingProduct) {
        $statusDesc = switch ($licensingProduct.LicenseStatus) {
            0 { "Unlicensed" }
            1 { "Licensed (Activated)" }
            2 { "Initial Grace Period (OOB Grace)" }
            3 { "Additional Grace Period (Non-Genuine Grace)" }
            4 { "Notification (Non-Genuine)" }
            5 { "Extended Grace Period" }
            default { "Unknown Status Code ($($licensingProduct.LicenseStatus))" }
        }
         $activationInfo += "  License Status: $statusDesc"
         $activationInfo += "  Partial Product Key: $(Get-SafeProperty $licensingProduct 'PartialProductKey')"
         $activationInfo += "  Application ID: $(Get-SafeProperty $licensingProduct 'ApplicationID')"
         if ($licensingService) {
            $activationInfo += "  Description (Service): $(Get-SafeProperty $licensingService 'Description')"
            $kmsHost = Get-SafeProperty $licensingService 'KeyManagementServiceHost'
            if ($kmsHost -ne "Not Found" -and $kmsHost) {
               $activationInfo += "  KMS Host: $($kmsHost):$(Get-SafeProperty $licensingService 'KeyManagementServicePort')"
            }
            $oemKeyDescription = Get-SafeProperty $licensingService 'OA3xOriginalProductKeyDescription'
            if ($oemKeyDescription -ne "Not Found" -and $oemKeyDescription) {
                 $activationInfo += "  OEM Key Info: $oemKeyDescription"
            }
         }
         if(Get-SafeProperty $licensingProduct 'IsKeyManagementServiceLicense') {
             $activationInfo += "  License Type: KMS Volume License"
         }

    } else {
        $activationInfo += "Could not determine activation status via WMI/SoftwareLicensingProduct."
    }
    Write-Log $activationInfo

} catch {
     Write-Log "Error checking Windows activation status: $($_.Exception.Message)"
}
Write-Log ""

# --- Footer ---
Write-Log @"

=================================================
            END OF INVENTORY REPORT
=================================================
"@

#endregion Inventory Script Logic
