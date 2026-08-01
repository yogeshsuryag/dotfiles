[CmdletBinding()]
param(
    [ValidateSet('0', '1')] [string] $DarkMode = '0',
    [ValidateSet('0', '1')] [string] $ShowFileExtensions = '0',
    [ValidateSet('0', '1')] [string] $ShowHiddenFiles = '0',
    [ValidateSet('0', '1')] [string] $HideDesktopIcons = '0',
    [ValidateSet('0', '1')] [string] $TaskbarAutoHide = '0',
    [ValidateSet('0', '1')] [string] $KeyboardRepeat = '0',
    [ValidateRange(0, 3)] [int] $KeyboardDelay = 0,
    [ValidateRange(0, 31)] [int] $KeyboardSpeed = 31,
    [ValidateSet('0', '1')] [string] $RestartExplorer = '0'
)

$ErrorActionPreference = 'Stop'

function Set-UserDword([string] $Path, [string] $Name, [int] $Value) {
    New-Item -Path $Path -Force | Out-Null
    New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
}

function Set-UserString([string] $Path, [string] $Name, [string] $Value) {
    New-Item -Path $Path -Force | Out-Null
    New-ItemProperty -Path $Path -Name $Name -PropertyType String -Value $Value -Force | Out-Null
}

function Set-ExplorerSetting([string] $Name, [int] $Value) {
    Set-UserDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' $Name $Value
}

$changedExplorer = $false

if ($DarkMode -eq '1') {
    Set-UserDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'AppsUseLightTheme' 0
    Set-UserDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'SystemUsesLightTheme' 0
    Write-Host 'Enabled dark mode for apps and Windows.'
}

if ($ShowFileExtensions -eq '1') {
    Set-ExplorerSetting 'HideFileExt' 0
    $changedExplorer = $true
    Write-Host 'Enabled file extensions in Explorer.'
}

if ($ShowHiddenFiles -eq '1') {
    Set-ExplorerSetting 'Hidden' 1
    Write-Host 'Enabled hidden files in Explorer.'
    $changedExplorer = $true
}

if ($HideDesktopIcons -eq '1') {
    Set-ExplorerSetting 'HideIcons' 1
    Write-Host 'Hidden desktop icons.'
    $changedExplorer = $true
}

if ($TaskbarAutoHide -eq '1') {
    $taskbarPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
    if (Test-Path $taskbarPath) {
        $settings = (Get-ItemProperty -Path $taskbarPath -Name Settings).Settings
        if ($settings.Length -gt 8) {
            # StuckRects3 byte 8 is 03 for auto-hide and 02 for always visible.
            $settings[8] = 3
            Set-ItemProperty -Path $taskbarPath -Name Settings -Value $settings
            $changedExplorer = $true
            Write-Host 'Enabled taskbar auto-hide.'
        }
    } else {
        Write-Warning 'Taskbar registry settings were not found; skipped auto-hide.'
    }
}

if ($KeyboardRepeat -eq '1') {
    Set-UserString 'HKCU:\Control Panel\Keyboard' 'KeyboardDelay' "$KeyboardDelay"
    Set-UserString 'HKCU:\Control Panel\Keyboard' 'KeyboardSpeed' "$KeyboardSpeed"
    Write-Host "Set keyboard repeat delay=$KeyboardDelay speed=$KeyboardSpeed."
}

if ($RestartExplorer -eq '1' -and $changedExplorer) {
    Write-Host 'Restarting Explorer to apply Explorer and taskbar settings.'
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer.exe
}
