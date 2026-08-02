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
        '-WeztermConfigDir', (Join-Path $xdg 'wezterm'),
        '-WeztermConfigFile', (Join-Path $user '.wezterm.lua'),
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
    . (Join-Path $root 'windows-common.ps1')

    foreach ($script in (Get-ChildItem -LiteralPath $root -Filter '*.ps1' -File)) {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref] $tokens, [ref] $errors) | Out-Null
        Assert-Test ($errors.Count -eq 0) "PowerShell script parses: $($script.Name)"
    }
    Pass-Test 'PowerShell scripts parse under Windows PowerShell'

    $config = Read-DotfilesEnvFile (Join-Path $root 'windows-config.example.env')
    Initialize-DotfilesConfigDefaults $config | Out-Null
    Assert-DotfilesConfig $config
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
    $state.CustomPackages = @('bat', 'delta')
    Sync-DotfilesTuiToConfig $state
    Assert-Test ($stateConfig.DOTFILES_SCOOP_PACKAGES -eq 'neovim wezterm starship ripgrep fd fzf jq lazygit nodejs Hack-NF bat delta') 'PowerShell TUI serializes package choices'
    Pass-Test 'PowerShell TUI state covers documented package choices'

    $settingsResult = Invoke-NativeScript (Join-Path $root 'windows-settings.ps1') @(
        '-DarkMode', '0', '-ShowFileExtensions', '0', '-ShowHiddenFiles', '0',
        '-HideDesktopIcons', '0', '-TaskbarAutoHide', '0', '-KeyboardRepeat', '0',
        '-RestartExplorer', '0'
    )
    Assert-Test ($settingsResult.ExitCode -eq 0) 'disabled Windows settings are a no-op'
    Pass-Test 'Disabled Windows settings make no system changes'

    $probeDirectory = Join-Path $testRoot 'symbolic-link-probe'
    New-Item -ItemType Directory -Path $probeDirectory -Force | Out-Null
    $probeSource = Join-Path $probeDirectory 'source.txt'
    $probeTarget = Join-Path $probeDirectory 'target.txt'
    Set-Content -LiteralPath $probeSource -Value 'probe' -NoNewline
    $symbolicLinksAvailable = $true
    try {
        New-Item -ItemType SymbolicLink -Path $probeTarget -Target $probeSource -ErrorAction Stop | Out-Null
        Remove-Item -LiteralPath $probeTarget -Force
    } catch {
        $symbolicLinksAvailable = $false
    }

    if (-not $symbolicLinksAvailable) {
        Write-Host 'skip: Windows symbolic-link privilege is unavailable; link E2E was not run'
    } else {
        $fixture = Join-Path $testRoot 'links'
        New-Item -ItemType Directory -Path (Join-Path $fixture 'user/.claude') -Force | Out-Null
        $settingsTarget = Join-Path $fixture 'user/.claude/settings.json'
        Set-Content -LiteralPath $settingsTarget -Value 'pre-existing settings' -NoNewline
        $linkScript = Join-Path $root 'windows-links.ps1'
        $linkArguments = Get-LinkArguments $fixture $root
        $linkResult = Invoke-NativeScript $linkScript $linkArguments
        Assert-Test ($linkResult.ExitCode -eq 0) 'Windows link helper created disposable links'
        Assert-Test (Test-Path -LiteralPath $settingsTarget -PathType Leaf) 'Windows link helper created the settings link'
        $backupPattern = "$settingsTarget.dotfiles-backup-*"
        $backupCount = @(Get-ChildItem -Path $backupPattern -Force).Count
        Assert-Test ($backupCount -eq 1) 'Windows link helper preserved the existing settings file'

        $secondResult = Invoke-NativeScript $linkScript $linkArguments
        Assert-Test ($secondResult.ExitCode -eq 0) 'Windows link helper reapplied links'
        Assert-Test (@(Get-ChildItem -Path $backupPattern -Force).Count -eq $backupCount) 'reapplying links did not create an unnecessary backup'

        $uninstallResult = Invoke-NativeScript (Join-Path $root 'windows-uninstall.ps1') ($linkArguments + @('-RestoreBackups', '1'))
        Assert-Test ($uninstallResult.ExitCode -eq 0) 'Windows uninstall helper removed disposable links'
        Assert-Test ((Get-Content -LiteralPath $settingsTarget -Raw) -eq 'pre-existing settings') 'Windows uninstall helper restored the preserved settings file'
        Pass-Test 'Windows links are repeatable, backup-safe, and restorable'
    }

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
    Remove-DotfilesZshStartup $discoveredMsys2Root
    Assert-Test ((Get-Content -LiteralPath $zshStartup -Raw) -notmatch 'dotfiles managed MSYS2 zsh startup') 'MSYS2 zsh startup removal removes only the managed block'
    Pass-Test 'MSYS2 discovery and zsh startup are repeatable and removable'

    Write-Host "1..$passed"
} catch {
    Write-Error "not ok - $($_.Exception.Message)"
    exit 1
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
