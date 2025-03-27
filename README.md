# EITIN - Elevated IT Inventory

This repository contains a PowerShell script (`EITIN.ps1`) that automates the collection of detailed system information for IT inventory purposes. The goal is to streamline asset management by ensuring that the report is generated with elevated privileges, either via a launcher (`EITIN.bat`) or through self-elevation.


## Table of Contents

- [Features](#-features)
- [Requirements](#-Requirements)
- [Installation](#-installation)
- [Usage](#-usage)
- [Report Structure](#-report-structure)
- [Example Output](#-example-output)
- [Technologies](#-technologies)
- [License](#-license)
- [Project Status](#-project-status)
- [Security and Compliance](#-security-and-compliance)
- [Contributions](#-contributions)


## ✨ Features

The PowerShell script collects a comprehensive set of system data, including:

-   **System Identification**: Computer name, logged-in users, script execution context.
-   **Operating System**: OS details (Caption, Version, Architecture).
-   **Windows Specifications**: Product name, edition, build, installation date.
-   **Hardware Information**: Device type (Desktop/Laptop), CPU, RAM modules, Physical Disks (Type, Model, Serial, Size, Status, BusType), Volume space usage (with low space warning).
-   **Network**: Details of active network adapters (including MAC, Speed, IPv4/IPv6, Gateway), separated by type (Ethernet/Wi-Fi).
-   **Software**: List of installed applications (excluding Microsoft products/updates).
-   **System Product**: Manufacturer, Model, Serial Number/Service Tag (Dell specific), UUID.
-   **BIOS & Firmware**: Manufacturer, Version, Release Date, Chassis Type.
-   **Monitors**: Information on connected monitors (Manufacturer, Serial, Detected Resolution via WMI).
-   **Windows Updates**: History of the last 10 installed updates, categorized.
-   **Active Directory**: Computer's AD details (DN, DNS Name, OS, Last Logon, etc.), if domain-joined and module is available.
-   **Graphics Card (GPU)**: Details of installed GPUs (Name, Driver Version/Date, RAM, Resolution).
-   **Security Status**: Firewall status (Domain, Private, Public profiles) and Antivirus status (via WMI SecurityCenter2).
-   **Activation Status**: Windows license activation status (via WMI).


## ⚠️ Requirements

-   **Operating System**: Windows 7 or later (including Windows Server 2012 or later versions).
-   **PowerShell**: Version 3 or higher recommended (uses cmdlets like `Get-CimInstance`, `Get-NetAdapter`, `Get-PhysicalDisk`). PowerShell 5.1+ is ideal.
-   **Administrative Permissions**: Required to collect comprehensive system data (WMI/CIM queries, registry access, etc.). Execution without admin rights will attempt elevation (via UAC) or result in an incomplete report/failure.
-   **PowerShell Execution Policy**: The launchers (`EITIN.bat` or the self-elevation mechanism in `EITIN.ps1`) attempt to use `-ExecutionPolicy Bypass` for the execution instance. Ensure system policies do not completely block PowerShell execution. After running, consider setting a more secure default policy (e.g., `Set-ExecutionPolicy RemoteSigned`).
-   **Active Directory Module (Optional):** For collecting Active Directory data, the `ActiveDirectory` module (part of Remote Server Administration Tools - RSAT) must be installed and the machine must be domain-joined.


## 💾 Installation

1.  Clone the repository:
    ```bash
    git clone https://github.com/victorvernier/EITIN.git
    ```
2.  Or download the ZIP file directly from GitHub and extract it.


## 🚀 Usage

You can run the inventory collection using one of the following methods:

1.  **Using the Launcher (`EITIN.bat`) (Option 2 - Simple):**
    * Navigate to the script directory.
    * Run the `EITIN.bat` file (e.g., by double-clicking or typing `EITIN.bat` in `cmd.exe`).
    * It will silently request the necessary administrative privileges via UAC prompt.

2.  **Using PowerShell Directly (`EITIN.ps1`) (Option 1 - Recommended):**
    * Open PowerShell (a normal, non-admin window is fine).
    * Navigate to the script directory using `cd`:
        ```powershell
        cd C:\path\to\EITIN\script ## <-- Adjust path to your local folder
        ```
    * Execute the script:
        ```powershell
        .\EITIN.ps1
        ```
    * If run without admin rights, the script will attempt to self-elevate by triggering a UAC prompt.

**Report Generation**:

In both cases, if elevation is successful, the script will run silently and the report will be automatically generated and saved on the **current user's Desktop** with the filename format: ```COMPUTERNAME_Inventory.txt```

**Example**: 
```
C:\Users\YourUser\Desktop\WORKPC-LNV01_Inventory.txt
```

*(Note: If run via Task Scheduler as SYSTEM, the Desktop path might resolve differently. Consider modifying the `$outputDir` variable in `EITIN.ps1` for scheduled tasks if needed.)*


## 📂 Report Structure

The generated report (`COMPUTERNAME_Inventory.txt`) includes the following sections clearly marked:

-   Header (Title, Computer Name, Generation Date)
-   `[IDENTIFICATION]`
-   `[SYSTEM INFORMATION]`
-   `[EQUIPMENT TYPE]`
-   `[PROCESSOR]`
-   `[RAM MEMORY]`
-   `[STORAGE]` (Includes Physical Disks and Volume Space)
-   `[NETWORK]`
-   `[INSTALLED SOFTWARE]` (Non-Microsoft)
-   `[SYSTEM PRODUCT]` (Manufacturer/Model/Serial/UUID)
-   `[BIOS & FIRMWARE]`
-   `[MONITORS]`
-   `[WINDOWS UPDATES]` (Last 10)
-   `[ACTIVE DIRECTORY]`
-   `[GRAPHIC CARD (GPU)]`
-   `[FIREWALL STATUS]`
-   `[ANTIVIRUS STATUS]`
-   `[WINDOWS ACTIVATION STATUS]`
-   Footer


## 📝 Example Output

Example snippet from `COMPUTERNAME_Inventory.txt`:

```text
=================================================
        IT INVENTORY - YOUR_PC_NAME
=================================================
Report Generated On: 2025-03-26 21:45:10
(Executed with Administrator privileges)

--- [ IDENTIFICATION ] ---
Computer Name: YOUR_PC_NAME
Logged-in User(s) (Interactive): YOUR_DOMAIN\your_user
Script Executing User (Effective): YOUR_DOMAIN\your_user_or_SYSTEM
...

--- [ SYSTEM INFORMATION ] ---
Operating System: Windows 10 Enterprise (Microsoft Windows 10 Enterprise)
Edition: Enterprise
Version: 10.0.19045 (Build 19045)
Architecture: 64-bit
Install Date: 2024-01-20 11:55:30
...

--- [ RAM MEMORY ] ---

  Module 1:
    Manufacturer: Corsair
    Part Number: CMK16GX4M2B3200C16
    Serial Number: 0123456789ABCDEF0
    Capacity: 8 GB
    Speed: 3200 MHz
    Type: DDR4
...

--- [ STORAGE ] ---
  Physical Disks:

    Drive: NVMe Samsung SSD 970 EVO Plus 1TB
      Type: SSD NVMe
      Model: Samsung SSD 970 EVO Plus 1TB
      Serial: S4EWNF0N123456X
      Size: 931.51 GB
      Status: OK
      Bus Type: NVMe
...
  Space by Volume:
    Drive C: "Sistema" (NTFS)
      Total: 930.9 GB | Used: 250.2 GB | Free: 680.7 GB (73.1 % free)
...

--- [ NETWORK ] ---

  Adapter: Ethernet (Realtek Gaming GbE Family Controller)
    Status: Up
    MAC Address: B4-2E-99-AA-BB-CC
    Speed: 1.0 Gbps
    IPv4: 192.168.0.50 / 24
      Gateway: 192.168.0.1
...

--- [ INSTALLED SOFTWARE (NON-MICROSOFT) ] ---
  - Adobe Acrobat Reader DC - Portuguese
    (Version: 23.008.20470 | Publisher: Adobe | Installed On: 20240210)
  - Google Chrome
    (Version: 123.0.6312.86 | Publisher: Google LLC | Installed On: 20240820)
...

--- [ ANTIVIRUS STATUS ] ---
  - Antivirus: Microsoft Defender Antivirus
      Registered Status: Inactive
  - Antivirus: Kaspersky Standard
      Registered Status: Active and Updated
...

=================================================
            END OF INVENTORY REPORT
=================================================
```


## 🛠️ Technologies

* PowerShell: Core scripting language. Uses various built-in cmdlets and WMI/CIM objects.

* Batch Script (```.bat```): Optional launcher (```EITIN.bat```) for simplified execution with elevation request.


## ⚖️ License
This project is licensed under the MIT License - see the [LICENSE.md](https://github.com/victorvernier/EITIN/blob/main/LICENSE) file for details.


## 📊 Project Status

* Feature Complete


## 🔐 Security and Compliance
This script was developed for legitimate use in corporate and personal IT environments for asset management and inventory purposes. It should be run in a controlled environment, with a full understanding of the information being collected.

The collection of potentially sensitive data, such as hardware identifiers (serial numbers, UUIDs), user accounts, software lists, and network details, must be performed in accordance with your organization's information security guidelines and privacy policies (like GDPR, LGPD, CCPA, etc.).

### Recommendations for Compliance:

* **Legitimate Basis**: Ensure you have a valid legal basis (e.g., consent, legitimate interest for corporate asset management) for collecting this data.

* **Transparency**: Clearly inform users/asset owners about the data being collected, its purpose (IT inventory), and how it will be stored and protected.

* **Security**: Implement appropriate technical and organizational measures to protect the collected inventory data against unauthorized access, alteration, or disclosure. Control access to the generated reports.

* **Data Minimization**: Collect only the data necessary for the specific purpose of IT inventory and asset management. Review if all collected fields are strictly required.

* **Purpose Limitation**: Use the collected data only for the stated purpose of IT inventory.


## ☕ Contributions
Contributions, issues, and feature requests are welcome. Feel free to check the [issues page](https://github.com/victorvernier/EITIN/issues). If you'd like to contribute code, please fork the repository and submit a pull request.
