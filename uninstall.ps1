[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]] $CliArguments
)

$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath($PSScriptRoot)
$env:DOTFILES_ROOT = $root

function Show-DotfilesUninstallUsage {
    Write-Error 'Usage: .\uninstall.ps1 [--check|--configure] [--keep-backups] [--yes]' -ErrorAction Continue
}

$checkOnly = $false
$configure = $false
$restoreBackups = '1'
$assumeYes = $false
foreach ($argument in @($CliArguments | Where-Object { $null -ne $_ -and $_ -ne '' })) {
    switch ($argument) {
        '--check' { $checkOnly = $true }
        '--configure' { $configure = $true }
        '--keep-backups' { $restoreBackups = '0' }
        '--yes' { $assumeYes = $true }
        default {
            Show-DotfilesUninstallUsage
            exit 2
        }
    }
}

. (Join-Path $root 'windows-common.ps1')

try {
    $configuration = Get-DotfilesConfiguration -Root $root -CheckOnly:$checkOnly -Configure:($configure -and -not $checkOnly)
    $config = $configuration.Values
    Assert-DotfilesConfig $config

    if ($checkOnly) {
        Write-Host "Windows dotfiles uninstall configuration is valid: $($configuration.Path)"
        Write-Host "Repository: $root"
        Write-Host "User home: $($config.DOTFILES_WINDOWS_HOME)"
        Write-Host "Restore backups: $([bool]($restoreBackups -eq '1'))"
        exit 0
    }

    Write-Host 'This will remove only repository-managed links, shell startup blocks, and the managed Git Bash hook.'
    if ($restoreBackups -eq '1') {
        Write-Host 'Matching .dotfiles-backup-* targets will be restored when the destination is empty.'
    } else {
        Write-Host 'Existing .dotfiles-backup-* targets will be left untouched.'
    }
    Write-Host 'Registry settings, Scoop packages, MSYS2, zsh, Herdr, and agent CLIs will not be uninstalled.'

    if (-not $assumeYes) {
        if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
            throw 'Refusing to uninstall without an interactive confirmation. Use --yes only after reviewing the targets.'
        }
        $confirmation = Read-Host 'Type UNINSTALL to continue'
        if ($confirmation -ne 'UNINSTALL') {
            Write-Host 'Uninstall cancelled.'
            exit 0
        }
    }

    Write-Host '==> Removing repository-managed Windows links'
    Invoke-DotfilesUninstallLinks $root $config $restoreBackups
    Write-Host '==> Removing the managed Git Bash hook'
    Remove-DotfilesBashHook $config
    $msys2Root = Get-DotfilesMsys2Root
    if ($msys2Root) {
        Write-Host '==> Removing the managed MSYS2 zsh startup block'
        Remove-DotfilesZshStartup $msys2Root
        Remove-DotfilesMsys2Plugins $msys2Root
    }

    Write-Host 'Windows dotfiles uninstall complete.'
    Write-Host 'Review any remaining .dotfiles-backup-* paths before deleting them.'
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
