# ==============================================================================
# PROJETO MATHZ OPTIMIZER - MOTOR DE GERACAO DINAMICA DE CURSORES .CUR
# Permite ao usuario alterar a Cor de Dentro (Preenchimento) e a Linha de Fora
# ==============================================================================

Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue

$compactArrowPts = [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(2, 2),
    [System.Drawing.Point]::new(2, 16),
    [System.Drawing.Point]::new(5, 13),
    [System.Drawing.Point]::new(8, 19),
    [System.Drawing.Point]::new(11, 18),
    [System.Drawing.Point]::new(8, 12),
    [System.Drawing.Point]::new(13, 12)
)

$compactHandPts = [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(11, 3),
    [System.Drawing.Point]::new(14, 3),
    [System.Drawing.Point]::new(14, 10),
    [System.Drawing.Point]::new(17, 11),
    [System.Drawing.Point]::new(19, 13),
    [System.Drawing.Point]::new(19, 21),
    [System.Drawing.Point]::new(16, 24),
    [System.Drawing.Point]::new(9, 24),
    [System.Drawing.Point]::new(7, 19),
    [System.Drawing.Point]::new(7, 15),
    [System.Drawing.Point]::new(11, 13)
)

$nsPts = [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(16, 6),
    [System.Drawing.Point]::new(12, 11),
    [System.Drawing.Point]::new(14, 11),
    [System.Drawing.Point]::new(14, 21),
    [System.Drawing.Point]::new(12, 21),
    [System.Drawing.Point]::new(16, 26),
    [System.Drawing.Point]::new(20, 21),
    [System.Drawing.Point]::new(18, 21),
    [System.Drawing.Point]::new(18, 11),
    [System.Drawing.Point]::new(20, 11)
)

$wePts = [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(6, 16),
    [System.Drawing.Point]::new(11, 12),
    [System.Drawing.Point]::new(11, 14),
    [System.Drawing.Point]::new(21, 14),
    [System.Drawing.Point]::new(21, 12),
    [System.Drawing.Point]::new(26, 16),
    [System.Drawing.Point]::new(21, 20),
    [System.Drawing.Point]::new(21, 18),
    [System.Drawing.Point]::new(11, 18),
    [System.Drawing.Point]::new(11, 20)
)

$nwsePts = [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(8, 8),
    [System.Drawing.Point]::new(14, 8),
    [System.Drawing.Point]::new(12, 10),
    [System.Drawing.Point]::new(21, 19),
    [System.Drawing.Point]::new(23, 17),
    [System.Drawing.Point]::new(23, 23),
    [System.Drawing.Point]::new(17, 23),
    [System.Drawing.Point]::new(19, 21),
    [System.Drawing.Point]::new(10, 12),
    [System.Drawing.Point]::new(8, 14)
)

$neswPts = [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(23, 8),
    [System.Drawing.Point]::new(23, 14),
    [System.Drawing.Point]::new(21, 12),
    [System.Drawing.Point]::new(12, 21),
    [System.Drawing.Point]::new(14, 23),
    [System.Drawing.Point]::new(8, 23),
    [System.Drawing.Point]::new(8, 17),
    [System.Drawing.Point]::new(10, 19),
    [System.Drawing.Point]::new(19, 10),
    [System.Drawing.Point]::new(17, 8)
)

$upPts = [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(16, 5),
    [System.Drawing.Point]::new(11, 12),
    [System.Drawing.Point]::new(14, 12),
    [System.Drawing.Point]::new(14, 25),
    [System.Drawing.Point]::new(18, 25),
    [System.Drawing.Point]::new(18, 12),
    [System.Drawing.Point]::new(21, 12)
)

$penPts = [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(4, 25),
    [System.Drawing.Point]::new(19, 10),
    [System.Drawing.Point]::new(22, 13),
    [System.Drawing.Point]::new(7, 28)
)

$bodyPts = [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(8, 24),
    [System.Drawing.Point]::new(11, 16),
    [System.Drawing.Point]::new(21, 16),
    [System.Drawing.Point]::new(24, 24)
)

