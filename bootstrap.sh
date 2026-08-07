#!/usr/bin/env bash
# Bootstrap the Windows setup from Git Bash. Delegates to the native
# PowerShell engine, which is the single implementation of this setup.
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export DOTFILES_ROOT

export MSYS_NO_PATHCONV=1
exec powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass \
  -File "$(cygpath -w "$DOTFILES_ROOT/bootstrap.ps1")" "$@"
