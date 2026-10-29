# ==============================================================================
# MATHZ CONTROL PANEL - APLICADOR AUTÔNOMO DE CURSORES "MATHZ PERFORMANCE"
# Design: Pure Black (#050508) com Contorno Neon Red (#FF003C)
# ==============================================================================

[CmdletBinding()]
param (
    [switch]$RestoreDefault
)

if (-not ([System.Management.Automation.PSTypeName]'WinCursorAPI').Type) {
    $csharp = @'
    using System;
    using System.Runtime.InteropServices;

    public class WinCursorAPI {
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr LoadCursorFromFile(string lpFileName);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetSystemCursor(IntPtr hcur, uint id);

        [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW", SetLastError = true)]
        public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);

        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);

        public const uint SPI_SETCURSORS = 0x0057;
        public const uint SPIF_UPDATEINIFILE = 0x01;
        public const uint SPIF_SENDCHANGE = 0x02;
        public const uint WM_SETTINGCHANGE = 0x001A;
        public const uint HWND_BROADCAST = 0xFFFF;
        public const uint SMTO_ABORTIFHUNG = 0x0002;
        public const uint OCR_NORMAL      = 32512;
        public const uint OCR_IBEAM       = 32513;
        public const uint OCR_WAIT        = 32514;
        public const uint OCR_CROSS       = 32515;
        public const uint OCR_UP          = 32516;
        public const uint OCR_SIZENWSE    = 32642;
        public const uint OCR_SIZENESW    = 32643;
        public const uint OCR_SIZEWE      = 32644;
        public const uint OCR_SIZENS      = 32645;
        public const uint OCR_SIZEALL     = 32646;
        public const uint OCR_NO          = 32648;
        public const uint OCR_HAND        = 32649;
        public const uint OCR_APPSTARTING = 32650;

        public static void ReloadLive(string targetDirOrFile) {
            string dir = targetDirOrFile;
            if (System.IO.File.Exists(targetDirOrFile)) {
                dir = System.IO.Path.GetDirectoryName(targetDirOrFile);
            }

            var mapping = new System.Collections.Generic.Dictionary<string, uint> {
                { "mathz_arrow.cur",       OCR_NORMAL },
                { "mathz_beam.cur",        OCR_IBEAM },
                { "mathz_wait.cur",        OCR_WAIT },
                { "mathz_cross.cur",       OCR_CROSS },
                { "mathz_up.cur",          OCR_UP },
                { "mathz_nwse.cur",        OCR_SIZENWSE },
                { "mathz_nesw.cur",        OCR_SIZENESW },
                { "mathz_ew.cur",          OCR_SIZEWE },
                { "mathz_ns.cur",          OCR_SIZENS },
                { "mathz_move.cur",        OCR_SIZEALL },
                { "mathz_no.cur",          OCR_NO },
                { "mathz_hand.cur",        OCR_HAND },
                { "mathz_appstarting.cur", OCR_APPSTARTING }
            };

            foreach (var kvp in mapping) {
                try {
                    string curFile = System.IO.Path.Combine(dir, kvp.Key);
                    if (System.IO.File.Exists(curFile)) {
                        IntPtr h = LoadCursorFromFile(curFile);
                        if (h != IntPtr.Zero) {
                            SetSystemCursor(h, kvp.Value);
                        }
                    } 
                } catch { }
            }

            try {
                SystemParametersInfo(SPI_SETCURSORS, 0, IntPtr.Zero, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
            } catch { }

            try {
                IntPtr res;
                SendMessageTimeout((IntPtr)HWND_BROADCAST, WM_SETTINGCHANGE, IntPtr.Zero, "Cursors", SMTO_ABORTIFHUNG, 2000, out res);
            } catch { }
        }

        public static void RestoreLive() {
            try {
                SystemParametersInfo(SPI_SETCURSORS, 0, IntPtr.Zero, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
            } catch { }

            try {
                IntPtr res;
                SendMessageTimeout((IntPtr)HWND_BROADCAST, WM_SETTINGCHANGE, IntPtr.Zero, "Cursors", SMTO_ABORTIFHUNG, 2000, out res);
            } catch { }
        }
    }
'@
    Add-Type -TypeDefinition $csharp -ErrorAction SilentlyContinue
}

$cursorSystemDir = "C:\Windows\Cursors\MathzPerformance"

if ($RestoreDefault) {
    $curRegPath = "HKCU:\Control Panel\Cursors"
    if (-not (Test-Path $curRegPath)) { New-Item -Path $curRegPath -Force | Out-Null }
    Set-ItemProperty -Path $curRegPath -Name "(Default)" -Value "Windows Default" -Force
    $roles = @("Arrow","Help","AppStarting","Wait","Crosshair","IBeam","NWPen","No","SizeNS","SizeWE","SizeNWSE","SizeNESW","SizeAll","UpArrow","Hand","Pin","Person")
    foreach ($r in $roles) {
        Set-ItemProperty -Path $curRegPath -Name $r -Value "" -Force
    }
    [WinCursorAPI]::RestoreLive()
    return
}

# Localizar pasta com os arquivos .cur
$baseDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($global:PSScriptRoot) { $global:PSScriptRoot } else { (Get-Location).Path }
$potentialDirs = @(
    (Join-Path -Path $baseDir -ChildPath "Cursors"),
    (Join-Path -Path $baseDir -ChildPath "MathzControlCenter\Cursors"),
    (Join-Path -Path (Split-Path $baseDir -Parent) -ChildPath "MathzControlCenter\Cursors"),
    (Join-Path -Path $env:LOCALAPPDATA -ChildPath "MathzControlPanel\MathzControlCenter\Cursors"),
    (Join-Path -Path $env:LOCALAPPDATA -ChildPath "MathzControlPanel\Cursors"),
    $cursorSystemDir
)

$sourceDir = $null
foreach ($d in $potentialDirs) {
    if (Test-Path (Join-Path $d "mathz_arrow.cur")) {
        $sourceDir = $d
        break
    }
}

if (-not $sourceDir) {
    return
}

# Tenta copiar para pasta do sistema C:\Windows\Cursors\MathzPerformance (se tiver permissão)
$targetDir = $sourceDir
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    try {
        if (-not (Test-Path $cursorSystemDir)) {
            New-Item -ItemType Directory -Path $cursorSystemDir -Force | Out-Null
        }
        Get-ChildItem -Path $sourceDir -Filter "*.cur" | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $cursorSystemDir -Force
        }
        $targetDir = $cursorSystemDir
    } catch {
        $targetDir = $sourceDir
    }
}