function Save-CurStream {
    param($bmp, $path, $hx = 0, $hy = 0)
    $w = $bmp.Width; $h = $bmp.Height
    $headerSize = 40; $xorSize = $w * $h * 4
    $andRowBytes = [math]::Ceiling($w / 32) * 4
    $andSize = $andRowBytes * $h
    $imageSize = $headerSize + $xorSize + $andSize

    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $bw.Write([UInt16]0); $bw.Write([UInt16]2); $bw.Write([UInt16]1)
    $bw.Write([Byte]$w); $bw.Write([Byte]$h); $bw.Write([Byte]0); $bw.Write([Byte]0)
    $bw.Write([UInt16]$hx); $bw.Write([UInt16]$hy); $bw.Write([UInt32]$imageSize); $bw.Write([UInt32]22)
    $bw.Write([UInt32]40); $bw.Write([Int32]$w); $bw.Write([Int32]($h * 2)); $bw.Write([UInt16]1); $bw.Write([UInt16]32)
    $bw.Write([UInt32]0); $bw.Write([UInt32]($xorSize + $andSize)); $bw.Write([Int32]0); $bw.Write([Int32]0); $bw.Write([UInt32]0); $bw.Write([UInt32]0)

    for ($y = $h - 1; $y -ge 0; $y--) {
        for ($x = 0; $x -lt $w; $x++) {
            $p = $bmp.GetPixel($x, $y)
            $bw.Write([Byte]$p.B); $bw.Write([Byte]$p.G); $bw.Write([Byte]$p.R); $bw.Write([Byte]$p.A)
        }
    }
    for ($y = $h - 1; $y -ge 0; $y--) {
        $rowBytes = New-Object byte[] $andRowBytes
        for ($x = 0; $x -lt $w; $x++) {
            $p = $bmp.GetPixel($x, $y)
            if ($p.A -eq 0) {
                $byteIdx = [math]::Floor($x / 8)
                $bitIdx = 7 - ($x % 8)
                $rowBytes[$byteIdx] = $rowBytes[$byteIdx] -bor (1 -shl $bitIdx)
            }
        }
        $bw.Write($rowBytes)
    }
    $bytes = $ms.ToArray()
    $bw.Close(); $ms.Close()
    [System.IO.File]::WriteAllBytes($path, $bytes)
}

function New-CanvasBmp {
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    return @{ Bitmap = $bmp; Graphics = $g }
}

