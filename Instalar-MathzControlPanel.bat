@echo off
:: ==============================================================================
:: INSTALADOR UNIVERSAL - PAINEL DE COMANDO MTZ (STANDALONE EXE)
:: ==============================================================================
setlocal
cd /d "%~dp0"
if exist "%~dp0MathzControlPanel.exe" (
    start "" "%~dp0MathzControlPanel.exe" /install
) else (
    echo Executavel MathzControlPanel.exe nao encontrado nesta pasta.
    pause
)
exit
