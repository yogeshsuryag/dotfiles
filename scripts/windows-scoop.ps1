# Scoop installation and package management for the Windows dotfiles engine.
# Loaded by windows-common.ps1.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Install-DotfilesScoop {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    Update-DotfilesProcessPath
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        return
    }
    if ([string] $Config.DOTFILES_INSTALL_SCOOP -ne '1') {
        throw 'Scoop is not installed and DOTFILES_INSTALL_SCOOP is not enabled.'
    }

    Write-Host '==> Installing Scoop for the current Windows user'
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-Expression (Invoke-RestMethod -Uri 'https://get.scoop.sh')
    Update-DotfilesProcessPath
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        throw 'Scoop installed but its shims are not visible in this PowerShell session. Close and reopen PowerShell, then rerun the bootstrap.'
    }
}

function Get-DotfilesScoopBuckets {
    $command = Get-Command scoop -ErrorAction Stop
    $output = & $command.Name bucket list 2>$null | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to read the installed Scoop buckets.'
    }
    return @(
        ($output -split "`r?`n") |
            ForEach-Object { if ($_ -match '^\s*([^\s]+)\s+') { $matches[1] } } |
            Where-Object { $_ -and $_ -notin @('Name', '---') } |
            Select-Object -Unique
    )
}

function Configure-DotfilesScoop {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    Install-DotfilesScoop $Config
    $config = $Config
    if ([string] $config.DOTFILES_UPDATE_SCOOP -eq '1') {
        Write-Host '==> Updating Scoop buckets'
        Invoke-DotfilesCommand 'scoop' @('update')
    }

    $known = @(Get-DotfilesScoopBuckets)
    foreach ($spec in ([string] $config.DOTFILES_SCOOP_BUCKETS -split '\s+' | Where-Object { $_ })) {
        $parts = $spec -split '=', 2
        $name = $parts[0]
        if ($known -contains $name) {
            continue
        }
        Write-Host "==> Adding Scoop bucket: $name"
        if ($parts.Count -eq 2) {
            Invoke-DotfilesCommand 'scoop' @('bucket', 'add', $name, $parts[1])
        } else {
            Invoke-DotfilesCommand 'scoop' @('bucket', 'add', $name)
        }
        $known += $name
    }

    if ($known -notcontains 'nerd-fonts') {
        Write-Host '==> Adding Scoop bucket: nerd-fonts'
        Invoke-DotfilesCommand 'scoop' @('bucket', 'add', 'nerd-fonts', [string] $config.DOTFILES_NERD_FONTS_BUCKET_URL)
    }
}

function Install-DotfilesPackages {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    $packages = @([string] $Config.DOTFILES_SCOOP_PACKAGES -split '\s+' | Where-Object { $_ })
    if ([string] $Config.DOTFILES_INSTALL_OH_MY_POSH -eq '1' -and $packages -notcontains 'oh-my-posh') {
        $packages += 'oh-my-posh'
    }
    if ($packages.Count -eq 0) {
        Write-Host '==> No Scoop packages declared, skipping package installation'
        return
    }
    Configure-DotfilesScoop $Config
    Write-Host '==> Installing declared Scoop packages'
    Invoke-DotfilesCommand 'scoop' (@('install') + $packages)
}
