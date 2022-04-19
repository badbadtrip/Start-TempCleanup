<#
.SYNOPSIS
  System cleanup script

.DESCRIPTION
  The cleaning parameters are written to the
  'HKLM' registry branch:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\',
  the list of subfolders of which can be seen in the $Settings List.
  Then the garbage is automatically cleaned by means of cleanmgr, taking into account the system folder.
  After that, the Temp folder and the trash are cleared for all users in this system.

.INPUTS
  None

.OUTPUTS
  None

.NOTES
  Version:  1.0.0
  Date:     2022-04-06
  Author:   Egor Naidovich
  Author:   Viachaslav Eliseev
  Changes:  Initial version

  Version:  1.0.1
  Date:     2022-04-19
  Author:   Egor Naidovich
  Changes:  Added logging to EventLog

.EXAMPLE
  PS> .\Start-TempCleanup.ps1
#>
$watch = [System.Diagnostics.Stopwatch]::StartNew()
$watch.Start()
Import-Module AdminAbiitNlog 

$LogName = 'AdminAbiit'
if (![System.Diagnostics.EventLog]::Exists($LogName)) {
  New-EventLog -LogName 'AdminAbiit' -Source 'Start-TempCleanup.ps1'
}
$Target = New-NLogTarget -EventLogTarget
$Target.Log = $LogName
Enable-NLogLogging -Target $Target -MinimumLevel Trace
$Target.Source = 'Start-TempCleanup'
$logger = Get-NLogLogger

$RegeditPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'

$SettingsList = @(
  'Active Setup Temp Folders',
  'D3D Shader Cache',
  'Delivery Optimization Files',
  'Diagnostic Data Viewer database files',
  'Downloaded Program Files',
  'DownloadsFolder',
  'Internet Cache Files',
  'Old ChkDsk Files',
  'Recycle Bin',
  'Service Pack Cleanup',
  'Setup Log Files',
  'System error memory dump files',
  'System error minidump files',
  'Temporary Files',
  'Thumbnail Cache',
  'Update Cleanup',
  'Windows Defender',
  'Windows Error Reporting Files'
)

$PachTemp = @()
foreach ($s in $SettingsList) {
  $StrPath = '{0}\{1}' -f $RegeditPath, $s
  if (Test-Path -Path $StrPath) {
    Set-ItemProperty -Path $StrPath -Name 'StateFlags0004' -Value 2
    $PachTemp += $s + "`n"
  }
}
$logger.Info("`nPATH $RegeditPath :`n$PachTemp")

$CleanmgrPath = '{0}\System32\CleanMgr.exe' -f $env:SystemRoot
Start-Process -FilePath $CleanmgrPath -ArgumentList '/sagerun:4' -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue

$ErrorTemp = @()
$Users = Get-ChildItem -Path 'C:\Users'
foreach ($u in $Users) {
  $curTempPath = '{0}\AppData\Local\Temp\*' -f $u.FullName
  if (Test-Path -Path $curTempPath) {
    Remove-Item -Path $curTempPath -Force -Recurse -ErrorAction SilentlyContinue -ErrorVariable ErrTmpClean
  }
}
foreach ($x in $ErrTmpClean) {
  $ErrorTemp += $x.TargetObject.FullName + "`n"
}
$logger.Warn("`nProcess cannot access files:`n$ErrorTemp") 

$RecyclePath = '{0}\$Recycle.bin\' -f $env:SystemDrive
Get-ChildItem $RecyclePath -Force | Remove-Item -Recurse -Force

$Watch.Stop()
$TimeRun = $Watch.Elapsed.TotalSeconds
$TimeRun = [math]::Round($TimeRun, 2)
$logger.Info("`nCleanup completed, run time: $TimeRun seconds") 