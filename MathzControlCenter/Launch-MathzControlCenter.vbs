' ==============================================================================
' LAUNCHER SILENCIOSO - MATHZ CONTROL CENTER
' Inicia o painel WPF sem exibir a janela preta do console do PowerShell
' ==============================================================================

Set objShell = CreateObject("Wscript.Shell")
strPath = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
strCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & strPath & "\MathzControlCenter.ps1"""
objShell.Run strCommand, 0, False
Set objShell = Nothing
