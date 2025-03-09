# EITIN - Elevated IT Inventory

This repository contains a PowerShell script (`run_as_admin.ps1`) that automates the collection of detailed system information for IT inventory purposes. The goal is to streamline asset management by ensuring that the report is generated with elevated privileges.

### 📋 Overview

The PowerShell script collects a comprehensive set of system data, including:

- **Windows Specifications**: Name, version, build, installation date, and last boot time.
- **Hardware Information**: CPU, RAM, disks, device type (Desktop or Laptop).
- **Network**: Status of active network adapters, MAC addresses (Wi-Fi and Ethernet interfaces), and main IP address.
- **Software and Updates**: List of installed software (excluding Microsoft products) and the history of the last 10 Windows updates, categorized into quality updates, drivers, definitions, and others.
- **Others**: Information about BIOS, firmware, monitors, and Active Directory data (if available).
- **Graphics Card**: Information about the installed graphics card.
- **Firewall Status**: Firewall status check.
- **Antivirus**: Windows Defender and other installed antivirus status.
- **Activation Status**: Checks if Windows is activated.

### 🚀 How to Use

**Prerequisites**:

- **Operating System**: Windows 7 or later (including Windows Server 2012 or later versions).
- **PowerShell**: Version 2 or higher (recommended).
- **Administrative Permissions**: Required to run the script (in case of failure).
- **PowerShell Execution Policy**: Ensure the execution policy allows the use of `-ExecutionPolicy Bypass`. After running, it is recommended to adjust the policy to a more secure level.  (e.g., `Set-ExecutionPolicy RemoteSigned`)

**Steps**:

1. Clone the repository or download the folder directly from GitHub.
2. Run the `run_as_admin.bat` file (elevated privileges are automatic). Alternatively, right-click on the script file and select **Run as Administrator**.
3. **Report Generation**: The report will be automatically generated and saved on the current user's desktop in the following format:

   `Inventory_ddMMyyyy_HHmmss.txt`

   Example:

   `C:\Users\YourUser\Desktop\Inventory_04022025_153045.txt`

### 📂 Report Content

The generated report will include the following sections:

- **Header**: Title with date and time of generation.
- **[IDENTIFICATION]**: Computer name and active users (excluding default and disabled accounts), along with the user who ran the script.
- **[OPERATING SYSTEM]**: System name, version, and architecture.
- **[WINDOWS SPECIFICATIONS]**: Windows details (product, edition, version, build, installation date, and last boot).
- **[DEVICE TYPE]**: Identifies if the device is a Desktop or Laptop.
- **[PROCESSOR]**: Model, number of cores, and maximum speed.
- **[RAM MEMORY]**: List of installed modules (manufacturer, capacity, speed, and type).
- **[STORAGE]**: Information about physical disks (type, serial number) and volume space report.
- **[NETWORK]**: Detailed information about active network adapters, separating Wi-Fi and Ethernet, including main IP and list of all active adapters.
- **[INSTALLED SOFTWARE]**: List of installed applications (excluding Microsoft products).
- **[MAC]**: Product information for Dell systems (Model, Manufacturer, UUID, Product ID, and Service Tag).
- **[BIOS & FIRMWARE]**: BIOS versions, release date, and chassis information.
- **[MONITORS]**: Data on connected monitors (via WMI).
- **[WINDOWS UPDATES]**: History of the last 10 installed updates, categorized by type.
- **[ACTIVE DIRECTORY]**: DistinguishedName from Active Directory (if available).
- **[GRAPHICS CARD]**: Information about the installed graphics card.
- **[FIREWALL STATUS]**: Firewall status for Domain, Public, and Private profiles.
- **[ANTIVIRUS]**: Status of Windows Defender and other installed antivirus software.
- **[ACTIVATION STATUS]**: Information about Windows activation.

### ⚠️ Requirements

- **Operating System**: Windows 7 or later (including Windows Server 2012 or later versions).
- **PowerShell**: Version 2 or higher (recommended).
- **Administrative Permissions**: Required to access all system information (in case of failure).

### 🔐 Security and Compliance with LGPD

This script was developed for legitimate use in corporate and personal IT environments. It should be run in a controlled environment, with a full understanding of the information being collected. The collection of sensitive data, such as Windows activation keys and hardware information, must be performed in accordance with your organization's information security guidelines and privacy policies, ensuring compliance with the General Data Protection Law (LGPD).

**Recommendations for LGPD Compliance**:

- **Consent**: Ensure that proper consent is obtained before collecting personal or sensitive information.
- **Transparency**: Clearly inform users about the data being collected and how it will be used.
- **Security**: Implement appropriate measures to protect the collected data during the collection and storage process.
- **Data Minimization**: Collect only the data necessary for the specific purposes of the inventory.

### ☕ Contributions

Pull requests are welcome! Feel free to contribute with improvements, bug fixes, or new features.
