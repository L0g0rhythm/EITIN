# IT Inventory with Privilege Elevation

This repository contains a PowerShell script (.ps1) that automates the collection of detailed system information for IT inventory purposes. The goal is to facilitate asset management, ensuring the report is generated with elevated privileges.

---

## 📋 Overview

The PowerShell script collects system data, including:

*   **Windows Specifications:** Name, version, build, installation date, and last boot time;
*   **Hardware Information:** CPU, RAM, disks, and device type (Desktop or Laptop);
*   **Network:** Status of active network adapters, MAC addresses (differentiating Wi-Fi and Ethernet interfaces), and primary IP;
*   **Software and Updates:** List of installed software (excluding Microsoft products) and history of the last 10 Windows updates, categorized as quality updates, drivers, definitions, and others;
*   **Others:** Information about BIOS, firmware, monitors, and Active Directory data when available;
*   **Graphics Card:** Information about the installed graphics card.
*   **Firewall Status:** Checks the firewall status.
*   **Antivirus:** Checks the status of Windows Defender and other installed antivirus software.

---

## 🚀 How to Use

1.  **Prerequisites:**
    *   Windows 8 or later (including Windows Server 2012 or newer).
    *   PowerShell enabled.
    *   Administrative permissions to run the script.
    *   PowerShell execution policy configured to allow the use of the `-ExecutionPolicy Bypass` parameter. (It is recommended to adjust the policy to a more secure level after execution, if necessary.)

2.  **Steps:**
    *   Clone the repository or download the `Get-SystemInfo.ps1` file directly.
    *   Run the PowerShell script (`Get-SystemInfo.ps1`) with elevated privileges (Run as Administrator). You can do this by right-clicking the file and selecting "Run as administrator".
    *   **Report Generation:** The report will be automatically created and saved on the current user's Desktop in the following format:
        ```
        Inventory_ddMMyyyy_HHmmss.txt
        ```
        **Example:**
        ```
        C:\Users\YourUser\Desktop\Inventory_04022025_153045.txt
        ```

---

## 📂 Report Contents

The generated report includes the following sections:

*   **Header:** Title with date/time of generation.
*   **[IDENTIFICATION]:** Computer name and list of active users (excluding default and disabled accounts). Includes the user who executed the script.
*   **[OPERATING SYSTEM]:** System name, version, and architecture.
*   **[WINDOWS SPECIFICATIONS]:** Windows details (product, edition, version, build, installation date, and last boot).
*   **[DEVICE TYPE]:** Identifies whether the device is a Desktop or Laptop.
*   **[PROCESSOR]:** Model, number of cores, and maximum speed.
*   **[RAM MEMORY]:** List of installed modules with details (manufacturer, capacity, speed, and type).
*   **[STORAGE]:** Information about physical disks (type, serial) and volume space report.
*   **[NETWORK]:** Detailed information about active network adapters, separating Wi-Fi and Ethernet, plus the primary IP and a list of all active adapters.
*   **[INSTALLED SOFTWARE]:** List of installed applications (excluding Microsoft products).
*   **[MAC]:** Product information (Model, Manufacturer, UUID, Product ID, and Service Tag for Dell systems).
*   **[BIOS & FIRMWARE]:** BIOS versions, release date, and chassis information.
*   **[MONITORS]:** Data of connected monitors via WMI.
*   **[WINDOWS UPDATES]:** History of the last 10 installed updates, categorized.
*   **[ACTIVE DIRECTORY]:** If available, collects the computer's DistinguishedName in AD.
*   **[GRAPHICS CARD]:** Information about the graphics card.
*   **[FIREWALL STATUS]:** Firewall status for Domain, Public, and Private profiles.
*   **[ANTIVIRUS]:** Status of Windows Defender and other installed antivirus software.

---

## ⚠️ Requirements

*   **Operating System:** Windows 8 or later (including Windows Server 2012 or newer).
*   **PowerShell:** Version 5.1 or later (recommended).
*   **Administrative Permissions:** Required to access all system information.

---

## 🔐 Security

This script was developed for legitimate use in corporate and personal IT environments. It is crucial to run the script in a controlled environment and understand the information being collected. Adjust PowerShell execution permissions according to your organization's security policies.

---

## ☕ Contributions

Pull requests are welcome! Feel free to contribute with improvements, bug fixes, or new features.
