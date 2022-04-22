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

  Version:  1.0.2
  Date:     2022-04-22
  Author:   Egor Naidovich
  Changes:  Added logging to EventLog and Logfile

.EXAMPLE
  PS> .\Start-TempCleanup.ps1
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator
#Requires -Modules @{ ModuleName="AdminAbiitNlog"; RequiredVersion="0.0.1" }

$scriptName = $MyInvocation.MyCommand.Name.Replace('.ps1','')
$LogName = 'AdminAbiit'
$NlogConfig = Get-NLogConfiguration

$FileLogTarget = New-NLogTarget -FileTarget
$FileLogTarget.FileName = '{0}/Logs/{1}/{2}.log' -f $env:windir, $LogName, $scriptName
$FileLogTarget.Layout = '${longdate} | ${level:uppercase=true} | ${message:withexception=true}'
$FileLogTarget.Name = 'FileTarget'
$FileLogTarget.ArchiveFileName = '{0}/Logs/{1}/{2}{3}.log' -f $env:windir, $LogName, $scriptName, '#'
$FileLogTarget.ArchiveEvery = 'Day'
$FileLogTarget.ArchiveNumbering = 'Date'
$FileLogTarget.ArchiveDateFormat = 'yyyyMMdd'
$FileLogTarget.MaxArchiveFiles = '14'

$EventLogTarget = New-NLogTarget -EventLogTarget
$EventLogTarget.Log = $LogName
$EventLogTarget.Layout = '${message}'
$EventLogTarget.Name = 'EventTarget'
$EventLogTarget.Source = $scriptName

$NlogConfig.AddRule([NLog.LogLevel]::Debug, [Nlog.LogLevel]::Fatal, $FileLogTarget)
$NlogConfig.AddRule([NLog.LogLevel]::Info, [Nlog.LogLevel]::Fatal, $EventLogTarget)

Set-NLogConfiguration -Configuration $NlogConfig

$log = Get-NLogLogger
$msg = 'Started script: {0}' -f $scriptName
$log.Info($msg)

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

$regeditFlag = 'StateFlags0004'
$regeditValue = 2

foreach ($s in $SettingsList) {
  $StrPath = '{0}\{1}' -f $RegeditPath, $s
  if (Test-Path -Path $StrPath) {
      if ($(Get-ItemProperty -path $StrPath -Name $regeditFlag -ErrorAction SilentlyContinue).$regeditFlag -ne $regeditValue) {
        Set-ItemProperty -Path $StrPath -Name $regeditFlag -Value $regeditValue
        $msg = 'regedit: {0} at {1} is set to: {2}' -f $regeditFlag, $s, $regeditValue
        $log.Info($msg)
      }
  }
}

$CleanmgrPath = '{0}\System32\CleanMgr.exe' -f $env:SystemRoot
Start-Process -FilePath $CleanmgrPath -ArgumentList '/sagerun:4' -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue

$usersPath = '{0}\Users' -f $env:SystemDrive
$Users = Get-ChildItem -Path $usersPath

foreach ($u in $Users) {
  $curTempPath = '{0}\AppData\Local\Temp\*' -f $u.FullName
  if (Test-Path -Path $curTempPath) {
    try {
      Remove-Item -Path $curTempPath -Force -Recurse -ErrorAction Stop
    } catch {
      $log.Debug($_.ToString())
    }
  }
}

$RecyclePath = '{0}\$Recycle.bin\*' -f $env:SystemDrive
Remove-Item -Path $RecyclePath -Recurse -Force

$log.Info("Cleanup completed.")
[NLog.LogManager]::Shutdown()
