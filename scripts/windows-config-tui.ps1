# Dependency-free keyboard-driven configuration UI for native PowerShell.

Set-StrictMode -Version 3.0

$script:DotfilesTuiPackageMap = @{
    'git' = 'git'
    'neovim' = 'neovim'
    'starship' = 'starship'
    'ripgrep' = 'BurntSushi.ripgrep.MSVC'
    'fd' = 'sharkdp.fd'
    'fzf' = 'junegunn.fzf'
    'jq' = 'jqlang.jq'
    'lazygit' = 'JesseDuffield.lazygit'
    'nodejs' = 'node'
    'oh-my-posh' = 'JanDeDobbeleer.OhMyPosh'
}
$script:DotfilesTuiPackageMapReverse = @{}
foreach ($entry in $script:DotfilesTuiPackageMap.GetEnumerator()) {
    $script:DotfilesTuiPackageMapReverse[$entry.Value] = $entry.Key
}

function New-DotfilesTuiState {
    param(
        [Parameter(Mandatory = $true)] [hashtable] $Config,
        [Parameter(Mandatory = $true)] [string] $RequestedConfig
    )

    $options = @('git', 'neovim', 'starship', 'ripgrep', 'fd', 'fzf', 'jq', 'lazygit', 'nodejs', 'oh-my-posh')
    $labels = @('Git for Windows', 'Neovim', 'Starship', 'ripgrep', 'fd', 'fzf', 'jq', 'lazygit', 'Node.js LTS', 'Oh My Posh')
    $descriptions = @(
        'Git and Git Bash from the official portable archive, used by the repository and daily development.'
        'The terminal editor configured in home/.config/nvim, from the official portable archive.'
        'The shell prompt used by the managed Git Bash and PowerShell configurations, from the official portable archive.'
        'Fast recursive search for files and text.'
        'A fast, user-friendly alternative to find.'
        'Fuzzy finder used by shell and editor workflows.'
        'Command-line JSON processing.'
        'A terminal UI for Git repositories.'
        'The runtime needed by optional agent CLI installers, from the official Node.js LTS archive.'
        'The optional prompt configured for zsh.'
    )
    $selected = @{}
    foreach ($option in $options) { $selected[$option] = $false }
    $customPackages = @()
    $useScoop = ([string] $Config.DOTFILES_PACKAGE_MANAGER -eq 'scoop')
    $packageList = if ($useScoop) { [string] $Config.DOTFILES_SCOOP_PACKAGES } else { [string] $Config.DOTFILES_WINGET_PACKAGES }
    foreach ($package in ($packageList -split '\s+' | Where-Object { $_ })) {
        $optionName = if ($useScoop) { $package } else { $script:DotfilesTuiPackageMapReverse[$package] }
        if ($optionName -and $selected.ContainsKey($optionName)) {
            $selected[$optionName] = $true
        } else {
            $customPackages += $package
        }
    }
    if ([string] $Config.DOTFILES_INSTALL_OH_MY_POSH -eq '1') {
        $selected['oh-my-posh'] = $true
    }

    $customBuckets = @()
    $bucketExtras = $false
    foreach ($bucket in ([string] $Config.DOTFILES_SCOOP_BUCKETS -split '\s+' | Where-Object { $_ })) {
        if ($bucket -eq 'extras') { $bucketExtras = $true } else { $customBuckets += $bucket }
    }

    return [pscustomobject]@{
        Config = $Config
        RequestedConfig = $RequestedConfig
        Page = 0
        Selected = 0
        ReviewSelected = 0
        Items = @()
        PackageOptions = $options
        PackageLabels = $labels
        PackageDescriptions = $descriptions
        PackageSelected = $selected
        CustomPackages = @($customPackages)
        BucketExtras = $bucketExtras
        CustomBuckets = @($customBuckets)
    }
}

function Add-DotfilesTuiItem {
    param(
        [Parameter(Mandatory = $true)] $State,
        [Parameter(Mandatory = $true)] [string] $Kind,
        [Parameter(Mandatory = $true)] [string] $Key,
        [Parameter(Mandatory = $true)] [string] $Label,
        [Parameter(Mandatory = $true)] [string] $Description
    )

    $State.Items += [pscustomobject]@{
        Kind = $Kind
        Key = $Key
        Label = $Label
        Description = $Description
    }
}

function Add-DotfilesTuiAction {
    param(
        [Parameter(Mandatory = $true)] $State,
        [Parameter(Mandatory = $true)] [string] $Key,
        [Parameter(Mandatory = $true)] [string] $Label,
        [Parameter(Mandatory = $true)] [string] $Description
    )

    Add-DotfilesTuiItem $State 'action' $Key $Label $Description
}

