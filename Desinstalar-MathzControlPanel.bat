@echo off
:: ==============================================================================
:: DESINSTALADOR - PAINEL DE COMANDO MTZ
:: ==============================================================================
setlocal
cd /d "%~dp0"
if exist "%~dp0MathzControlPanel.exe" (
    start "" "%~dp0MathzControlPanel.exe" /uninstall
) else if exist "%LOCALAPPDATA%\MathzControlPanel\MathzControlPanel.exe" (
    start "" "%LOCALAPPDATA%\MathzControlPanel\MathzControlPanel.exe" /uninstall
) else (
    echo Desinstalando atalhos e registros residuais...
    del /f /q "%USERPROFILE%\Desktop\Painel de Comando MTZ.lnk" >nul 2>&1
    del /f /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Painel de Comando MTZ.lnk" >nul 2>&1
    reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\MathzControlPanel" /f >nul 2>&1
    echo Painel de Comando MTZ removido.
    pause
)
exit
