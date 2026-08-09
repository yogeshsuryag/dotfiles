# Firstmate checkout and cross-shell launchers for the Windows dotfiles engine.
# Loaded by windows-common.ps1.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$script:DotfilesFirstmateRepositoryUrl = 'https://github.com/kunchenguid/firstmate.git'

function Get-DotfilesGitBashPath {
    param([switch] $Required)

    $candidates = @()
    foreach ($gitCommand in @(
        (Get-Command git.exe -ErrorAction SilentlyContinue),
        (Get-Command git -ErrorAction SilentlyContinue)
    )) {
        if ($null -eq $gitCommand -or $gitCommand.CommandType -ne 'Application' -or [string]::IsNullOrWhiteSpace([string] $gitCommand.Source)) {
            continue
        }
        $gitDirectory = Split-Path -Parent $gitCommand.Source
        $gitRoot = Split-Path -Parent $gitDirectory
        $candidates += Join-Path $gitRoot 'usr/bin/bash.exe'
        $candidates += Join-Path $gitRoot 'bin/bash.exe'
        if ((Split-Path -Leaf $gitDirectory) -ieq 'shims') {
            $scoopRoot = $gitRoot
            $candidates += Join-Path $scoopRoot 'apps/git/current/usr/bin/bash.exe'
            $candidates += Join-Path $scoopRoot 'apps/git/current/bin/bash.exe'
        }
    }

    $scoopRoot = if ($env:SCOOP) {
        ConvertTo-NativePath $env:SCOOP
    } elseif ($env:USERPROFILE) {
        Join-Path $env:USERPROFILE 'scoop'
    } else {
        $null
    }
    if ($scoopRoot) {
        $candidates += Join-Path $scoopRoot 'apps/git/current/usr/bin/bash.exe'
        $candidates += Join-Path $scoopRoot 'apps/git/current/bin/bash.exe'
    }

    foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA, $env:USERPROFILE) | Where-Object { $_ }) {
        $candidates += Join-Path $root 'Git/usr/bin/bash.exe'
        $candidates += Join-Path $root 'Git/bin/bash.exe'
        $candidates += Join-Path $root 'Programs/Git/usr/bin/bash.exe'
        $candidates += Join-Path $root 'Programs/Git/bin/bash.exe'
    }

    foreach ($bashCommand in @(
        (Get-Command bash.exe -ErrorAction SilentlyContinue),
        (Get-Command bash -ErrorAction SilentlyContinue)
    )) {
        if ($null -eq $bashCommand -or $bashCommand.CommandType -ne 'Application' -or [string]::IsNullOrWhiteSpace([string] $bashCommand.Source)) {
            continue
        }
        if ([string] $bashCommand.Source -notmatch '(?i)\\Windows\\System32\\|\\WindowsApps\\') {
            $candidates += $bashCommand.Source
        }
    }

    foreach ($candidate in @($candidates | Where-Object { $_ } | Select-Object -Unique)) {
        try {
            $path = [System.IO.Path]::GetFullPath((ConvertTo-NativePath ([string] $candidate)))
        } catch {
            continue
        }
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            return $path
        }
    }

    if ($Required) {
        throw 'Git Bash was not found. Install Git for Windows before enabling Firstmate.'
    }
    return $null
}

function ConvertTo-DotfilesCmdValue {
    param([Parameter(Mandatory = $true)] [string] $Value)

    $builder = New-Object System.Text.StringBuilder
    foreach ($char in $Value.ToCharArray()) {
        switch ([int] $char) {
            37 { [void] $builder.Append('%%') }
            38 { [void] $builder.Append('^&') }
            60 { [void] $builder.Append('^<') }
            62 { [void] $builder.Append('^>') }
            94 { [void] $builder.Append('^^') }
            124 { [void] $builder.Append('^|') }
            default { [void] $builder.Append($char) }
        }
    }
    return $builder.ToString()
}

function Write-DotfilesManagedFirstmateFile {
    param(
        [Parameter(Mandatory = $true)] [string] $Path,
        [Parameter(Mandatory = $true)] [string] $Marker,
        [Parameter(Mandatory = $true)] [string] $Content
    )

    if (Test-Path -LiteralPath $Path) {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw "Firstmate launcher target is not a file: $Path"
        }
        $existing = Get-Content -LiteralPath $Path -Raw
        if ($existing.IndexOf($Marker, [System.StringComparison]::Ordinal) -lt 0) {
            throw "Refusing to overwrite an unmanaged Firstmate launcher: $Path"
        }
    }
    Set-DotfilesTextFile $Path $Content
}

