[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('dotfiles-windows-' + [guid]::NewGuid().ToString())
$passed = 0
$powerShellExecutable = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell.exe' }

function Pass-Test {
    param([Parameter(Mandatory = $true)] [string] $Message)
    $script:passed++
    Write-Host "ok - $Message"
}

function Fail-Test {
    param([Parameter(Mandatory = $true)] [string] $Message)
    throw $Message
}

function Assert-Test {
    param(
        [Parameter(Mandatory = $true)] [bool] $Condition,
        [Parameter(Mandatory = $true)] [string] $Message
    )
    if (-not $Condition) { Fail-Test $Message }
}

function Invoke-NativeScript {
    param(
        [Parameter(Mandatory = $true)] [string] $ScriptPath,
        [string[]] $CommandArguments = @()
    )

    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $script:powerShellExecutable -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $ScriptPath @CommandArguments 2>&1 | Out-String
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output = $output
        }
    } finally {
        $ErrorActionPreference = $previousErrorPreference
    }
}

function Invoke-WithConfigPath {
    param(
        [Parameter(Mandatory = $true)] [string] $ConfigPath,
        [Parameter(Mandatory = $true)] [scriptblock] $ScriptBlock
    )

    $previous = [Environment]::GetEnvironmentVariable('DOTFILES_CONFIG_FILE', 'Process')
    $env:DOTFILES_CONFIG_FILE = $ConfigPath
    try {
        & $ScriptBlock
    } finally {
        if ($null -eq $previous) {
            Remove-Item Env:DOTFILES_CONFIG_FILE -ErrorAction SilentlyContinue
        } else {
            $env:DOTFILES_CONFIG_FILE = $previous
        }
    }
}

function Get-LinkArguments {
    param(
        [Parameter(Mandatory = $true)] [string] $FixtureRoot,
        [Parameter(Mandatory = $true)] [string] $RepositoryRoot
    )

    $user = Join-Path $FixtureRoot 'user'
    $local = Join-Path $FixtureRoot 'local'
    $appData = Join-Path $FixtureRoot 'appdata'
    $xdg = Join-Path $FixtureRoot 'xdg'
    return @(
        '-RepoRoot', $RepositoryRoot,
        '-UserHome', $user,
        '-LocalAppData', $local,
        '-AppData', $appData,
        '-XdgConfigHome', $xdg,
        '-DotfilesLinkPath', (Join-Path $user '.dotfiles'),
        '-NvimConfigDir', (Join-Path $local 'nvim'),
        '-DocumentsDir', (Join-Path $fixtureRoot 'documents'),
        '-HerdrConfigDir', (Join-Path $appData 'herdr'),
        '-ClaudeConfigDir', (Join-Path $user '.claude'),
        '-CodexConfigDir', (Join-Path $user '.codex'),
        '-OpencodeConfigDir', (Join-Path $xdg 'opencode'),
        '-PiAgentDir', (Join-Path $user '.pi/agent'),
        '-LinkMode', 'junction',
        '-BackupExisting', '1'
    )
}

