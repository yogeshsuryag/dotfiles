[CmdletBinding()]
param()

# Shared native PowerShell functions for the Windows dotfiles entry points.
# This file loads the focused engine modules in dependency order. The
# configuration file remains Bash-compatible so both frontends can use it.

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'windows-config.ps1')
. (Join-Path $PSScriptRoot 'windows-tools.ps1')
. (Join-Path $PSScriptRoot 'windows-scoop.ps1')
. (Join-Path $PSScriptRoot 'windows-msys2.ps1')
. (Join-Path $PSScriptRoot 'windows-installers.ps1')
. (Join-Path $PSScriptRoot 'windows-hooks.ps1')
. (Join-Path $PSScriptRoot 'windows-apply.ps1')
. (Join-Path $PSScriptRoot 'windows-config-tui.ps1')
