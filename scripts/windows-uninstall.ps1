[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $RepoRoot,
    [Parameter(Mandatory = $true)] [string] $UserHome,
    [Parameter(Mandatory = $true)] [string] $LocalAppData,
    [Parameter(Mandatory = $true)] [string] $AppData,
    [Parameter(Mandatory = $true)] [string] $XdgConfigHome,
    [Parameter(Mandatory = $true)] [string] $DotfilesLinkPath,
    [Parameter(Mandatory = $true)] [string] $NvimConfigDir,
    [AllowNull()] [string] $DocumentsDir = $null,
    [Parameter(Mandatory = $true)] [string] $HerdrConfigDir,
    [Parameter(Mandatory = $true)] [string] $ClaudeConfigDir,
    [Parameter(Mandatory = $true)] [string] $CodexConfigDir,
    [Parameter(Mandatory = $true)] [string] $OpencodeConfigDir,
    [Parameter(Mandatory = $true)] [string] $PiAgentDir,
    [ValidateSet('0', '1')] [string] $RestoreBackups = '1'
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'windows-link-manifest.ps1')

function Is-ManagedHardLink([string] $Source, [string] $Target, [System.IO.FileSystemInfo] $Item) {
    if ($Item.PSIsContainer -or (($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
        return $false
    }
    $expectedSource = Normalize-Path $Source
    return @(Get-DotfilesHardLinkPaths $Target) -contains $expectedSource
}

function Get-ExistingItem([string] $Path) {
    return Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
}

function Is-ReparsePoint([System.IO.FileSystemInfo] $Item) {
    return (($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Is-ManagedLink([string] $Source, [string] $Target, [System.IO.FileSystemInfo] $Item) {
    if (-not (Is-ReparsePoint $Item)) {
        return Is-ManagedHardLink $Source $Target $Item
    }

    $expectedSource = Normalize-Path $Source
    $targetValues = @($Item.Target)
    if ($targetValues.Count -gt 0 -and $targetValues[0]) {
        foreach ($targetValue in $targetValues) {
            if ((Normalize-Path ([string] $targetValue)) -eq $expectedSource) {
                return $true
            }
        }
        return $false
    }

    try {
        $resolvedTarget = Normalize-Path ((Resolve-Path -LiteralPath $Target -ErrorAction Stop).Path)
        $resolvedSource = Normalize-Path $Source
        return $resolvedTarget -eq $resolvedSource
    } catch {
        # A broken or inaccessible link is not safe to identify automatically.
        return $false
    }
}

function Get-LatestBackup([string] $Target) {
    $parent = Split-Path -Parent $Target
    $leaf = Split-Path -Leaf $Target
    if (-not $parent -or -not $leaf) {
        return $null
    }

    return Get-ChildItem -LiteralPath $parent -Filter "$leaf.dotfiles-backup-*" -Force -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

function Restore-Backup([string] $Target) {
    if ($null -ne (Get-ExistingItem $Target)) {
        Write-Host "Keeping existing target; no backup restored: $Target"
        return
    }

    $backup = Get-LatestBackup $Target
    if ($null -eq $backup) {
        return
    }

    Ensure-Parent $Target
    Move-Item -LiteralPath $backup.FullName -Destination $Target -Force
    Write-Host "Restored $Target from $($backup.FullName)"
}

function Remove-ManagedLink([string] $Source, [string] $Target) {
    $item = Get-ExistingItem $Target
    if ($null -eq $item) {
        return
    }

    if (-not (Is-ManagedLink $Source $Target $item)) {
        if (Is-ReparsePoint $item) {
            Write-Warning "Skipping reparse point that does not resolve to this repository: $Target"
        } else {
            Write-Host "Keeping real target: $Target"
        }
        return
    }

    if ($item.PSIsContainer) {
        [System.IO.Directory]::Delete($Target, $false)
    } else {
        [System.IO.File]::Delete($Target)
    }
    Write-Host "Removed managed link: $Target"
}

$links = Get-DotfilesLinkManifest `
    -RepoRoot $RepoRoot `
    -UserHome $UserHome `
    -LocalAppData $LocalAppData `
    -AppData $AppData `
    -XdgConfigHome $XdgConfigHome `
    -DotfilesLinkPath $DotfilesLinkPath `
    -NvimConfigDir $NvimConfigDir `
    -DocumentsDir $DocumentsDir `
    -HerdrConfigDir $HerdrConfigDir `
    -ClaudeConfigDir $ClaudeConfigDir `
    -CodexConfigDir $CodexConfigDir `
    -OpencodeConfigDir $OpencodeConfigDir `
    -PiAgentDir $PiAgentDir

foreach ($link in $links) {
    $source = Normalize-Path $link.Source
    $target = Normalize-Path $link.Target
    Remove-ManagedLink $source $target
    if ($RestoreBackups -eq '1') {
        Restore-Backup $target
    }
}
