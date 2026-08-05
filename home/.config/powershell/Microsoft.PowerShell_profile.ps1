# Shared profile for Windows PowerShell 5.1 and PowerShell 7.

$script:DotfilesProfileConfig = @{}

function ConvertFrom-DotfilesProfileValue {
    param([Parameter(Mandatory = $true)] [string] $RawValue)

    $value = $RawValue.Trim()
    if (-not $value) {
        return ''
    }
    if ($value.StartsWith('"') -and $value.EndsWith('"') -and $value.Length -ge 2) {
        $value = $value.Substring(1, $value.Length - 2)
        $builder = New-Object System.Text.StringBuilder
        for ($index = 0; $index -lt $value.Length; $index++) {
            $char = $value[$index]
            if ($char -eq '\' -and $index + 1 -lt $value.Length) {
                $next = $value[$index + 1]
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
    if ($value.StartsWith("'") -and $value.EndsWith("'") -and $value.Length -ge 2) {
        return $value.Substring(1, $value.Length - 2)
    }
    return $value
}

function ConvertTo-DotfilesProfileNativePath {
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

function ConvertTo-DotfilesProfileMsysPath {
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

function Get-DotfilesProfileConfigFile {
    $candidates = @()
    if ($env:DOTFILES_CONFIG_FILE) {
        $candidates += ConvertTo-DotfilesProfileNativePath $env:DOTFILES_CONFIG_FILE
    }
    if ($env:DOTFILES_ROOT) {
        $candidates += Join-Path (ConvertTo-DotfilesProfileNativePath $env:DOTFILES_ROOT) 'windows-config.env'
    }
    if ($env:DOTFILES_DOTFILES_LINK) {
        $candidates += Join-Path (ConvertTo-DotfilesProfileNativePath $env:DOTFILES_DOTFILES_LINK) 'windows-config.env'
    }
    $candidates += Join-Path $HOME '.dotfiles/windows-config.env'

    foreach ($candidate in @($candidates | Where-Object { $_ } | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }
    return $null
}

$profileConfigFile = Get-DotfilesProfileConfigFile
if ($profileConfigFile) {
    foreach ($line in (Get-Content -LiteralPath $profileConfigFile)) {
        if ($line -match '^\s*(DOTFILES_[A-Za-z0-9_]+)\s*=\s*(.*)$') {
            $script:DotfilesProfileConfig[$matches[1]] = ConvertFrom-DotfilesProfileValue $matches[2]
        }
    }
}

function Get-DotfilesProfileValue {
    param(
        [Parameter(Mandatory = $true)] [string] $Name,
        [Parameter(Mandatory = $true)] [string] $Default
    )

    $environmentValue = [Environment]::GetEnvironmentVariable($Name, 'Process')
    if (-not [string]::IsNullOrEmpty($environmentValue)) {
        return $environmentValue
    }
    if ($script:DotfilesProfileConfig.ContainsKey($Name)) {
        return [string] $script:DotfilesProfileConfig[$Name]
    }
    return $Default
}

$profileRootValue = if ($env:DOTFILES_ROOT) {
    $env:DOTFILES_ROOT
} elseif ($env:DOTFILES_DOTFILES_LINK) {
    $env:DOTFILES_DOTFILES_LINK
} elseif ($script:DotfilesProfileConfig.ContainsKey('DOTFILES_DOTFILES_LINK')) {
    [string] $script:DotfilesProfileConfig.DOTFILES_DOTFILES_LINK
} else {
    Join-Path $HOME '.dotfiles'
}
$script:DotfilesProfileRoot = ConvertTo-DotfilesProfileNativePath $profileRootValue

$env:DOTFILES_ROOT = ConvertTo-DotfilesProfileMsysPath $script:DotfilesProfileRoot
$env:DOTFILES_DOTFILES_LINK = $env:DOTFILES_ROOT
$env:EDITOR = Get-DotfilesProfileValue 'DOTFILES_EDITOR' 'nvim'
$env:VISUAL = Get-DotfilesProfileValue 'DOTFILES_VISUAL' $env:EDITOR
$env:PI_CODING_AGENT_DIR = ConvertTo-DotfilesProfileNativePath (Get-DotfilesProfileValue 'DOTFILES_PI_AGENT_DIR' (Join-Path $HOME '.pi/agent'))

function Get-DotfilesOhMyPoshThemePath {
    $theme = Get-DotfilesProfileValue 'DOTFILES_OH_MY_POSH_THEME' 'tokyo-night-storm'
    if ($theme -notin @('tokyo-night-storm', 'rose-pine-moon')) {
        $theme = 'tokyo-night-storm'
    }
    return Join-Path $script:DotfilesProfileRoot "home/.config/oh-my-posh/$theme.omp.json"
}

function Initialize-DotfilesOhMyPosh {
    if ((Get-DotfilesProfileValue 'DOTFILES_INSTALL_OH_MY_POSH' '0') -ne '1') {
        return
    }
    $command = Get-Command 'oh-my-posh' -ErrorAction SilentlyContinue
    $themePath = Get-DotfilesOhMyPoshThemePath
    if ($null -eq $command -or -not (Test-Path -LiteralPath $themePath -PathType Leaf)) {
        return
    }
    & $command.Source init pwsh --config $themePath | Invoke-Expression
}

function Find-DotfilesMsys2Shell {
    $roots = @()
    if ($env:SCOOP) {
        $roots += Join-Path (ConvertTo-DotfilesProfileNativePath $env:SCOOP) 'apps/msys2/current'
    }
    $roots += Join-Path $HOME 'scoop/apps/msys2/current'
    foreach ($root in @($roots | Where-Object { $_ } | Select-Object -Unique)) {
        $shell = Join-Path $root 'msys2_shell.cmd'
        $zsh = Join-Path $root 'usr/bin/zsh.exe'
        if ((Test-Path -LiteralPath $shell -PathType Leaf) -and (Test-Path -LiteralPath $zsh -PathType Leaf)) {
            return $shell
        }
    }
    return $null
}

Initialize-DotfilesOhMyPosh

$interactiveConsole = $Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected
$shouldStartZsh = (Get-DotfilesProfileValue 'DOTFILES_INSTALL_ZSH' '1') -eq '1' -and
    $env:DOTFILES_ZSH_ACTIVE -ne '1' -and $env:DOTFILES_NO_ZSH -ne '1'
if ($interactiveConsole -and $shouldStartZsh) {
    $msys2Shell = Find-DotfilesMsys2Shell
    if ($msys2Shell) {
        $env:DOTFILES_ZSH_ACTIVE = '1'
        $env:DOTFILES_INSTALL_ZSH = '1'
        $env:DOTFILES_INSTALL_OH_MY_POSH = Get-DotfilesProfileValue 'DOTFILES_INSTALL_OH_MY_POSH' '0'
        $env:DOTFILES_OH_MY_POSH_THEME = Get-DotfilesProfileValue 'DOTFILES_OH_MY_POSH_THEME' 'tokyo-night-storm'
        & $msys2Shell '-defterm' '-here' '-no-start' '-msys' '-shell' 'zsh'
        $exitCode = $LASTEXITCODE
        exit $exitCode
    }
    Write-Warning 'MSYS2 zsh was not found; continuing with native PowerShell.'
}
