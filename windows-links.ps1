[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $RepoRoot,
    [Parameter(Mandatory = $true)] [string] $UserHome,
    [Parameter(Mandatory = $true)] [string] $LocalAppData,
    [Parameter(Mandatory = $true)] [string] $AppData,
    [Parameter(Mandatory = $true)] [string] $XdgConfigHome,
    [Parameter(Mandatory = $true)] [string] $DotfilesLinkPath,
    [Parameter(Mandatory = $true)] [string] $NvimConfigDir,
    [Parameter(Mandatory = $true)] [string] $WeztermConfigDir,
    [Parameter(Mandatory = $true)] [string] $WeztermConfigFile,
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
    while (Test-Path -LiteralPath $backup -Force) {
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
    Remove-Item -LiteralPath $Target -Force
    return $true
}

function New-DotfilesLink([string] $Source, [string] $Target, [ValidateSet('Directory', 'File')] [string] $Kind) {
    if (-not (Test-Path -LiteralPath $Source -PathType Any)) {
        throw "Source does not exist: $Source"
    }

    Ensure-Parent $Target
    $existing = Get-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        if (-not (Remove-Link $existing $Target)) {
            Backup-Existing $Target
        }
    }

    $itemType = if ($Kind -eq 'Directory' -and $LinkMode -eq 'junction') { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $itemType -Path $Target -Target $Source | Out-Null
    Write-Host "$itemType $Target -> $Source"
}

$RepoRoot = Normalize-Path $RepoRoot
$links = @(
    @{ Source = $RepoRoot; Target = $DotfilesLinkPath; Kind = 'Directory' },
    @{ Source = (Join-Path $RepoRoot 'home/.config/nvim'); Target = $NvimConfigDir; Kind = 'Directory' },
    @{ Source = (Join-Path $RepoRoot 'home/.config/wezterm'); Target = $WeztermConfigDir; Kind = 'Directory' },
    @{ Source = (Join-Path $RepoRoot 'home/.config/wezterm/wezterm.lua'); Target = $WeztermConfigFile; Kind = 'File' },
    @{ Source = (Join-Path $RepoRoot 'home/.config/herdr'); Target = $HerdrConfigDir; Kind = 'Directory' },
    @{ Source = (Join-Path $RepoRoot 'home/.claude/settings.json'); Target = (Join-Path $ClaudeConfigDir 'settings.json'); Kind = 'File' },
    @{ Source = (Join-Path $RepoRoot 'home/.claude/status-line.js'); Target = (Join-Path $ClaudeConfigDir 'status-line.js'); Kind = 'File' },
    @{ Source = (Join-Path $RepoRoot 'home/.pi/agent/themes'); Target = (Join-Path $PiAgentDir 'themes'); Kind = 'Directory' },
    @{ Source = (Join-Path $RepoRoot 'home/.pi/agent/extensions'); Target = (Join-Path $PiAgentDir 'extensions'); Kind = 'Directory' },
    @{ Source = (Join-Path $RepoRoot 'home/.pi/agent/models.json'); Target = (Join-Path $PiAgentDir 'models.json'); Kind = 'File' },
    @{ Source = (Join-Path $RepoRoot 'home/.pi/agent/settings.json'); Target = (Join-Path $PiAgentDir 'settings.json'); Kind = 'File' },
    @{ Source = (Join-Path $RepoRoot 'home/AGENTS.md'); Target = (Join-Path $ClaudeConfigDir 'CLAUDE.md'); Kind = 'File' },
    @{ Source = (Join-Path $RepoRoot 'home/AGENTS.md'); Target = (Join-Path $CodexConfigDir 'AGENTS.md'); Kind = 'File' },
    @{ Source = (Join-Path $RepoRoot 'home/AGENTS.md'); Target = (Join-Path $OpencodeConfigDir 'AGENTS.md'); Kind = 'File' }
)

foreach ($link in $links) {
    New-DotfilesLink -Source (Normalize-Path $link.Source) -Target (Normalize-Path $link.Target) -Kind $link.Kind
}
