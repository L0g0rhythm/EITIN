# IT Inventory with Privilege Elevation

This repository contains a PowerShell script (.ps1) and a Batch file (.bat) that, together, automate the collection of detailed system information for IT inventory purposes. The goal is to facilitate asset management, ensuring the report is generated with elevated privileges and output in Brazilian Portuguese.

---

## 📋 Overview

- **PowerShell Script (run_as_admin.ps1):**  
  Collects system data, including:  
  - **Windows Specifications:** Name, version, build, installation date, and last boot time;  
  - **Hardware Information:** CPU, RAM, disks, and device type (Desktop or Laptop);  
  - **Network:** Status of active network adapters, MAC addresses (differentiating Wi-Fi and Ethernet interfaces), and primary IP;  
  - **Software and Updates:** List of installed software (excluding Microsoft products) and history of the last 10 Windows updates, categorized as quality updates, drivers, definitions, and others;  
  - **Others:** Information about BIOS, firmware, monitors, and Active Directory data when available.  

- **Batch File (run_as_admin.bat):**  
  Acts as a launcher to start the PowerShell script with elevated privileges (Run as Administrator), ensuring full access to system information.

---

## 🚀 How to Use

1. **Prerequisites:**  
   - Windows 8 or later (including Windows Server 2012 or newer). with PowerShell enabled.
   - Administrative permissions to run the scripts.  
   - Execution policy configured to allow the use of the Bypass parameter.
 

2. **Steps:**  
   - Clone the repository or download the files:  
     ```
     git clone https://github.com/your-username/your-repository.git
     ```  
   - Run the Batch file (`run_as_admin.bat`) by double-clicking it.  
     This file will launch the PowerShell script with elevated privileges.  
   - **Report Generation:**  
     The report will be automatically created and saved on the current user's Desktop in the following format:  
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

- **Header:** Title with date/time of generation.  
- **[IDENTIFICATION]:** Computer name and list of active users (excluding default and disabled accounts).  
- **[OPERATING SYSTEM]:** System name, version, and architecture.  
- **[WINDOWS SPECIFICATIONS]:** Windows details (product, edition, build, installation date, and last boot).  
- **[DEVICE TYPE]:** Identifies whether the device is a Desktop or Laptop.  
- **[PROCESSOR]:** Model, number of cores, and maximum speed.  
- **[RAM MEMORY]:** List of installed modules with details (manufacturer, capacity, speed, and type).  
- **[STORAGE]:** Information about physical disks (type, serial) and volume space report.  
- **[NETWORK]:** Detailed information on active network adapters, separating Wi-Fi and Ethernet, plus the primary IP.  
- **[INSTALLED SOFTWARE]:** List of installed applications (excluding Microsoft products).  
- **[MAC]:** Product data (model, manufacturer, UUID, product ID, and Service Tag for Dell systems).  
- **[BIOS & FIRMWARE]:** BIOS versions, release date, and chassis information.  
- **[MONITORS]:** Data on monitors connected via WMI, with byte array decoding.  
- **[WINDOWS UPDATES]:** History of the last 10 installed updates, categorized as quality updates, drivers, definitions, or others.  
- **[ACTIVE DIRECTORY]:** If available, collects the computer's DistinguishedName in AD.
- **[GRAPHIC CARD]:** Information about the graphic card.
- **[FIREWALL STATUS]:** Firewall status check.

---

## ⚠️ Requirements

- **Operating System:** Windows 8 or later (including Windows Server 2012 or newer).  
- **PowerShell:** Version compatible with script execution and support for the -ExecutionPolicy Bypass parameter.  
- **Administrative Permissions:** Required to access all system information.
- **PowerShell Version:** Windows PowerShell 5.1 or later. 

---

## 🔐 Security

This project was developed for legitimate use in corporate and personal IT environments.