try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    . (Join-Path $root 'scripts/windows-common.ps1')

    $scriptsToParse = @(Get-ChildItem -LiteralPath $root -Filter '*.ps1' -File)
    $scriptsToParse += Get-ChildItem -LiteralPath (Join-Path $root 'scripts') -Filter '*.ps1' -File
    $scriptsToParse += Get-ChildItem -LiteralPath (Join-Path $root 'home/.config/powershell') -Filter '*.ps1' -File
    foreach ($script in $scriptsToParse) {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref] $tokens, [ref] $errors) | Out-Null
        Assert-Test ($errors.Count -eq 0) "PowerShell script parses: $($script.Name)"
    }
    Pass-Test 'PowerShell scripts parse under Windows PowerShell'

    $config = Read-DotfilesEnvFile (Join-Path $root 'windows-config.example.env')
    Initialize-DotfilesConfigDefaults $config | Out-Null
    Assert-DotfilesConfig $config
    Assert-Test ([string] $config.DOTFILES_PACKAGE_MANAGER -eq 'scoop') 'Scoop is the default package manager'
    Assert-Test ([string] $config.DOTFILES_INSTALL_ZSH -eq '0') 'MSYS2 zsh is opt-in by default'
    Assert-Test ([string] $config.DOTFILES_COLOR_THEME -eq 'tokyo-night') 'tokyo-night is the default color theme'
    Assert-Test ([string] $config.DOTFILES_OH_MY_POSH_THEME -eq 'tokyo-night-storm') 'tokyo-night-storm is the derived prompt theme'
    $seededConfig = @{ DOTFILES_OH_MY_POSH_THEME = 'rose-pine-moon' }
    Initialize-DotfilesConfigDefaults $seededConfig | Out-Null
    Assert-Test ([string] $seededConfig.DOTFILES_COLOR_THEME -eq 'rose-pine-moon') 'existing rose-pine-moon prompt choice seeds the color theme'
    $invalidThemeConfig = Read-DotfilesEnvFile (Join-Path $root 'windows-config.example.env')
    Initialize-DotfilesConfigDefaults $invalidThemeConfig | Out-Null
    $invalidThemeConfig.DOTFILES_COLOR_THEME = 'gruvbox'
    $invalidThemeThrew = $false
    try { Assert-DotfilesConfig $invalidThemeConfig } catch { $invalidThemeThrew = $true }
    Assert-Test $invalidThemeThrew 'Assert-DotfilesConfig rejects unknown color themes'
    $config.DOTFILES_EDITOR = 'C:\Program Files\Editor\editor.exe "$HOME"'
    $roundTripPath = Join-Path $testRoot 'roundtrip.env'
    Write-DotfilesEnvFile $config $roundTripPath
    $roundTrip = Read-DotfilesEnvFile $roundTripPath
    foreach ($key in $script:DotfilesConfigKeys) {
        Assert-Test ([string] $roundTrip[$key] -eq [string] $config[$key]) "configuration round-trip preserved $key"
    }
    Pass-Test 'Shared windows-config.env values parse and serialize without Bash'

    $missingConfig = Join-Path $testRoot 'missing-windows-config.env'
    foreach ($scriptName in @('bootstrap.ps1', 'rebuild.ps1', 'uninstall.ps1')) {
        $scriptPath = Join-Path $root $scriptName
        $result = Invoke-WithConfigPath $missingConfig {
            Invoke-NativeScript $scriptPath @('--check')
        }
        Assert-Test ($result.ExitCode -eq 0) "$scriptName --check succeeded"
        Assert-Test (-not (Test-Path -LiteralPath $missingConfig)) "$scriptName --check did not create configuration"
    }
    Pass-Test 'PowerShell preflight modes are non-mutating'

    $noninteractiveConfig = Join-Path $testRoot 'noninteractive-windows-config.env'
    $result = Invoke-WithConfigPath $noninteractiveConfig {
        Invoke-NativeScript (Join-Path $root 'bootstrap.ps1') @()
    }
    Assert-Test ($result.ExitCode -ne 0) 'noninteractive bootstrap refused configuration creation'
    Assert-Test (-not (Test-Path -LiteralPath $noninteractiveConfig)) 'noninteractive bootstrap did not create configuration'
    Assert-Test (($result.Output -match 'interactive') -and ($result.Output -match 'configuration') -and ($result.Output -match 'UI')) 'noninteractive bootstrap explained how to configure'
    Pass-Test 'Noninteractive bootstrap refuses to create local configuration'

    foreach ($scriptName in @('bootstrap.ps1', 'rebuild.ps1', 'uninstall.ps1')) {
        $result = Invoke-NativeScript (Join-Path $root $scriptName) @('--unsupported')
        Assert-Test ($result.ExitCode -eq 2) "$scriptName rejects unsupported arguments"
    }
    Pass-Test 'PowerShell entry points reject unsupported arguments'

    $stateConfig = Read-DotfilesEnvFile (Join-Path $root 'windows-config.example.env')
    Initialize-DotfilesConfigDefaults $stateConfig | Out-Null
    $state = New-DotfilesTuiState $stateConfig 'test.env'
    Set-DotfilesTuiItems $state
    Assert-Test ($state.Items.Count -gt 10) 'PowerShell TUI package page contains the documented choices'
    Assert-Test ((Get-DotfilesTuiSelectedPackages $state) -eq $stateConfig.DOTFILES_SCOOP_PACKAGES) 'PowerShell TUI initializes package choices'
    $state.PackageSelected.git = $false
    $state.PackageSelected['oh-my-posh'] = $true
    $state.CustomPackages = @('bat', 'delta')
    Sync-DotfilesTuiToConfig $state
    Assert-Test ($stateConfig.DOTFILES_SCOOP_PACKAGES -eq 'neovim starship ripgrep fd fzf jq lazygit nodejs bat delta') 'PowerShell TUI serializes Scoop package choices'
    Assert-Test ($stateConfig.DOTFILES_WINGET_PACKAGES -eq 'neovim starship BurntSushi.ripgrep.MSVC sharkdp.fd junegunn.fzf jqlang.jq JesseDuffield.lazygit node bat delta') 'PowerShell TUI serializes WinGet package choices'
    Assert-Test ([string] $stateConfig.DOTFILES_INSTALL_OH_MY_POSH -eq '1') 'PowerShell TUI enables Oh My Posh with the package choice'
    $managerItem = @($state.Items | Where-Object { $_.Key -eq 'DOTFILES_PACKAGE_MANAGER' })[0]
    Assert-Test ($managerItem.Kind -eq 'choice') 'PowerShell TUI exposes the package manager choice'
    Toggle-DotfilesTuiItem $state $managerItem
    Assert-Test ($stateConfig.DOTFILES_PACKAGE_MANAGER -eq 'winget') 'PowerShell TUI toggles the package manager'
    $state.Page = 3
    Set-DotfilesTuiItems $state
    $themeItem = @($state.Items | Where-Object { $_.Key -eq 'DOTFILES_COLOR_THEME' })[0]
    Assert-Test ($themeItem.Kind -eq 'choice') 'PowerShell TUI exposes the color theme choice'
    Toggle-DotfilesTuiItem $state $themeItem
    Assert-Test ($stateConfig.DOTFILES_COLOR_THEME -eq 'rose-pine-moon') 'PowerShell TUI toggles the color theme'
    Assert-Test ((Get-DotfilesTuiChoiceLabel 'DOTFILES_COLOR_THEME' 'tokyo-night') -eq 'Tokyo Night (recommended)') 'PowerShell TUI labels Tokyo Night as the recommended color theme'
    $stateConfig.DOTFILES_COLOR_THEME = 'tokyo-night'
    Sync-DotfilesTuiToConfig $state
    Assert-Test ([string] $stateConfig.DOTFILES_OH_MY_POSH_THEME -eq 'tokyo-night-storm') 'PowerShell TUI derives the prompt theme from Tokyo Night'
    $stateConfig.DOTFILES_COLOR_THEME = 'rose-pine-moon'
    Sync-DotfilesTuiToConfig $state
    Assert-Test ([string] $stateConfig.DOTFILES_OH_MY_POSH_THEME -eq 'rose-pine-moon') 'PowerShell TUI derives the prompt theme from Rose Pine Moon'
    Pass-Test 'PowerShell TUI state covers documented package choices'

    $fakeBin = Join-Path $testRoot 'fakebin'
    New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null
    Copy-Item -LiteralPath (Get-Command $powerShellExecutable).Source -Destination (Join-Path $fakeBin 'fake-tool.exe') -Force
    $previousPath = $env:PATH
    $env:PATH = "$fakeBin;$previousPath"
    try {
        $foundProbe = Test-DotfilesToolOnPath 'fake-tool'
        Assert-Test ($null -ne $foundProbe -and $foundProbe.Source -eq (Join-Path $fakeBin 'fake-tool.exe')) 'plan tool probe finds a tool on PATH'
        Assert-Test ($null -eq (Test-DotfilesToolOnPath 'dotfiles-tool-that-does-not-exist')) 'plan tool probe reports missing tools'
        $planConfig = Read-DotfilesEnvFile (Join-Path $root 'windows-config.example.env')
        Initialize-DotfilesConfigDefaults $planConfig | Out-Null
        $planConfig.DOTFILES_PACKAGE_MANAGER = 'scoop'
        $planConfig.DOTFILES_SCOOP_PACKAGES = 'fake-tool dotfiles-tool-that-does-not-exist git'
        $planConfig.DOTFILES_INSTALL_AGENT_CLIS = '0'
        $plan = @(Get-DotfilesPackagePlan $planConfig)
        Assert-Test ($plan.Count -eq 3) 'package plan covers every declared package'
        $availableEntry = @($plan | Where-Object { $_.Name -eq 'fake-tool' })[0]
        Assert-Test ($availableEntry.Status -eq 'available') 'plan marks PATH tools from another source as available'
        Assert-Test ($availableEntry.RecommendedAction -eq 'Skip' -and $availableEntry.Action -eq 'Skip') 'plan recommends and defaults to Skip for available tools'
        Assert-Test (($availableEntry.AllowedActions -join ',') -eq 'Skip,Replace') 'plan offers Replace for available tools'
        $missingEntry = @($plan | Where-Object { $_.Name -eq 'dotfiles-tool-that-does-not-exist' })[0]
        Assert-Test ($missingEntry.Status -eq 'not-found' -and $missingEntry.RecommendedAction -eq 'Install' -and $missingEntry.Action -eq 'Install') 'plan recommends and defaults to Install for missing tools'
        $gitEntry = @($plan | Where-Object { $_.Name -eq 'git' })[0]
        Assert-Test ($gitEntry.Status -in @('installed', 'available')) 'plan recognizes the git executable on the machine'
        Set-DotfilesPlanEntryNextAction $missingEntry
        Assert-Test ($missingEntry.Action -eq 'Skip') 'plan action cycles forward from Install to Skip'
        Set-DotfilesPlanEntryNextAction $missingEntry
        Assert-Test ($missingEntry.Action -eq 'Install') 'plan action cycles back to the first allowed action'
        Pass-Test 'Package plan detects existing tools and recommends the best choice'
    } finally {
        $env:PATH = $previousPath
    }

    $agentConfig = Read-DotfilesEnvFile (Join-Path $root 'windows-config.example.env')
    Initialize-DotfilesConfigDefaults $agentConfig | Out-Null
    $agentConfig.DOTFILES_PACKAGE_MANAGER = 'scoop'
    $agentConfig.DOTFILES_SCOOP_PACKAGES = ''
    $agentConfig.DOTFILES_INSTALL_AGENT_CLIS = '1'
    $agentPlan = @(Get-DotfilesPackagePlan $agentConfig)
    Assert-Test ($agentPlan.Count -eq 4) 'agent CLIs are added to the plan when enabled'
    Assert-Test ((@($agentPlan | Where-Object { $_.ManagerName -eq 'npm' }).Count) -eq 4) 'agent CLI plan entries use the npm manager'
    Assert-Test ((@($agentPlan | Where-Object { $_.Package -eq '@anthropic-ai/claude-code' }).Count) -eq 1) 'agent CLI plan entries carry the npm package name'
    Pass-Test 'Optional agent CLIs participate in the package plan'

    $autoProbe = Join-Path $testRoot 'auto-apply-probe.ps1'
    Set-Content -LiteralPath $autoProbe -Value @'
