# Windows Terminal settings merge for the Windows dotfiles engine.
# Loaded by windows-common.ps1.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Get-DotfilesWindowsTerminalSettingsPath {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    $localAppData = ConvertTo-NativePath ([string] $Config.DOTFILES_LOCAL_APPDATA)
    $storePackages = Join-Path $localAppData 'Packages'
    if (Test-Path -LiteralPath $storePackages -PathType Container) {
        foreach ($package in @(Get-ChildItem -LiteralPath $storePackages -Directory -Filter 'Microsoft.WindowsTerminal*' -ErrorAction SilentlyContinue)) {
            $candidate = Join-Path (Join-Path $package.FullName 'LocalState') 'settings.json'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return $candidate
            }
        }
    }
    return Join-Path (Join-Path $localAppData 'Microsoft/Windows Terminal') 'settings.json'
}

function Remove-DotfilesJsonComments {
    param([Parameter(Mandatory = $true)] [string] $Json)

    $builder = New-Object System.Text.StringBuilder
    $inString = $false
    $escaped = $false
    $index = 0
    while ($index -lt $Json.Length) {
        $char = $Json[$index]
        $next = if ($index + 1 -lt $Json.Length) { $Json[$index + 1] } else { [char] 0 }

        if ($inString) {
            [void] $builder.Append($char)
            if ($escaped) {
                $escaped = $false
            } elseif ($char -eq '\') {
                $escaped = $true
            } elseif ($char -eq '"') {
                $inString = $false
            }
            $index++
            continue
        }

        if ($char -eq '"') {
            $inString = $true
            [void] $builder.Append($char)
            $index++
            continue
        }
        if ($char -eq '/' -and $next -eq '/') {
            while ($index -lt $Json.Length -and $Json[$index] -ne "`n" -and $Json[$index] -ne "`r") {
                $index++
            }
            continue
        }
        if ($char -eq '/' -and $next -eq '*') {
            $index += 2
            while ($index + 1 -lt $Json.Length -and -not ($Json[$index] -eq '*' -and $Json[$index + 1] -eq '/')) {
                $index++
            }
            $index += 2
            continue
        }
        [void] $builder.Append($char)
        $index++
    }
    return $builder.ToString()
}

function Test-DotfilesNoteProperty {
    param(
        [Parameter(Mandatory = $true)] $Object,
        [Parameter(Mandatory = $true)] [string] $Name
    )

    foreach ($property in $Object.PSObject.Properties) {
        if ($property.Name -eq $Name) {
            return $true
        }
    }
    return $false
}

