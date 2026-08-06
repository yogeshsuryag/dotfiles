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
    [ValidateSet('junction', 'symbolic')] [string] $LinkMode = 'junction',
    [ValidateSet('0', '1')] [string] $BackupExisting = '1'
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

function Test-DotfilesManagedHardLink([string] $Source, [string] $Target, [System.IO.FileSystemInfo] $Item) {
    if ($Item.PSIsContainer -or (($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
        return $false
    }
    $expectedSource = Normalize-Path $Source
    return @(Get-DotfilesHardLinkPaths $Target) -contains $expectedSource
}

function Ensure-Parent([string] $Path) {
    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function Backup-Existing([string] $Target) {
    if ($BackupExisting -ne '1') {
        throw "Target already exists and is not a link: $Target. Set DOTFILES_BACKUP_EXISTING=1 to preserve it automatically."
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = "$Target.dotfiles-backup-$stamp"
    $suffix = 0
    while (Test-Path -LiteralPath $backup) {
        $suffix++
        $backup = "$Target.dotfiles-backup-$stamp-$suffix"
    }
    Move-Item -LiteralPath $Target -Destination $backup -Force
    Write-Host "Backed up $Target to $backup"
}

function Remove-Link([System.IO.FileSystemInfo] $Item, [string] $Target) {
    if (($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
        return $false
    }
    if ($Item.PSIsContainer) {
        [System.IO.Directory]::Delete($Target, $false)
    } else {
        [System.IO.File]::Delete($Target)
    }
    return $true
}

function New-DotfilesLink([string] $Source, [string] $Target, [ValidateSet('Directory', 'File')] [string] $Kind) {
    if (-not (Test-Path -LiteralPath $Source -PathType Any)) {
        throw "Source does not exist: $Source"
    }

    if ($LinkMode -eq 'junction' -and $Kind -eq 'File') {
        $sourceRoot = [System.IO.Path]::GetPathRoot((Normalize-Path $Source))
        $targetRoot = [System.IO.Path]::GetPathRoot((Normalize-Path $Target))
        if (-not [string]::Equals($sourceRoot, $targetRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Hard links require the repository and the target on the same volume (source: $sourceRoot, target: $targetRoot). Move the repository to the same volume as the Windows profile, or set DOTFILES_LINK_MODE=symbolic."
        }
    }

    Ensure-Parent $Target
    $existing = Get-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        if (-not (Remove-Link $existing $Target)) {
            if ($Kind -eq 'File' -and $LinkMode -eq 'junction' -and (Test-DotfilesManagedHardLink $Source $Target $existing)) {
                [System.IO.File]::Delete($Target)
            } else {
                Backup-Existing $Target
            }
        }
    }

    $itemType = if ($LinkMode -eq 'symbolic') {
        'SymbolicLink'
    } elseif ($Kind -eq 'Directory') {
        'Junction'
    } else {
        'HardLink'
    }
    New-Item -ItemType $itemType -Path $Target -Target $Source | Out-Null
    Write-Host "$itemType $Target -> $Source"
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

$profileSource = Join-Path $RepoRoot 'home/.config/powershell/Microsoft.PowerShell_profile.ps1'
$links = @(
    @{ Source = $RepoRoot; Target = $DotfilesLinkPath; Kind = 'Directory' },
    @{ Source = (Join-Path $RepoRoot 'home/.config/nvim'); Target = $NvimConfigDir; Kind = 'Directory' },
    @{ Source = (Join-Path $RepoRoot 'home/.config/oh-my-posh'); Target = (Join-Path $XdgConfigHome 'oh-my-posh'); Kind = 'Directory' },
    @{ Source = (Join-Path $RepoRoot 'home/.config/herdr'); Target = $HerdrConfigDir; Kind = 'Directory' },
    @{ Source = (Join-Path $RepoRoot 'home/.claude/settings.json'); Target = (Join-Path $ClaudeConfigDir 'settings.json'); Kind = 'File' },
    @{ Source = (Join-Path $RepoRoot 'home/.claude/status-line.js'); Target = (Join-Path $ClaudeConfigDir 'status-line.js'); Kind = 'File' },
    @{ Source = (Join-Path $RepoRoot 'home/.pi/agent/themes'); Target = (Join-Path $PiAgentDir 'themes'); Kind = 'Directory' },
    @{ Source = (Join-Path $RepoRoot 'home/.pi/agent/extensions'); Target = (Join-Path $PiAgentDir 'extensions'); Kind = 'Directory' },
    @{ Source = (Join-Path $RepoRoot 'home/.pi/agent/models.json'); Target = (Join-Path $PiAgentDir 'models.json'); Kind = 'File' },
    @{ Source = (Join-Path $RepoRoot 'home/.pi/agent/settings.json'); Target = (Join-Path $PiAgentDir 'settings.json'); Kind = 'File' },
    @{ Source = (Join-Path $RepoRoot 'home/AGENTS.md'); Target = (Join-Path $ClaudeConfigDir 'CLAUDE.md'); Kind = 'File' },
    @{ Source = (Join-Path $RepoRoot 'home/AGENTS.md'); Target = (Join-Path $CodexConfigDir 'AGENTS.md'); Kind = 'File' },
    @{ Source = (Join-Path $RepoRoot 'home/AGENTS.md'); Target = (Join-Path $OpencodeConfigDir 'AGENTS.md'); Kind = 'File' },
    @{ Source = $profileSource; Target = (Join-Path $documentsDir 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'); Kind = 'File' },
    @{ Source = $profileSource; Target = (Join-Path $documentsDir 'PowerShell\Microsoft.PowerShell_profile.ps1'); Kind = 'File' }
)

foreach ($link in $links) {
    New-DotfilesLink -Source (Normalize-Path $link.Source) -Target (Normalize-Path $link.Target) -Kind $link.Kind
}
