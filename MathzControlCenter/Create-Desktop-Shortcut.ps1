# ==============================================================================
# CRIAR ATALHO NA ÁREA DE TRABALHO - PAINEL DE COMANDO MTZ
# ==============================================================================

$WshShell = New-Object -ComObject WScript.Shell
$targetDir = $PSScriptRoot
$parentDir = Split-Path $targetDir -Parent

# Busca executável oficial
$exeCandidates = @(
    (Join-Path $parentDir "MathzControlPanel.exe"),
    (Join-Path $targetDir "MathzControlPanel.exe"),
    "C:\Program Files\MathzControlPanel\MathzControlPanel.exe",
    "C:\MathzOS\MathzControlPanel.exe"
)
$exeLauncher = $exeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

$vbsLauncher = Join-Path -Path $targetDir -ChildPath "Launch-MathzControlPanel.vbs"

$icoCandidates = @(
    (Join-Path $targetDir "Assets\Mathz.ico"),
    (Join-Path $parentDir "Mathz.ico"),
    (Join-Path $targetDir "Mathz.ico")
)
$icoFile = $icoCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $icoFile) { $icoFile = "$env:SystemRoot\System32\shell32.dll,238" }

$desktops = @(
    [System.Environment]::GetFolderPath('Desktop'),
    [System.Environment]::GetFolderPath('CommonDesktopDirectory')
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

foreach ($desk in $desktops) {
    try {
        # Limpar atalho antigo se houver
        $oldShortcut = Join-Path -Path $desk -ChildPath "Mathz Control Panel.lnk"
        if (Test-Path $oldShortcut) { Remove-Item $oldShortcut -Force -ErrorAction SilentlyContinue }

        $shortcutPath = Join-Path -Path $desk -ChildPath "Painel de Comando MTZ.lnk"
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)
        
        if ($exeLauncher) {
            $Shortcut.TargetPath = $exeLauncher
            $Shortcut.WorkingDirectory = Split-Path $exeLauncher -Parent
            $Shortcut.IconLocation = "$exeLauncher,0"
        } elseif (Test-Path $vbsLauncher) {
            $Shortcut.TargetPath = "wscript.exe"
            $Shortcut.Arguments = "`"$vbsLauncher`""
            $Shortcut.WorkingDirectory = $targetDir
            $Shortcut.IconLocation = "$icoFile,0"
        } else {
            $psScript = Join-Path $targetDir "MathzControlCenter.ps1"
            $Shortcut.TargetPath = "powershell.exe"
            $Shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$psScript`""
            $Shortcut.WorkingDirectory = $targetDir
            $Shortcut.IconLocation = "$icoFile,0"
        }

        $Shortcut.Description = "Painel de Comando MTZ - Clocks, Tweaks, Cursores e Desempenho"
        $Shortcut.Save()
        Write-Host "[+] Atalho 'Painel de Comando MTZ' criado em: $desk" -ForegroundColor Green
    } catch {
        # Ignora restricoes de permissao se executado sem elevacao
    }
}