function Get-DotfilesTuiPageTitle {
    param([Parameter(Mandatory = $true)] [int] $Page)

    switch ($Page) {
        0 { return 'Tools and packages' }
        1 { return 'Additional installers' }
        2 { return 'File locations' }
        3 { return 'Shell and links' }
        4 { return 'Windows settings' }
        default { return 'Review your choices' }
    }
}

function Get-DotfilesTuiPageIntro {
    param([Parameter(Mandatory = $true)] [int] $Page)

    switch ($Page) {
        0 { return 'Choose how packages are installed and which tools to include. Space toggles a choice; custom entries stay space-separated.' }
        1 { return 'These installers are optional. URLs are editable so you can review the source before continuing.' }
        2 { return 'Defaults are detected from Windows. Press Enter to edit any path.' }
        3 { return 'Choose the color theme, link behavior, and which editor commands Git Bash should use.' }
        4 { return 'Registry changes are opt-in. Leave the master switch off to make this section a no-op.' }
        default { return 'Nothing is saved until you choose Save configuration. Go back to adjust any section.' }
    }
}

function Set-DotfilesTuiItems {
    param([Parameter(Mandatory = $true)] $State)

    $State.Items = @()
    switch ($State.Page) {
        0 {
            Add-DotfilesTuiItem $State 'choice' 'DOTFILES_PACKAGE_MANAGER' 'Package manager' 'Scoop is the default: every app lives in its own ~/scoop/apps/<name>/current directory with a shim on PATH, so installs stay self-contained and never need elevation. WinGet remains an alternative.'
            Add-DotfilesTuiItem $State 'toggle' 'DOTFILES_UPDATE_PACKAGES' 'Update packages before installing' 'Run WinGet upgrades for existing packages before installing new ones.'
            Add-DotfilesTuiItem $State 'toggle' 'DOTFILES_UPDATE_SCOOP' 'Update Scoop before installing' 'Refresh Scoop metadata first. This only applies when Scoop is the package manager.'
            Add-DotfilesTuiItem $State 'bucket' 'extras' 'Add the extras bucket' "Enables Scoop's community extras bucket for additional package manifests. Only applies in Scoop mode."
            Add-DotfilesTuiItem $State 'text' '__custom_buckets' 'Additional Scoop buckets' 'Optional space-separated bucket names or name=URL values. Only applies in Scoop mode.'
            Add-DotfilesTuiItem $State 'text' 'DOTFILES_NERD_FONTS_BUCKET_URL' 'Nerd Fonts source' 'Repository used when the setup adds the Nerd Fonts Scoop bucket. Only applies in Scoop mode.'
            for ($index = 0; $index -lt $State.PackageOptions.Count; $index++) {
                Add-DotfilesTuiItem $State 'package' $State.PackageOptions[$index] $State.PackageLabels[$index] $State.PackageDescriptions[$index]
            }
            Add-DotfilesTuiItem $State 'text' '__custom_packages' 'Additional packages' 'Optional space-separated names: Scoop package names in Scoop mode, or WinGet package IDs in WinGet mode.'
            Add-DotfilesTuiAction $State 'next' 'Continue to optional installers' 'Save these choices temporarily and open the next section.'
        }
        1 {
            Add-DotfilesTuiItem $State 'toggle' 'DOTFILES_INSTALL_HERDR' 'Install Herdr' "Install Herdr's Windows beta using the source below when it is not already available."
            Add-DotfilesTuiItem $State 'text' 'DOTFILES_HERDR_INSTALL_URL' 'Herdr installer source' 'PowerShell installer URL used for the optional Herdr installation.'
            Add-DotfilesTuiItem $State 'toggle' 'DOTFILES_INSTALL_AGENT_CLIS' 'Install optional AI command-line tools' 'Install Claude, Codex, Pi, and opencode with npm. Credentials remain local to each tool.'
            Add-DotfilesTuiItem $State 'toggle' 'DOTFILES_INSTALL_ZSH' 'Install MSYS2 zsh' 'Install MSYS2 with zsh and the zsh plugins. Launch zsh from the MSYS2 shell after setup; Git Bash and PowerShell stay independent.'
            Add-DotfilesTuiAction $State 'back' 'Back to tools and packages' 'Return to the previous section without losing these choices.'
            Add-DotfilesTuiAction $State 'next' 'Continue to file locations' 'Open the detected Windows paths and application locations.'
        }
        2 {
            Add-DotfilesTuiItem $State 'text' 'DOTFILES_WINDOWS_HOME' 'Windows home directory' 'The main user directory used for dotfiles, agent settings, and shell files.'
            Add-DotfilesTuiItem $State 'text' 'DOTFILES_LOCAL_APPDATA' 'Local application data' 'Windows local application data directory; Neovim is linked below it by default.'
            Add-DotfilesTuiItem $State 'text' 'DOTFILES_APPDATA' 'Roaming application data' 'Windows roaming application data directory; Herdr is linked below it by default.'
            Add-DotfilesTuiItem $State 'text' 'DOTFILES_XDG_CONFIG_HOME' 'Shared config directory' 'Config home used by zsh, Oh My Posh, and opencode.'
            Add-DotfilesTuiItem $State 'text' 'DOTFILES_DOTFILES_LINK' 'Repository link location' 'Convenient path exposed in the shell as the active dotfiles checkout.'
            Add-DotfilesTuiItem $State 'text' 'DOTFILES_NVIM_CONFIG_DIR' 'Neovim configuration directory' "Destination for the repository's Neovim configuration."
            Add-DotfilesTuiItem $State 'text' 'DOTFILES_HERDR_CONFIG_DIR' 'Herdr configuration directory' "Destination for the repository's Herdr configuration."
            Add-DotfilesTuiItem $State 'text' 'DOTFILES_CLAUDE_CONFIG_DIR' 'Claude configuration directory' 'Destination for authored Claude configuration files.'
            Add-DotfilesTuiItem $State 'text' 'DOTFILES_CODEX_CONFIG_DIR' 'Codex configuration directory' 'Destination for shared Codex instruction files.'
            Add-DotfilesTuiItem $State 'text' 'DOTFILES_OPENCODE_CONFIG_DIR' 'opencode configuration directory' 'Destination for shared opencode instruction and configuration files.'
            Add-DotfilesTuiItem $State 'text' 'DOTFILES_PI_AGENT_DIR' 'Pi agent configuration directory' 'Destination for authored Pi settings, themes, and extensions.'
            Add-DotfilesTuiAction $State 'back' 'Back to optional installers' 'Return to the previous section without losing these paths.'
            Add-DotfilesTuiAction $State 'next' 'Continue to shell and links' 'Open link behavior and Git Bash integration.'
        }
        3 {
            Add-DotfilesTuiItem $State 'choice' 'DOTFILES_COLOR_THEME' 'Color theme' 'Choose the color theme shared by Windows Terminal, Neovim, Herdr, zsh, and the prompt.'
            Add-DotfilesTuiItem $State 'choice' 'DOTFILES_LINK_MODE' 'Link repository paths using' 'The default uses junctions for directories and hard links for files; symbolic links require the appropriate privilege.'
            Add-DotfilesTuiItem $State 'toggle' 'DOTFILES_BACKUP_EXISTING' 'Back up existing files' 'Move real files and directories aside before creating managed links.'
            Add-DotfilesTuiItem $State 'toggle' 'DOTFILES_INSTALL_BASH_HOOK' 'Install Git Bash integration' 'Add a managed block to .bashrc and .bash_profile for the repository and editor settings.'
            Add-DotfilesTuiItem $State 'text' 'DOTFILES_EDITOR' 'Editor command' 'Command used when shell tools open an editor, such as nvim.'
            Add-DotfilesTuiItem $State 'text' 'DOTFILES_VISUAL' 'Visual editor command' 'Fallback visual editor command used by programs that distinguish it from the editor.'
            Add-DotfilesTuiAction $State 'back' 'Back to file locations' 'Return to the previous section without losing these choices.'
            Add-DotfilesTuiAction $State 'next' 'Continue to Windows settings' 'Open the optional registry-backed settings.'
        }
        4 {
            Add-DotfilesTuiItem $State 'toggle' 'DOTFILES_APPLY_WINDOWS_SETTINGS' 'Apply Windows settings' 'Master switch. Keep this off to avoid registry changes during bootstrap or rebuild.'
            Add-DotfilesTuiItem $State 'toggle' 'DOTFILES_DARK_MODE' 'Use dark mode' 'Use dark mode for Windows and supported applications.'
            Add-DotfilesTuiItem $State 'toggle' 'DOTFILES_SHOW_FILE_EXTENSIONS' 'Show file extensions' 'Show filename extensions in File Explorer.'
            Add-DotfilesTuiItem $State 'toggle' 'DOTFILES_SHOW_HIDDEN_FILES' 'Show hidden files' 'Show hidden files in File Explorer.'
            Add-DotfilesTuiItem $State 'toggle' 'DOTFILES_HIDE_DESKTOP_ICONS' 'Hide desktop icons' 'Hide desktop icons without deleting anything from the Desktop folder.'
            Add-DotfilesTuiItem $State 'toggle' 'DOTFILES_TASKBAR_AUTO_HIDE' 'Auto-hide the taskbar' 'Enable taskbar auto-hide where Windows exposes the required setting.'
            Add-DotfilesTuiItem $State 'toggle' 'DOTFILES_KEYBOARD_REPEAT' 'Tune keyboard repeat' 'Apply the delay and speed values below to keyboard repeat behavior.'
            Add-DotfilesTuiItem $State 'number' 'DOTFILES_KEYBOARD_DELAY' 'Keyboard repeat delay' 'Delay value from 0 to 3. Use Left and Right to adjust it.'
            Add-DotfilesTuiItem $State 'number' 'DOTFILES_KEYBOARD_SPEED' 'Keyboard repeat speed' 'Speed value from 0 to 31. Use Left and Right to adjust it.'
            Add-DotfilesTuiItem $State 'toggle' 'DOTFILES_RESTART_EXPLORER' 'Restart Explorer after changes' 'Restart Explorer after Explorer or taskbar settings are applied.'
            Add-DotfilesTuiAction $State 'back' 'Back to shell and links' 'Return to the previous section without losing these choices.'
            Add-DotfilesTuiAction $State 'next' 'Review all choices' 'Show a concise summary before anything is written.'
        }
    }
}

