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

function Normalize-Path([string] $Path) {
    return [System.IO.Path]::GetFullPath($Path)
}

function Get-DotfilesHardLinkPaths([string] $Path) {
    $fsutil = Get-Command 'fsutil.exe' -ErrorAction SilentlyContinue
    if ($null -eq $fsutil) {
        return @()
    }

    $output = @(& $fsutil.Name hardlink list $Path 2>$null)
    if ($LASTEXITCODE -ne 0) {
        return @()
    }

    $paths = @()
    foreach ($line in $output) {
        $candidate = ([string] $line).Trim()
        $candidate = $candidate -replace '^\\\?\?\\', ''
        if (-not $candidate) {
            continue
        }
        try {
            $paths += Normalize-Path $candidate
        } catch {
            continue
        }
    }
    return @($paths | Select-Object -Unique)
}

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

function Ensure-Parent([string] $Path) {
    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
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

$RepoRoot = Normalize-Path $RepoRoot
$documentsDir = if ([string]::IsNullOrWhiteSpace($DocumentsDir)) {
    [Environment]::GetFolderPath('MyDocuments')
} else {
    Normalize-Path $DocumentsDir
}
if ([string]::IsNullOrWhiteSpace($documentsDir)) {
    $documentsDir = Join-Path $UserHome 'Documents'
}

$links = @(
    @{ Source = $RepoRoot; Target = $DotfilesLinkPath },
    @{ Source = (Join-Path $RepoRoot 'home/.config/nvim'); Target = $NvimConfigDir },
    @{ Source = (Join-Path $RepoRoot 'home/.config/oh-my-posh'); Target = (Join-Path $XdgConfigHome 'oh-my-posh') },
    @{ Source = (Join-Path $RepoRoot 'home/.config/herdr'); Target = $HerdrConfigDir },
    @{ Source = (Join-Path $RepoRoot 'home/.claude/settings.json'); Target = (Join-Path $ClaudeConfigDir 'settings.json') },
    @{ Source = (Join-Path $RepoRoot 'home/.claude/status-line.js'); Target = (Join-Path $ClaudeConfigDir 'status-line.js') },
    @{ Source = (Join-Path $RepoRoot 'home/.pi/agent/themes'); Target = (Join-Path $PiAgentDir 'themes') },
    @{ Source = (Join-Path $RepoRoot 'home/.pi/agent/extensions'); Target = (Join-Path $PiAgentDir 'extensions') },
    @{ Source = (Join-Path $RepoRoot 'home/.pi/agent/models.json'); Target = (Join-Path $PiAgentDir 'models.json') },
    @{ Source = (Join-Path $RepoRoot 'home/.pi/agent/settings.json'); Target = (Join-Path $PiAgentDir 'settings.json') },
    @{ Source = (Join-Path $RepoRoot 'home/AGENTS.md'); Target = (Join-Path $ClaudeConfigDir 'CLAUDE.md') },
    @{ Source = (Join-Path $RepoRoot 'home/AGENTS.md'); Target = (Join-Path $CodexConfigDir 'AGENTS.md') },
    @{ Source = (Join-Path $RepoRoot 'home/AGENTS.md'); Target = (Join-Path $OpencodeConfigDir 'AGENTS.md') },
    @{ Source = (Join-Path $RepoRoot 'home/.config/powershell/Microsoft.PowerShell_profile.ps1'); Target = (Join-Path $documentsDir 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1') },
    @{ Source = (Join-Path $RepoRoot 'home/.config/powershell/Microsoft.PowerShell_profile.ps1'); Target = (Join-Path $documentsDir 'PowerShell\Microsoft.PowerShell_profile.ps1') }
)

foreach ($link in $links) {
    $source = Normalize-Path $link.Source
    $target = Normalize-Path $link.Target
    Remove-ManagedLink $source $target
    if ($RestoreBackups -eq '1') {
        Restore-Backup $target
    }
}
