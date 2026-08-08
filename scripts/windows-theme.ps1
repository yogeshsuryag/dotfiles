# Color theme application for the Windows dotfiles engine: renders the Herdr
# config from the tracked template with the chosen color theme. Loaded by
# windows-common.ps1.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function ConvertTo-DotfilesHerdrThemeName {
    param([Parameter(Mandatory = $true)] [string] $ColorTheme)

    if ($ColorTheme -eq 'rose-pine-moon') { return 'rose-pine' }
    return 'tokyo-night'
}

function Get-DotfilesHerdrConfigPath {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    return Join-Path (ConvertTo-NativePath ([string] $Config.DOTFILES_HERDR_CONFIG_DIR)) 'config.toml'
}

function Get-DotfilesRenderedHerdrConfig {
    param(
        [Parameter(Mandatory = $true)] [string] $Root,
        [Parameter(Mandatory = $true)] [string] $Theme
    )

    $template = Join-Path $Root 'home/.config/herdr/config.toml.template'
    if (-not (Test-Path -LiteralPath $template -PathType Leaf)) {
        throw "Tracked Herdr config template was not found: $template"
    }
    return (Get-Content -LiteralPath $template -Raw).Replace('{DOTFILES_COLOR_THEME}', $Theme)
}

function Write-DotfilesHerdrConfig {
    param(
        [Parameter(Mandatory = $true)] [string] $Root,
        [Parameter(Mandatory = $true)] [hashtable] $Config
    )

    Write-Host '==> Rendering Herdr config with the chosen color theme'
    $theme = ConvertTo-DotfilesHerdrThemeName ([string] $Config.DOTFILES_COLOR_THEME)
    $content = Get-DotfilesRenderedHerdrConfig -Root $Root -Theme $theme
    $target = Get-DotfilesHerdrConfigPath $Config
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        $existing = Get-Content -LiteralPath $target -Raw
        if ($existing -eq $content) {
            Write-Host "Herdr config already uses the $theme theme"
            return
        }
    }
    $parent = Split-Path -Parent $target
    if ($parent) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-DotfilesTextFile $target $content
    Write-Host "Rendered Herdr config with the $theme theme at $target"
}

function Remove-DotfilesHerdrConfig {
    param(
        [Parameter(Mandatory = $true)] [string] $Root,
        [Parameter(Mandatory = $true)] [hashtable] $Config
    )

    $target = Get-DotfilesHerdrConfigPath $Config
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        return
    }
    $content = Get-Content -LiteralPath $target -Raw
    $rendered = @(
        (Get-DotfilesRenderedHerdrConfig -Root $Root -Theme 'tokyo-night'),
        (Get-DotfilesRenderedHerdrConfig -Root $Root -Theme 'rose-pine')
    )
    if ($rendered -notcontains $content) {
        Write-Host "Kept unmanaged Herdr config at $target"
        return
    }
    Remove-Item -LiteralPath $target -Force
    Write-Host "Removed generated Herdr config $target"
}