function Generate-MathzSuiteFiles {
    param(
        [string]$InsideHex = "#050508",
        [string]$OutlineHex = "#FF003C",
        [string]$TargetDir
    )

    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    try {
        $cIn = [System.Drawing.ColorTranslator]::FromHtml($InsideHex)
    } catch {
        $cIn = [System.Drawing.Color]::FromArgb(255, 6, 6, 9)
    }

    try {
        $cOut = [System.Drawing.ColorTranslator]::FromHtml($OutlineHex)
    } catch {
        $cOut = [System.Drawing.Color]::FromArgb(255, 255, 0, 60)
    }

    $bIn = New-Object System.Drawing.SolidBrush $cIn
    $pOut = New-Object System.Drawing.Pen $cOut, 1.3
    $bOut = New-Object System.Drawing.SolidBrush $cOut

    # 1. Arrow (Ponteiro Normal)
    $c = New-CanvasBmp; $c.Graphics.FillPolygon($bIn, $compactArrowPts); $c.Graphics.DrawPolygon($pOut, $compactArrowPts); $c.Graphics.Dispose()
    Save-CurStream $c.Bitmap (Join-Path $TargetDir "mathz_arrow.cur") 2 2; $c.Bitmap.Dispose()

    # 2. AppStarting (Trabalhando em Segundo Plano - Seta + Mini Radar ao Lado)
    $c = New-CanvasBmp
    $c.Graphics.FillPolygon($bIn, $compactArrowPts); $c.Graphics.DrawPolygon($pOut, $compactArrowPts)
    $c.Graphics.FillEllipse($bIn, 15, 13, 13, 13); $c.Graphics.DrawEllipse($pOut, 15, 13, 13, 13)
    $arcP = New-Object System.Drawing.Pen $cOut, 1.8; $c.Graphics.DrawArc($arcP, 17, 15, 9, 9, [single]45, [single]220); $arcP.Dispose()
    $c.Graphics.FillEllipse($bOut, 19, 17, 4, 4); $c.Graphics.Dispose()
    Save-CurStream $c.Bitmap (Join-Path $TargetDir "mathz_appstarting.cur") 2 2; $c.Bitmap.Dispose()

    # 3. Wait (Ocupado - Radar Cyber com Nucleo Neon)
    $c = New-CanvasBmp
    $c.Graphics.FillEllipse($bIn, 6, 6, 20, 20); $c.Graphics.DrawEllipse($pOut, 6, 6, 20, 20)
    $arcP = New-Object System.Drawing.Pen $cOut, 2.0; $c.Graphics.DrawArc($arcP, 9, 9, 14, 14, [single]30, [single]220); $arcP.Dispose()
    $c.Graphics.FillEllipse($bOut, 14, 14, 4, 4); $c.Graphics.Dispose()
    Save-CurStream $c.Bitmap (Join-Path $TargetDir "mathz_wait.cur") 16 16; $c.Bitmap.Dispose()

    # 4. Cross (Selecao de Precisao / Mira FPS)
    $c = New-CanvasBmp
    $c.Graphics.DrawLine($pOut, 16, 8, 16, 13); $c.Graphics.DrawLine($pOut, 16, 19, 16, 24)
    $c.Graphics.DrawLine($pOut, 8, 16, 13, 16); $c.Graphics.DrawLine($pOut, 19, 16, 24, 16)
    $c.Graphics.FillEllipse($bOut, 15, 15, 2, 2); $c.Graphics.DrawEllipse($pOut, 11, 11, 10, 10); $c.Graphics.Dispose()
    Save-CurStream $c.Bitmap (Join-Path $TargetDir "mathz_cross.cur") 16 16; $c.Bitmap.Dispose()

    # 5. Beam (Selecao de Texto)
    $c = New-CanvasBmp
    $c.Graphics.DrawLine($pOut, 13, 8, 19, 8); $c.Graphics.DrawLine($pOut, 13, 24, 19, 24); $c.Graphics.DrawLine($pOut, 16, 8, 16, 24)
    $c.Graphics.FillRectangle($bIn, 15, 10, 2, 12); $c.Graphics.Dispose()
    Save-CurStream $c.Bitmap (Join-Path $TargetDir "mathz_beam.cur") 16 16; $c.Bitmap.Dispose()

    # 6. Hand (Selecao de Link)
    $c = New-CanvasBmp; $c.Graphics.FillPolygon($bIn, $compactHandPts); $c.Graphics.DrawPolygon($pOut, $compactHandPts)
    $c.Graphics.DrawLine($pOut, 14, 13, 14, 18); $c.Graphics.Dispose()
    Save-CurStream $c.Bitmap (Join-Path $TargetDir "mathz_hand.cur") 12 3; $c.Bitmap.Dispose()

    # 7. No (Nao Disponivel)
    $c = New-CanvasBmp; $c.Graphics.FillEllipse($bIn, 8, 8, 16, 16); $c.Graphics.DrawEllipse($pOut, 8, 8, 16, 16)
    $c.Graphics.DrawLine($pOut, 11, 11, 21, 21); $c.Graphics.Dispose()
    Save-CurStream $c.Bitmap (Join-Path $TargetDir "mathz_no.cur") 16 16; $c.Bitmap.Dispose()

    # 8. NS (Redimensionamento Vertical)
    $c = New-CanvasBmp; $c.Graphics.FillPolygon($bIn, $nsPts); $c.Graphics.DrawPolygon($pOut, $nsPts); $c.Graphics.Dispose()
    Save-CurStream $c.Bitmap (Join-Path $TargetDir "mathz_ns.cur") 16 16; $c.Bitmap.Dispose()

    # 9. EW (Redimensionamento Horizontal)
    $c = New-CanvasBmp; $c.Graphics.FillPolygon($bIn, $wePts); $c.Graphics.DrawPolygon($pOut, $wePts); $c.Graphics.Dispose()
    Save-CurStream $c.Bitmap (Join-Path $TargetDir "mathz_ew.cur") 16 16; $c.Bitmap.Dispose()

    # 10. NWSE (Diagonal 1)
    $c = New-CanvasBmp; $c.Graphics.FillPolygon($bIn, $nwsePts); $c.Graphics.DrawPolygon($pOut, $nwsePts); $c.Graphics.Dispose()
    Save-CurStream $c.Bitmap (Join-Path $TargetDir "mathz_nwse.cur") 16 16; $c.Bitmap.Dispose()

    # 11. NESW (Diagonal 2)
    $c = New-CanvasBmp; $c.Graphics.FillPolygon($bIn, $neswPts); $c.Graphics.DrawPolygon($pOut, $neswPts); $c.Graphics.Dispose()
    Save-CurStream $c.Bitmap (Join-Path $TargetDir "mathz_nesw.cur") 16 16; $c.Bitmap.Dispose()

    # 12. Move (Mover)
    $c = New-CanvasBmp
    $c.Graphics.DrawLine($pOut, 16, 7, 16, 25); $c.Graphics.DrawLine($pOut, 7, 16, 25, 16)
    $c.Graphics.FillPolygon($bOut, [System.Drawing.Point[]]@([System.Drawing.Point]::new(16, 5), [System.Drawing.Point]::new(13, 9), [System.Drawing.Point]::new(19, 9)))
    $c.Graphics.FillPolygon($bOut, [System.Drawing.Point[]]@([System.Drawing.Point]::new(16, 27), [System.Drawing.Point]::new(13, 23), [System.Drawing.Point]::new(19, 23)))
    $c.Graphics.FillPolygon($bOut, [System.Drawing.Point[]]@([System.Drawing.Point]::new(5, 16), [System.Drawing.Point]::new(9, 13), [System.Drawing.Point]::new(9, 19)))
    $c.Graphics.FillPolygon($bOut, [System.Drawing.Point[]]@([System.Drawing.Point]::new(27, 16), [System.Drawing.Point]::new(23, 13), [System.Drawing.Point]::new(23, 19)))
    $c.Graphics.FillEllipse($bIn, 13, 13, 6, 6); $c.Graphics.DrawEllipse($pOut, 13, 13, 6, 6); $c.Graphics.Dispose()
    Save-CurStream $c.Bitmap (Join-Path $TargetDir "mathz_move.cur") 16 16; $c.Bitmap.Dispose()

    # 13. Up (Seta para Cima)
    $c = New-CanvasBmp; $c.Graphics.FillPolygon($bIn, $upPts); $c.Graphics.DrawPolygon($pOut, $upPts); $c.Graphics.Dispose()
    Save-CurStream $c.Bitmap (Join-Path $TargetDir "mathz_up.cur") 16 5; $c.Bitmap.Dispose()

    # 14. Help (Ajuda)
    $c = New-CanvasBmp; $c.Graphics.FillPolygon($bIn, $compactArrowPts); $c.Graphics.DrawPolygon($pOut, $compactArrowPts)
    $fnt = [System.Drawing.Font]::new("Arial", [single]9, [System.Drawing.FontStyle]::Bold)
    $c.Graphics.DrawString("?", $fnt, $bOut, [single]16, [single]10); $fnt.Dispose(); $c.Graphics.Dispose()
    Save-CurStream $c.Bitmap (Join-Path $TargetDir "mathz_help.cur") 2 2; $c.Bitmap.Dispose()

    # 15. Pen (Caneta)
    $c = New-CanvasBmp; $c.Graphics.FillPolygon($bIn, $penPts); $c.Graphics.DrawPolygon($pOut, $penPts)
    $c.Graphics.FillEllipse($bOut, 3, 26, 3, 3); $c.Graphics.Dispose()
    Save-CurStream $c.Bitmap (Join-Path $TargetDir "mathz_pen.cur") 4 27; $c.Bitmap.Dispose()

    # 16. Pin (Localizacao)
    $c = New-CanvasBmp; $c.Graphics.FillEllipse($bIn, 11, 5, 10, 10); $c.Graphics.DrawEllipse($pOut, 11, 5, 10, 10)
    $c.Graphics.FillEllipse($bOut, 14, 8, 4, 4); $c.Graphics.DrawLine($pOut, 16, 15, 16, 25); $c.Graphics.Dispose()
    Save-CurStream $c.Bitmap (Join-Path $TargetDir "mathz_pin.cur") 16 25; $c.Bitmap.Dispose()

    # 17. Person (Usuario)
    $c = New-CanvasBmp; $c.Graphics.FillEllipse($bIn, 12, 6, 8, 8); $c.Graphics.DrawEllipse($pOut, 12, 6, 8, 8)
    $c.Graphics.FillPolygon($bIn, $bodyPts); $c.Graphics.DrawPolygon($pOut, $bodyPts); $c.Graphics.Dispose()
    Save-CurStream $c.Bitmap (Join-Path $TargetDir "mathz_person.cur") 16 16; $c.Bitmap.Dispose()

    $bIn.Dispose(); $pOut.Dispose(); $bOut.Dispose()
}