function Set-DotfilesNoteProperty {
    param(
        [Parameter(Mandatory = $true)] $Object,
        [Parameter(Mandatory = $true)] [string] $Name,
        $Value
    )

    if (Test-DotfilesNoteProperty $Object $Name) {
        $Object.$Name = $Value
    } else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Copy-DotfilesNoteProperties {
    param(
        [Parameter(Mandatory = $true)] $Source,
        [Parameter(Mandatory = $true)] $Target
    )

    foreach ($property in $Source.PSObject.Properties) {
        Set-DotfilesNoteProperty $Target $property.Name $property.Value
    }
    return $Target
}

function Merge-DotfilesWindowsTerminalSettings {
    param(
        [Parameter(Mandatory = $true)] [string] $SourceFile,
        [Parameter(Mandatory = $true)] [string] $SettingsPath
    )

    $tracked = ConvertFrom-Json (Get-Content -LiteralPath $SourceFile -Raw)
    if ($null -eq $tracked -or $tracked -isnot [pscustomobject]) {
        throw "Windows Terminal settings source is not a JSON object: $SourceFile"
    }

    $target = $null
    if (Test-Path -LiteralPath $SettingsPath -PathType Leaf) {
        $target = ConvertFrom-Json (Remove-DotfilesJsonComments (Get-Content -LiteralPath $SettingsPath -Raw))
    }
    if ($null -eq $target -or $target -isnot [pscustomobject]) {
        $target = [pscustomobject] @{}
    }

    $trackedDefaults = $tracked.profiles.defaults
    if ($null -ne $trackedDefaults) {
        if (-not (Test-DotfilesNoteProperty $target 'profiles') -or $null -eq $target.profiles) {
            $target | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject] @{})
        }
        if (-not (Test-DotfilesNoteProperty $target.profiles 'defaults') -or $null -eq $target.profiles.defaults) {
            $target.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject] @{})
        }
        Copy-DotfilesNoteProperties $trackedDefaults $target.profiles.defaults | Out-Null
    }

    $targetSchemes = if (Test-DotfilesNoteProperty $target 'schemes') { @($target.schemes) } else { @() }
    foreach ($scheme in @($tracked.schemes)) {
        $existing = $null
        foreach ($candidate in $targetSchemes) {
            if ($candidate.name -eq $scheme.name) {
                $existing = $candidate
                break
            }
        }
        if ($null -eq $existing) {
            $copy = Copy-DotfilesNoteProperties $scheme ([pscustomobject] @{})
            if (-not (Test-DotfilesNoteProperty $target 'schemes')) {
                $target | Add-Member -NotePropertyName schemes -NotePropertyValue @($copy)
            } else {
                $target.schemes += $copy
            }
        } else {
            Copy-DotfilesNoteProperties $scheme $existing | Out-Null
        }
    }

    $targetThemes = if (Test-DotfilesNoteProperty $target 'themes') { @($target.themes) } else { @() }
    foreach ($theme in @($tracked.themes)) {
        $existing = $null
        foreach ($candidate in $targetThemes) {
            if ($candidate.name -eq $theme.name) {
                $existing = $candidate
                break
            }
        }
        if ($null -eq $existing) {
            $copy = Copy-DotfilesNoteProperties $theme ([pscustomobject] @{})
            if (-not (Test-DotfilesNoteProperty $target 'themes')) {
                $target | Add-Member -NotePropertyName themes -NotePropertyValue @($copy)
            } else {
                $target.themes += $copy
            }
        } else {
            Copy-DotfilesNoteProperties $theme $existing | Out-Null
        }
    }

    foreach ($key in @('showTabsInTitlebar', 'tabWidthMode', 'theme', 'defaultProfile')) {
        if ($null -ne $tracked.$key) {
            Set-DotfilesNoteProperty $target $key $tracked.$key
        }
    }

    $json = ConvertTo-Json -InputObject $target -Depth 20
    Set-DotfilesTextFile $SettingsPath $json
    Write-Host "Merged Windows Terminal settings into $SettingsPath"
}

function Backup-DotfilesWindowsTerminalSettings {
    param([Parameter(Mandatory = $true)] [string] $SettingsPath)

    if (-not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
        return
    }
    $parent = Split-Path -Parent $SettingsPath
    $existingBackups = @(Get-ChildItem -LiteralPath $parent -Filter 'settings.json.dotfiles-backup-*' -Force -ErrorAction SilentlyContinue)
    if ($existingBackups.Count -gt 0) {
        return
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = "$SettingsPath.dotfiles-backup-$stamp"
    Copy-Item -LiteralPath $SettingsPath -Destination $backup
    Write-Host "Backed up Windows Terminal settings to $backup"
}

$script:DotfilesWindowsTerminalZshProfileGuid = '{6D1AC648-2D78-4AAE-9EF1-11BFA5CB6B59}'

function Get-DotfilesWindowsTerminalSourceFile {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    $fileName = if ([string] $Config.DOTFILES_COLOR_THEME -eq 'rose-pine-moon') { 'settings.rose-pine-moon.json' } else { 'settings.json' }
    $relative = 'home/.config/windows-terminal/' + $fileName
    $linkBased = Join-Path (ConvertTo-NativePath ([string] $Config.DOTFILES_DOTFILES_LINK)) $relative
    if (Test-Path -LiteralPath $linkBased -PathType Leaf) {
        return $linkBased
    }
    if ($env:DOTFILES_ROOT) {
        $rootBased = Join-Path (ConvertTo-NativePath $env:DOTFILES_ROOT) $relative
        if (Test-Path -LiteralPath $rootBased -PathType Leaf) {
            return $rootBased
        }
    }
    return $null
}

function New-DotfilesWindowsTerminalZshProfile {
    param([Parameter(Mandatory = $true)] [string] $Msys2Root)

    $icon = Join-Path $Msys2Root 'msys2.ico'
    $profile = [pscustomobject]@{
        guid = $script:DotfilesWindowsTerminalZshProfileGuid
        name = 'zsh (MSYS2)'
        commandline = (Join-Path $Msys2Root 'msys2_shell.cmd') + ' -defterm -here -no-start -use-full-path'
        startingDirectory = '%USERPROFILE%'
    }
    if (Test-Path -LiteralPath $icon -PathType Leaf) {
        $profile | Add-Member -NotePropertyName icon -NotePropertyValue $icon
    }
    return $profile
}

function Update-DotfilesWindowsTerminalZshProfile {
    param(
        [Parameter(Mandatory = $true)] [string] $SettingsPath,
        [Parameter(Mandatory = $true)] [string] $Msys2Root
    )

    if (-not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
        return
    }
    $target = ConvertFrom-Json (Remove-DotfilesJsonComments (Get-Content -LiteralPath $SettingsPath -Raw))
    if ($null -eq $target -or $target -isnot [pscustomobject]) {
        return
    }
    if (-not (Test-DotfilesNoteProperty $target 'profiles')) {
        $target | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject] @{})
    }
    $list = @()
    if ((Test-DotfilesNoteProperty $target.profiles 'list') -and $null -ne $target.profiles.list) {
        $list = @($target.profiles.list)
    }
    $profile = New-DotfilesWindowsTerminalZshProfile $Msys2Root
    $existing = $null
    foreach ($entry in $list) {
        if ([string] $entry.guid -eq $script:DotfilesWindowsTerminalZshProfileGuid) {
            $existing = $entry
            break
        }
    }
    if ($null -ne $existing) {
        Copy-DotfilesNoteProperties $profile $existing | Out-Null
        $json = ConvertTo-Json -InputObject $target -Depth 20
        Set-DotfilesTextFile $SettingsPath $json
        return
    }
    $list += $profile
    Set-DotfilesNoteProperty $target.profiles 'list' $list
    $json = ConvertTo-Json -InputObject $target -Depth 20
    Set-DotfilesTextFile $SettingsPath $json
    Write-Host 'Added the MSYS2 zsh profile to Windows Terminal'
}

