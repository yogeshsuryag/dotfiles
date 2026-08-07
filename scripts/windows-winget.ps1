# WinGet package installation and official portable zip installers for the
# Windows dotfiles engine. Loaded by windows-common.ps1.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Get-DotfilesWingetInstallArguments {
    param([Parameter(Mandatory = $true)] [string] $Id)

    return @(
        'install', '--exact', '--id', $Id, '--source', 'winget',
        '--silent', '--disable-interactivity',
        '--accept-package-agreements', '--accept-source-agreements'
    )
}

function Test-DotfilesWingetPackage {
    param([Parameter(Mandatory = $true)] [string] $Id)

    $command = Get-Command winget -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw 'WinGet was not found. Install App Installer from the Microsoft Store, then rerun the bootstrap.'
    }
    & $command.Name 'list' '--exact' '--id' $Id '--source' 'winget' '--disable-interactivity' 2>$null | Out-Null
    return $LASTEXITCODE -eq 0
}

function Invoke-DotfilesWingetInstall {
    param([Parameter(Mandatory = $true)] [string] $Id)

    if (Test-DotfilesWingetPackage $Id) {
        Write-Host "==> WinGet package already installed: $Id"
        return
    }
    Write-Host "==> Installing WinGet package: $Id"
    Invoke-DotfilesCommand 'winget' (Get-DotfilesWingetInstallArguments $Id)
}

function Add-DotfilesUserPath {
    param([Parameter(Mandatory = $true)] [string] $Path)

    $target = [System.IO.Path]::GetFullPath((ConvertTo-NativePath $Path))
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = @($userPath -split ';' | Where-Object { $_ })
    foreach ($entry in $entries) {
        try {
            if ([string]::Equals([System.IO.Path]::GetFullPath($entry), $target, [System.StringComparison]::OrdinalIgnoreCase)) {
                return
            }
        } catch {
            continue
        }
    }
    $combined = if ($entries.Count -eq 0) { $target } else { ($entries -join ';') + ';' + $target }
    [Environment]::SetEnvironmentVariable('Path', $combined, 'User')
    Write-Host "Added to user PATH: $target"
}

function Get-DotfilesGitHubReleaseAsset {
    param(
        [Parameter(Mandatory = $true)] [string] $Repository,
        [Parameter(Mandatory = $true)] [string] $AssetPattern
    )

    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest" -Headers @{ 'User-Agent' = 'dotfiles' }
    foreach ($asset in $release.assets) {
        if ($asset.name -match $AssetPattern) {
            return [pscustomobject]@{ Name = $asset.name; Url = $asset.browser_download_url }
        }
    }
    throw "Unable to find a matching asset in the latest $Repository release."
}

function Get-DotfilesPortableGitDownload {
    param(
        [Parameter(Mandatory = $true)] [string] $Architecture
    )

    $archPattern = if ($Architecture -eq 'arm64') { 'arm64' } else { '64-bit' }
    return Get-DotfilesGitHubReleaseAsset -Repository 'git-for-windows/git' -AssetPattern "^Git-[\d.]+-$archPattern\.7z\.exe$|^PortableGit-[\d.]+-$archPattern\.7z\.exe$"
}

function Expand-DotfilesPortableArchive {
    param(
        [Parameter(Mandatory = $true)] [string] $Archive,
        [Parameter(Mandatory = $true)] [string] $InstallPath,
        [Parameter(Mandatory = $true)] [string] $ProbeFile
    )

    $probe = Join-Path $InstallPath $ProbeFile
    $quotedPath = '"{0}"' -f ($InstallPath -replace '\\', '/')
    foreach ($switchForm in @(
        "-InstallPath=$quotedPath",
        "-InstallPath=$($InstallPath -replace '\\', '/')",
        "-o$quotedPath",
        "-o$($InstallPath -replace '\\', '/')"
    )) {
        & $Archive '-y' '-gm2' $switchForm
        if (Test-Path -LiteralPath $probe -PathType Leaf) {
            return
        }
    }
    throw "Portable archive extraction did not produce the expected file: $probe"
}

