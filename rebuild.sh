#!/usr/bin/env bash
# Re-link and re-apply the Windows setup from Git Bash after configuration
# changes. Delegates to the native PowerShell engine.
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export DOTFILES_ROOT

export MSYS_NO_PATHCONV=1
exec powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass \
  -File "$(cygpath -w "$DOTFILES_ROOT/rebuild.ps1")" "$@"
