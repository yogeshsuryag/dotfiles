[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]] $CliArguments
)

$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath($PSScriptRoot)
$env:DOTFILES_ROOT = $root

function Show-DotfilesBootstrapUsage {
    Write-Error 'Usage: .\bootstrap.ps1 [--check|--configure]' -ErrorAction Continue
}

$argumentList = @($CliArguments | Where-Object { $null -ne $_ -and $_ -ne '' })
if ($argumentList.Count -gt 1 -or ($argumentList.Count -eq 1 -and $argumentList[0] -notin @('--check', '--configure'))) {
    Show-DotfilesBootstrapUsage
    exit 2
}
$mode = if ($argumentList.Count -eq 1) { $argumentList[0] } else { '' }

. (Join-Path $root 'scripts/windows-common.ps1')

try {
    if ($mode -ne '--check') {
        Ensure-DotfilesPowerShell7 -EntryPoint $PSCommandPath -CliArguments $CliArguments
    }

    $configuration = Get-DotfilesConfiguration -Root $root -CheckOnly:($mode -eq '--check') -Configure:($mode -eq '--configure')
    $config = $configuration.Values
    Assert-DotfilesConfig $config

    if ($mode -eq '--check') {
        Write-Host "Windows dotfiles configuration is valid: $($configuration.Path)"
        Write-Host "Repository: $root"
        Write-Host "User home: $($config.DOTFILES_WINDOWS_HOME)"
        Write-Host "Package manager: $($config.DOTFILES_PACKAGE_MANAGER)"
        Write-Host "Packages: $($config.DOTFILES_WINGET_PACKAGES)"
        Write-Host ''
        Write-Host 'Detected tools before installation:'
        foreach ($entry in @(Get-DotfilesPackagePlan $config)) {
            Write-Host ("  {0,-24} {1}" -f $entry.Name, (Get-DotfilesPlanEntryDetail $entry))
        }
        exit 0
    }

    Write-Host '==> Checking installed tools before installing anything'
    $plan = @(Get-DotfilesPackagePlan $config)
    if (-not (Invoke-DotfilesPackagePlanReview $plan)) {
        throw 'Installation cancelled. Nothing was installed.'
    }
    Write-Host '==> Installing approved tools'
    Invoke-DotfilesPackagePlan $config $plan
    Install-DotfilesHerdr $config
    Install-DotfilesZsh $config

    Write-Host '==> Installing Git Bash configuration hook'
    Invoke-DotfilesLinks $root $config
    Install-DotfilesBashHook $root $config
    Write-DotfilesHerdrConfig $root $config
    Invoke-DotfilesWindowsTerminalSettings $config
    Invoke-DotfilesWindowsSettings $root $config

    Write-Host '==> Bootstrap complete'
    Write-Host '    Restart Git Bash to load the new shell configuration.'
    Write-Host '    Restart PowerShell so the PowerShell 7 profile and Starship prompt load.'
    Write-Host '    Re-run .\rebuild.ps1 after changing repository files or windows-config.env.'
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
