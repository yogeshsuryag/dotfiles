#!/usr/bin/env bash
# Bootstrap the Windows setup from Git Bash.
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export DOTFILES_ROOT
CHECK_ONLY="${1:-}"
case "$CHECK_ONLY" in
  ""|--check|--configure) ;;
  *)
    echo "Usage: $0 [--check|--configure]" >&2
    exit 2
    ;;
esac
if [ "$CHECK_ONLY" = "--check" ]; then
  export DOTFILES_SKIP_CONFIG_CREATE=1
elif [ "$CHECK_ONLY" = "--configure" ]; then
  export DOTFILES_PROMPT_CONFIG=1
fi

# shellcheck source=windows-common.sh
. "$DOTFILES_ROOT/windows-common.sh"

dotfiles_require_windows_tools
dotfiles_load_config
dotfiles_setup_paths
dotfiles_validate_config

if [ "$CHECK_ONLY" = "--check" ]; then
  echo "Windows dotfiles configuration is valid: $DOTFILES_CONFIG_FILE"
  echo "Repository: $DOTFILES_ROOT"
  echo "User home: $DOTFILES_WINDOWS_HOME"
  echo "Scoop packages: $DOTFILES_SCOOP_PACKAGES"
  exit 0
fi

echo "==> Installing declared tools"
dotfiles_install_packages
dotfiles_install_herdr
dotfiles_install_agent_clis
dotfiles_install_zsh

echo "==> Installing Git Bash configuration hook"
dotfiles_link_configs
dotfiles_install_bash_hook
dotfiles_apply_windows_settings

echo "==> Bootstrap complete"
echo "    Restart Git Bash to load the new shell configuration."
echo "    Restart PowerShell so its profile launches the new MSYS2 zsh shell."
echo "    Re-run ./rebuild.sh after changing repository files or windows-config.env."
