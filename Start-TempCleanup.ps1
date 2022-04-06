<# 
.SYNOPSIS 
    Start-TempCleanup запускает очистку системы. 

.DESCRIPTION 
    Записываются параметры очистки в ветку реестра 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\'
    Затем производится автоматическая очистка мусора по средствам cleanmgr.
    После - очистка папки Temp и корзины у всех у всех пользователей в этой системе. 

.INPUTS
    None

.OUTPUTS
    None

.NOTES
    Author: Наидович Егор
    Author: Елисеев Вячеслав
    Date: 2022-04-06
    Version 1.0.0 - inicial 
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

$RegeditPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'

foreach ($i in $SettingsList) {
    $StrPath = ("{0}\{1}" -f $RegeditPath, $i)
    Set-iProperty -Path $StrPath -Name "StateFlags0004" -Value 2 -ErrorAction SilentlyContinue
}
Start-Process -FilePath CleanMgr.exe -ArgumentList '/sagerun:4' -WindowStyle Hidden -Wait  

$Users = Get-Childi -Path 'C:\Users'
$TempPath = 'AppData\Local\Temp\*'
foreach ($u in $Users) {
    $FullTempPath = ("{0}\{1}" -f $u.FullName, $TempPath)
    if (Test-Path -Path $FullTempPath) {
        Remove-i -Path $FullTempPath -Force -Recurse -ErrorAction Ignore
    }
}

Clear-RecycleBin -Force