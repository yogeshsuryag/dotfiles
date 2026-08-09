# MSYS2 zsh discovery, pacman install, plugins, and managed startup blocks
# for the Windows dotfiles engine. Loaded by windows-common.ps1.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Get-DotfilesMsys2Root {
    param(
        [switch] $Required,
        [AllowNull()] [string] $ScoopRoot
    )

    $candidates = @()
    if ($ScoopRoot) {
        $candidates += Join-Path (ConvertTo-NativePath $ScoopRoot) 'apps/msys2/current'
    } else {
        $candidates += 'C:\msys64'

        $scoopCommand = Get-Command scoop -ErrorAction SilentlyContinue
        if ($null -ne $scoopCommand) {
            $prefixOutput = (& $scoopCommand.Name prefix msys2 2>$null | Out-String).Trim()
            $prefixExitCode = $LASTEXITCODE
            if ($prefixExitCode -eq 0 -and $prefixOutput) {
                $candidates += $prefixOutput
            }
        }

        $detectedScoopRoot = if ($env:SCOOP) {
            ConvertTo-NativePath $env:SCOOP
        } elseif ($env:USERPROFILE) {
            Join-Path $env:USERPROFILE 'scoop'
        } else {
            $null
        }
        if ($detectedScoopRoot) {
            $candidates += Join-Path $detectedScoopRoot 'apps/msys2/current'
        }
    }

    foreach ($candidate in @($candidates | Where-Object { $_ } | Select-Object -Unique)) {
        try {
            $root = [System.IO.Path]::GetFullPath((ConvertTo-NativePath ([string] $candidate)))
        } catch {
            continue
        }
        if ((Test-Path -LiteralPath (Join-Path $root 'msys2_shell.cmd') -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $root 'usr/bin/bash.exe') -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $root 'usr/bin/pacman.exe') -PathType Leaf)) {
            return $root
        }
    }

    if ($Required) {
        throw 'MSYS2 was not discovered. Install it through WinGet or Scoop, or set DOTFILES_INSTALL_ZSH=0.'
    }
    return $null
}

function Get-DotfilesMsys2StartupPath {
    param([Parameter(Mandatory = $true)] [string] $Msys2Root)

    $username = if ($env:USERNAME) { $env:USERNAME } else { [Environment]::UserName }
    if ([string]::IsNullOrWhiteSpace($username)) {
        throw 'Unable to determine the Windows user name for the MSYS2 zsh startup file.'
    }
    return Join-Path (Join-Path $Msys2Root 'home') (Join-Path $username '.zshrc')
}

function Invoke-DotfilesMsys2Pacman {
    param([Parameter(Mandatory = $true)] [string] $Msys2Root)

    $bashPath = Join-Path $Msys2Root 'usr/bin/bash.exe'
    if (-not (Test-Path -LiteralPath $bashPath -PathType Leaf)) {
        throw "MSYS2 bash was not found: $bashPath"
    }

    Write-Host '==> Installing or updating MSYS2 zsh with pacman'
    $previousArgumentConversion = $env:MSYS2_ARG_CONV_EXCL
    $env:MSYS2_ARG_CONV_EXCL = '*'
    try {
        & $bashPath '--login' '-c' 'pacman -S --needed --noconfirm zsh'
        $exitCode = $LASTEXITCODE
    } finally {
        if ($null -eq $previousArgumentConversion) {
            Remove-Item Env:MSYS2_ARG_CONV_EXCL -ErrorAction SilentlyContinue
        } else {
            $env:MSYS2_ARG_CONV_EXCL = $previousArgumentConversion
        }
    }
    if ($exitCode -ne 0) {
        throw "MSYS2 pacman failed while installing zsh with exit code $exitCode."
    }

    $zshPath = Join-Path $Msys2Root 'usr/bin/zsh.exe'
    if (-not (Test-Path -LiteralPath $zshPath -PathType Leaf)) {
        throw "MSYS2 pacman completed but zsh was not found: $zshPath"
    }

    Invoke-DotfilesMsys2Plugins $Msys2Root
}

function Invoke-DotfilesMsys2Plugins {
    param([Parameter(Mandatory = $true)] [string] $Msys2Root)

    $pluginsRoot = Join-Path $Msys2Root 'usr/share/zsh/plugins'
    $plugins = @(
        @{ Name = 'zsh-autosuggestions'; Url = 'https://github.com/zsh-users/zsh-autosuggestions.git' },
        @{ Name = 'zsh-syntax-highlighting'; Url = 'https://github.com/zsh-users/zsh-syntax-highlighting.git' }
    )
    foreach ($plugin in $plugins) {
        $target = Join-Path $pluginsRoot $plugin.Name
        if (Test-Path -LiteralPath (Join-Path $target '.git')) {
            Write-Host "==> Updating MSYS2 zsh plugin $($plugin.Name)"
            Invoke-DotfilesCommand 'git' @('-C', $target, 'pull', '--ff-only')
        } else {
            Write-Host "==> Installing MSYS2 zsh plugin $($plugin.Name)"
            Invoke-DotfilesCommand 'git' @('clone', '--depth', '1', $plugin.Url, $target)
        }
    }
}