function Get-DotfilesTuiTextValue {
    param(
        [Parameter(Mandatory = $true)] $State,
        [Parameter(Mandatory = $true)] [string] $Key
    )

    switch ($Key) {
        '__custom_packages' { return ($State.CustomPackages -join ' ') }
        '__custom_buckets' { return ($State.CustomBuckets -join ' ') }
        default { return [string] $State.Config[$Key] }
    }
}

function Set-DotfilesTuiTextValue {
    param(
        [Parameter(Mandatory = $true)] $State,
        [Parameter(Mandatory = $true)] [string] $Key,
        [AllowNull()] [string] $Value
    )

    $words = @($Value -split '\s+' | Where-Object { $_ })
    switch ($Key) {
        '__custom_packages' { $State.CustomPackages = $words }
        '__custom_buckets' { $State.CustomBuckets = $words }
        default { $State.Config[$Key] = $Value }
    }
}

function Get-DotfilesTuiChoiceLabel {
    param(
        [Parameter(Mandatory = $true)] [string] $Key,
        [Parameter(Mandatory = $true)] [string] $Value
    )

    if ($Key -eq 'DOTFILES_COLOR_THEME' -and $Value -eq 'tokyo-night') { return 'Tokyo Night (recommended)' }
    if ($Key -eq 'DOTFILES_COLOR_THEME' -and $Value -eq 'rose-pine-moon') { return 'Rose Pine Moon' }
    if ($Key -eq 'DOTFILES_LINK_MODE' -and $Value -eq 'junction') { return 'Junctions and hard links (recommended)' }
    if ($Key -eq 'DOTFILES_LINK_MODE' -and $Value -eq 'symbolic') { return 'Symbolic links' }
    if ($Key -eq 'DOTFILES_PACKAGE_MANAGER' -and $Value -eq 'scoop') { return 'Scoop (recommended)' }
    if ($Key -eq 'DOTFILES_PACKAGE_MANAGER' -and $Value -eq 'winget') { return 'WinGet (alternative)' }
    return $Value
}

