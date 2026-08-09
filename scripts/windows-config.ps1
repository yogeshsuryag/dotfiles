# Shared configuration handling for the Windows dotfiles engine: config keys,
# path conversion, defaults, the Bash-compatible env file, and validation.
# Loaded by windows-common.ps1.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$script:DotfilesConfigKeys = @(
    'DOTFILES_PACKAGE_MANAGER',
    'DOTFILES_WINGET_PACKAGES',
    'DOTFILES_LOCAL_TOOLS_DIR',
    'DOTFILES_UPDATE_PACKAGES',
    'DOTFILES_INSTALL_SCOOP',
    'DOTFILES_SCOOP_BUCKETS',
    'DOTFILES_NERD_FONTS_BUCKET_URL',
    'DOTFILES_SCOOP_PACKAGES',
    'DOTFILES_UPDATE_SCOOP',
    'DOTFILES_INSTALL_PSMUX',
    'DOTFILES_INSTALL_ZSH',
    'DOTFILES_INSTALL_OH_MY_POSH',
    'DOTFILES_COLOR_THEME',
    'DOTFILES_OH_MY_POSH_THEME',
    'DOTFILES_INSTALL_HERDR',
    'DOTFILES_HERDR_INSTALL_URL',
    'DOTFILES_INSTALL_AGENT_CLIS',
    'DOTFILES_WINDOWS_HOME',
    'DOTFILES_LOCAL_APPDATA',
    'DOTFILES_APPDATA',
    'DOTFILES_XDG_CONFIG_HOME',
    'DOTFILES_DOTFILES_LINK',
    'DOTFILES_NVIM_CONFIG_DIR',
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
    Set-DotfilesDefault $Config 'DOTFILES_LOCAL_TOOLS_DIR' (Join-DotfilesConfigPath $Config.DOTFILES_LOCAL_APPDATA 'Programs')
    Set-DotfilesDefault $Config 'DOTFILES_HERDR_CONFIG_DIR' (Join-DotfilesConfigPath $Config.DOTFILES_APPDATA 'herdr')
    Set-DotfilesDefault $Config 'DOTFILES_CLAUDE_CONFIG_DIR' (Join-DotfilesConfigPath $Config.DOTFILES_WINDOWS_HOME '.claude')
    Set-DotfilesDefault $Config 'DOTFILES_CODEX_CONFIG_DIR' (Join-DotfilesConfigPath $Config.DOTFILES_WINDOWS_HOME '.codex')
    Set-DotfilesDefault $Config 'DOTFILES_OPENCODE_CONFIG_DIR' (Join-DotfilesConfigPath $Config.DOTFILES_XDG_CONFIG_HOME 'opencode')
    Set-DotfilesDefault $Config 'DOTFILES_PI_AGENT_DIR' (Join-DotfilesConfigPath $Config.DOTFILES_WINDOWS_HOME '.pi/agent')

    # Scoop is the default package manager: every app installs into its own
    # versioned directory under ~/scoop/apps/<name>/current with a shim on
    # PATH, which keeps installs self-contained, easy to update, and never
    # requires elevation. WinGet remains an alternative through
    # DOTFILES_PACKAGE_MANAGER.
    Set-DotfilesDefault $Config 'DOTFILES_PACKAGE_MANAGER' 'scoop'
    Set-DotfilesDefault $Config 'DOTFILES_WINGET_PACKAGES' 'git node neovim starship BurntSushi.ripgrep.MSVC sharkdp.fd junegunn.fzf jqlang.jq JesseDuffield.lazygit'
    Set-DotfilesDefault $Config 'DOTFILES_UPDATE_PACKAGES' '0'
    Set-DotfilesDefault $Config 'DOTFILES_INSTALL_SCOOP' '1'
    Set-DotfilesDefault $Config 'DOTFILES_SCOOP_BUCKETS' 'extras'
    Set-DotfilesDefault $Config 'DOTFILES_NERD_FONTS_BUCKET_URL' 'https://github.com/matthewjberger/scoop-nerd-fonts'
    Set-DotfilesDefault $Config 'DOTFILES_SCOOP_PACKAGES' 'git neovim starship ripgrep fd fzf jq lazygit nodejs'
    Set-DotfilesDefault $Config 'DOTFILES_UPDATE_SCOOP' '0'
    Set-DotfilesDefault $Config 'DOTFILES_INSTALL_PSMUX' '1'
    Set-DotfilesDefault $Config 'DOTFILES_INSTALL_ZSH' '0'
    Set-DotfilesDefault $Config 'DOTFILES_INSTALL_OH_MY_POSH' '0'
    $seededColorTheme = $null
    if (([string] $Config['DOTFILES_OH_MY_POSH_THEME']) -eq 'rose-pine-moon') {
        $seededColorTheme = 'rose-pine-moon'
    }
    Set-DotfilesDefault $Config 'DOTFILES_COLOR_THEME' 'tokyo-night'
    if ($null -ne $seededColorTheme) {
        $Config['DOTFILES_COLOR_THEME'] = $seededColorTheme
    }
    $Config['DOTFILES_OH_MY_POSH_THEME'] = if ([string] $Config['DOTFILES_COLOR_THEME'] -eq 'rose-pine-moon') { 'rose-pine-moon' } else { 'tokyo-night-storm' }
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
    if (@('tokyo-night', 'rose-pine-moon') -notcontains [string] $Config.DOTFILES_COLOR_THEME) {
        throw 'DOTFILES_COLOR_THEME must be tokyo-night or rose-pine-moon.'
    }
    if (@('tokyo-night-storm', 'rose-pine-moon') -notcontains [string] $Config.DOTFILES_OH_MY_POSH_THEME) {
        throw 'DOTFILES_OH_MY_POSH_THEME must be tokyo-night-storm or rose-pine-moon.'
    }
    if (@('winget', 'scoop') -notcontains [string] $Config.DOTFILES_PACKAGE_MANAGER) {
        throw 'DOTFILES_PACKAGE_MANAGER must be winget or scoop.'
    }

    $booleanKeys = @(
        'DOTFILES_INSTALL_SCOOP', 'DOTFILES_UPDATE_SCOOP', 'DOTFILES_INSTALL_PSMUX', 'DOTFILES_INSTALL_ZSH', 'DOTFILES_INSTALL_OH_MY_POSH', 'DOTFILES_INSTALL_HERDR',
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