$probeRoot = $args[0]
. (Join-Path $probeRoot 'scripts/windows-common.ps1')
$config = @{}
Initialize-DotfilesConfigDefaults $config | Out-Null
$config.DOTFILES_PACKAGE_MANAGER = 'scoop'
$config.DOTFILES_SCOOP_PACKAGES = 'dotfiles-tool-that-does-not-exist'
$config.DOTFILES_INSTALL_AGENT_CLIS = '0'
$plan = @(Get-DotfilesPackagePlan $config)
$result = Invoke-DotfilesPackagePlanReview $plan
Write-Output "result=$result action=$($plan[0].Action)"
'@ -NoNewline
    $probeProcess = New-Object System.Diagnostics.Process
    $probeProcess.StartInfo.FileName = $powerShellExecutable
    $probeProcess.StartInfo.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$autoProbe`" `"$root`""
    $probeProcess.StartInfo.UseShellExecute = $false
    $probeProcess.StartInfo.RedirectStandardInput = $true
    $probeProcess.StartInfo.RedirectStandardOutput = $true
    $probeProcess.StartInfo.RedirectStandardError = $true
    [void] $probeProcess.Start()
    $probeProcess.StandardInput.Close()
    $autoOutput = $probeProcess.StandardOutput.ReadToEnd()
    $probeProcess.WaitForExit()
    Assert-Test ($probeProcess.ExitCode -eq 0) 'non-interactive plan review completes without a terminal'
    Assert-Test ($autoOutput -match 'result=True') 'non-interactive plan review auto-applies recommendations'
    Assert-Test ($autoOutput -match 'action=Install') 'non-interactive plan review keeps the recommended action for missing tools'
    Pass-Test 'Non-interactive plan review applies recommendations without a terminal'

    $planFixtureConfig = Read-DotfilesEnvFile (Join-Path $root 'windows-config.example.env')
    Initialize-DotfilesConfigDefaults $planFixtureConfig | Out-Null
    $planFixturePath = Join-Path $testRoot 'plan-windows-config.env'
    Write-DotfilesEnvFile $planFixtureConfig $planFixturePath
    $checkResult = Invoke-WithConfigPath $planFixturePath {
        Invoke-NativeScript (Join-Path $root 'bootstrap.ps1') @('--check')
    }
    Assert-Test ($checkResult.ExitCode -eq 0) 'bootstrap --check prints the package plan'
    Assert-Test ($checkResult.Output -match 'Detected tools before installation') 'bootstrap --check shows the detected tools heading'
    Pass-Test 'bootstrap --check previews detected tools without installing'

    $wingetArguments = Get-DotfilesWingetInstallArguments 'BurntSushi.ripgrep.MSVC'
    Assert-Test (($wingetArguments -contains '--silent') -and ($wingetArguments -contains '--disable-interactivity')) 'WinGet install arguments stay silent and noninteractive'
    Assert-Test (-not ($wingetArguments -contains '--scope')) 'WinGet install arguments do not force a scope unsupported by portable packages'
    Pass-Test 'WinGet install arguments avoid elevation traps'

    $settingsResult = Invoke-NativeScript (Join-Path $root 'scripts/windows-settings.ps1') @(
        '-DarkMode', '0', '-ShowFileExtensions', '0', '-ShowHiddenFiles', '0',
        '-HideDesktopIcons', '0', '-TaskbarAutoHide', '0', '-KeyboardRepeat', '0',
        '-RestartExplorer', '0'
    )
    Assert-Test ($settingsResult.ExitCode -eq 0) 'disabled Windows settings are a no-op'
    Pass-Test 'Disabled Windows settings make no system changes'

    $fixture = Join-Path $testRoot 'links'
    New-Item -ItemType Directory -Path (Join-Path $fixture 'user/.claude') -Force | Out-Null
    $settingsTarget = Join-Path $fixture 'user/.claude/settings.json'
    Set-Content -LiteralPath $settingsTarget -Value 'pre-existing settings' -NoNewline
    $linkScript = Join-Path $root 'scripts/windows-links.ps1'
    $linkArguments = Get-LinkArguments $fixture $root
    $linkResult = Invoke-NativeScript $linkScript $linkArguments
    Assert-Test ($linkResult.ExitCode -eq 0) 'Windows link helper created disposable links without elevation'
    Assert-Test ($linkResult.Output -match 'HardLink') 'Windows link helper used hard links for files by default'
    Assert-Test (Test-Path -LiteralPath $settingsTarget -PathType Leaf) 'Windows link helper created the settings link'
    $profile51Target = Join-Path $fixture 'documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1'
    $profile7Target = Join-Path $fixture 'documents/PowerShell/Microsoft.PowerShell_profile.ps1'
    Assert-Test (Test-Path -LiteralPath $profile51Target -PathType Leaf) 'Windows link helper linked the Windows PowerShell profile'
    Assert-Test (Test-Path -LiteralPath $profile7Target -PathType Leaf) 'Windows link helper linked the PowerShell 7 profile'
    $backupPattern = "$settingsTarget.dotfiles-backup-*"
    $backupCount = @(Get-ChildItem -Path $backupPattern -Force).Count
    Assert-Test ($backupCount -eq 1) 'Windows link helper preserved the existing settings file'

    $secondResult = Invoke-NativeScript $linkScript $linkArguments
    Assert-Test ($secondResult.ExitCode -eq 0) 'Windows link helper reapplied links'
    Assert-Test (@(Get-ChildItem -Path $backupPattern -Force).Count -eq $backupCount) 'reapplying links did not create an unnecessary backup'

    $uninstallArguments = @()
    for ($index = 0; $index -lt $linkArguments.Count; $index += 2) {
        if ($linkArguments[$index] -in @('-LinkMode', '-BackupExisting')) {
            continue
        }
        $uninstallArguments += $linkArguments[$index], $linkArguments[$index + 1]
    }
    $uninstallResult = Invoke-NativeScript (Join-Path $root 'scripts/windows-uninstall.ps1') ($uninstallArguments + @('-RestoreBackups', '1'))
    Assert-Test ($uninstallResult.ExitCode -eq 0) 'Windows uninstall helper removed disposable links'
    Assert-Test ((Get-Content -LiteralPath $settingsTarget -Raw) -eq 'pre-existing settings') 'Windows uninstall helper restored the preserved settings file'
    Assert-Test (-not (Test-Path -LiteralPath $profile7Target)) 'Windows uninstall helper removed the PowerShell profile link'
    Pass-Test 'Windows links are repeatable, backup-safe, restorable, and non-elevated'

    $hookConfig = Read-DotfilesEnvFile (Join-Path $root 'windows-config.example.env')
    Initialize-DotfilesConfigDefaults $hookConfig | Out-Null
    $hookHome = Join-Path $testRoot 'hook-home'
    $hookConfig.DOTFILES_WINDOWS_HOME = $hookHome
    $hookConfig.DOTFILES_DOTFILES_LINK = $root
    New-Item -ItemType Directory -Path $hookHome -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $hookHome '.bash_profile') -Value '# user profile' -NoNewline
    Install-DotfilesBashHook $root $hookConfig
    Install-DotfilesBashHook $root $hookConfig
    $hookProfile = Join-Path $hookHome '.bashrc'
    $hookContent = Get-Content -LiteralPath $hookProfile -Raw
    Assert-Test ((@($hookContent -split "`r?`n" | Where-Object { $_ -eq '# >>> dotfiles managed Git Bash hook >>>' }).Count) -eq 1) 'PowerShell Git Bash hook installation is idempotent'
    Remove-DotfilesBashHook $hookConfig
    Assert-Test ((Get-Content -LiteralPath $hookProfile -Raw) -notmatch 'dotfiles managed Git Bash hook') 'PowerShell Git Bash hook removal removes only the managed block'
    Assert-Test ((Get-Content -LiteralPath (Join-Path $hookHome '.bash_profile') -Raw) -match '# user profile') 'PowerShell Git Bash hook removal preserves unmanaged profile content'
    Pass-Test 'PowerShell Git Bash hooks are idempotent and removable'

    $msys2ScoopRoot = Join-Path $testRoot 'msys2-scoop'
    $msys2Root = Join-Path $msys2ScoopRoot 'apps/msys2/current'
    New-Item -ItemType Directory -Path (Join-Path $msys2Root 'usr/bin') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $msys2Root 'msys2_shell.cmd') -Value '@echo off' -NoNewline
    Set-Content -LiteralPath (Join-Path $msys2Root 'usr/bin/bash.exe') -Value 'fixture' -NoNewline
    Set-Content -LiteralPath (Join-Path $msys2Root 'usr/bin/pacman.exe') -Value 'fixture' -NoNewline
    Set-Content -LiteralPath (Join-Path $msys2Root 'usr/bin/zsh.exe') -Value 'fixture' -NoNewline
    $discoveredMsys2Root = Get-DotfilesMsys2Root -ScoopRoot $msys2ScoopRoot
    Assert-Test ($discoveredMsys2Root -eq [System.IO.Path]::GetFullPath($msys2Root)) 'MSYS2 discovery finds the Scoop app root'
    $zshConfig = Read-DotfilesEnvFile (Join-Path $root 'windows-config.example.env')
    Initialize-DotfilesConfigDefaults $zshConfig | Out-Null
    $zshConfig.DOTFILES_DOTFILES_LINK = $root
    $zshConfig.DOTFILES_PI_AGENT_DIR = Join-Path $hookHome '.pi/agent'
    Install-DotfilesZshStartup $zshConfig $discoveredMsys2Root
    Install-DotfilesZshStartup $zshConfig $discoveredMsys2Root
    $zshStartup = Get-DotfilesMsys2StartupPath $discoveredMsys2Root
    $zshStartupContent = Get-Content -LiteralPath $zshStartup -Raw
    Assert-Test ((@($zshStartupContent -split "`r?`n" | Where-Object { $_ -eq '# >>> dotfiles managed MSYS2 zsh startup >>>' }).Count) -eq 1) 'MSYS2 zsh startup installation is idempotent'
    Assert-Test ($zshStartupContent -match '\. "\$DOTFILES_ROOT/home/\.zshrc"') 'MSYS2 zsh startup sources the tracked zsh configuration'
    Assert-Test ($zshStartupContent -match 'DOTFILES_ZSH_ACTIVE') 'MSYS2 zsh startup exports the PowerShell recursion guard'
    Remove-DotfilesZshStartup $discoveredMsys2Root
    Assert-Test ((Get-Content -LiteralPath $zshStartup -Raw) -notmatch 'dotfiles managed MSYS2 zsh startup') 'MSYS2 zsh startup removal removes only the managed block'
    $pluginFixture = Join-Path $msys2Root 'usr/share/zsh/plugins'
    New-Item -ItemType Directory -Path (Join-Path $pluginFixture 'zsh-autosuggestions') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $pluginFixture 'zsh-syntax-highlighting') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $pluginFixture 'zsh-autosuggestions/zsh-autosuggestions.zsh') -Value 'fixture' -NoNewline
    Set-Content -LiteralPath (Join-Path $pluginFixture 'zsh-syntax-highlighting/zsh-syntax-highlighting.zsh') -Value 'fixture' -NoNewline
    Remove-DotfilesMsys2Plugins $discoveredMsys2Root
    Assert-Test (-not (Test-Path -LiteralPath (Join-Path $pluginFixture 'zsh-autosuggestions'))) 'MSYS2 plugin removal removes zsh-autosuggestions'
    Assert-Test (-not (Test-Path -LiteralPath (Join-Path $pluginFixture 'zsh-syntax-highlighting'))) 'MSYS2 plugin removal removes zsh-syntax-highlighting'
    Pass-Test 'MSYS2 discovery and zsh startup are repeatable and removable'
    $zshrcContent = Get-Content -LiteralPath (Join-Path $root 'home/.zshrc') -Raw
    Assert-Test ($zshrcContent -match 'zsh-autosuggestions') 'zsh configuration loads zsh-autosuggestions'
    Assert-Test ($zshrcContent -match 'zsh-syntax-highlighting') 'zsh configuration loads zsh-syntax-highlighting'
    Assert-Test ($zshrcContent -match 'fzf --zsh') 'zsh configuration enables fzf key bindings'
    Assert-Test ($zshrcContent -match 'eval "\$\(starship init zsh\)"') 'zsh configuration falls back to Starship'
    Assert-Test ($zshrcContent -match 'oh-my-posh init zsh') 'zsh configuration initializes Oh My Posh'
    Assert-Test ($zshrcContent -match 'DOTFILES_INSTALL_OH_MY_POSH') 'zsh configuration honors the Oh My Posh opt-in'
    Assert-Test ((Get-Content -LiteralPath (Join-Path $root 'scripts/windows-msys2.ps1') -Raw) -match 'github.com/zsh-users/zsh-autosuggestions.git') 'MSYS2 setup installs the zsh-autosuggestions plugin from its repository'
    Assert-Test ((Get-Content -LiteralPath (Join-Path $root 'scripts/windows-msys2.ps1') -Raw) -match 'github.com/zsh-users/zsh-syntax-highlighting.git') 'MSYS2 setup installs the zsh-syntax-highlighting plugin from its repository'
    $profilePath = Join-Path $root 'home/.config/powershell/Microsoft.PowerShell_profile.ps1'
    Assert-Test (Test-Path -LiteralPath $profilePath -PathType Leaf) 'shared PowerShell profile is present'
    $profileContent = Get-Content -LiteralPath $profilePath -Raw
    Assert-Test ($profileContent -match 'starship init powershell') 'PowerShell profile initializes Starship'
    Assert-Test ($profileContent -notmatch 'DOTFILES_DEFAULT_SHELL') 'PowerShell profile no longer references the removed default shell key'
    Assert-Test (Test-Path -LiteralPath (Join-Path $root 'home/.config/oh-my-posh/tokyo-night-storm.omp.json') -PathType Leaf) 'Tokyo Night Oh My Posh theme is present'
    Assert-Test (Test-Path -LiteralPath (Join-Path $root 'home/.config/oh-my-posh/rose-pine-moon.omp.json') -PathType Leaf) 'Rose Pine Moon Oh My Posh theme is present'
    Assert-Test ((Get-Content -LiteralPath (Join-Path $root 'home/.config/oh-my-posh/tokyo-night-storm.omp.json') -Raw) -match '"type": "node"') 'Tokyo Night theme includes the node segment'
    Assert-Test ((Get-Content -LiteralPath (Join-Path $root 'home/.config/oh-my-posh/rose-pine-moon.omp.json') -Raw) -match '"type": "execution_time"') 'Rose Pine theme includes the execution time segment'
    $colorschemeContent = Get-Content -LiteralPath (Join-Path $root 'home/.config/nvim/lua/plugins/colorscheme.lua') -Raw
    Assert-Test ($colorschemeContent -match 'folke/tokyonight.nvim') 'Neovim declares the tokyonight color scheme'
    Assert-Test ($colorschemeContent -match 'tokyonight-storm') 'Neovim selects the Tokyo Night Storm style'
    Assert-Test ($colorschemeContent -match 'DOTFILES_COLOR_THEME') 'Neovim resolves the shared color theme choice'
    Assert-Test ($colorschemeContent -match "theme ~= 'rose-pine-moon'") 'Neovim keeps rose-pine-moon as the alternative color scheme'
    Assert-Test ((Get-Content -LiteralPath (Join-Path $root 'home/.config/nvim/lazy-lock.json') -Raw) -match 'tokyonight.nvim') 'Neovim plugin lock pins tokyonight'
    Pass-Test 'Shell autocomplete and themed prompt configuration are validated'

    $trackedTerminal = Join-Path $root 'home/.config/windows-terminal/settings.json'
    Assert-Test (Test-Path -LiteralPath $trackedTerminal -PathType Leaf) 'tracked Windows Terminal settings are present'
    $jsonWithComments = @'
{
    // local customization
    "profiles": {
        "list": [
            { "name": "My Profile", "guid": "{11111111-2222-3333-4444-555555555555}" }
        ],
        "defaults": {
            "opacity": 55
        }
    },
    "theme": "system",
    "url": "https://example.com"
}
'@
    $commentFree = Remove-DotfilesJsonComments $jsonWithComments
    Assert-Test ($commentFree -notmatch 'local customization') 'JSONC stripper removes line comments'
    Assert-Test ($commentFree -match 'https://example.com') 'JSONC stripper preserves slashes inside strings'
    $terminalTarget = Join-Path $testRoot 'terminal/settings.json'
    New-Item -ItemType Directory -Path (Split-Path -Parent $terminalTarget) -Force | Out-Null
    Set-Content -LiteralPath $terminalTarget -Value $jsonWithComments -NoNewline
    Merge-DotfilesWindowsTerminalSettings -SourceFile $trackedTerminal -SettingsPath $terminalTarget
    $terminalMerged = ConvertFrom-Json (Get-Content -LiteralPath $terminalTarget -Raw)
    Assert-Test (@($terminalMerged.profiles.list).Count -eq 1 -and $terminalMerged.profiles.list[0].name -eq 'My Profile') 'Windows Terminal merge preserves the local profile list'
    Assert-Test ($terminalMerged.profiles.defaults.opacity -eq 70) 'Windows Terminal merge applies tracked profile defaults'
    Assert-Test (@($terminalMerged.schemes | Where-Object { $_.name -eq 'Tokyo Night Storm' }).Count -eq 1) 'Windows Terminal merge adds the tracked color scheme'
    Assert-Test (@($terminalMerged.themes | Where-Object { $_.name -eq 'Tokyo Night' }).Count -eq 1) 'Windows Terminal merge adds the tracked theme'
    Assert-Test ($terminalMerged.theme -eq 'Tokyo Night') 'Windows Terminal merge applies the tracked theme selection'
    Assert-Test ($terminalMerged.defaultProfile -eq '{574e775e-4f2a-5b96-ac1e-a2962a402336}') 'Windows Terminal merge applies PowerShell 7 as the default profile'
    Assert-Test ($terminalMerged.url -eq 'https://example.com') 'Windows Terminal merge preserves unrelated local settings'
    $fakeLocalAppData = Join-Path $testRoot 'terminal/local-appdata'
    $packageDir = Join-Path $fakeLocalAppData 'Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState'
    New-Item -ItemType Directory -Path $packageDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $packageDir 'settings.json') -Value '{}' -NoNewline
    $wtConfig = Read-DotfilesEnvFile (Join-Path $root 'windows-config.example.env')
    Initialize-DotfilesConfigDefaults $wtConfig | Out-Null
    $wtConfig.DOTFILES_LOCAL_APPDATA = $fakeLocalAppData
    $foundPath = Get-DotfilesWindowsTerminalSettingsPath $wtConfig
    Assert-Test ($foundPath -eq (Join-Path $packageDir 'settings.json')) 'Windows Terminal settings discovery finds the packaged install'
    $missingLocalAppData = Join-Path $testRoot 'terminal/missing-local-appdata'
    $wtConfig.DOTFILES_LOCAL_APPDATA = $missingLocalAppData
    Assert-Test ((Get-DotfilesWindowsTerminalSettingsPath $wtConfig) -eq (Join-Path $missingLocalAppData 'Microsoft/Windows Terminal/settings.json')) 'Windows Terminal settings discovery falls back to the classic path'
    Pass-Test 'Windows Terminal settings merge preserves local profiles and applies tracked styling'

    $roseTerminalSource = Join-Path $root 'home/.config/windows-terminal/settings.rose-pine-moon.json'
    Assert-Test (Test-Path -LiteralPath $roseTerminalSource -PathType Leaf) 'tracked Rose Pine Moon Windows Terminal settings are present'
    $roseTarget = Join-Path $testRoot 'terminal/rose-settings.json'
    Merge-DotfilesWindowsTerminalSettings -SourceFile $roseTerminalSource -SettingsPath $roseTarget
    $roseMerged = ConvertFrom-Json (Get-Content -LiteralPath $roseTarget -Raw)
    Assert-Test ($roseMerged.profiles.defaults.colorScheme -eq 'Rose Pine Moon') 'Rose Pine Moon merge applies its color scheme'
    Assert-Test ($roseMerged.theme -eq 'Rose Pine Moon') 'Rose Pine Moon merge applies its theme selection'
    Assert-Test ($roseMerged.defaultProfile -eq '{574e775e-4f2a-5b96-ac1e-a2962a402336}') 'Rose Pine Moon merge keeps PowerShell 7 as the default profile'
    $themeConfig = Read-DotfilesEnvFile (Join-Path $root 'windows-config.example.env')
    Initialize-DotfilesConfigDefaults $themeConfig | Out-Null
    $themeConfig.DOTFILES_DOTFILES_LINK = $root
    Assert-Test ((Get-DotfilesWindowsTerminalSourceFile $themeConfig) -eq $trackedTerminal) 'Windows Terminal source selection defaults to Tokyo Night'
    $themeConfig.DOTFILES_COLOR_THEME = 'rose-pine-moon'
    Assert-Test ((Get-DotfilesWindowsTerminalSourceFile $themeConfig) -eq $roseTerminalSource) 'Windows Terminal source selection follows the color theme'
    Pass-Test 'Windows Terminal styling follows the chosen color theme'

    $herdrConfig = Read-DotfilesEnvFile (Join-Path $root 'windows-config.example.env')
    Initialize-DotfilesConfigDefaults $herdrConfig | Out-Null
    $herdrDir = Join-Path $testRoot 'herdr'
    $herdrConfig.DOTFILES_HERDR_CONFIG_DIR = $herdrDir
    Write-DotfilesHerdrConfig $root $herdrConfig
    $herdrToml = Join-Path $herdrDir 'config.toml'
    Assert-Test (Test-Path -LiteralPath $herdrToml -PathType Leaf) 'Herdr config generation writes config.toml'
    Assert-Test ((Get-Content -LiteralPath $herdrToml -Raw) -match 'name = "tokyo-night"') 'Herdr config generation applies the Tokyo Night theme'
    Write-DotfilesHerdrConfig $root $herdrConfig
    Assert-Test ((Get-Content -LiteralPath $herdrToml -Raw) -match 'name = "tokyo-night"') 'Herdr config generation is idempotent'
    $herdrConfig.DOTFILES_COLOR_THEME = 'rose-pine-moon'
    Write-DotfilesHerdrConfig $root $herdrConfig
    Assert-Test ((Get-Content -LiteralPath $herdrToml -Raw) -match 'name = "rose-pine"') 'Herdr config generation maps Rose Pine Moon to the herdr rose-pine theme'
    Remove-DotfilesHerdrConfig $root $herdrConfig
    Assert-Test (-not (Test-Path -LiteralPath $herdrToml)) 'Herdr config removal deletes the generated file'
    Set-Content -LiteralPath $herdrToml -Value 'custom content' -NoNewline
    Remove-DotfilesHerdrConfig $root $herdrConfig
    Assert-Test ((Get-Content -LiteralPath $herdrToml -Raw) -eq 'custom content') 'Herdr config removal preserves unmanaged content'
    Assert-Test ((Get-Content -LiteralPath (Join-Path $root '.gitignore') -Raw) -match 'home/.config/herdr/config.toml') '.gitignore guards the generated Herdr config'
    Assert-Test ((Get-Content -LiteralPath (Join-Path $root 'home/.config/herdr/config.toml.template') -Raw) -match 'DOTFILES_COLOR_THEME') 'Herdr template carries the color theme placeholder'
    Pass-Test 'Herdr config follows the color theme and stays restorable'

    $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
    if ($null -ne $nodeCommand) {
        foreach ($scriptPath in @(
            (Join-Path $root 'home/.claude/status-line.js'),
            (Join-Path $root 'home/.pi/agent/extensions/terminal-status-title.js')
        )) {
            $nodeResult = & $nodeCommand.Source --check $scriptPath 2>&1 | Out-String
            Assert-Test ($LASTEXITCODE -eq 0) "Node configuration helper parses: $($scriptPath -replace [regex]::Escape($root), '')"
        }
        $statusFixture = '{"model":{"display_name":"Test Model"},"context_window":{"used_percentage":42.4}}'
        $renderResult = $statusFixture | & $nodeCommand.Source (Join-Path $root 'home/.claude/status-line.js') 2>&1 | Out-String
        Assert-Test (($renderResult.Trim() -eq 'Test Model | ctx: 42% used')) 'Claude status line renders the expected output'
        Pass-Test 'Node configuration helpers parse and render'
    } else {
        Write-Host 'skip: node not found for JSON and status line checks'
    }

    Write-Host "1..$passed"
} catch {
    Write-Error "not ok - $($_.Exception.Message)"
    exit 1
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
