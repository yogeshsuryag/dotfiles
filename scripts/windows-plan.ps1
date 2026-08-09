# Pre-install package plan for the Windows dotfiles engine: detect which
# declared tools already exist, recommend the best action per tool, let the
# user review and adjust the plan in a keyboard UI, and install only what was
# approved. Loaded by windows-common.ps1 (last, after windows-config-tui.ps1).

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$script:DotfilesPlanExeProbes = @{
    'git' = 'git'
    'neovim' = 'nvim'
    'starship' = 'starship'
    'ripgrep' = 'rg'
    'fd' = 'fd'
    'fzf' = 'fzf'
    'jq' = 'jq'
    'lazygit' = 'lazygit'
    'nodejs' = 'node'
    'node' = 'node'
    'oh-my-posh' = 'oh-my-posh'
    'psmux' = 'tmux'
}

$script:DotfilesPlanAgentClis = @(
    [pscustomobject]@{ Name = 'claude'; Package = '@anthropic-ai/claude-code' },
    [pscustomobject]@{ Name = 'codex'; Package = '@openai/codex' },
    [pscustomobject]@{ Name = 'pi'; Package = '@earendil-works/pi-coding-agent' },
    [pscustomobject]@{ Name = 'opencode'; Package = 'opencode-ai' }
)

function Test-DotfilesToolOnPath {
    param([Parameter(Mandatory = $true)] [string] $Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return $null
    }
    if ($command.CommandType -ne 'Application' -and $command.CommandType -ne 'ExternalScript') {
        return $null
    }
    $version = ''
    foreach ($flag in @('--version', '-v')) {
        if ($version) { break }
        try {
            $candidate = ((& $command.Source $flag 2>$null | Select-Object -First 1) -join ' ').Trim()
            if ($candidate) { $version = $candidate }
        } catch {
            $version = ''
        }
    }
    return [pscustomobject]@{ Source = [string] $command.Source; Version = $version }
}

function Get-DotfilesScoopInstalled {
    $command = Get-Command scoop -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return @()
    }
    $output = & $command.Name list 2>$null | Out-String
    if ($LASTEXITCODE -ne 0) {
        return @()
    }
    return @(
        ($output -split "`r?`n") |
            ForEach-Object { if ($_ -match '^\s*([^\s]+)\s+') { $matches[1] } } |
            Where-Object { $_ -and $_ -notin @('Name', '---') } |
            Select-Object -Unique
    )
}

function New-DotfilesPlanEntry {
    param(
        [Parameter(Mandatory = $true)] [string] $Name,
        [Parameter(Mandatory = $true)] [string] $Exe,
        [Parameter(Mandatory = $true)] [bool] $InManager,
        [Parameter(Mandatory = $true)] [string] $ManagerName,
        [AllowNull()] [string] $Package = $null
    )

    $probe = Test-DotfilesToolOnPath $Exe
    if ($InManager) {
        $status = 'installed'
        $source = "via $ManagerName"
        $version = if ($null -ne $probe) { $probe.Version } else { '' }
    } elseif ($null -ne $probe) {
        $status = 'available'
        $source = $probe.Source
        $version = $probe.Version
    } else {
        $status = 'not-found'
        $source = ''
        $version = ''
    }

    $allowedActions = switch ($status) {
        'installed' { @('Skip', 'Reinstall') }
        'available' { @('Skip', 'Replace') }
        default { @('Install', 'Skip') }
    }
    $recommended = if ($status -eq 'installed' -or $status -eq 'available') { 'Skip' } else { 'Install' }

    return [pscustomobject]@{
        Name = $Name
        Exe = $Exe
        Package = if ($Package) { $Package } else { $Name }
        Status = $status
        Source = $source
        Version = $version
        ManagerName = $ManagerName
        AllowedActions = @($allowedActions)
        RecommendedAction = $recommended
        Action = $recommended
    }
}