function Remove-DotfilesWindowsTerminalZshProfile {
    param([Parameter(Mandatory = $true)] [string] $SettingsPath)

    if (-not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
        return
    }
    $target = ConvertFrom-Json (Remove-DotfilesJsonComments (Get-Content -LiteralPath $SettingsPath -Raw))
    if ($null -eq $target -or $target -isnot [pscustomobject]) {
        return
    }
    if (-not (Test-DotfilesNoteProperty $target 'profiles')) {
        return
    }
    $list = @()
    if ((Test-DotfilesNoteProperty $target.profiles 'list') -and $null -ne $target.profiles.list) {
        $list = @($target.profiles.list)
    }
    $remaining = @($list | Where-Object { [string] $_.guid -ne $script:DotfilesWindowsTerminalZshProfileGuid })
    if ($remaining.Count -eq $list.Count) {
        return
    }
    Set-DotfilesNoteProperty $target.profiles 'list' $remaining
    $json = ConvertTo-Json -InputObject $target -Depth 20
    Set-DotfilesTextFile $SettingsPath $json
    Write-Host 'Removed the MSYS2 zsh profile from Windows Terminal'
}

function Invoke-DotfilesWindowsTerminalSettings {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    $sourceFile = Get-DotfilesWindowsTerminalSourceFile $Config
    if ($null -eq $sourceFile) {
        Write-Warning 'Tracked Windows Terminal settings were not found; skipping.'
        return
    }
    $settingsPath = Get-DotfilesWindowsTerminalSettingsPath $Config
    Write-Host '==> Merging Windows Terminal settings'
    Backup-DotfilesWindowsTerminalSettings $settingsPath
    Merge-DotfilesWindowsTerminalSettings -SourceFile $sourceFile -SettingsPath $settingsPath
    if ([string] $Config.DOTFILES_INSTALL_ZSH -eq '1') {
        $msys2Root = Get-DotfilesMsys2Root
        if ($msys2Root) {
            Write-Host '==> Adding the MSYS2 zsh profile to Windows Terminal'
            Update-DotfilesWindowsTerminalZshProfile -SettingsPath $settingsPath -Msys2Root $msys2Root
        }
    }
}

function Restore-DotfilesWindowsTerminalSettings {
    param([Parameter(Mandatory = $true)] [hashtable] $Config)

    $settingsPath = Get-DotfilesWindowsTerminalSettingsPath $Config
    if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
        return
    }
    Remove-DotfilesWindowsTerminalZshProfile $settingsPath
    $backup = Get-ChildItem -LiteralPath (Split-Path -Parent $settingsPath) -Filter 'settings.json.dotfiles-backup-*' -Force -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $backup) {
        return
    }
    Copy-Item -LiteralPath $backup.FullName -Destination $settingsPath -Force
    Write-Host "Restored Windows Terminal settings from $($backup.FullName)"
}