function Install-DotfilesPortableGit {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    Update-DotfilesProcessPath
    if (Get-Command git -ErrorAction SilentlyContinue) {
        return
    }

    $architecture = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
    $download = Get-DotfilesPortableGitDownload $architecture
    $installPath = Join-Path (ConvertTo-NativePath ([string] $Config.DOTFILES_LOCAL_TOOLS_DIR)) 'Git'
    New-Item -ItemType Directory -Path (Split-Path -Parent $installPath) -Force | Out-Null

    $temporary = Join-Path ([System.IO.Path]::GetTempPath()) ('dotfiles-' + [guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $temporary -Force | Out-Null
    $archive = Join-Path $temporary $download.Name
    try {
        Write-Host "==> Downloading portable Git from $($download.Url)"
        Invoke-WebRequest -Uri $download.Url -OutFile $archive
        Write-Host "==> Extracting portable Git to $installPath"
        Expand-DotfilesPortableArchive -Archive $archive -InstallPath $installPath -ProbeFile 'cmd/git.exe'
        Add-DotfilesUserPath (Join-Path $installPath 'cmd')
        Update-DotfilesProcessPath
        Invoke-DotfilesCommand 'git' @('--version')
    } finally {
        Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-DotfilesPortableNodeDownload {
    $index = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json'
    foreach ($entry in $index) {
        if ($entry.lts -is [string]) {
            $architecture = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
            return [pscustomobject]@{
                Version = [string] $entry.version
                Url = "https://nodejs.org/dist/$($entry.version)/node-$($entry.version)-win-$architecture.zip"
                DirectoryName = "node-$($entry.version)-win-$architecture"
            }
        }
    }
    throw 'Unable to determine the latest Node.js LTS release from nodejs.org.'
}

function Install-DotfilesPortableZip {
    param(
        [Parameter(Mandatory = $true)] [string] $ToolName,
        [Parameter(Mandatory = $true)] [string] $DownloadUrl,
        [Parameter(Mandatory = $true)] [string] $ArchiveFileName,
        [Parameter(Mandatory = $true)] [string] $InstallPath,
        [Parameter(Mandatory = $true)] [string] $PathEntry,
        [Parameter(Mandatory = $true)] [string] $ProbeFile,
        [Parameter(Mandatory = $true)] [string] $VersionCommand
    )

    New-Item -ItemType Directory -Path (Split-Path -Parent $InstallPath) -Force | Out-Null
    $temporary = Join-Path ([System.IO.Path]::GetTempPath()) ('dotfiles-' + [guid]::NewGuid().ToString())
    $extractDir = Join-Path $temporary 'extract'
    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
    $archive = Join-Path $temporary $ArchiveFileName
    try {
        Write-Host "==> Downloading $ToolName from $DownloadUrl"
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $archive
        Write-Host "==> Extracting $ToolName to $InstallPath"
        Expand-Archive -LiteralPath $archive -DestinationPath $extractDir -Force
        $innerDirectory = Get-ChildItem -LiteralPath $extractDir -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $innerDirectory) {
            Move-Item -LiteralPath $innerDirectory.FullName -Destination $InstallPath -Force
        } else {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
        Copy-Item -Path (Join-Path $extractDir '*') -Destination $InstallPath -Recurse -Force
        }
        $probe = Join-Path $InstallPath $ProbeFile
        if (-not (Test-Path -LiteralPath $probe -PathType Leaf)) {
            throw "$ToolName extraction did not produce the expected file: $probe"
        }
        Add-DotfilesUserPath $PathEntry
        Update-DotfilesProcessPath
        Invoke-DotfilesCommand $VersionCommand @('--version')
    } finally {
        Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-DotfilesPortableNode {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    Update-DotfilesProcessPath
    if (Get-Command node -ErrorAction SilentlyContinue) {
        return
    }

    $download = Get-DotfilesPortableNodeDownload
    $toolsRoot = ConvertTo-NativePath ([string] $Config.DOTFILES_LOCAL_TOOLS_DIR)
    $installPath = Join-Path $toolsRoot $download.DirectoryName
    Install-DotfilesPortableZip -ToolName ("Node.js " + $download.Version) -DownloadUrl $download.Url -ArchiveFileName ($download.DirectoryName + '.zip') -InstallPath $installPath -PathEntry $installPath -ProbeFile 'node.exe' -VersionCommand 'node'
}

function Get-DotfilesPortableNeovimDownload {
    $architecture = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
    $assetPattern = if ($architecture -eq 'arm64') { '^nvim-win-arm64\.zip$' } else { '^nvim-win64\.zip$' }
    return Get-DotfilesGitHubReleaseAsset -Repository 'neovim/neovim' -AssetPattern $assetPattern
}

function Install-DotfilesPortableNeovim {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    Update-DotfilesProcessPath
    if (Get-Command nvim -ErrorAction SilentlyContinue) {
        return
    }

    $download = Get-DotfilesPortableNeovimDownload
    $toolsRoot = ConvertTo-NativePath ([string] $Config.DOTFILES_LOCAL_TOOLS_DIR)
    $installPath = Join-Path $toolsRoot 'nvim'
    $binPath = Join-Path $installPath 'bin'
    Install-DotfilesPortableZip -ToolName 'Neovim' -DownloadUrl $download.Url -ArchiveFileName $download.Name -InstallPath $installPath -PathEntry $binPath -ProbeFile 'bin/nvim.exe' -VersionCommand 'nvim'
}

function Get-DotfilesPortableStarshipDownload {
    $architecture = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'aarch64' } else { 'x86_64' }
    return Get-DotfilesGitHubReleaseAsset -Repository 'starship/starship' -AssetPattern "^starship-$architecture-pc-windows-msvc\.zip$"
}

function Install-DotfilesPortableStarship {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    Update-DotfilesProcessPath
    if (Get-Command starship -ErrorAction SilentlyContinue) {
        return
    }

    $download = Get-DotfilesPortableStarshipDownload
    $toolsRoot = ConvertTo-NativePath ([string] $Config.DOTFILES_LOCAL_TOOLS_DIR)
    $installPath = Join-Path $toolsRoot 'starship'
    Install-DotfilesPortableZip -ToolName 'Starship' -DownloadUrl $download.Url -ArchiveFileName $download.Name -InstallPath $installPath -PathEntry $installPath -ProbeFile 'starship.exe' -VersionCommand 'starship'
}

function Configure-DotfilesWinget {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'WinGet was not found. Install App Installer from the Microsoft Store, then rerun the bootstrap.'
    }
    if ([string] $Config.DOTFILES_UPDATE_PACKAGES -eq '1') {
        Write-Host '==> Updating installed WinGet packages'
        Invoke-DotfilesCommand 'winget' @('upgrade', '--all', '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements')
    }
}

function Install-DotfilesWingetPackages {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    $specs = @([string] $Config.DOTFILES_WINGET_PACKAGES -split '\s+' | Where-Object { $_ })
    if ([string] $Config.DOTFILES_INSTALL_OH_MY_POSH -eq '1' -and $specs -notcontains 'JanDeDobbeleer.OhMyPosh') {
        $specs += 'JanDeDobbeleer.OhMyPosh'
    }
    if ($specs.Count -eq 0) {
        Write-Host '==> No WinGet packages declared, skipping package installation'
        return
    }

    Configure-DotfilesWinget $Config

    foreach ($spec in $specs) {
        if ($spec -eq 'git') {
            Install-DotfilesPortableGit $Config
            continue
        }
        if ($spec -eq 'node') {
            Install-DotfilesPortableNode $Config
            continue
        }
        if ($spec -eq 'neovim') {
            Install-DotfilesPortableNeovim $Config
            continue
        }
        if ($spec -eq 'starship') {
            Install-DotfilesPortableStarship $Config
            continue
        }
        Invoke-DotfilesWingetInstall $spec
    }
}