function Get-DotfilesPackagePlan {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    $useScoop = ([string] $Config.DOTFILES_PACKAGE_MANAGER -eq 'scoop')
    $entries = @()

    if ($useScoop) {
        $declared = @([string] $Config.DOTFILES_SCOOP_PACKAGES -split '\s+' | Where-Object { $_ })
        if ([string] $Config.DOTFILES_INSTALL_OH_MY_POSH -eq '1' -and $declared -notcontains 'oh-my-posh') {
            $declared += 'oh-my-posh'
        }
        if ([string] $Config.DOTFILES_INSTALL_PSMUX -eq '1' -and $declared -notcontains 'psmux') {
            $declared += 'psmux'
        }
        $installed = @(Get-DotfilesScoopInstalled)
        foreach ($name in $declared) {
            $exe = if ($script:DotfilesPlanExeProbes.ContainsKey($name)) { $script:DotfilesPlanExeProbes[$name] } else { $name }
            $entries += New-DotfilesPlanEntry -Name $name -Exe $exe -InManager ($installed -contains $name) -ManagerName 'scoop'
        }
    } else {
        $declared = @([string] $Config.DOTFILES_WINGET_PACKAGES -split '\s+' | Where-Object { $_ })
        if ([string] $Config.DOTFILES_INSTALL_OH_MY_POSH -eq '1' -and $declared -notcontains 'JanDeDobbeleer.OhMyPosh') {
            $declared += 'JanDeDobbeleer.OhMyPosh'
        }
        $wingetAvailable = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
        foreach ($id in $declared) {
            $scoopName = if ($script:DotfilesTuiPackageMapReverse.ContainsKey($id)) { $script:DotfilesTuiPackageMapReverse[$id] } else { $null }
            $exe = if ($scoopName -and $script:DotfilesPlanExeProbes.ContainsKey($scoopName)) {
                $script:DotfilesPlanExeProbes[$scoopName]
            } else {
                ($id -split '\.')[-1].ToLowerInvariant()
            }
            $inManager = if ($wingetAvailable) { Test-DotfilesWingetPackage $id } else { $false }
            $entries += New-DotfilesPlanEntry -Name $id -Exe $exe -InManager $inManager -ManagerName 'winget'
        }
    }

    if ([string] $Config.DOTFILES_INSTALL_AGENT_CLIS -eq '1') {
        foreach ($cli in $script:DotfilesPlanAgentClis) {
            $entries += New-DotfilesPlanEntry -Name $cli.Name -Exe $cli.Name -InManager $false -ManagerName 'npm' -Package $cli.Package
        }
    }

    return @($entries)
}

function Get-DotfilesPlanEntryDetail {
    param([Parameter(Mandatory = $true)] $Entry)

    switch ($Entry.Status) {
        'installed' {
            if ($Entry.Version) {
                return "installed via $($Entry.ManagerName) ($($Entry.Version))"
            }
            return "installed via $($Entry.ManagerName)"
        }
        'available' {
            if ($Entry.Version) {
                return "found: $(Clip-DotfilesTuiValue $Entry.Version 42)"
            }
            return "found on PATH: $(Clip-DotfilesTuiValue $Entry.Source 30)"
        }
        default { return 'not found anywhere' }
    }
}

function Get-DotfilesPlanEntryHint {
    param([Parameter(Mandatory = $true)] $Entry)

    switch ($Entry.Status) {
        'installed' { return "Already installed via $($Entry.ManagerName). Skip keeps it; Reinstall runs the install again." }
        'available' { return 'Found on PATH from another source. Skip keeps it; Replace also installs it through the configured package manager, whose shims take PATH priority.' }
        default { return 'Not installed anywhere. Install adds it through the configured package manager.' }
    }
}

