# EITIN - Professional IT Inventory by L0g0rhythm

**Project Version: 5.0**

## Table of Contents

- [Overview](#-overview)
- [✨ Key Features](#-key-features)
- [📂 Project Structure](#-project-structure)
- [⚠️ Requirements](#️-requirements)
- [🚀 Usage](#-usage)
- [📊 Generated Reports](#-generated-reports)
- [🔐 Security and Compliance](#-security-and-compliance)
- [⚖️ License](#️-license)
- [📞 Contact](#-contact)

---

## 🌎 Overview

**EITIN (Elevated IT Inventory)** is a PowerShell automation suite designed to perform a comprehensive, professional-grade IT inventory. Originally a monolithic script, the project has been completely refactored into a modular, robust, and highly extensible architecture.

Its main goal is to provide detailed, accurate, and visually elegant reports in multiple formats (Interactive HTML, Print/PDF-Optimized HTML, and CSV), ensuring portability and ease of use in diverse IT environments. The tool is self-sufficient and designed to run with minimal dependencies, featuring a self-elevation mechanism to ensure complete data collection.

## ✨ Key Features

### Architecture and Execution

- **Complete Modularization:** The project is divided into `Core` (central functions), `Modules` (data collection scripts), `Config` (execution control), and `Assets` (style resources), ensuring high maintainability.
- **Control via `config.json`:** Allows enabling or disabling the collection of specific inventory sections without changing a single line of code, offering maximum flexibility.
- **Self-Elevation of Privileges:** The main script detects if it is being run as an Administrator and, if not, requests elevation via UAC to ensure complete data collection.
- **Full Portability:** Designed to be run from any location, such as a flash drive, without requiring installation.
- **Assured Compatibility:** Standardized encoding (`UTF-8 with BOM` for `.ps1`, `ANSI` for `.bat`) to ensure correct display of characters in PowerShell 5.1 and higher.

### Multi-Format Report Generation

- **Premium Interactive HTML Report:**
  - **"Liquid Glass" Visual:** A modern, translucent design that simulates floating glass panels.
  - **Intelligent Navigation:** Sidebar with smooth scrolling, highlighting of the active section, and elegant animations.
  - **Robust and Responsive Layout:** The layout adapts to different screen sizes without breaking or visual "jumps".
  - **Scrollable Containers:** Sections with a large amount of data (like Installed Software, Updates, and Network) have elegant, internally scrolling boxes to avoid cluttering the view.
  - **Self-Sufficient File:** The generated HTML contains all the necessary CSS and JavaScript embedded, making it 100% portable.
- **PDF-Optimized HTML Report:**
  - A second HTML file is generated with a clean, vertical "flat" design, optimized for the A4 format.
  - Ideal for use with the browser's "Print > Save as PDF" function, generating a professional and perfectly formatted document.
- **Complete CSV Reports:**
  - Generates a `.csv` file for **each section** of the inventory.
  - Tabular data is exported directly, and simple key-value data is transformed into two-column tables, ensuring **no information is lost** and facilitating analysis in spreadsheets.
- **Traditional TXT Report:**
  - Maintains the generation of a simple text report with consistent and highly readable formatting, ideal for quick viewing in terminals.
- **Organized Naming Convention:** All reports are saved in a `Logs/COMPUTER_NAME/USER_NAME/` folder structure with standardized file names for easy identification.

### Comprehensive Data Collection

- **Identification:** Computer name, logged-in users, etc.
- **Operating System:** Edition, version, build, installation date.
- **Hardware:** Equipment type, Processor (CPU), RAM (per module), Graphics Cards (GPU), Storage (Physical Disks and Volumes), Monitors, and Peripherals.
- **Network:** Details of all active network adapters, including IP addresses, MAC, and speed.
- **Software:** Third-party installed software, Microsoft Office licenses, and Windows activation status.
- **Security:** Firewall status, Antivirus status, and a security compliance summary (BitLocker, UAC, etc.).
- **Updates:** History of the last 15 installed Windows updates.

## 📂 Project Structure

```
EITIN/
├── Core/
│   ├── CsvReportGenerator.ps1
│   ├── HtmlReportGenerator.ps1
│   ├── Logger.ps1
│   ├── TxtReportGenerator.ps1
│   ├── UIEnhancements.ps1
│   └── Utils.ps1
├── Modules/
│   ├── Get-Identification.ps1
│   └── (other .ps1 collection modules...)
├── Config/
│   └── config.json
├── Assets/
│   ├── style.css
│   └── print-style.css
├── Logs/
│   └── (generated reports are saved here)
├── EITIN.ps1        # Main orchestrator script
├── EITIN.bat        # Simplified launcher
└── README.md        # This file
```

## ⚠️ Requirements

- **Operating System:** Windows 10 or higher (including Windows Server 2016 or higher).
- **PowerShell:** Version 5.1 or higher.
- **Administrative Permissions:** Essential for complete data collection.

## 🚀 Usage

The simplest and recommended way to run the tool:

1.  Navigate to the `EITIN` folder.
2.  Double-click the **`EITIN.bat`** file.
3.  A UAC (User Account Control) prompt will appear requesting elevation. **Accept** it to continue.
4.  A PowerShell window will open, and the inventory collection will begin.
5.  Upon completion, the console will display the paths to all generated reports.

## 📊 Generated Reports

All reports are saved in the `Logs\[COMPUTER_NAME]\[USER_NAME]\` folder.

- **`[COMPUTER_NAME]_[USER_NAME].txt`**: Plain text report.
- **`[COMPUTER_NAME]_[USER_NAME]_Interactive.html`**: Interactive report with the "Liquid Glass" design.
- **`[COMPUTER_NAME]_[USER_NAME]_Printable.html`**: Report optimized for printing and PDF conversion.
- **`CSV_Reports/` folder**: Contains a `.csv` file for each inventory section.

## 🔐 Security and Compliance

This script is intended for legitimate use in IT environments for asset management purposes. Data collection must be performed in accordance with your organization's security and privacy policies (e.g., GDPR, LGPD). Use responsibly.

## ⚖️ License

This project is licensed under the MIT License - see the `LICENSE.md` file for details.

## 📞 Contact

Developed by **L0g0rhythm** - [https://www.l0g0rhythm.com.br/](https://www.l0g0rhythm.com.br/)
