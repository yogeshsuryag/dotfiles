# Managed Git Bash startup hook for the Windows dotfiles engine.
# Loaded by windows-common.ps1.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

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
        '" DOTFILES_COLOR_THEME="' + (ConvertTo-BashDoubleQuoted ([string] $Config.DOTFILES_COLOR_THEME)) +
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
