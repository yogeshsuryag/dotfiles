# Optional third-party installers (Herdr, agent CLIs, and agent skills) for the
# Windows dotfiles engine. Loaded by windows-common.ps1.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$script:DotfilesAgenticSkills = @(
    [pscustomobject]@{
        ConfigKey = 'DOTFILES_INSTALL_GH_AXI'
        Name = 'GitHub AXI'
        Source = 'kunchenguid/gh-axi'
        Skill = 'gh-axi'
    }
    [pscustomobject]@{
        ConfigKey = 'DOTFILES_INSTALL_CHROME_DEVTOOLS_AXI'
        Name = 'Chrome DevTools AXI'
        Source = 'kunchenguid/chrome-devtools-axi'
        Skill = 'chrome-devtools-axi'
    }
    [pscustomobject]@{
        ConfigKey = 'DOTFILES_INSTALL_LAVISH_AXI'
        Name = 'Lavish AXI'
        Source = 'kunchenguid/lavish-axi'
        Skill = 'lavish'
    }
)

function Install-DotfilesHerdr {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    if ([string] $Config.DOTFILES_INSTALL_HERDR -ne '1' -or (Get-Command herdr -ErrorAction SilentlyContinue)) {
        return
    }
    Write-Host "==> Installing Herdr's Windows beta"
    Invoke-Expression (Invoke-RestMethod -Uri ([string] $Config.DOTFILES_HERDR_INSTALL_URL))
}

function Install-DotfilesAgentClis {
    param(
        [Parameter(Mandatory = $true)] [hashtable] $Config,
        [string[]] $Packages = @()
    )

    if ([string] $Config.DOTFILES_INSTALL_AGENT_CLIS -ne '1') {
        return
    }
    if ($Packages.Count -eq 0) {
        $Packages = @('@anthropic-ai/claude-code', '@openai/codex', '@earendil-works/pi-coding-agent', 'opencode-ai')
    }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        throw 'Agent CLIs requested, but npm is unavailable. Select the Node.js LTS package in the setup UI, or add node to DOTFILES_WINGET_PACKAGES (or nodejs to DOTFILES_SCOOP_PACKAGES in Scoop mode), then rerun.'
    }
    Write-Host "==> Installing optional agent CLIs with npm: $($Packages -join ' ')"
    Invoke-DotfilesCommand 'npm' ((@('install', '--global', '--ignore-scripts') + @($Packages)))
}

function Install-DotfilesAgenticSkills {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    $selected = @($script:DotfilesAgenticSkills | Where-Object { [string] $Config[$_.ConfigKey] -eq '1' })
    if ($selected.Count -eq 0) {
        return
    }
    if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
        throw 'Agentic skills requested, but npx is unavailable. Select the Node.js LTS package in the setup UI, or install Node.js and rerun the bootstrap.'
    }

    foreach ($skill in $selected) {
        Write-Host "==> Installing $($skill.Name) globally with npx"
        Invoke-DotfilesCommand 'npx' @('--yes', 'skills', 'add', $skill.Source, '--skill', $skill.Skill, '-g', '-y')
    }
}