function Install-DotfilesZshStartup {
    param(
        [Parameter(Mandatory = $true)] [hashtable] $Config,
        [Parameter(Mandatory = $true)] [string] $Msys2Root
    )

    $target = Get-DotfilesMsys2StartupPath $Msys2Root
    $content = if (Test-Path -LiteralPath $target -PathType Leaf) { Get-Content -LiteralPath $target -Raw } else { '' }
    $start = '# >>> dotfiles managed MSYS2 zsh startup >>>'
    $end = '# <<< dotfiles managed MSYS2 zsh startup <<<'
    $clean = Remove-DotfilesManagedBlock $content $start $end
    $dotfilesLink = ConvertTo-GitBashPath (ConvertTo-NativePath ([string] $Config.DOTFILES_DOTFILES_LINK))
    $firstmateDir = ConvertTo-GitBashPath (ConvertTo-NativePath ([string] $Config.DOTFILES_FIRSTMATE_DIR))
    $firstmateLauncher = ConvertTo-GitBashPath (Join-Path (ConvertTo-NativePath ([string] $Config.DOTFILES_WINDOWS_HOME)) 'bin/firstmate')
    $piAgentDir = ConvertTo-GitBashPath (ConvertTo-NativePath ([string] $Config.DOTFILES_PI_AGENT_DIR))
    $sourceLine = 'export DOTFILES_ROOT="' + (ConvertTo-BashDoubleQuoted $dotfilesLink) +
        '" DOTFILES_ZSH_ACTIVE="1" DOTFILES_INSTALL_ZSH="1" DOTFILES_INSTALL_FIRSTMATE="' + (ConvertTo-BashDoubleQuoted ([string] $Config.DOTFILES_INSTALL_FIRSTMATE)) +
        '" DOTFILES_FIRSTMATE_DIR="' + (ConvertTo-BashDoubleQuoted $firstmateDir) +
        '" DOTFILES_FIRSTMATE_HARNESS="' + (ConvertTo-BashDoubleQuoted ([string] $Config.DOTFILES_FIRSTMATE_HARNESS)) +
        '" DOTFILES_FIRSTMATE_LAUNCHER="' + (ConvertTo-BashDoubleQuoted $firstmateLauncher) +
        '" DOTFILES_INSTALL_OH_MY_POSH="' + (ConvertTo-BashDoubleQuoted ([string] $Config.DOTFILES_INSTALL_OH_MY_POSH)) +
        '" DOTFILES_COLOR_THEME="' + (ConvertTo-BashDoubleQuoted ([string] $Config.DOTFILES_COLOR_THEME)) +
        '" DOTFILES_OH_MY_POSH_THEME="' + (ConvertTo-BashDoubleQuoted ([string] $Config.DOTFILES_OH_MY_POSH_THEME)) +
        '" DOTFILES_EDITOR="' + (ConvertTo-BashDoubleQuoted ([string] $Config.DOTFILES_EDITOR)) +
        '" DOTFILES_VISUAL="' + (ConvertTo-BashDoubleQuoted ([string] $Config.DOTFILES_VISUAL)) +
        '" PI_CODING_AGENT_DIR="' + (ConvertTo-BashDoubleQuoted $piAgentDir) +
        '"; . "$DOTFILES_ROOT/home/.zshrc"'
    $block = "$start`n$sourceLine`n$end"
    $newContent = if ($clean) { "$clean`n`n$block`n" } else { "$block`n" }
    Set-DotfilesTextFile $target $newContent
}

function Remove-DotfilesZshStartup {
    param([Parameter(Mandatory = $true)] [string] $Msys2Root)

    $target = Get-DotfilesMsys2StartupPath $Msys2Root
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        return
    }
    $start = '# >>> dotfiles managed MSYS2 zsh startup >>>'
    $end = '# <<< dotfiles managed MSYS2 zsh startup <<<'
    $content = Get-Content -LiteralPath $target -Raw
    if ($content.IndexOf($start, [System.StringComparison]::Ordinal) -lt 0) {
        return
    }
    $clean = Remove-DotfilesManagedBlock $content $start $end
    Set-DotfilesTextFile $target (($clean.TrimEnd("`n") + "`n"))
}

function Remove-DotfilesMsys2Plugins {
    param([Parameter(Mandatory = $true)] [string] $Msys2Root)

    foreach ($name in @('zsh-autosuggestions', 'zsh-syntax-highlighting')) {
        $target = Join-Path (Join-Path $Msys2Root 'usr/share/zsh/plugins') $name
        if (Test-Path -LiteralPath $target) {
            Write-Host "==> Removing MSYS2 zsh plugin $name"
            Remove-Item -LiteralPath $target -Recurse -Force
        }
    }
}

function Install-DotfilesMsys2 {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    if ([string] $Config.DOTFILES_PACKAGE_MANAGER -eq 'scoop') {
        Install-DotfilesScoop $Config
        Write-Host '==> Installing MSYS2 through Scoop'
        Invoke-DotfilesCommand 'scoop' @('install', 'msys2')
        return
    }

    $wingetRoot = Get-DotfilesMsys2Root
    if ($wingetRoot) {
        Write-Host "==> MSYS2 already installed at $wingetRoot"
        return
    }
    Invoke-DotfilesWingetInstall 'MSYS2.MSYS2'
}

function Install-DotfilesZsh {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    if ([string] $Config.DOTFILES_INSTALL_ZSH -ne '1') {
        $existingRoot = Get-DotfilesMsys2Root
        if ($existingRoot) {
            Remove-DotfilesZshStartup $existingRoot
            Remove-DotfilesMsys2Plugins $existingRoot
        }
        return
    }

    Install-DotfilesMsys2 $Config

    $msys2Root = Get-DotfilesMsys2Root -Required
    Invoke-DotfilesMsys2Pacman $msys2Root
    Install-DotfilesZshStartup $Config $msys2Root
}
