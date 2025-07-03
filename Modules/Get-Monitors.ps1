function Invoke-EitinMonitorsInfo {
    [CmdletBinding()]
    param()

    process {
        #region Win32 API C# Helper
        $csharpCode = @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Management.Automation;

namespace Win32
{
    public static class DisplayConfig
    {
        // All structs and enums must be defined BEFORE they are used in DllImport signatures.

        #region Structs
        [StructLayout(LayoutKind.Sequential)]
        public struct POINTL { public int x; public int y; }

        [StructLayout(LayoutKind.Sequential)]
        public struct DISPLAYCONFIG_RATIONAL { public uint Numerator; public uint Denominator; }

        [StructLayout(LayoutKind.Sequential)]
        public struct DISPLAYCONFIG_PATH_SOURCE_INFO {
            public uint adapterId_low;
            public uint adapterId_high;
            public uint id;
            public uint modeInfoIdx;
            public uint statusFlags;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct DISPLAYCONFIG_PATH_TARGET_INFO {
            public uint adapterId_low;
            public uint adapterId_high;
            public uint id;
            public uint modeInfoIdx;
            public DISPLAYCONFIG_VIDEO_OUTPUT_TECHNOLOGY outputTechnology;
            public DISPLAYCONFIG_ROTATION rotation;
            public DISPLAYCONFIG_SCALING scaling;
            public DISPLAYCONFIG_RATIONAL refreshRate;
            public DISPLAYCONFIG_SCANLINE_ORDERING scanLineOrdering;
            public bool targetAvailable;
            public uint statusFlags;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct DISPLAYCONFIG_PATH_INFO
        {
            public DISPLAYCONFIG_PATH_SOURCE_INFO sourceInfo;
            public DISPLAYCONFIG_PATH_TARGET_INFO targetInfo;
            public uint flags;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct DISPLAYCONFIG_TARGET_MODE {
            public DISPLAYCONFIG_VIDEO_SIGNAL_INFO videoSignalInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct DISPLAYCONFIG_SOURCE_MODE {
            public uint width;
            public uint height;
            public DISPLAYCONFIG_PIXELFORMAT pixelFormat;
            public POINTL position;
        }

        [StructLayout(LayoutKind.Explicit)]
        public struct UnionDisplayConfigModeInfo {
            [FieldOffset(0)]
            public DISPLAYCONFIG_TARGET_MODE targetMode;
            [FieldOffset(0)]
            public DISPLAYCONFIG_SOURCE_MODE sourceMode;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct DISPLAYCONFIG_MODE_INFO {
            public DISPLAYCONFIG_MODE_INFO_TYPE infoType;
            public uint id;
            public uint adapterId_low;
            public uint adapterId_high;
            public UnionDisplayConfigModeInfo modeInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct DISPLAYCONFIG_VIDEO_SIGNAL_INFO {
            public ulong pixelRate;
            public DISPLAYCONFIG_RATIONAL hSyncFreq;
            public DISPLAYCONFIG_RATIONAL vSyncFreq;
            public DISPLAYCONFIG_2DREGION activeSize;
            public DISPLAYCONFIG_2DREGION totalSize;
            public uint videoStandard;
            public DISPLAYCONFIG_SCANLINE_ORDERING scanLineOrdering;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct DISPLAYCONFIG_2DREGION { public uint cx; public uint cy; }
        #endregion

        #region Enums
        public enum DISPLAYCONFIG_VIDEO_OUTPUT_TECHNOLOGY : uint { OTHER = 4294967295, HD15 = 0, SVIDEO = 1, COMPOSITE_VIDEO = 2, COMPONENT_VIDEO = 3, DVI = 4, HDMI = 5, LVDS = 6, D_JPN = 8, SDI = 9, DISPLAYPORT_EXTERNAL = 10, DISPLAYPORT_EMBEDDED = 11, UDI_EXTERNAL = 12, UDI_EMBEDDED = 13, SDTVDONGLE = 14, MIRACAST = 15, INTERNAL = 2147483648, BNC = 2147483648 }
        public enum DISPLAYCONFIG_ROTATION : uint { IDENTITY = 1, ROTATE90 = 2, ROTATE180 = 3, ROTATE270 = 4 }
        public enum DISPLAYCONFIG_SCALING : uint { IDENTITY = 1, CENTERED = 2, STRETCHED = 3, ASPECTRATIOCENTEREDMAX = 4, CUSTOM = 5, PREFERRED = 128 }
        public enum DISPLAYCONFIG_SCANLINE_ORDERING : uint { UNspecified = 0, PROGRESSIVE = 1, INTERLACED = 2, INTERLACED_UPPERFIELDFIRST = 2, INTERLACED_LOWERFIELDFIRST = 3 }
        public enum DISPLAYCONFIG_MODE_INFO_TYPE : uint { SOURCE = 1, TARGET = 2, DESKTOP_IMAGE = 3 }
        public enum DISPLAYCONFIG_PIXELFORMAT : uint { PIXELFORMAT_8BPP = 1, PIXELFORMAT_16BPP = 2, PIXELFORMAT_24BPP = 3, PIXELFORMAT_32BPP = 4, PIXELFORMAT_NONGDI = 5 }
        #endregion

        #region DllImports
        [DllImport("user32.dll")]
        public static extern int GetDisplayConfigBufferSizes(uint flags, out uint numPathArrayElements, out uint numModeInfoArrayElements);

        [DllImport("user32.dll")]
        public static extern int QueryDisplayConfig(uint flags, ref uint numPathArrayElements, [Out] DISPLAYCONFIG_PATH_INFO[] pathInfoArray, ref uint numModeInfoArrayElements, [Out] DISPLAYCONFIG_MODE_INFO[] modeInfoArray, IntPtr currentTopologyId);
        #endregion

        public static List<PSObject> GetDisplayInfo()
        {
            var results = new List<PSObject>();
            
            uint pathCount;
            uint modeCount;
            GetDisplayConfigBufferSizes(1, out pathCount, out modeCount);

            if (pathCount == 0) return results;

            var displayPaths = new DISPLAYCONFIG_PATH_INFO[pathCount];
            var displayModes = new DISPLAYCONFIG_MODE_INFO[modeCount];
            QueryDisplayConfig(1, ref pathCount, displayPaths, ref modeCount, displayModes, IntPtr.Zero);

            for (int i = 0; i < pathCount; i++)
            {
                if (displayPaths[i].targetInfo.targetAvailable &&
                    displayPaths[i].sourceInfo.modeInfoIdx < modeCount &&
                    displayPaths[i].targetInfo.modeInfoIdx < modeCount)
                {
                    var sourceMode = displayModes[displayPaths[i].sourceInfo.modeInfoIdx].modeInfo.sourceMode;
                    var targetMode = displayModes[displayPaths[i].targetInfo.modeInfoIdx].modeInfo.targetMode;
                    
                    var psObj = new System.Management.Automation.PSObject();
                    psObj.Properties.Add(new System.Management.Automation.PSNoteProperty("Resolution", string.Format("{0}x{1}", sourceMode.width, sourceMode.height)));
                    psObj.Properties.Add(new System.Management.Automation.PSNoteProperty("RefreshRate", Math.Round((double)targetMode.videoSignalInfo.vSyncFreq.Numerator / targetMode.videoSignalInfo.vSyncFreq.Denominator, 0)));
                    
                    results.Add(psObj);
                }
            }
            return results;
        }
    }
}
"@
        #endregion

        try {
            # Suppress verbose output from Add-Type
            $null = Add-Type -TypeDefinition $csharpCode -PassThru -ErrorAction Stop
        } catch {
            $psError = $_.Exception.Message
            Write-Error "Falha ao compilar o código de apoio da API do Windows. Não é possível continuar com a precisão total. Detalhes: $psError"
            return
        }
        
        $displayApiInfo = [Win32.DisplayConfig]::GetDisplayInfo()

        $monitorsList = New-Object System.Collections.ArrayList
        $wmiMonitors = Get-WmiObject -Namespace 'root\wmi' -Class 'WmiMonitorID' -ErrorAction SilentlyContinue
        
        if ($wmiMonitors) {
            for ($i = 0; $i -lt $wmiMonitors.Count; $i++) {
                if ($i -ge $displayApiInfo.Count) { continue } 

                $monitorWmi = $wmiMonitors[$i]
                $apiInfo = $displayApiInfo[$i]

                $refreshRateString = "$($apiInfo.RefreshRate) Hz"
                $resolutionString = $apiInfo.Resolution

                $nameBytes = $monitorWmi.UserFriendlyName
                $name = if ($nameBytes) { ([System.Text.Encoding]::Default.GetString($nameBytes).Trim([char]0).Trim()) } else { $null }

                $manufacturerBytes = $monitorWmi.ManufacturerName
                $manufacturer = if ($manufacturerBytes) { ([System.Text.Encoding]::Default.GetString($manufacturerBytes).Trim([char]0).Trim()) } else { $null }

                $serialBytes = $monitorWmi.SerialNumberID
                $serial = if ($serialBytes) { ([System.Text.Encoding]::Default.GetString($serialBytes).Trim([char]0).Trim()) } else { $null }

                $monitorDetails = @{
                    "Nome do Monitor"           = if (-not [string]::IsNullOrWhiteSpace($name)) { $name } else { "Monitor Genérico" }
                    "Fabricante do Monitor"     = if (-not [string]::IsNullOrWhiteSpace($manufacturer)) { $manufacturer } else { "Não Encontrado" }
                    # Check if serial is null, whitespace, OR just "0" before showing it.
                    "Número de Série (Monitor)" = if (-not [string]::IsNullOrWhiteSpace($serial) -and $serial -ne '0') { $serial } else { "Não Encontrado" }
                    "Resolução Detectada"       = $resolutionString
                    "Taxa de Atualização"       = $refreshRateString
                }
                [void]$monitorsList.Add((New-Object PSObject -Property $monitorDetails))
            }
        }
        else {
             foreach($apiInfo in $displayApiInfo) {
                 $monitorDetails = @{
                    "Nome do Monitor"           = "Monitor Desconhecido"
                    "Fabricante do Monitor"     = "Não Encontrado"
                    "Número de Série (Monitor)" = "Não Encontrado"
                    "Resolução Detectada"       = $apiInfo.Resolution
                    "Taxa de Atualização"       = "$($apiInfo.RefreshRate) Hz"
                }
                [void]$monitorsList.Add((New-Object PSObject -Property $monitorDetails))
             }
        }

        if ($monitorsList.Count -eq 0) {
            $errorDetails = @{
                "Fabricante do Monitor"     = "-"
                "Nome do Monitor"           = "Nenhum Monitor Detectado"
                "Número de Série (Monitor)" = "-"
                "Resolução Detectada"       = "-"
                "Taxa de Atualização"       = "-"
            }
            [void]$monitorsList.Add((New-Object PSObject -Property $errorDetails))
        }
        
        # Use Select-Object to enforce the final property order for consistent display.
        return $monitorsList.ToArray() | Select-Object "Fabricante do Monitor", "Nome do Monitor", "Número de Série (Monitor)", "Resolução Detectada", "Taxa de Atualização"
    }
}
