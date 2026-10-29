# ==============================================================================
# MATHZ CONTROL PANEL - APLICADOR AUTONOMO DE CURSORES
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
@
    Add-Type -TypeDefinition $csharp -ErrorAction SilentlyContinue
}

[WinCursorAPI]::ReloadLive("$curDir")
