# Dispatch from the Windows dotfiles engine to the links, settings, and
# uninstall helper scripts. Loaded by windows-common.ps1.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Get-DotfilesLinkScriptArguments {
    param(
        [Parameter(Mandatory = $true)] [string] $Root,
        [Parameter(Mandatory = $true)] [hashtable] $Config
    )

    return [ordered]@{
        RepoRoot = (ConvertTo-NativePath $Root)
        UserHome = (ConvertTo-NativePath $Config.DOTFILES_WINDOWS_HOME)
        LocalAppData = (ConvertTo-NativePath $Config.DOTFILES_LOCAL_APPDATA)
        AppData = (ConvertTo-NativePath $Config.DOTFILES_APPDATA)
        XdgConfigHome = (ConvertTo-NativePath $Config.DOTFILES_XDG_CONFIG_HOME)
        DotfilesLinkPath = (ConvertTo-NativePath $Config.DOTFILES_DOTFILES_LINK)
        NvimConfigDir = (ConvertTo-NativePath $Config.DOTFILES_NVIM_CONFIG_DIR)
        DocumentsDir = (Join-Path (ConvertTo-NativePath $Config.DOTFILES_WINDOWS_HOME) 'Documents')
        HerdrConfigDir = (ConvertTo-NativePath $Config.DOTFILES_HERDR_CONFIG_DIR)
        ClaudeConfigDir = (ConvertTo-NativePath $Config.DOTFILES_CLAUDE_CONFIG_DIR)
        CodexConfigDir = (ConvertTo-NativePath $Config.DOTFILES_CODEX_CONFIG_DIR)
        OpencodeConfigDir = (ConvertTo-NativePath $Config.DOTFILES_OPENCODE_CONFIG_DIR)
        PiAgentDir = (ConvertTo-NativePath $Config.DOTFILES_PI_AGENT_DIR)
    }
}

function Invoke-DotfilesLinks {
    param(
        [Parameter(Mandatory = $true)] [string] $Root,
        [Parameter(Mandatory = $true)] [hashtable] $Config
    )

    Write-Host '==> Linking Windows application configurations'
    $linkArguments = Get-DotfilesLinkScriptArguments $Root $Config
    & (Join-Path $Root 'scripts/windows-links.ps1') @linkArguments `
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
    & (Join-Path $Root 'scripts/windows-settings.ps1') `
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

    $uninstallArguments = Get-DotfilesLinkScriptArguments $Root $Config
    & (Join-Path $Root 'scripts/windows-uninstall.ps1') @uninstallArguments `
        -RestoreBackups $RestoreBackups
}