function Get-DotfilesTuiItemValue {
    param(
        [Parameter(Mandatory = $true)] $State,
        [Parameter(Mandatory = $true)] $Item
    )

    switch ($Item.Kind) {
        'toggle' {
            if ([string] $State.Config[$Item.Key] -eq '1') { return 'ON' }
            return 'OFF'
        }
        'package' {
            if ($State.PackageSelected[$Item.Key]) { return '1' }
            return '0'
        }
        'bucket' {
            if ($State.BucketExtras) { return 'ON' }
            return 'OFF'
        }
        'choice' { return Get-DotfilesTuiChoiceLabel $Item.Key ([string] $State.Config[$Item.Key]) }
        'number' { return [string] $State.Config[$Item.Key] }
        'text' { return Get-DotfilesTuiTextValue $State $Item.Key }
        default { return '' }
    }
}

function Clip-DotfilesTuiValue {
    param(
        [AllowNull()][string] $Value,
        [int] $Maximum = 68
    )

    if ($null -eq $Value) { return '' }
    if ($Value.Length -le $Maximum) { return $Value }
    if ($Maximum -le 24) { return $Value.Substring(0, $Maximum) }
    $tailLength = 18
    return ($Value.Substring(0, $Maximum - $tailLength - 3) + '...' + $Value.Substring($Value.Length - $tailLength))
}

