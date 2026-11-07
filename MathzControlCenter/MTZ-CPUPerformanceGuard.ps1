# MTZ CPU Performance Guard
# Persiste apenas políticas suportadas pelo Windows; não grava MSR nem contorna BIOS/firmware.
[CmdletBinding()]
param([ValidateSet('Extreme','Balanced','Eco')][string]$Mode = 'Extreme')
$ErrorActionPreference = 'SilentlyContinue'
$ultimate = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
$high = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
$balanced = '381b4222-f694-41f0-9685-ff5bb260df2e'
$eco = 'a1841308-3541-4fab-bc81-f71556f20b4a'
$scheme = switch ($Mode) { 'Balanced' {$balanced} 'Eco' {$eco} default {$ultimate} }
$plans = powercfg -list
if ($Mode -eq 'Extreme' -and $plans -notmatch $ultimate) { powercfg -duplicatescheme $ultimate | Out-Null }
powercfg -setactive $scheme
if ($Mode -eq 'Extreme') {
  powercfg -setacvalueindex $scheme SUB_PROCESSOR PROCTHROTTLEMIN 100
  powercfg -setacvalueindex $scheme SUB_PROCESSOR PROCTHROTTLEMAX 100
  powercfg -setdcvalueindex $scheme SUB_PROCESSOR PROCTHROTTLEMIN 100
  powercfg -setdcvalueindex $scheme SUB_PROCESSOR PROCTHROTTLEMAX 100
  powercfg -setacvalueindex $scheme SUB_PROCESSOR CPMINCORES 100
  powercfg -setdcvalueindex $scheme SUB_PROCESSOR CPMINCORES 100
  powercfg -setacvalueindex $scheme SUB_PROCESSOR PERFBOOSTMODE 2
  powercfg -setdcvalueindex $scheme SUB_PROCESSOR PERFBOOSTMODE 2
}
powercfg -setactive $scheme
if ($Mode -eq 'Extreme') { powercfg -change -standby-timeout-ac 0; powercfg -change -hibernate-timeout-ac 0 }
