# Low-level helpers for the Windows dotfiles engine: process PATH updates,
# native command invocation, shell-quoted output, and managed text blocks.
# Loaded by windows-common.ps1.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Update-DotfilesProcessPath {
    $parts = @()
    foreach ($candidate in @(
        $env:PATH,
        [Environment]::GetEnvironmentVariable('Path', 'User'),
        [Environment]::GetEnvironmentVariable('Path', 'Machine')
    )) {
        if ($candidate) {
            $parts += ($candidate -split ';')
        }
    }
    $scoopRoot = if ($env:SCOOP) { ConvertTo-NativePath $env:SCOOP } else { Join-Path $env:USERPROFILE 'scoop' }
    $shimPath = Join-Path $scoopRoot 'shims'
    if (Test-Path -LiteralPath $shimPath -PathType Container) {
        $parts = @($shimPath) + $parts
    }
    $unique = @($parts | Where-Object { $_ } | Select-Object -Unique)
    $env:PATH = $unique -join ';'
}

function Invoke-DotfilesCommand {
    param(
        [Parameter(Mandatory = $true)] [string] $Name,
        [object[]] $CommandArguments = @()
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw "Required command is unavailable: $Name"
    }
    & $command.Name @CommandArguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
    }
}

function ConvertTo-BashDoubleQuoted {
    param([AllowNull()][string] $Value)

    if ($null -eq $Value) { return '' }
    $builder = New-Object System.Text.StringBuilder
    foreach ($char in $Value.ToCharArray()) {
        switch ([int] $char) {
            92 { [void] $builder.Append('\\') }
            34 { [void] $builder.Append('\"') }
            36 { [void] $builder.Append('\$') }
            96 { [void] $builder.Append('\`') }
            default { [void] $builder.Append($char) }
        }
    }
    return $builder.ToString()
}

function Set-DotfilesTextFile {
    param(
        [Parameter(Mandatory = $true)] [string] $Path,
        [Parameter(Mandatory = $true)] [string] $Content
    )

    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Remove-DotfilesManagedBlock {
    param(
        [AllowNull()][string] $Content,
        [string] $StartMarker = '# >>> dotfiles managed Git Bash hook >>>',
        [string] $EndMarker = '# <<< dotfiles managed Git Bash hook <<<'
    )

    if ($null -eq $Content) { return '' }
    $start = $StartMarker
    $end = $EndMarker
    if ($Content.IndexOf($start, [System.StringComparison]::Ordinal) -lt 0) {
        return $Content
    }
    $inside = $false
    $kept = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($Content -split "`r?`n")) {
        if ($line -eq $start) { $inside = $true; continue }
        if ($line -eq $end) { $inside = $false; continue }
        if (-not $inside) { [void] $kept.Add($line) }
    }
    return ($kept -join "`n").TrimEnd("`n")
}
