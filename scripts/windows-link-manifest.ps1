# Shared link manifest and helpers used by the Windows link and uninstall scripts.

Set-StrictMode -Version 3.0

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

function Ensure-Parent([string] $Path) {
    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function Get-DotfilesLinkManifest {
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
        [Parameter(Mandatory = $true)] [string] $PiAgentDir
    )

    $repoRoot = Normalize-Path $RepoRoot
    $documentsDir = if ([string]::IsNullOrWhiteSpace($DocumentsDir)) {
        [Environment]::GetFolderPath('MyDocuments')
    } else {
        Normalize-Path $DocumentsDir
    }
    if ([string]::IsNullOrWhiteSpace($documentsDir)) {
        $documentsDir = Join-Path $UserHome 'Documents'
    }

    $profileSource = Join-Path $repoRoot 'home/.config/powershell/Microsoft.PowerShell_profile.ps1'
    return @(
        @{ Source = $repoRoot; Target = $DotfilesLinkPath; Kind = 'Directory' },
        @{ Source = (Join-Path $repoRoot 'home/.config/nvim'); Target = $NvimConfigDir; Kind = 'Directory' },
        @{ Source = (Join-Path $repoRoot 'home/.config/oh-my-posh'); Target = (Join-Path $XdgConfigHome 'oh-my-posh'); Kind = 'Directory' },
        @{ Source = (Join-Path $repoRoot 'home/.config/herdr'); Target = $HerdrConfigDir; Kind = 'Directory' },
        @{ Source = (Join-Path $repoRoot 'home/.claude/settings.json'); Target = (Join-Path $ClaudeConfigDir 'settings.json'); Kind = 'File' },
        @{ Source = (Join-Path $repoRoot 'home/.claude/status-line.js'); Target = (Join-Path $ClaudeConfigDir 'status-line.js'); Kind = 'File' },
        @{ Source = (Join-Path $repoRoot 'home/.pi/agent/themes'); Target = (Join-Path $PiAgentDir 'themes'); Kind = 'Directory' },
        @{ Source = (Join-Path $repoRoot 'home/.pi/agent/extensions'); Target = (Join-Path $PiAgentDir 'extensions'); Kind = 'Directory' },
        @{ Source = (Join-Path $repoRoot 'home/.pi/agent/models.json'); Target = (Join-Path $PiAgentDir 'models.json'); Kind = 'File' },
        @{ Source = (Join-Path $repoRoot 'home/.pi/agent/settings.json'); Target = (Join-Path $PiAgentDir 'settings.json'); Kind = 'File' },
        @{ Source = (Join-Path $repoRoot 'home/AGENTS.md'); Target = (Join-Path $ClaudeConfigDir 'CLAUDE.md'); Kind = 'File' },
        @{ Source = (Join-Path $repoRoot 'home/AGENTS.md'); Target = (Join-Path $CodexConfigDir 'AGENTS.md'); Kind = 'File' },
        @{ Source = (Join-Path $repoRoot 'home/AGENTS.md'); Target = (Join-Path $OpencodeConfigDir 'AGENTS.md'); Kind = 'File' },
        @{ Source = $profileSource; Target = (Join-Path $documentsDir 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'); Kind = 'File' },
        @{ Source = $profileSource; Target = (Join-Path $documentsDir 'PowerShell\Microsoft.PowerShell_profile.ps1'); Kind = 'File' }
    )
}