function New-DotfilesFirstmateLaunchers {
    param(
        [Parameter(Mandatory = $true)] [hashtable] $Config,
        [Parameter(Mandatory = $true)] [string] $GitBashPath
    )

    $firstmateHome = [System.IO.Path]::GetFullPath((ConvertTo-NativePath ([string] $Config.DOTFILES_FIRSTMATE_DIR)))
    $firstmateHomeBash = ConvertTo-GitBashPath $firstmateHome
    $launcherDirectory = Join-Path (ConvertTo-NativePath ([string] $Config.DOTFILES_WINDOWS_HOME)) 'bin'
    $bashLauncher = Join-Path $launcherDirectory 'firstmate'
    $powershellLauncher = Join-Path $launcherDirectory 'firstmate.cmd'
    $harness = [string] $Config.DOTFILES_FIRSTMATE_HARNESS

    New-Item -ItemType Directory -Path $launcherDirectory -Force | Out-Null
    if (-not (Test-Path -LiteralPath $GitBashPath -PathType Leaf)) {
        throw "Git Bash launcher was not found: $GitBashPath"
    }

    $bashContent = @(
        '#!/usr/bin/env bash'
        '# dotfiles managed Firstmate launcher'
        'set -euo pipefail'
        ('firstmate_home="${DOTFILES_FIRSTMATE_DIR:-' + (ConvertTo-BashDoubleQuoted $firstmateHomeBash) + '}"')
        'if [[ ! -d "$firstmate_home" ]]; then'
        '  printf ''Firstmate home was not found: %s\n'' "$firstmate_home" >&2'
        '  exit 1'
        'fi'
        'harness="${DOTFILES_FIRSTMATE_HARNESS:-' + (ConvertTo-BashDoubleQuoted $harness) + '}"'
        'if [[ -z "$harness" ]]; then'
        '  printf ''Firstmate harness is not configured.\n'' >&2'
        '  exit 1'
        'fi'
        'cd "$firstmate_home"'
        'export FM_HOME="$firstmate_home" FM_ROOT_OVERRIDE="$firstmate_home"'
        'exec "$harness" "$@"'
    ) -join "`n"

    $bashPathForCmd = ConvertTo-DotfilesCmdValue ([System.IO.Path]::GetFullPath($GitBashPath))
    $bashScriptForCmd = ConvertTo-DotfilesCmdValue (ConvertTo-GitBashPath $bashLauncher)
    $homeForCmd = ConvertTo-DotfilesCmdValue $firstmateHomeBash
    $harnessForCmd = ConvertTo-DotfilesCmdValue $harness
    $cmdContent = @(
        '@echo off'
        'rem dotfiles managed Firstmate launcher'
        ('set "DOTFILES_FIRSTMATE_DIR=' + $homeForCmd + '"')
        ('set "DOTFILES_FIRSTMATE_HARNESS=' + $harnessForCmd + '"')
        ('"' + $bashPathForCmd + '" --login "' + $bashScriptForCmd + '" %*')
        'exit /b %ERRORLEVEL%'
    ) -join "`r`n"

    Write-DotfilesManagedFirstmateFile $bashLauncher '# dotfiles managed Firstmate launcher' ($bashContent + "`n")
    Write-DotfilesManagedFirstmateFile $powershellLauncher 'rem dotfiles managed Firstmate launcher' ($cmdContent + "`r`n")

    return [pscustomobject]@{
        BashLauncher = $bashLauncher
        PowerShellLauncher = $powershellLauncher
        FirstmateHome = $firstmateHome
        Harness = $harness
    }
}

function Test-DotfilesFirstmateRemote {
    param([Parameter(Mandatory = $true)] [string] $Remote)

    return $Remote.Trim() -match '(?i)github\.com[/:]kunchenguid/firstmate(?:\.git)?$'
}

function Install-DotfilesFirstmate {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    if ([string] $Config.DOTFILES_INSTALL_FIRSTMATE -ne '1') {
        return
    }

    $target = [System.IO.Path]::GetFullPath((ConvertTo-NativePath ([string] $Config.DOTFILES_FIRSTMATE_DIR)))
    if (Test-Path -LiteralPath $target) {
        if (-not (Test-Path -LiteralPath $target -PathType Container)) {
            throw "Firstmate target is not a directory: $target"
        }
        if (-not (Test-Path -LiteralPath (Join-Path $target '.git')) -or -not (Test-Path -LiteralPath (Join-Path $target 'AGENTS.md'))) {
            throw "Firstmate target exists but is not a Firstmate checkout: $target"
        }
        $gitCommand = Get-Command git -ErrorAction SilentlyContinue
        if ($null -eq $gitCommand) {
            throw 'Firstmate is enabled, but git is unavailable.'
        }
        $gitExecutable = if ($gitCommand.Source) { $gitCommand.Source } else { $gitCommand.Name }
        $remote = (& $gitExecutable '-C' $target 'remote' 'get-url' 'origin' 2>$null | Out-String).Trim()
        $remoteExitCode = $LASTEXITCODE
        if ($remoteExitCode -ne 0 -or -not (Test-DotfilesFirstmateRemote $remote)) {
            throw "Firstmate target has an unexpected origin: $target"
        }
        Write-Host "==> Firstmate checkout already exists at $target"
    } else {
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Write-Host "==> Cloning Firstmate to $target"
        Invoke-DotfilesCommand 'git' @('clone', $script:DotfilesFirstmateRepositoryUrl, $target)
    }

    $gitBashPath = Get-DotfilesGitBashPath -Required
    $launchers = New-DotfilesFirstmateLaunchers $Config $gitBashPath
    Add-DotfilesUserPath (Split-Path -Parent $launchers.BashLauncher)
    Add-DotfilesUserPath (Join-Path $launchers.FirstmateHome 'bin')
    Update-DotfilesProcessPath
    return $launchers
}