# Grava esquema nos registros do Windows
$curRegPath = "HKCU:\Control Panel\Cursors"
if (-not (Test-Path $curRegPath)) { New-Item -Path $curRegPath -Force | Out-Null }
Set-ItemProperty -Path $curRegPath -Name "(Default)" -Value "Mathz Performance" -Force

$cursorMap = @{
    "Arrow"       = "$targetDir\mathz_arrow.cur"
    "Help"        = "$targetDir\mathz_help.cur"
    "AppStarting" = "$targetDir\mathz_appstarting.cur"
    "Wait"        = "$targetDir\mathz_wait.cur"
    "Crosshair"   = "$targetDir\mathz_cross.cur"
    "IBeam"       = "$targetDir\mathz_beam.cur"
    "NWPen"       = "$targetDir\mathz_pen.cur"
    "No"          = "$targetDir\mathz_no.cur"
    "SizeNS"      = "$targetDir\mathz_ns.cur"
    "SizeWE"      = "$targetDir\mathz_ew.cur"
    "SizeNWSE"    = "$targetDir\mathz_nwse.cur"
    "SizeNESW"    = "$targetDir\mathz_nesw.cur"
    "SizeAll"     = "$targetDir\mathz_move.cur"
    "UpArrow"     = "$targetDir\mathz_up.cur"
    "Hand"        = "$targetDir\mathz_hand.cur"
    "Pin"         = "$targetDir\mathz_pin.cur"
    "Person"      = "$targetDir\mathz_person.cur"
}

foreach ($role in $cursorMap.Keys) {
    Set-ItemProperty -Path $curRegPath -Name $role -Value $cursorMap[$role] -Force
}

# Recarrega cursores dinamicamente no Windows
[WinCursorAPI]::ReloadLive($targetDir)
