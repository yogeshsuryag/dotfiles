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
    Assert-Test ([string] $config.DOTFILES_INSTALL_ZSH -eq '1') 'MSYS2 zsh is enabled by default'
    Assert-Test ([string] $config.DOTFILES_DEFAULT_SHELL -eq 'zsh') 'zsh is the default shell'
    Assert-Test ([string] $config.DOTFILES_OH_MY_POSH_THEME -eq 'tokyo-night-storm') 'tokyo-night-storm is the default prompt theme'
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
    Assert-Test ($stateConfig.DOTFILES_SCOOP_PACKAGES -eq 'neovim oh-my-posh starship ripgrep fd fzf jq lazygit nodejs Hack-NF bat delta') 'PowerShell TUI serializes package choices'
    Assert-Test ([string] $stateConfig.DOTFILES_INSTALL_OH_MY_POSH -eq '1') 'PowerShell TUI enables Oh My Posh with the package choice'
    $state.Page = 3
    Set-DotfilesTuiItems $state
    $shellItem = @($state.Items | Where-Object { $_.Key -eq 'DOTFILES_DEFAULT_SHELL' })[0]
    Assert-Test ($shellItem.Kind -eq 'choice') 'PowerShell TUI exposes the default shell choice'
    Toggle-DotfilesTuiItem $state $shellItem
    Assert-Test ($stateConfig.DOTFILES_DEFAULT_SHELL -eq 'powershell') 'PowerShell TUI toggles the default shell'
    $themeItem = @($state.Items | Where-Object { $_.Key -eq 'DOTFILES_OH_MY_POSH_THEME' })[0]
    Assert-Test ($themeItem.Kind -eq 'choice') 'PowerShell TUI exposes the prompt theme choice'
    Toggle-DotfilesTuiItem $state $themeItem
    Assert-Test ($stateConfig.DOTFILES_OH_MY_POSH_THEME -eq 'rose-pine-moon') 'PowerShell TUI toggles the prompt theme'
    Pass-Test 'PowerShell TUI state covers documented package choices'

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
    Assert-Test ((Get-Content -LiteralPath (Join-Path $root 'scripts/windows-common.ps1') -Raw) -match 'github.com/zsh-users/zsh-autosuggestions.git') 'MSYS2 setup installs the zsh-autosuggestions plugin from its repository'
    Assert-Test ((Get-Content -LiteralPath (Join-Path $root 'scripts/windows-common.ps1') -Raw) -match 'github.com/zsh-users/zsh-syntax-highlighting.git') 'MSYS2 setup installs the zsh-syntax-highlighting plugin from its repository'
    $profilePath = Join-Path $root 'home/.config/powershell/Microsoft.PowerShell_profile.ps1'
    Assert-Test (Test-Path -LiteralPath $profilePath -PathType Leaf) 'shared PowerShell profile is present'
    $profileContent = Get-Content -LiteralPath $profilePath -Raw
    Assert-Test ($profileContent -match 'Set-DotfilesPSReadLineAutocomplete') 'PowerShell profile sets up PSReadLine autocomplete'
    Assert-Test ($profileContent -match 'InlinePrediction') 'PowerShell profile themes inline predictions'
    Assert-Test ($profileContent -match '-use-full-path') 'PowerShell profile launches zsh with the full Windows PATH'
    Assert-Test ($profileContent -match 'function zsh') 'PowerShell profile exposes an on-demand zsh entry point'
    Assert-Test ($profileContent -match 'DOTFILES_DEFAULT_SHELL') 'PowerShell profile honors the default shell choice'
    Assert-Test (Test-Path -LiteralPath (Join-Path $root 'home/.config/oh-my-posh/tokyo-night-storm.omp.json') -PathType Leaf) 'Tokyo Night Oh My Posh theme is present'
    Assert-Test (Test-Path -LiteralPath (Join-Path $root 'home/.config/oh-my-posh/rose-pine-moon.omp.json') -PathType Leaf) 'Rose Pine Moon Oh My Posh theme is present'
    Assert-Test ((Get-Content -LiteralPath (Join-Path $root 'home/.config/oh-my-posh/tokyo-night-storm.omp.json') -Raw) -match '"type": "node"') 'Tokyo Night theme includes the node segment'
    Assert-Test ((Get-Content -LiteralPath (Join-Path $root 'home/.config/oh-my-posh/rose-pine-moon.omp.json') -Raw) -match '"type": "execution_time"') 'Rose Pine theme includes the execution time segment'
    Pass-Test 'Shell autocomplete and themed prompt configuration are validated'

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