function Apply-MathzCustomColors {
    param(
        [string]$InsideHex = "#050508",
        [string]$OutlineHex = "#FF003C"
    )

    $cursorSysDir = "C:\Windows\Cursors\MathzPerformance"
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    $targetDir = $cursorSysDir
    if (-not $isAdmin) {
        $targetDir = [System.IO.Path]::Combine($env:LOCALAPPDATA, "MathzControlPanel\Cursors")
    }

    # Gera todos os 17 cursores .cur com as novas cores
    Generate-MathzSuiteFiles -InsideHex $InsideHex -OutlineHex $OutlineHex -TargetDir $targetDir

    # Mapeia na chave do usuario atual
    $cursorMap = [ordered]@{
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

    $curRegPath = "HKCU:\Control Panel\Cursors"
    if (-not (Test-Path $curRegPath)) { New-Item -Path $curRegPath -Force | Out-Null }
    Set-ItemProperty -Path $curRegPath -Name "(Default)" -Value "Mathz Custom ($OutlineHex)" -Force

    foreach ($key in $cursorMap.Keys) {
        Set-ItemProperty -Path $curRegPath -Name $key -Value $cursorMap[$key] -Force
    }

    # Recarrega via API nativa User32 instantaneamente (Injecao em RAM + Broadcast do Windows)
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

    [WinCursorAPI]::ReloadLive("$targetDir")
    return $true
}

function Restore-MathzDefaultCursors {
    $curRegPath = "HKCU:\Control Panel\Cursors"
    if (-not (Test-Path $curRegPath)) { New-Item -Path $curRegPath -Force | Out-Null }
    Set-ItemProperty -Path $curRegPath -Name "(Default)" -Value "Windows Default" -Force

    $roles = @("Arrow","Help","AppStarting","Wait","Crosshair","IBeam","NWPen","No","SizeNS","SizeWE","SizeNWSE","SizeNESW","SizeAll","UpArrow","Hand","Pin","Person")
    foreach ($r in $roles) {
        Set-ItemProperty -Path $curRegPath -Name $r -Value "" -Force
    }

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
            public const uint OCR_NORMAL = 32512;

            public static void ReloadLive(string arrowCurPath) {
                try {
                    if (!string.IsNullOrEmpty(arrowCurPath) && System.IO.File.Exists(arrowCurPath)) {
                        IntPtr h = LoadCursorFromFile(arrowCurPath);
                        if (h != IntPtr.Zero) {
                            SetSystemCursor(h, OCR_NORMAL);
                        }
                    }
                } catch { }

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

    [WinCursorAPI]::RestoreLive()
    return $true
}