function Write-DotfilesTuiPage {
    param([Parameter(Mandatory = $true)] $State)

    Clear-Host
    Write-Host 'Windows dotfiles setup' -ForegroundColor Cyan
    Write-Host ("Step {0} of 5: {1}" -f ($State.Page + 1), (Get-DotfilesTuiPageTitle $State.Page))
    Write-Host (Get-DotfilesTuiPageIntro $State.Page)
    Write-Host ''

    for ($index = 0; $index -lt $State.Items.Count; $index++) {
        $item = $State.Items[$index]
        $marker = if ($index -eq $State.Selected) { '>' } else { ' ' }
        if ($item.Kind -eq 'action') {
            if ($index -eq $State.Selected) {
                Write-Host ("{0} [{1}]" -f $marker, $item.Label) -ForegroundColor Cyan
            } else {
                Write-Host ("  [{0}]" -f $item.Label)
            }
            continue
        }

        $stateValue = Get-DotfilesTuiItemValue $State $item
        if ($item.Kind -eq 'package' -or $item.Kind -eq 'bucket') {
            $displayValue = if ($stateValue -eq '1' -or $stateValue -eq 'ON') { '[x]' } else { '[ ]' }
        } elseif ($item.Kind -eq 'toggle') {
            $displayValue = $stateValue
        } else {
            $displayValue = Clip-DotfilesTuiValue $stateValue 42
            if (-not $displayValue) { $displayValue = '(none)' }
        }

        if ($index -eq $State.Selected) {
            $current = $stateValue
            if ($item.Kind -eq 'package') { $current = if ($stateValue -eq '1') { 'selected' } else { 'not selected' } }
            if ($item.Kind -eq 'bucket') { $current = if ($stateValue -eq 'ON') { 'enabled' } else { 'not enabled' } }
            if (-not $current) { $current = 'none' }
            Write-Host ("{0} {1,-37} {2}" -f $marker, $item.Label, $displayValue) -ForegroundColor Cyan
            Write-Host ("    {0}" -f $item.Description)
            Write-Host ("    Current: {0}" -f (Clip-DotfilesTuiValue $current 68))
        } else {
            Write-Host ("  {0,-37} {1}" -f $item.Label, $displayValue)
        }
    }

    Write-Host ''
    Write-Host 'Up/Down move  Space toggle  Enter edit/select  Tab next  Left/Right adjust choices  Esc/q cancel'
}

function Write-DotfilesTuiSummary {
    param([Parameter(Mandatory = $true)] $State)

    $packages = Get-DotfilesTuiSelectedPackages $State
    $buckets = Get-DotfilesTuiSelectedBuckets $State
    $packageCount = @($packages -split '\s+' | Where-Object { $_ }).Count
    $herdrState = if ([string] $State.Config.DOTFILES_INSTALL_HERDR -eq '1') { 'ON' } else { 'OFF' }
    $agentState = if ([string] $State.Config.DOTFILES_INSTALL_AGENT_CLIS -eq '1') { 'ON' } else { 'OFF' }
    $zshState = if ([string] $State.Config.DOTFILES_INSTALL_ZSH -eq '1') { 'ON' } else { 'OFF' }
    $ohMyPoshState = if ([string] $State.Config.DOTFILES_INSTALL_OH_MY_POSH -eq '1') { 'ON' } else { 'OFF' }
    $backupState = if ([string] $State.Config.DOTFILES_BACKUP_EXISTING -eq '1') { 'ON' } else { 'OFF' }
    $hookState = if ([string] $State.Config.DOTFILES_INSTALL_BASH_HOOK -eq '1') { 'ON' } else { 'OFF' }
    $settingsState = if ([string] $State.Config.DOTFILES_APPLY_WINDOWS_SETTINGS -eq '1') { 'ON' } else { 'OFF' }
    $packageList = if ($packages) { $packages } else { 'none' }
    $bucketList = if ($buckets) { $buckets } else { 'none' }
    Clear-Host
    Write-Host 'Windows dotfiles setup' -ForegroundColor Cyan
    Write-Host 'Review your choices before saving'
    Write-Host ''
    Write-Host ("  Package manager: {0}" -f (Get-DotfilesTuiChoiceLabel 'DOTFILES_PACKAGE_MANAGER' ([string] $State.Config.DOTFILES_PACKAGE_MANAGER)))
    Write-Host ("  Packages selected: {0}" -f $packageCount)
    Write-Host ("  Package list: {0}" -f (Clip-DotfilesTuiValue $packageList 68))
    Write-Host ("  Scoop buckets: {0}" -f (Clip-DotfilesTuiValue $bucketList 68))
    Write-Host ("  Installers: Herdr {0}, AI tools {1}, MSYS2 zsh {2}, Oh My Posh {3}" -f $herdrState, $agentState, $zshState, $ohMyPoshState)
    Write-Host ("  Main home: {0}" -f (Clip-DotfilesTuiValue $State.Config.DOTFILES_WINDOWS_HOME 68))
    Write-Host ("  Repository link: {0}" -f (Clip-DotfilesTuiValue $State.Config.DOTFILES_DOTFILES_LINK 68))
    Write-Host ("  Color theme: {0}" -f (Get-DotfilesTuiChoiceLabel 'DOTFILES_COLOR_THEME' $State.Config.DOTFILES_COLOR_THEME))
    Write-Host ("  Linking: {0}, backups {1}, Git Bash integration {2}" -f (Get-DotfilesTuiChoiceLabel 'DOTFILES_LINK_MODE' $State.Config.DOTFILES_LINK_MODE), $backupState, $hookState)
    Write-Host ("  Windows settings: {0}" -f $settingsState)
    Write-Host ("  Save target: {0}" -f (Clip-DotfilesTuiValue $State.RequestedConfig 68))
    Write-Host ''

    $options = @('Save configuration', 'Back to Windows settings', 'Cancel without saving')
    for ($index = 0; $index -lt $options.Count; $index++) {
        $prefix = if ($index -eq $State.ReviewSelected) { '>' } else { ' ' }
        Write-Host ("{0} [{1}]" -f $prefix, $options[$index]) -ForegroundColor $(if ($index -eq $State.ReviewSelected) { 'Cyan' } else { 'Gray' })
    }
    Write-Host ''
    Write-Host 'Up/Down or Tab move  Enter/Space select  Esc/q cancel'
}

