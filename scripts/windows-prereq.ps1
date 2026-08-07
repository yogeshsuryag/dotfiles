# PowerShell 7 bootstrap for the Windows dotfiles engine. Loaded by
# windows-common.ps1.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Get-DotfilesPowerShell7Command {
    $command = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command
    }
    foreach ($candidate in @(
        (Join-Path $env:ProgramFiles 'PowerShell/7/pwsh.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs/PowerShell/7/pwsh.exe')
    )) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return Get-Item -LiteralPath $candidate
        }
    }
    return $null
}

function Ensure-DotfilesPowerShell7 {
    param(
        [Parameter(Mandatory = $true)] [string] $EntryPoint,
        [string[]] $CliArguments = @()
    )

    if ($PSVersionTable.PSEdition -eq 'Core') {
        return
    }

    Update-DotfilesProcessPath
    $pwshCommand = Get-DotfilesPowerShell7Command
    if ($null -eq $pwshCommand) {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            throw 'WinGet was not found. Install App Installer from the Microsoft Store, or install PowerShell 7 yourself, then rerun the bootstrap.'
        }
        Write-Host '==> Installing PowerShell 7 with WinGet (one elevation prompt may appear)'
        Invoke-DotfilesCommand 'winget' @(
            'install', '--exact', '--id', 'Microsoft.PowerShell', '--source', 'winget',
            '--silent', '--disable-interactivity', '--accept-package-agreements', '--accept-source-agreements'
        )
        Update-DotfilesProcessPath
        $pwshCommand = Get-DotfilesPowerShell7Command
        if ($null -eq $pwshCommand) {
            throw 'PowerShell 7 was installed but pwsh was not found. Close and reopen PowerShell, then rerun the bootstrap.'
        }
    }

    $pwshSource = if ($pwshCommand -is [System.IO.FileSystemInfo]) {
        $pwshCommand.FullName
    } else {
        [string] $pwshCommand.Source
    }
    if ($null -eq $pwshSource -or -not (Test-Path -LiteralPath $pwshSource -PathType Leaf)) {
        throw "PowerShell 7 was found but its executable is not usable: $pwshSource"
    }

    Write-Host '==> Restarting the bootstrap under PowerShell 7'
    $argumentList = @($CliArguments | Where-Object { $_ })
    & $pwshSource '-NoLogo' '-NoProfile' '-ExecutionPolicy' 'Bypass' '-File' $EntryPoint @argumentList
    exit $LASTEXITCODE
}
