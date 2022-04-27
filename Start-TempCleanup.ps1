<#PSScriptInfo

.VERSION 1.0.3

.GUID 05B9C36C-1FA3-5A11-A3E7-A728F3B4E4E3

.AUTHOR Winbackend Team

.COMPANYNAME AdminAbiit

.COPYRIGHT Copyright (c) 2022, AdminAbiit

.TAGS AdminAbiit, Winbackend, Script, Server

.EXTERNALMODULEDEPENDENCIES Nlog

.RELEASENOTES
  Version:  1.0.0
  Date:     2022-04-06
  Author:   Egor Naidovich
  Author:   Viachaslav Eliseev
  Changes:  Initial version

  Version:  1.0.1
  Date:     2022-04-22
  Author:   Egor Naidovich
  Changes:  Added logging to EventLog and Logfile

  Version:  1.0.2
  Date:     2022-04-23
  Author:   Oleg Galushko
  Changes:  Added stdout trace log
            Removed AdminAbiitNlog module requirement
             Removed cleanmgr.exe usage

  Version:  1.0.3
  Date:     2022-04-27
  Author:   Egor Naidovich
  Changes:  Fix logging to console
             
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.DESCRIPTION
  This script will remove all temporary files from users temp folders and recycle bins

.EXAMPLE
  PS> .\Start-TempCleanup.ps1
#>

# Install and assembly NLog
$NLogVersion = '4.7.15'

try {
  $null = Get-Package -Name 'NLog' -ErrorAction 'Stop' | Where-Object { $_.Version -eq $NLogVersion }
}
catch {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Write-Host 'Installing NLog...'
  Install-Package -Name 'NLog' `
    -ProviderName 'NuGet' `
    -Source 'https://nuget.org/api/v2/' `
    -Scope 'AllUsers' `
    -RequiredVersion $NLogVersion `
    -SkipDependencies `
    -Force
}
$NlogPackage = Get-Package -Name 'NLog' -ErrorAction 'SilentlyContinue' | Where-Object { $_.Version -eq $NLogVersion }
$NLogAssemblyPath = Split-Path -Path $NlogPackage.Source -Resolve -Parent
$NLogDllPath = Join-Path -Path $NLogAssemblyPath -ChildPath 'lib\net45\NLog.dll'

Write-Host "Loading NLog assembly from: $NLogDllPath"
$null = [System.Reflection.Assembly]::LoadFrom($NLogDllPath)


$ScriptName = $MyInvocation.MyCommand.Name.Replace('.ps1', '')

$LogName = 'AdminAbiit'
$FileLogPath = '{0}/Logs/{1}/{2}' -f $env:windir, $LogName, $scriptName

$NlogConfig = [NLog.Config.LoggingConfiguration]::New()

$ConsoleTarget = [NLog.Targets.ColoredConsoleTarget]::New()
$ConsoleTarget.Name = 'ConsoleTarget'

$FileTarget = [NLog.Targets.FileTarget]::New()
$FileTarget.Name = 'FileTarget'
$FileTarget.ArchiveDateFormat = 'yyyyMMdd'
$FileTarget.ArchiveEvery = 'Day'
$FileTarget.ArchiveFileName = '{0}{1}.log' -f $FileLogPath, '{#}'
$FileTarget.ArchiveNumbering = 'Date'
$FileTarget.FileName = '{0}.log' -f $FileLogPath
$FileTarget.Layout = '${longdate} | ${level:uppercase=true} | ${message:withexception=true}'
$FileTarget.MaxArchiveFiles = '14'

$EventTarget = [NLog.Targets.EventLogTarget]::New()
$EventTarget.Name = 'EventTarget'
$EventTarget.Layout = '${message}'
$EventTarget.Log = $LogName
$EventTarget.Source = $scriptName

$NlogConfig.AddRule([NLog.LogLevel]::Trace, [Nlog.LogLevel]::Fatal, $ConsoleTarget)
$NlogConfig.AddRule([NLog.LogLevel]::Trace, [Nlog.LogLevel]::Fatal, $FileTarget)
$NlogConfig.AddRule([NLog.LogLevel]::Info, [Nlog.LogLevel]::Fatal, $EventTarget)

[NLog.LogManager]::Configuration = $NlogConfig

$log = [NLog.LogManager]::GetCurrentClassLogger()

$log.Info('Starting script...')
$log.Debug('RunAs: {0}', $env:UserName)

$Users = Get-ChildItem -Path $('{0}\Users' -f $env:SystemDrive)

$log.Debug('Founded users paths: {0}', $($Users.Name -join ', '))
$log.Debug('Users count: {0}', $Users.Count)
$log.Debug('Scaning users temp folders...')

foreach ($u in $Users) {
  $curTempPath = '{0}\AppData\Local\Temp\*' -f $u.FullName
  $files = Get-ChildItem -Path $curTempPath -Recurse -ErrorAction 'SilentlyContinue'
  if (Test-Path -Path $curTempPath) {
    $size = [System.Math]::Round($($files | Measure-Object -Property 'Length' -Sum).Sum / 1GB, 3)
    $log.Debug('{0}: {1} files / {2} GB', $curTempPath, $files.count, $size)
    Get-ChildItem $curTempPath -Recurse -Force -File | Sort-Object -Property FullName -Descending | ForEach-Object {
      try {
        Remove-Item -Path $_.FullName -Force -ErrorAction Stop;
      }
      catch { $log.Trace($_.ToString()) }
    }
    $folders = Get-ChildItem $curTempPath -recurse | Where-Object { $_.PSIsContainer -eq $True } | `
      Where-Object { $_.GetFiles().Count -eq 0 }
    $folders | Foreach-Object { Remove-Item $_.FullName -recurse -ErrorAction 'SilentlyContinue' }
  }
}

$RecyclePath = '{0}\$Recycle.bin\*' -f $env:SystemDrive
$log.Info('Cleaning Recycle bin started')
Remove-Item -Path $RecyclePath -Recurse -Force
$log.Info('Cleaning Recycle bin finished')

$log.Info('Script finished.')
[NLog.LogManager]::Shutdown()