function Read-DotfilesTuiKey {
    $key = [Console]::ReadKey($true)
    if ($key.Key -eq [ConsoleKey]::UpArrow) { return [pscustomobject]@{ Name = 'up'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::DownArrow) { return [pscustomobject]@{ Name = 'down'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::LeftArrow) { return [pscustomobject]@{ Name = 'left'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::RightArrow) { return [pscustomobject]@{ Name = 'right'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::Home) { return [pscustomobject]@{ Name = 'home'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::End) { return [pscustomobject]@{ Name = 'end'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::Delete) { return [pscustomobject]@{ Name = 'delete'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::Backspace) { return [pscustomobject]@{ Name = 'backspace'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::Escape) { return [pscustomobject]@{ Name = 'escape'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::Enter) { return [pscustomobject]@{ Name = 'enter'; Character = '' } }
    if ($key.Key -eq [ConsoleKey]::Tab) {
        if (([int] $key.Modifiers -band [int] [ConsoleModifiers]::Shift) -ne 0) { return [pscustomobject]@{ Name = 'backtab'; Character = '' } }
        return [pscustomobject]@{ Name = 'tab'; Character = '' }
    }
    if ($key.Key -eq [ConsoleKey]::Spacebar) { return [pscustomobject]@{ Name = 'space'; Character = ' ' } }
    if ([int] $key.KeyChar -eq 3) { return [pscustomobject]@{ Name = 'cancel'; Character = '' } }
    return [pscustomobject]@{ Name = 'char'; Character = [string] $key.KeyChar }
}

function Move-DotfilesTuiSelection {
    param(
        [Parameter(Mandatory = $true)] $State,
        [Parameter(Mandatory = $true)] [string] $Direction
    )

    if ($Direction -eq 'next') {
        $State.Selected = ($State.Selected + 1) % $State.Items.Count
    } else {
        $State.Selected = ($State.Selected - 1 + $State.Items.Count) % $State.Items.Count
    }
}

function Toggle-DotfilesTuiItem {
    param(
        [Parameter(Mandatory = $true)] $State,
        [Parameter(Mandatory = $true)] $Item
    )

    switch ($Item.Kind) {
        'toggle' {
            $State.Config[$Item.Key] = if ([string] $State.Config[$Item.Key] -eq '1') { '0' } else { '1' }
        }
        'package' { $State.PackageSelected[$Item.Key] = -not $State.PackageSelected[$Item.Key] }
        'bucket' { $State.BucketExtras = -not $State.BucketExtras }
        'choice' {
            if ($Item.Key -eq 'DOTFILES_COLOR_THEME') {
                $State.Config[$Item.Key] = if ([string] $State.Config[$Item.Key] -eq 'tokyo-night') { 'rose-pine-moon' } else { 'tokyo-night' }
            } elseif ($Item.Key -eq 'DOTFILES_PACKAGE_MANAGER') {
                $State.Config[$Item.Key] = if ([string] $State.Config[$Item.Key] -eq 'winget') { 'scoop' } else { 'winget' }
            } else {
                $State.Config[$Item.Key] = if ([string] $State.Config[$Item.Key] -eq 'junction') { 'symbolic' } else { 'junction' }
            }
        }
    }
}

function Adjust-DotfilesTuiItem {
    param(
        [Parameter(Mandatory = $true)] $State,
        [Parameter(Mandatory = $true)] $Item,
        [Parameter(Mandatory = $true)] [string] $Direction
    )

    if ($Item.Kind -eq 'choice') {
        Toggle-DotfilesTuiItem $State $Item
        return
    }
    if ($Item.Kind -ne 'number') { return }
    $value = [int] $State.Config[$Item.Key]
    if ($Direction -eq 'left' -and $value -gt 0) { $value-- }
    if ($Direction -eq 'right') {
        $maximum = if ($Item.Key -eq 'DOTFILES_KEYBOARD_DELAY') { 3 } else { 31 }
        if ($value -lt $maximum) { $value++ }
    }
    $State.Config[$Item.Key] = [string] $value
}

function Invoke-DotfilesTuiTextEdit {
    param(
        [Parameter(Mandatory = $true)] $State,
        [Parameter(Mandatory = $true)] $Item
    )

    $value = Get-DotfilesTuiTextValue $State $Item.Key
    $cursor = $value.Length
    while ($true) {
        Clear-Host
        Write-Host 'Edit value' -ForegroundColor Cyan
        Write-Host $Item.Label
        Write-Host $Item.Description
        Write-Host ''
        Write-Host ("  {0}|{1}" -f $value.Substring(0, $cursor), $value.Substring($cursor))
        Write-Host ''
        Write-Host 'Left/Right move  Backspace delete  Enter/Tab accept  Esc cancel'
        $key = Read-DotfilesTuiKey
        switch ($key.Name) {
            'char' { $value = $value.Insert($cursor, $key.Character); $cursor++ }
            'space' { $value = $value.Insert($cursor, ' '); $cursor++ }
            'left' { if ($cursor -gt 0) { $cursor-- } }
            'right' { if ($cursor -lt $value.Length) { $cursor++ } }
            'home' { $cursor = 0 }
            'end' { $cursor = $value.Length }
            'backspace' {
                if ($cursor -gt 0) { $value = $value.Remove($cursor - 1, 1); $cursor-- }
            }
            'delete' {
                if ($cursor -lt $value.Length) { $value = $value.Remove($cursor, 1) }
            }
            'enter' { Set-DotfilesTuiTextValue $State $Item.Key $value; return 'enter' }
            'tab' { Set-DotfilesTuiTextValue $State $Item.Key $value; return 'tab' }
            'escape' { return 'cancel' }
            'cancel' { return 'cancel' }
        }
    }
}

function Invoke-DotfilesTuiCurrentItem {
    param([Parameter(Mandatory = $true)] $State)

    $item = $State.Items[$State.Selected]
    switch ($item.Kind) {
        'action' { return $item.Key }
        'text' {
            $result = Invoke-DotfilesTuiTextEdit $State $item
            if ($result -eq 'tab') { Move-DotfilesTuiSelection $State 'next' }
        }
        'toggle' { Toggle-DotfilesTuiItem $State $item }
        'package' { Toggle-DotfilesTuiItem $State $item }
        'bucket' { Toggle-DotfilesTuiItem $State $item }
        'choice' { Toggle-DotfilesTuiItem $State $item }
    }
    return ''
}

function Invoke-DotfilesTuiPages {
    param([Parameter(Mandatory = $true)] $State)

    $State.Page = 0
    $State.Selected = 0
    while ($State.Page -lt 5) {
        Set-DotfilesTuiItems $State
        Write-DotfilesTuiPage $State
        $key = Read-DotfilesTuiKey
        $action = ''
        switch ($key.Name) {
            'up' { Move-DotfilesTuiSelection $State 'previous' }
            'backtab' { Move-DotfilesTuiSelection $State 'previous' }
            'down' { Move-DotfilesTuiSelection $State 'next' }
            'tab' { Move-DotfilesTuiSelection $State 'next' }
            'left' { Adjust-DotfilesTuiItem $State $State.Items[$State.Selected] 'left' }
            'right' { Adjust-DotfilesTuiItem $State $State.Items[$State.Selected] 'right' }
            'space' { Toggle-DotfilesTuiItem $State $State.Items[$State.Selected] }
            'enter' { $action = Invoke-DotfilesTuiCurrentItem $State }
            'escape' { return 'cancel' }
            'cancel' { return 'cancel' }
            'char' { if ($key.Character -eq 'q' -or $key.Character -eq 'Q') { return 'cancel' } }
        }
        if ($action -eq 'next') {
            $State.Page++
            $State.Selected = 0
        } elseif ($action -eq 'back') {
            $State.Page--
            $State.Selected = 0
        }
    }
    return 'review'
}

function Invoke-DotfilesTuiReview {
    param([Parameter(Mandatory = $true)] $State)

    $State.ReviewSelected = 0
    while ($true) {
        Write-DotfilesTuiSummary $State
        $key = Read-DotfilesTuiKey
        switch ($key.Name) {
            'up' { $State.ReviewSelected = ($State.ReviewSelected - 1 + 3) % 3 }
            'backtab' { $State.ReviewSelected = ($State.ReviewSelected - 1 + 3) % 3 }
            'down' { $State.ReviewSelected = ($State.ReviewSelected + 1) % 3 }
            'tab' { $State.ReviewSelected = ($State.ReviewSelected + 1) % 3 }
            'enter' { return @('save', 'back', 'cancel')[$State.ReviewSelected] }
            'space' { return @('save', 'back', 'cancel')[$State.ReviewSelected] }
            'escape' { return 'cancel' }
            'cancel' { return 'cancel' }
            'char' { if ($key.Character -eq 'q' -or $key.Character -eq 'Q') { return 'cancel' } }
        }
    }
}

function Get-DotfilesTuiSelectedPackages {
    param([Parameter(Mandatory = $true)] $State)

    $result = @()
    foreach ($package in $State.PackageOptions) {
        if ($State.PackageSelected[$package]) { $result += $package }
    }
    $result += @($State.CustomPackages)
    return ($result -join ' ')
}

function Get-DotfilesTuiSelectedBuckets {
    param([Parameter(Mandatory = $true)] $State)

    $result = @()
    if ($State.BucketExtras) { $result += 'extras' }
    $result += @($State.CustomBuckets)
    return ($result -join ' ')
}

function Sync-DotfilesTuiToConfig {
    param([Parameter(Mandatory = $true)] $State)

    $scoopNames = @()
    $wingetIds = @()
    foreach ($package in $State.PackageOptions) {
        if (-not $State.PackageSelected[$package]) { continue }
        if ($package -eq 'oh-my-posh') { continue }
        $scoopNames += $package
        $wingetIds += $script:DotfilesTuiPackageMap[$package]
    }
    $scoopNames += @($State.CustomPackages)
    $wingetIds += @($State.CustomPackages)
    $State.Config.DOTFILES_SCOOP_PACKAGES = ($scoopNames -join ' ')
    $State.Config.DOTFILES_WINGET_PACKAGES = ($wingetIds -join ' ')
    $State.Config.DOTFILES_SCOOP_BUCKETS = Get-DotfilesTuiSelectedBuckets $State
    $State.Config.DOTFILES_INSTALL_OH_MY_POSH = if ($State.PackageSelected['oh-my-posh']) { '1' } else { '0' }
    $State.Config.DOTFILES_OH_MY_POSH_THEME = if ([string] $State.Config.DOTFILES_COLOR_THEME -eq 'rose-pine-moon') { 'rose-pine-moon' } else { 'tokyo-night-storm' }
}

function Invoke-DotfilesConfigWizard {
    param(
        [Parameter(Mandatory = $true)] [hashtable] $Config,
        [Parameter(Mandatory = $true)] [string] $RequestedConfig
    )

    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        Write-Error 'Cannot open the interactive configuration UI without a terminal. Copy windows-config.example.env to windows-config.env or rerun from an interactive PowerShell console.'
        return $false
    }

    $state = New-DotfilesTuiState $Config $RequestedConfig
    $oldCursorVisible = $true
    try {
        $oldCursorVisible = [Console]::CursorVisible
        [Console]::CursorVisible = $false
        while ($true) {
            $pagesResult = Invoke-DotfilesTuiPages $state
            if ($pagesResult -eq 'cancel') {
                return $false
            }
            Sync-DotfilesTuiToConfig $state
            $reviewResult = Invoke-DotfilesTuiReview $state
            if ($reviewResult -eq 'back') {
                continue
            }
            if ($reviewResult -eq 'cancel') {
                return $false
            }
            try {
                Assert-DotfilesConfig $state.Config
            } catch {
                Write-Error ("Configuration could not be saved because one or more values are invalid: {0}" -f $_.Exception.Message)
                return $false
            }
            Write-DotfilesEnvFile $state.Config $RequestedConfig
            Write-Host "`n==> Saved $RequestedConfig"
            return $true
        }
    } finally {
        [Console]::CursorVisible = $oldCursorVisible
        Write-Host ''
    }
}
