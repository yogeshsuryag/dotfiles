# Optional third-party installers (Herdr, agent CLIs) for the Windows
# dotfiles engine. Loaded by windows-common.ps1.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

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
