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
  Author:   Viacheslav Eliseev
  Changes:  Initial version

.EXAMPLE
  PS> .\Start-TempCleanup.ps1
#>

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

$LogName = 'TempCleanup'
if ([System.Diagnostics.EventLog]::Exists($LogName -eq $False)) {
  New-EventLog -LogName 'TempCleanup' -Source 'Start-TempCleanup.ps1'
}

Write-EventLog -LogName $LogName -Source 'Start-TempCleanup.ps1' -EntryType 'Information' -EventId 1 -Message 'Cleaning cleanmgr started.'

$RegeditPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
foreach ($s in $SettingsList) {
  $StrPath = '{0}\{1}' -f $RegeditPath, $s
  if (Test-Path -Path $StrPath) {
    Set-ItemProperty -Path $StrPath -Name 'StateFlags0004' -Value 2
  }
}

$CleanmgrPath = '{0}\System32\CleanMgr.exe' -f $env:SystemRoot
try {
  Start-Process -FilePath $CleanmgrPath -ArgumentList '/sagerun:4' -WindowStyle Hidden -Wait
  Write-EventLog -LogName $LogName -Source 'Start-TempCleanup.ps1' -EntryType 'Information' -EventId 1 -Message 'Cleaning cleanmgr completed.'
}
catch {
  Write-EventLog -LogName $LogName -Source 'Start-TempCleanup.ps1' -EntryType 'Information' -EventId 1111 -Message 'Error cleanmgr'
}


$Users = Get-ChildItem -Path 'C:\Users'
foreach ($u in $Users) {
  $curTempPath = '{0}\AppData\Local\Temp\*' -f $u.FullName
  if (Test-Path -Path $curTempPath) {
    Remove-Item -Path $curTempPath -Force -Recurse -ErrorAction Ignore
  }
}
Write-EventLog -LogName $LogName -Source 'Start-TempCleanup.ps1' -EntryType 'Information' -EventId 1 -Message 'Cleaning Temp completed.'

$RecyclePath = '{0}\$Recycle.bin\' -f $env:SystemDrive
try {
  Get-ChildItem $RecyclePath -Force | Remove-Item -Recurse -Force
  Write-EventLog -LogName $LogName -Source 'Start-TempCleanup.ps1' -EntryType 'Information' -EventId 1 -Message 'Cleaning Recycle.bin completed.'
}
catch {
  Write-EventLog -LogName $LogName -Source 'Start-TempCleanup.ps1' -EntryType 'Information' -EventId 1111 -Message 'Error Recycle.bin'
}
