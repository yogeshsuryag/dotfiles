[CmdletBinding()]
param()

# Shared native PowerShell functions for the Windows dotfiles entry points.
# The configuration file remains Bash-compatible so both frontends can use it.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$script:DotfilesConfigKeys = @(
    'DOTFILES_INSTALL_SCOOP',
    'DOTFILES_SCOOP_BUCKETS',
    'DOTFILES_NERD_FONTS_BUCKET_URL',
    'DOTFILES_SCOOP_PACKAGES',
    'DOTFILES_UPDATE_SCOOP',
    'DOTFILES_INSTALL_ZSH',
    'DOTFILES_INSTALL_HERDR',
    'DOTFILES_HERDR_INSTALL_URL',
    'DOTFILES_INSTALL_AGENT_CLIS',
    'DOTFILES_WINDOWS_HOME',
    'DOTFILES_LOCAL_APPDATA',
    'DOTFILES_APPDATA',
    'DOTFILES_XDG_CONFIG_HOME',
    'DOTFILES_DOTFILES_LINK',
    'DOTFILES_NVIM_CONFIG_DIR',
    'DOTFILES_WEZTERM_CONFIG_DIR',
    'DOTFILES_WEZTERM_CONFIG_FILE',
    'DOTFILES_WEZTERM_THEME',
    'DOTFILES_HERDR_CONFIG_DIR',
    'DOTFILES_CLAUDE_CONFIG_DIR',
    'DOTFILES_CODEX_CONFIG_DIR',
    'DOTFILES_OPENCODE_CONFIG_DIR',
    'DOTFILES_PI_AGENT_DIR',
    'DOTFILES_LINK_MODE',
    'DOTFILES_BACKUP_EXISTING',
    'DOTFILES_INSTALL_BASH_HOOK',
    'DOTFILES_EDITOR',
    'DOTFILES_VISUAL',
    'DOTFILES_APPLY_WINDOWS_SETTINGS',
    'DOTFILES_DARK_MODE',
    'DOTFILES_SHOW_FILE_EXTENSIONS',
    'DOTFILES_SHOW_HIDDEN_FILES',
    'DOTFILES_HIDE_DESKTOP_ICONS',
    'DOTFILES_TASKBAR_AUTO_HIDE',
    'DOTFILES_KEYBOARD_REPEAT',
    'DOTFILES_KEYBOARD_DELAY',
    'DOTFILES_KEYBOARD_SPEED',
    'DOTFILES_RESTART_EXPLORER'
)

