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
$script:DotfilesNoMistakesInstallUrl = 'https://raw.githubusercontent.com/kunchenguid/no-mistakes/main/docs/install.ps1'
$script:DotfilesTreehouseInstallUrl = 'https://kunchenguid.github.io/treehouse/install.ps1'

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

function Install-DotfilesNoMistakes {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    if ([string] $Config.DOTFILES_INSTALL_NO_MISTAKES -ne '1') {
        return
    }

    $hasLocalAppDataVariable = -not [string]::IsNullOrWhiteSpace([string] $env:LOCALAPPDATA)
    $localAppData = if (-not $hasLocalAppDataVariable) {
        [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    } else {
        [string] $env:LOCALAPPDATA
    }
    if ([string]::IsNullOrWhiteSpace($localAppData)) {
        throw 'no-mistakes requested, but Windows did not provide a user-local application data directory.'
    }

    $installPath = Join-Path (Join-Path $localAppData 'no-mistakes') 'no-mistakes.exe'
    $command = Get-Command no-mistakes -ErrorAction SilentlyContinue
    if ((Test-Path -LiteralPath $installPath -PathType Leaf) -or $null -ne $command) {
        return
    }

    Write-Host '==> Installing no-mistakes for the current user'
    if (-not $hasLocalAppDataVariable) {
        $env:LOCALAPPDATA = $localAppData
    }
    try {
        $installer = Invoke-RestMethod -Uri $script:DotfilesNoMistakesInstallUrl
        if ([string]::IsNullOrWhiteSpace([string] $installer)) {
            throw 'no-mistakes installer returned an empty response.'
        }
        Invoke-Expression ([string] $installer)
    } finally {
        if (-not $hasLocalAppDataVariable) {
            Remove-Item Env:LOCALAPPDATA -ErrorAction SilentlyContinue
        }
    }
}

function Install-DotfilesGnhf {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    if ([string] $Config.DOTFILES_INSTALL_GNHF -ne '1') {
        return
    }
    if ($null -ne (Get-Command gnhf -ErrorAction SilentlyContinue)) {
        return
    }

    $npmCommand = Get-Command npm -ErrorAction SilentlyContinue
    if ($null -eq $npmCommand) {
        throw 'gnhf requested, but npm is unavailable. Select the Node.js LTS package in the setup UI, or install Node.js and rerun the bootstrap.'
    }
    $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
    if ($null -eq $nodeCommand) {
        throw 'gnhf requires Node.js 20 or newer, but node is unavailable. Select the Node.js LTS package in the setup UI, then rerun the bootstrap.'
    }

    $nodeVersionOutput = @(& $nodeCommand.Source '--version' 2>$null)
    $nodeVersion = if ($nodeVersionOutput.Count -gt 0) { ([string] $nodeVersionOutput[0]).Trim() } else { '' }
    $nodeVersionMatch = [regex]::Match($nodeVersion, '^v?(\d+)')
    if ($LASTEXITCODE -ne 0 -or -not $nodeVersionMatch.Success) {
        throw 'gnhf requires Node.js 20 or newer, but the installed node version could not be determined.'
    }
    $nodeMajor = [int] $nodeVersionMatch.Groups[1].Value
    if ($nodeMajor -lt 20) {
        throw "gnhf requires Node.js 20 or newer, but $nodeVersion is installed. Select the Node.js LTS package and rerun the bootstrap."
    }

    Write-Host '==> Installing gnhf globally with npm'
    Invoke-DotfilesCommand 'npm' @('install', '-g', 'gnhf')
}

function Install-DotfilesTreehouse {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    if ([string] $Config.DOTFILES_INSTALL_TREEHOUSE -ne '1') {
        return
    }

    $hasLocalAppDataVariable = -not [string]::IsNullOrWhiteSpace([string] $env:LOCALAPPDATA)
    $localAppData = if (-not $hasLocalAppDataVariable) {
        [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    } else {
        [string] $env:LOCALAPPDATA
    }
    if ([string]::IsNullOrWhiteSpace($localAppData)) {
        throw 'Treehouse requested, but Windows did not provide a user-local application data directory.'
    }

    $installPath = Join-Path (Join-Path $localAppData 'treehouse') 'treehouse.exe'
    $command = Get-Command treehouse -ErrorAction SilentlyContinue
    if ((Test-Path -LiteralPath $installPath -PathType Leaf) -or $null -ne $command) {
        return
    }

    Write-Host '==> Installing Treehouse for the current user'
    if (-not $hasLocalAppDataVariable) {
        $env:LOCALAPPDATA = $localAppData
    }
    try {
        $installer = Invoke-RestMethod -Uri $script:DotfilesTreehouseInstallUrl
        if ([string]::IsNullOrWhiteSpace([string] $installer)) {
            throw 'Treehouse installer returned an empty response.'
        }
        Invoke-Expression ([string] $installer)
    } finally {
        if (-not $hasLocalAppDataVariable) {
            Remove-Item Env:LOCALAPPDATA -ErrorAction SilentlyContinue
        }
    }
}