function Set-DotfilesPlanEntryNextAction {
    param([Parameter(Mandatory = $true)] $Entry)

    $index = [Array]::IndexOf([string[]] $Entry.AllowedActions, [string] $Entry.Action)
    if ($index -lt 0) { $index = 0 }
    $Entry.Action = $Entry.AllowedActions[($index + 1) % $Entry.AllowedActions.Count]
}

function Invoke-DotfilesPackagePlanReview {
    param([Parameter(Mandatory = $true)] $Plan)

    $entries = @($Plan)
    if ($entries.Count -eq 0) {
        return $true
    }
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        Write-Host '==> Non-interactive run: applying recommended actions (install missing tools, skip existing)'
        return $true
    }

    $selected = 0
    while ($true) {
        Clear-Host
        Write-Host 'Windows dotfiles setup' -ForegroundColor Cyan
        Write-Host 'Review detected tools before installing anything'
        Write-Host 'Space changes the action for the selected tool. Nothing is installed until you continue.'
        Write-Host ''
        Write-Host ("  {0,-24} {1,-42} {2,-12} {3}" -f 'Tool', 'Detected', 'Recommended', 'Action')
        for ($index = 0; $index -lt $entries.Count; $index++) {
            $entry = $entries[$index]
            $marker = if ($index -eq $selected) { '>' } else { ' ' }
            $line = ("{0} {1,-24} {2,-42} {3,-12} {4}" -f $marker, $entry.Name, (Get-DotfilesPlanEntryDetail $entry), $entry.RecommendedAction, $entry.Action)
            if ($index -eq $selected) {
                Write-Host $line -ForegroundColor Cyan
                Write-Host ("    {0}" -f (Get-DotfilesPlanEntryHint $entry))
            } else {
                Write-Host $line
            }
        }
        Write-Host ''
        Write-Host 'Up/Down move  Space change action  Enter continue  Esc/q cancel'
        $key = Read-DotfilesTuiKey
        switch ($key.Name) {
            'up' { $selected = ($selected - 1 + $entries.Count) % $entries.Count }
            'backtab' { $selected = ($selected - 1 + $entries.Count) % $entries.Count }
            'down' { $selected = ($selected + 1) % $entries.Count }
            'tab' { $selected = ($selected + 1) % $entries.Count }
            'space' { Set-DotfilesPlanEntryNextAction $entries[$selected] }
            'enter' { return $true }
            'escape' { return $false }
            'cancel' { return $false }
            'char' { if ($key.Character -eq 'q' -or $key.Character -eq 'Q') { return $false } }
        }
    }
}

function Invoke-DotfilesPackagePlan {
    param(
        [Parameter(Mandatory = $true)] [hashtable] $Config,
        [Parameter(Mandatory = $true)] $Plan
    )

    $entries = @($Plan)
    $approved = @($entries | Where-Object { $_.Action -eq 'Install' -or $_.Action -eq 'Replace' })
    $skipped = @($entries | Where-Object { $_.Action -eq 'Skip' })
    if ($approved.Count -eq 0) {
        Write-Host '==> Nothing to install: every declared tool is already installed or was skipped'
        return
    }

    $scoopPackages = @($approved | Where-Object { $_.ManagerName -eq 'scoop' } | ForEach-Object { $_.Package })
    if ($scoopPackages.Count -gt 0) {
        Install-DotfilesScoopPackages $Config -Packages $scoopPackages
    }
    $wingetSpecs = @($approved | Where-Object { $_.ManagerName -eq 'winget' } | ForEach-Object { $_.Package })
    if ($wingetSpecs.Count -gt 0) {
        Install-DotfilesWingetPackages $Config -Specs $wingetSpecs
    }
    $agentClis = @($approved | Where-Object { $_.ManagerName -eq 'npm' } | ForEach-Object { $_.Package })
    if ($agentClis.Count -gt 0) {
        Install-DotfilesAgentClis $Config -Packages $agentClis
    }
    if ($skipped.Count -gt 0) {
        Write-Host "==> Skipped: $($skipped.Name -join ' ')"
    }
}