function ConvertTo-NativePath {
    param([AllowNull()][string] $Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    $value = $Path.Trim()
    if ($value -match '^/([A-Za-z])(?:/(.*))?$') {
        $drive = $matches[1].ToUpperInvariant()
        $rest = if ($null -eq $matches[2]) { '' } else { $matches[2] }
        $rest = $rest -replace '/', '\'
        if ($rest) {
            return "${drive}:\$rest"
        }
        return "${drive}:\"
    }

    return ($value -replace '/', '\')
}

function ConvertTo-GitBashPath {
    param([AllowNull()][string] $Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    $value = $Path.Trim()
    if ($value -match '^([A-Za-z]):[\\/](.*)$') {
        $drive = $matches[1].ToLowerInvariant()
        $rest = $matches[2] -replace '\\', '/'
        return "/$drive/$rest"
    }

    return ($value -replace '\\', '/')
}

function Join-DotfilesConfigPath {
    param(
        [Parameter(Mandatory = $true)] [string] $Base,
        [Parameter(Mandatory = $true)] [string] $Child
    )

    return ConvertTo-GitBashPath (Join-Path (ConvertTo-NativePath $Base) $Child)
}

function Set-DotfilesDefault {
    param(
        [Parameter(Mandatory = $true)] [hashtable] $Config,
        [Parameter(Mandatory = $true)] [string] $Name,
        [AllowNull()] [string] $Value
    )

    if (-not $Config.ContainsKey($Name) -or [string]::IsNullOrEmpty([string] $Config[$Name])) {
        $Config[$Name] = $Value
    }
}

function Initialize-DotfilesConfigDefaults {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    $detectedHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { [Environment]::GetFolderPath('UserProfile') }
    $detectedLocalAppData = $env:LOCALAPPDATA
    $detectedAppData = $env:APPDATA
    if (-not $detectedHome) {
        $detectedHome = $HOME
    }

    Set-DotfilesDefault $Config 'DOTFILES_WINDOWS_HOME' (ConvertTo-GitBashPath $detectedHome)
    $homeNative = ConvertTo-NativePath $Config.DOTFILES_WINDOWS_HOME

    $localDefault = if ($detectedLocalAppData) { $detectedLocalAppData } else { Join-Path $homeNative 'AppData/Local' }
    $appDefault = if ($detectedAppData) { $detectedAppData } else { Join-Path $homeNative 'AppData/Roaming' }
    Set-DotfilesDefault $Config 'DOTFILES_LOCAL_APPDATA' (ConvertTo-GitBashPath $localDefault)
    Set-DotfilesDefault $Config 'DOTFILES_APPDATA' (ConvertTo-GitBashPath $appDefault)
    Set-DotfilesDefault $Config 'DOTFILES_XDG_CONFIG_HOME' (Join-DotfilesConfigPath $Config.DOTFILES_WINDOWS_HOME '.config')
    Set-DotfilesDefault $Config 'DOTFILES_DOTFILES_LINK' (Join-DotfilesConfigPath $Config.DOTFILES_WINDOWS_HOME '.dotfiles')

    Set-DotfilesDefault $Config 'DOTFILES_NVIM_CONFIG_DIR' (Join-DotfilesConfigPath $Config.DOTFILES_LOCAL_APPDATA 'nvim')
    Set-DotfilesDefault $Config 'DOTFILES_WEZTERM_CONFIG_DIR' (Join-DotfilesConfigPath $Config.DOTFILES_XDG_CONFIG_HOME 'wezterm')
    Set-DotfilesDefault $Config 'DOTFILES_WEZTERM_CONFIG_FILE' (Join-DotfilesConfigPath $Config.DOTFILES_WINDOWS_HOME '.wezterm.lua')
    Set-DotfilesDefault $Config 'DOTFILES_WEZTERM_THEME' 'Tokyo Night Storm'
    Set-DotfilesDefault $Config 'DOTFILES_HERDR_CONFIG_DIR' (Join-DotfilesConfigPath $Config.DOTFILES_APPDATA 'herdr')
    Set-DotfilesDefault $Config 'DOTFILES_CLAUDE_CONFIG_DIR' (Join-DotfilesConfigPath $Config.DOTFILES_WINDOWS_HOME '.claude')
    Set-DotfilesDefault $Config 'DOTFILES_CODEX_CONFIG_DIR' (Join-DotfilesConfigPath $Config.DOTFILES_WINDOWS_HOME '.codex')
    Set-DotfilesDefault $Config 'DOTFILES_OPENCODE_CONFIG_DIR' (Join-DotfilesConfigPath $Config.DOTFILES_XDG_CONFIG_HOME 'opencode')
    Set-DotfilesDefault $Config 'DOTFILES_PI_AGENT_DIR' (Join-DotfilesConfigPath $Config.DOTFILES_WINDOWS_HOME '.pi/agent')

    Set-DotfilesDefault $Config 'DOTFILES_INSTALL_SCOOP' '1'
    Set-DotfilesDefault $Config 'DOTFILES_SCOOP_BUCKETS' 'extras'
    Set-DotfilesDefault $Config 'DOTFILES_NERD_FONTS_BUCKET_URL' 'https://github.com/matthewjberger/scoop-nerd-fonts'
    Set-DotfilesDefault $Config 'DOTFILES_SCOOP_PACKAGES' 'git neovim wezterm starship ripgrep fd fzf jq lazygit nodejs Hack-NF'
    Set-DotfilesDefault $Config 'DOTFILES_UPDATE_SCOOP' '0'
    Set-DotfilesDefault $Config 'DOTFILES_INSTALL_ZSH' '1'
    Set-DotfilesDefault $Config 'DOTFILES_INSTALL_HERDR' '1'
    Set-DotfilesDefault $Config 'DOTFILES_HERDR_INSTALL_URL' 'https://herdr.dev/install.ps1'
    Set-DotfilesDefault $Config 'DOTFILES_INSTALL_AGENT_CLIS' '0'
    Set-DotfilesDefault $Config 'DOTFILES_LINK_MODE' 'junction'
    Set-DotfilesDefault $Config 'DOTFILES_BACKUP_EXISTING' '1'
    Set-DotfilesDefault $Config 'DOTFILES_INSTALL_BASH_HOOK' '1'
    Set-DotfilesDefault $Config 'DOTFILES_EDITOR' 'nvim'
    Set-DotfilesDefault $Config 'DOTFILES_VISUAL' $Config.DOTFILES_EDITOR
    Set-DotfilesDefault $Config 'DOTFILES_APPLY_WINDOWS_SETTINGS' '0'
    Set-DotfilesDefault $Config 'DOTFILES_DARK_MODE' '0'
    Set-DotfilesDefault $Config 'DOTFILES_SHOW_FILE_EXTENSIONS' '0'
    Set-DotfilesDefault $Config 'DOTFILES_SHOW_HIDDEN_FILES' '0'
    Set-DotfilesDefault $Config 'DOTFILES_HIDE_DESKTOP_ICONS' '0'
    Set-DotfilesDefault $Config 'DOTFILES_TASKBAR_AUTO_HIDE' '0'
    Set-DotfilesDefault $Config 'DOTFILES_KEYBOARD_REPEAT' '0'
    Set-DotfilesDefault $Config 'DOTFILES_KEYBOARD_DELAY' '0'
    Set-DotfilesDefault $Config 'DOTFILES_KEYBOARD_SPEED' '31'
    Set-DotfilesDefault $Config 'DOTFILES_RESTART_EXPLORER' '0'

    return $Config
}

function ConvertFrom-DotfilesEnvValue {
    param([Parameter(Mandatory = $true)] [string] $RawValue)

    $value = $RawValue.Trim()
    if (-not $value) {
        return ''
    }

    if ($value.StartsWith('$''') -and $value.EndsWith('''')) {
        $inner = $value.Substring(2, $value.Length - 3)
        $builder = New-Object System.Text.StringBuilder
        for ($index = 0; $index -lt $inner.Length; $index++) {
            $char = $inner[$index]
            if ($char -eq '\' -and $index + 1 -lt $inner.Length) {
                $index++
                $next = $inner[$index]
                switch ($next) {
                    'n' { [void] $builder.Append("`n") }
                    'r' { [void] $builder.Append("`r") }
                    't' { [void] $builder.Append("`t") }
                    default { [void] $builder.Append($next) }
                }
            } else {
                [void] $builder.Append($char)
            }
        }
        return $builder.ToString()
    }

    if ($value.StartsWith('"')) {
        if (-not $value.EndsWith('"') -or $value.Length -lt 2) {
            throw "Unsupported or unterminated quoted configuration value: $RawValue"
        }
        $inner = $value.Substring(1, $value.Length - 2)
        $builder = New-Object System.Text.StringBuilder
        for ($index = 0; $index -lt $inner.Length; $index++) {
            $char = $inner[$index]
            if ($char -eq '\' -and $index + 1 -lt $inner.Length) {
                $next = $inner[$index + 1]
                if ($next -eq '\' -or $next -eq '"' -or $next -eq '$' -or [int] $next -eq 96) {
                    $index++
                    [void] $builder.Append($next)
                } else {
                    [void] $builder.Append($char)
                }
            } else {
                [void] $builder.Append($char)
            }
        }
        return $builder.ToString()
    }

    if ($value.StartsWith('''')) {
        if (-not $value.EndsWith('''') -or $value.Length -lt 2) {
            throw "Unsupported or unterminated quoted configuration value: $RawValue"
        }
        return $value.Substring(1, $value.Length - 2)
    }

    $builder = New-Object System.Text.StringBuilder
    for ($index = 0; $index -lt $value.Length; $index++) {
        $char = $value[$index]
        if ($char -eq '\' -and $index + 1 -lt $value.Length) {
            $index++
            [void] $builder.Append($value[$index])
        } else {
            [void] $builder.Append($char)
        }
    }
    return $builder.ToString()
}

function Read-DotfilesEnvFile {
    param([Parameter(Mandatory = $true)] [string] $Path)

    $result = @{}
    foreach ($line in (Get-Content -LiteralPath $Path -ErrorAction Stop)) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith('#')) {
            continue
        }
        if ($trimmed -notmatch '^(?:export\s+)?(DOTFILES_[A-Za-z0-9_]+)\s*=\s*(.*)$') {
            throw "Unsupported configuration line in ${Path}: $line"
        }
        $result[$matches[1]] = ConvertFrom-DotfilesEnvValue $matches[2]
    }
    return $result
}

function ConvertTo-DotfilesEnvValue {
    param([AllowNull()][string] $Value)

    if ($null -eq $Value) {
        $Value = ''
    }
    $builder = New-Object System.Text.StringBuilder
    [void] $builder.Append('"')
    foreach ($char in $Value.ToCharArray()) {
        switch ([int] $char) {
            92 { [void] $builder.Append('\\') }
            34 { [void] $builder.Append('\"') }
            36 { [void] $builder.Append('\$') }
            96 { [void] $builder.Append('\`') }
            default { [void] $builder.Append($char) }
        }
    }
    [void] $builder.Append('"')
    return $builder.ToString()
}

function Write-DotfilesEnvFile {
    param(
        [Parameter(Mandatory = $true)] [hashtable] $Config,
        [Parameter(Mandatory = $true)] [string] $Path
    )

    $parent = Split-Path -Parent $Path
    if ($parent) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $temporary = "$Path.tmp.$PID"
    $encoding = New-Object System.Text.UTF8Encoding($false)
    $writer = New-Object System.IO.StreamWriter($temporary, $false, $encoding)
    try {
        $writer.WriteLine('# Generated by the dotfiles setup wizard. This file is local and ignored by Git.')
        $writer.WriteLine('# Review it before running the setup again.')
        $writer.WriteLine()
        foreach ($key in $script:DotfilesConfigKeys) {
            $writer.WriteLine("$key=$(ConvertTo-DotfilesEnvValue ([string] $Config[$key]))")
        }
    } finally {
        $writer.Dispose()
    }
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Get-DotfilesConfiguration {
    param(
        [Parameter(Mandatory = $true)] [string] $Root,
        [switch] $CheckOnly,
        [switch] $Configure
    )

    $requested = if ($env:DOTFILES_CONFIG_FILE) {
        ConvertTo-NativePath $env:DOTFILES_CONFIG_FILE
    } else {
        Join-Path $Root 'windows-config.env'
    }
    $requested = [System.IO.Path]::GetFullPath($requested)
    $example = Join-Path $Root 'windows-config.example.env'

    if (-not (Test-Path -LiteralPath $requested -PathType Leaf)) {
        if ($CheckOnly) {
            $selected = $example
            $values = Read-DotfilesEnvFile $selected
        } else {
            $values = @{}
            Initialize-DotfilesConfigDefaults $values | Out-Null
            if (-not (Invoke-DotfilesConfigWizard -Config $values -RequestedConfig $requested)) {
                throw 'Configuration cancelled. No changes were saved.'
            }
            $selected = $requested
            $values = Read-DotfilesEnvFile $selected
        }
    } else {
        $selected = $requested
        $values = Read-DotfilesEnvFile $selected
        if ($Configure) {
            Initialize-DotfilesConfigDefaults $values | Out-Null
            if (-not (Invoke-DotfilesConfigWizard -Config $values -RequestedConfig $requested)) {
                throw 'Configuration cancelled. No changes were saved.'
            }
            $values = Read-DotfilesEnvFile $requested
        }
    }

    Initialize-DotfilesConfigDefaults $values | Out-Null
    return [pscustomobject]@{
        Values = $values
        Path = $selected
    }
}

function Assert-DotfilesConfig {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    if (@('junction', 'symbolic') -notcontains [string] $Config.DOTFILES_LINK_MODE) {
        throw 'DOTFILES_LINK_MODE must be junction or symbolic.'
    }
    if (@('Tokyo Night Storm', 'rose-pine-moon') -notcontains [string] $Config.DOTFILES_WEZTERM_THEME) {
        throw 'DOTFILES_WEZTERM_THEME must be Tokyo Night Storm or rose-pine-moon.'
    }

    $booleanKeys = @(
        'DOTFILES_INSTALL_SCOOP', 'DOTFILES_UPDATE_SCOOP', 'DOTFILES_INSTALL_ZSH', 'DOTFILES_INSTALL_HERDR',
        'DOTFILES_INSTALL_AGENT_CLIS', 'DOTFILES_BACKUP_EXISTING', 'DOTFILES_INSTALL_BASH_HOOK',
        'DOTFILES_APPLY_WINDOWS_SETTINGS', 'DOTFILES_DARK_MODE', 'DOTFILES_SHOW_FILE_EXTENSIONS',
        'DOTFILES_SHOW_HIDDEN_FILES', 'DOTFILES_HIDE_DESKTOP_ICONS', 'DOTFILES_TASKBAR_AUTO_HIDE',
        'DOTFILES_KEYBOARD_REPEAT', 'DOTFILES_RESTART_EXPLORER'
    )
    foreach ($key in $booleanKeys) {
        if ([string] $Config[$key] -notmatch '^[01]$') {
            throw "$key must be 0 or 1."
        }
    }
    if ([string] $Config.DOTFILES_KEYBOARD_DELAY -notmatch '^[0-3]$') {
        throw 'DOTFILES_KEYBOARD_DELAY must be an integer from 0 to 3.'
    }
    if ([string] $Config.DOTFILES_KEYBOARD_SPEED -notmatch '^(?:[0-9]|[12][0-9]|3[01])$') {
        throw 'DOTFILES_KEYBOARD_SPEED must be an integer from 0 to 31.'
    }
}

function Update-DotfilesProcessPath {
    $parts = @()
    foreach ($candidate in @(
        $env:PATH,
        [Environment]::GetEnvironmentVariable('Path', 'User'),
        [Environment]::GetEnvironmentVariable('Path', 'Machine')
    )) {
        if ($candidate) {
            $parts += ($candidate -split ';')
        }
    }
    $scoopRoot = if ($env:SCOOP) { ConvertTo-NativePath $env:SCOOP } else { Join-Path $env:USERPROFILE 'scoop' }
    $shimPath = Join-Path $scoopRoot 'shims'
    if (Test-Path -LiteralPath $shimPath -PathType Container) {
        $parts = @($shimPath) + $parts
    }
    $unique = @($parts | Where-Object { $_ } | Select-Object -Unique)
    $env:PATH = $unique -join ';'
}

function Invoke-DotfilesCommand {
    param(
        [Parameter(Mandatory = $true)] [string] $Name,
        [object[]] $CommandArguments = @()
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw "Required command is unavailable: $Name"
    }
    & $command.Name @CommandArguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
    }
}

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
    if ($packages.Count -eq 0) {
        Write-Host '==> No Scoop packages declared, skipping package installation'
        return
    }
    Configure-DotfilesScoop $Config
    Write-Host '==> Installing declared Scoop packages'
    Invoke-DotfilesCommand 'scoop' (@('install') + $packages)
}

function Get-DotfilesMsys2Root {
    param(
        [switch] $Required,
        [AllowNull()] [string] $ScoopRoot
    )

    $candidates = @()
    if ($ScoopRoot) {
        $candidates += Join-Path (ConvertTo-NativePath $ScoopRoot) 'apps/msys2/current'
    } else {
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
        throw 'MSYS2 was not discovered through Scoop. Install it with Scoop or set DOTFILES_INSTALL_ZSH=0.'
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
    $piAgentDir = ConvertTo-GitBashPath (ConvertTo-NativePath ([string] $Config.DOTFILES_PI_AGENT_DIR))
    $sourceLine = 'export DOTFILES_ROOT="' + (ConvertTo-BashDoubleQuoted $dotfilesLink) +
        '" DOTFILES_INSTALL_ZSH="1" DOTFILES_EDITOR="' + (ConvertTo-BashDoubleQuoted ([string] $Config.DOTFILES_EDITOR)) +
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

function Install-DotfilesZsh {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    if ([string] $Config.DOTFILES_INSTALL_ZSH -ne '1') {
        $existingRoot = Get-DotfilesMsys2Root
        if ($existingRoot) {
            Remove-DotfilesZshStartup $existingRoot
        }
        return
    }

    Install-DotfilesScoop $Config
    Write-Host '==> Installing MSYS2 through Scoop'
    Invoke-DotfilesCommand 'scoop' @('install', 'msys2')

    $msys2Root = Get-DotfilesMsys2Root -Required
    Invoke-DotfilesMsys2Pacman $msys2Root
    Install-DotfilesZshStartup $Config $msys2Root
}

function Install-DotfilesHerdr {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    if ([string] $Config.DOTFILES_INSTALL_HERDR -ne '1' -or (Get-Command herdr -ErrorAction SilentlyContinue)) {
        return
    }
    Write-Host "==> Installing Herdr's Windows beta"
    Invoke-Expression (Invoke-RestMethod -Uri ([string] $Config.DOTFILES_HERDR_INSTALL_URL))
}

function Install-DotfilesAgentClis {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    if ([string] $Config.DOTFILES_INSTALL_AGENT_CLIS -ne '1') {
        return
    }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        throw 'Agent CLIs requested, but npm is unavailable. Add nodejs to DOTFILES_SCOOP_PACKAGES and rerun.'
    }
    Write-Host '==> Installing optional agent CLIs with npm'
    Invoke-DotfilesCommand 'npm' @(
        'install', '--global', '--ignore-scripts',
        '@anthropic-ai/claude-code', '@openai/codex',
        '@earendil-works/pi-coding-agent', 'opencode-ai'
    )
}

function ConvertTo-BashDoubleQuoted {
    param([AllowNull()][string] $Value)

    if ($null -eq $Value) { return '' }
    $builder = New-Object System.Text.StringBuilder
    foreach ($char in $Value.ToCharArray()) {
        switch ([int] $char) {
            92 { [void] $builder.Append('\\') }
            34 { [void] $builder.Append('\"') }
            36 { [void] $builder.Append('\$') }
            96 { [void] $builder.Append('\`') }
            default { [void] $builder.Append($char) }
        }
    }
    return $builder.ToString()
}

function Set-DotfilesTextFile {
    param(
        [Parameter(Mandatory = $true)] [string] $Path,
        [Parameter(Mandatory = $true)] [string] $Content
    )

    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Remove-DotfilesManagedBlock {
    param(
        [AllowNull()][string] $Content,
        [string] $StartMarker = '# >>> dotfiles managed Git Bash hook >>>',
        [string] $EndMarker = '# <<< dotfiles managed Git Bash hook <<<'
    )

    if ($null -eq $Content) { return '' }
    $start = $StartMarker
    $end = $EndMarker
    if ($Content.IndexOf($start, [System.StringComparison]::Ordinal) -lt 0) {
        return $Content
    }
    $inside = $false
    $kept = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($Content -split "`r?`n")) {
        if ($line -eq $start) { $inside = $true; continue }
        if ($line -eq $end) { $inside = $false; continue }
        if (-not $inside) { [void] $kept.Add($line) }
    }
    return ($kept -join "`n").TrimEnd("`n")
}

function Install-DotfilesBashHook {
    param(
        [Parameter(Mandatory = $true)] [string] $Root,
        [Parameter(Mandatory = $true)] [hashtable] $Config
    )

    if ([string] $Config.DOTFILES_INSTALL_BASH_HOOK -ne '1') { return }
    $userHomePath = ConvertTo-NativePath $Config.DOTFILES_WINDOWS_HOME
    $dotfilesLink = ConvertTo-GitBashPath (ConvertTo-NativePath $Config.DOTFILES_DOTFILES_LINK)
    $piAgentDir = ConvertTo-NativePath $Config.DOTFILES_PI_AGENT_DIR
    $sourceLine = 'export DOTFILES_ROOT="' + (ConvertTo-BashDoubleQuoted $dotfilesLink) +
        '" DOTFILES_INSTALL_ZSH="' + (ConvertTo-BashDoubleQuoted ([string] $Config.DOTFILES_INSTALL_ZSH)) +
        '" DOTFILES_EDITOR="' + (ConvertTo-BashDoubleQuoted ([string] $Config.DOTFILES_EDITOR)) +
        '" DOTFILES_VISUAL="' + (ConvertTo-BashDoubleQuoted ([string] $Config.DOTFILES_VISUAL)) +
        '" PI_CODING_AGENT_DIR="' + (ConvertTo-BashDoubleQuoted $piAgentDir) +
        '"; . "$DOTFILES_ROOT/home/.bashrc"'
    $block = "# >>> dotfiles managed Git Bash hook >>>`n$sourceLine`n# <<< dotfiles managed Git Bash hook <<<"

    foreach ($profileName in @('.bashrc', '.bash_profile')) {
        $profile = Join-Path $userHomePath $profileName
        $content = if (Test-Path -LiteralPath $profile -PathType Leaf) { Get-Content -LiteralPath $profile -Raw } else { '' }
        $clean = Remove-DotfilesManagedBlock $content
        $newContent = if ($clean) { "$clean`n`n$block`n" } else { "$block`n" }
        Set-DotfilesTextFile $profile $newContent
    }
}

function Remove-DotfilesBashHook {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    $userHomePath = ConvertTo-NativePath $Config.DOTFILES_WINDOWS_HOME
    foreach ($profileName in @('.bashrc', '.bash_profile')) {
        $profile = Join-Path $userHomePath $profileName
        if (-not (Test-Path -LiteralPath $profile -PathType Leaf)) { continue }
        $content = Get-Content -LiteralPath $profile -Raw
        if ($content.IndexOf('# >>> dotfiles managed Git Bash hook >>>', [System.StringComparison]::Ordinal) -lt 0) {
            continue
        }
        $clean = Remove-DotfilesManagedBlock $content
        Set-DotfilesTextFile $profile (($clean.TrimEnd("`n") + "`n"))
        Write-Host "Removed managed Git Bash hook from $profile"
    }
}

function Invoke-DotfilesLinks {
    param(
        [Parameter(Mandatory = $true)] [string] $Root,
        [Parameter(Mandatory = $true)] [hashtable] $Config
    )

    Write-Host '==> Linking Windows application configurations'
    $scriptPath = Join-Path $Root 'windows-links.ps1'
    & $scriptPath `
        -RepoRoot (ConvertTo-NativePath $Root) `
        -UserHome (ConvertTo-NativePath $Config.DOTFILES_WINDOWS_HOME) `
        -LocalAppData (ConvertTo-NativePath $Config.DOTFILES_LOCAL_APPDATA) `
        -AppData (ConvertTo-NativePath $Config.DOTFILES_APPDATA) `
        -XdgConfigHome (ConvertTo-NativePath $Config.DOTFILES_XDG_CONFIG_HOME) `
        -DotfilesLinkPath (ConvertTo-NativePath $Config.DOTFILES_DOTFILES_LINK) `
        -NvimConfigDir (ConvertTo-NativePath $Config.DOTFILES_NVIM_CONFIG_DIR) `
        -WeztermConfigDir (ConvertTo-NativePath $Config.DOTFILES_WEZTERM_CONFIG_DIR) `
        -WeztermConfigFile (ConvertTo-NativePath $Config.DOTFILES_WEZTERM_CONFIG_FILE) `
        -HerdrConfigDir (ConvertTo-NativePath $Config.DOTFILES_HERDR_CONFIG_DIR) `
        -ClaudeConfigDir (ConvertTo-NativePath $Config.DOTFILES_CLAUDE_CONFIG_DIR) `
        -CodexConfigDir (ConvertTo-NativePath $Config.DOTFILES_CODEX_CONFIG_DIR) `
        -OpencodeConfigDir (ConvertTo-NativePath $Config.DOTFILES_OPENCODE_CONFIG_DIR) `
        -PiAgentDir (ConvertTo-NativePath $Config.DOTFILES_PI_AGENT_DIR) `
        -LinkMode ([string] $Config.DOTFILES_LINK_MODE) `
        -BackupExisting ([string] $Config.DOTFILES_BACKUP_EXISTING)
}

function Invoke-DotfilesWindowsSettings {
    param(
        [Parameter(Mandatory = $true)] [string] $Root,
        [Parameter(Mandatory = $true)] [hashtable] $Config
    )

    if ([string] $Config.DOTFILES_APPLY_WINDOWS_SETTINGS -ne '1') { return }
    Write-Host '==> Applying opted-in Windows settings'
    & (Join-Path $Root 'windows-settings.ps1') `
        -DarkMode ([string] $Config.DOTFILES_DARK_MODE) `
        -ShowFileExtensions ([string] $Config.DOTFILES_SHOW_FILE_EXTENSIONS) `
        -ShowHiddenFiles ([string] $Config.DOTFILES_SHOW_HIDDEN_FILES) `
        -HideDesktopIcons ([string] $Config.DOTFILES_HIDE_DESKTOP_ICONS) `
        -TaskbarAutoHide ([string] $Config.DOTFILES_TASKBAR_AUTO_HIDE) `
        -KeyboardRepeat ([string] $Config.DOTFILES_KEYBOARD_REPEAT) `
        -KeyboardDelay ([int] $Config.DOTFILES_KEYBOARD_DELAY) `
        -KeyboardSpeed ([int] $Config.DOTFILES_KEYBOARD_SPEED) `
        -RestartExplorer ([string] $Config.DOTFILES_RESTART_EXPLORER)
}

function Invoke-DotfilesUninstallLinks {
    param(
        [Parameter(Mandatory = $true)] [string] $Root,
        [Parameter(Mandatory = $true)] [hashtable] $Config,
        [Parameter(Mandatory = $true)] [string] $RestoreBackups
    )

    & (Join-Path $Root 'windows-uninstall.ps1') `
        -RepoRoot (ConvertTo-NativePath $Root) `
        -UserHome (ConvertTo-NativePath $Config.DOTFILES_WINDOWS_HOME) `
        -LocalAppData (ConvertTo-NativePath $Config.DOTFILES_LOCAL_APPDATA) `
        -AppData (ConvertTo-NativePath $Config.DOTFILES_APPDATA) `
        -XdgConfigHome (ConvertTo-NativePath $Config.DOTFILES_XDG_CONFIG_HOME) `
        -DotfilesLinkPath (ConvertTo-NativePath $Config.DOTFILES_DOTFILES_LINK) `
        -NvimConfigDir (ConvertTo-NativePath $Config.DOTFILES_NVIM_CONFIG_DIR) `
        -WeztermConfigDir (ConvertTo-NativePath $Config.DOTFILES_WEZTERM_CONFIG_DIR) `
        -WeztermConfigFile (ConvertTo-NativePath $Config.DOTFILES_WEZTERM_CONFIG_FILE) `
        -HerdrConfigDir (ConvertTo-NativePath $Config.DOTFILES_HERDR_CONFIG_DIR) `
        -ClaudeConfigDir (ConvertTo-NativePath $Config.DOTFILES_CLAUDE_CONFIG_DIR) `
        -CodexConfigDir (ConvertTo-NativePath $Config.DOTFILES_CODEX_CONFIG_DIR) `
        -OpencodeConfigDir (ConvertTo-NativePath $Config.DOTFILES_OPENCODE_CONFIG_DIR) `
        -PiAgentDir (ConvertTo-NativePath $Config.DOTFILES_PI_AGENT_DIR) `
        -RestoreBackups $RestoreBackups
}

. (Join-Path $PSScriptRoot 'windows-config-tui.ps1')
