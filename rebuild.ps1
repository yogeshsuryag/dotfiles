[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]] $CliArguments
)

$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath($PSScriptRoot)
$env:DOTFILES_ROOT = $root

function Show-DotfilesRebuildUsage {
    Write-Error 'Usage: .\rebuild.ps1 [--check|--configure]' -ErrorAction Continue
}

$argumentList = @($CliArguments | Where-Object { $null -ne $_ -and $_ -ne '' })
if ($argumentList.Count -gt 1 -or ($argumentList.Count -eq 1 -and $argumentList[0] -notin @('--check', '--configure'))) {
    Show-DotfilesRebuildUsage
    exit 2
}
$mode = if ($argumentList.Count -eq 1) { $argumentList[0] } else { '' }

. (Join-Path $root 'scripts/windows-common.ps1')

try {
    $configuration = Get-DotfilesConfiguration -Root $root -CheckOnly:($mode -eq '--check') -Configure:($mode -eq '--configure')
    $config = $configuration.Values
    Assert-DotfilesConfig $config

    if ($mode -eq '--check') {
        Write-Host "Windows dotfiles configuration is valid: $($configuration.Path)"
        exit 0
    }

    Install-DotfilesZsh $config
    Invoke-DotfilesLinks $root $config
    Install-DotfilesBashHook $root $config
    Invoke-DotfilesWindowsSettings $root $config

    Write-Host 'Windows dotfiles re-applied.'
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
