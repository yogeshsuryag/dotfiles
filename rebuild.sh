#!/usr/bin/env bash
# Re-link and re-apply the Windows setup after configuration changes.
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
  exit 0
fi

dotfiles_link_configs
dotfiles_install_bash_hook
dotfiles_apply_windows_settings

echo "Windows dotfiles re-applied."
