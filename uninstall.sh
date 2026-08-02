#!/usr/bin/env bash
# Safely remove the Windows dotfiles links and restore preserved targets.
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export DOTFILES_ROOT

CHECK_ONLY=0
PROMPT_CONFIG=0
RESTORE_BACKUPS=1
ASSUME_YES=0

usage() {
  cat >&2 <<'USAGE'
Usage: ./uninstall.sh [--check|--configure] [--keep-backups] [--yes]

  --check          validate configuration without changing anything
  --configure      open the interactive configuration UI
  --keep-backups   remove managed links but leave preserved targets in place
  --yes            skip the final confirmation prompt
USAGE
}

for argument in "$@"; do
  case "$argument" in
    --check) CHECK_ONLY=1 ;;
    --configure) PROMPT_CONFIG=1 ;;
    --keep-backups) RESTORE_BACKUPS=0 ;;
    --yes) ASSUME_YES=1 ;;
    *) usage; exit 2 ;;
  esac
done

if [ "$CHECK_ONLY" = "1" ]; then
  export DOTFILES_SKIP_CONFIG_CREATE=1
elif [ "$PROMPT_CONFIG" = "1" ]; then
  export DOTFILES_PROMPT_CONFIG=1
fi

# shellcheck source=windows-common.sh
. "$DOTFILES_ROOT/windows-common.sh"

dotfiles_require_windows_tools
dotfiles_load_config
dotfiles_setup_paths
dotfiles_validate_config

if [ "$CHECK_ONLY" = "1" ]; then
  echo "Windows dotfiles uninstall configuration is valid: $DOTFILES_CONFIG_FILE"
  echo "Repository: $DOTFILES_ROOT"
  echo "User home: $DOTFILES_WINDOWS_HOME"
  echo "Restore backups: $RESTORE_BACKUPS"
  exit 0
fi

echo "This will remove only repository-managed links and the managed Git Bash hook."
if [ "$RESTORE_BACKUPS" = "1" ]; then
  echo "Matching .dotfiles-backup-* targets will be restored when the destination is empty."
else
  echo "Existing .dotfiles-backup-* targets will be left untouched."
fi
echo "Registry settings, Scoop packages, Herdr, and agent CLIs will not be uninstalled."

if [ "$ASSUME_YES" != "1" ]; then
  if [ ! -t 0 ]; then
    echo "Refusing to uninstall without an interactive confirmation. Use --yes only after reviewing the targets." >&2
    exit 1
  fi
  printf 'Type UNINSTALL to continue: ' >&2
  IFS= read -r confirmation
  if [ "$confirmation" != "UNINSTALL" ]; then
    echo "Uninstall cancelled."
    exit 0
  fi
fi

echo "==> Removing repository-managed Windows links"
dotfiles_powershell_file "$DOTFILES_ROOT/windows-uninstall.ps1" \
  -RepoRoot "$(dotfiles_to_windows_path "$DOTFILES_ROOT")" \
  -UserHome "$(dotfiles_to_windows_path "$DOTFILES_WINDOWS_HOME")" \
  -LocalAppData "$(dotfiles_to_windows_path "$DOTFILES_LOCAL_APPDATA")" \
  -AppData "$(dotfiles_to_windows_path "$DOTFILES_APPDATA")" \
  -XdgConfigHome "$(dotfiles_to_windows_path "$DOTFILES_XDG_CONFIG_HOME")" \
  -DotfilesLinkPath "$(dotfiles_to_windows_path "$DOTFILES_DOTFILES_LINK")" \
  -NvimConfigDir "$(dotfiles_to_windows_path "$DOTFILES_NVIM_CONFIG_DIR")" \
  -WeztermConfigDir "$(dotfiles_to_windows_path "$DOTFILES_WEZTERM_CONFIG_DIR")" \
  -WeztermConfigFile "$(dotfiles_to_windows_path "$DOTFILES_WEZTERM_CONFIG_FILE")" \
  -HerdrConfigDir "$(dotfiles_to_windows_path "$DOTFILES_HERDR_CONFIG_DIR")" \
  -ClaudeConfigDir "$(dotfiles_to_windows_path "$DOTFILES_CLAUDE_CONFIG_DIR")" \
  -CodexConfigDir "$(dotfiles_to_windows_path "$DOTFILES_CODEX_CONFIG_DIR")" \
  -OpencodeConfigDir "$(dotfiles_to_windows_path "$DOTFILES_OPENCODE_CONFIG_DIR")" \
  -PiAgentDir "$(dotfiles_to_windows_path "$DOTFILES_PI_AGENT_DIR")" \
  -RestoreBackups "$RESTORE_BACKUPS"

echo "==> Removing the managed Git Bash hook"
dotfiles_remove_bash_hook() {
  local marker_start="# >>> dotfiles managed Git Bash hook >>>"
  local marker_end="# <<< dotfiles managed Git Bash hook <<<"
  local profile temporary

  for profile in "$HOME/.bashrc" "$HOME/.bash_profile"; do
    [ -f "$profile" ] || continue
    temporary="${profile}.dotfiles-uninstall.tmp"
    awk -v start="$marker_start" -v end="$marker_end" '
      $0 == start { inside = 1; next }
      $0 == end { inside = 0; next }
      !inside { print }
    ' "$profile" > "$temporary"
    if cmp -s "$profile" "$temporary"; then
      rm -f "$temporary"
    else
      mv -f "$temporary" "$profile"
      echo "Removed managed Git Bash hook from $profile"
    fi
  done
}

dotfiles_remove_bash_hook

echo "Windows dotfiles uninstall complete."
echo "Review any remaining .dotfiles-backup-* paths before deleting them."
