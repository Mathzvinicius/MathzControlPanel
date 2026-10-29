' ==============================================================================
' LAUNCHER SILENCIOSO - PAINEL DE COMANDO MTZ
' ==============================================================================
Set objShell = CreateObject("Wscript.Shell")
strPath = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
strParent = CreateObject("Scripting.FileSystemObject").GetParentFolderName(strPath)

If CreateObject("Scripting.FileSystemObject").FileExists(strParent & "\MathzControlPanel.exe") Then
    objShell.Run """" & strParent & "\MathzControlPanel.exe""", 0, False
ElseIf CreateObject("Scripting.FileSystemObject").FileExists(strPath & "\MathzControlPanel.exe") Then
    objShell.Run """" & strPath & "\MathzControlPanel.exe""", 0, False
Else
    strCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & strPath & "\MathzControlCenter.ps1"""
    objShell.Run strCommand, 0, False
End If

Set objShell = Nothing
