#!/usr/bin/env bash
# Safely remove the Windows dotfiles links from Git Bash and restore preserved
# targets. Delegates to the native PowerShell engine.
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export DOTFILES_ROOT

export MSYS_NO_PATHCONV=1
exec powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass \
  -File "$(cygpath -w "$DOTFILES_ROOT/uninstall.ps1")" "$@"
