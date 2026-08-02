#!/usr/bin/env bash
# Shared Windows setup functions. Source this from bootstrap.sh or rebuild.sh.
set -euo pipefail

dotfiles_write_config_value() {
  local variable_name=$1
  printf '%s=%q\n' "$variable_name" "${!variable_name}"
}

# shellcheck source=windows-config-tui.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/windows-config-tui.sh"

dotfiles_load_config() {
  : "${DOTFILES_ROOT:?DOTFILES_ROOT must be set before loading configuration}"

  local requested_config="${DOTFILES_CONFIG_FILE:-$DOTFILES_ROOT/windows-config.env}"
  if [ ! -f "$requested_config" ]; then
    if [ "${DOTFILES_SKIP_CONFIG_CREATE:-0}" = "1" ]; then
      requested_config="$DOTFILES_ROOT/windows-config.example.env"
    else
      dotfiles_create_config_interactively "$requested_config"
    fi
  elif [ "${DOTFILES_PROMPT_CONFIG:-0}" = "1" ]; then
    # Load current values so the wizard can offer them as defaults.
    # shellcheck disable=SC1090
    . "$requested_config"
    dotfiles_create_config_interactively "$requested_config"
  fi

  # shellcheck disable=SC1090
  . "$requested_config"
  DOTFILES_CONFIG_FILE="$requested_config"
  export DOTFILES_CONFIG_FILE

  dotfiles_apply_config_defaults
}

dotfiles_require_windows_tools() {
  local missing=()
  local command_name
  for command_name in cygpath powershell.exe; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      missing+=("$command_name")
    fi
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    printf 'Missing required Windows/Git Bash commands: %s\n' "${missing[*]}" >&2
    printf 'Run this repository from Git Bash on Windows.\n' >&2
    return 1
  fi
}

dotfiles_windows_env_path() {
  local variable_name=$1 value
  value="${!variable_name:-}"
  if [ -n "$value" ]; then
    cygpath -u "$value"
    return
  fi
  return 1
}

dotfiles_setup_paths() {
  local home_from_windows local_appdata_from_windows appdata_from_windows
  home_from_windows="$(dotfiles_windows_env_path USERPROFILE 2>/dev/null || true)"
  local_appdata_from_windows="$(dotfiles_windows_env_path LOCALAPPDATA 2>/dev/null || true)"
  appdata_from_windows="$(dotfiles_windows_env_path APPDATA 2>/dev/null || true)"

  DOTFILES_WINDOWS_HOME="${DOTFILES_WINDOWS_HOME:-${home_from_windows:-$HOME}}"
  DOTFILES_LOCAL_APPDATA="${DOTFILES_LOCAL_APPDATA:-${local_appdata_from_windows:-$DOTFILES_WINDOWS_HOME/AppData/Local}}"
  DOTFILES_APPDATA="${DOTFILES_APPDATA:-${appdata_from_windows:-$DOTFILES_WINDOWS_HOME/AppData/Roaming}}"
  DOTFILES_XDG_CONFIG_HOME="${DOTFILES_XDG_CONFIG_HOME:-$DOTFILES_WINDOWS_HOME/.config}"
  DOTFILES_DOTFILES_LINK="${DOTFILES_DOTFILES_LINK:-$DOTFILES_WINDOWS_HOME/.dotfiles}"

  DOTFILES_NVIM_CONFIG_DIR="${DOTFILES_NVIM_CONFIG_DIR:-$DOTFILES_LOCAL_APPDATA/nvim}"
  DOTFILES_WEZTERM_CONFIG_DIR="${DOTFILES_WEZTERM_CONFIG_DIR:-$DOTFILES_XDG_CONFIG_HOME/wezterm}"
  DOTFILES_WEZTERM_CONFIG_FILE="${DOTFILES_WEZTERM_CONFIG_FILE:-$DOTFILES_WINDOWS_HOME/.wezterm.lua}"
  DOTFILES_HERDR_CONFIG_DIR="${DOTFILES_HERDR_CONFIG_DIR:-$DOTFILES_APPDATA/herdr}"
  DOTFILES_CLAUDE_CONFIG_DIR="${DOTFILES_CLAUDE_CONFIG_DIR:-$DOTFILES_WINDOWS_HOME/.claude}"
  DOTFILES_CODEX_CONFIG_DIR="${DOTFILES_CODEX_CONFIG_DIR:-$DOTFILES_WINDOWS_HOME/.codex}"
  DOTFILES_OPENCODE_CONFIG_DIR="${DOTFILES_OPENCODE_CONFIG_DIR:-$DOTFILES_XDG_CONFIG_HOME/opencode}"
  DOTFILES_PI_AGENT_DIR="${DOTFILES_PI_AGENT_DIR:-$DOTFILES_WINDOWS_HOME/.pi/agent}"

  export DOTFILES_WINDOWS_HOME DOTFILES_LOCAL_APPDATA DOTFILES_APPDATA
  export DOTFILES_XDG_CONFIG_HOME DOTFILES_DOTFILES_LINK
  export DOTFILES_NVIM_CONFIG_DIR DOTFILES_WEZTERM_CONFIG_DIR DOTFILES_WEZTERM_CONFIG_FILE
  export DOTFILES_HERDR_CONFIG_DIR DOTFILES_CLAUDE_CONFIG_DIR DOTFILES_CODEX_CONFIG_DIR
  export DOTFILES_OPENCODE_CONFIG_DIR DOTFILES_PI_AGENT_DIR
}

dotfiles_to_windows_path() {
  cygpath -w "$1"
}

dotfiles_powershell_file() {
  local script=$1
  shift
  local windows_script
  windows_script="$(dotfiles_to_windows_path "$script")"
  MSYS_NO_PATHCONV=1 powershell.exe -NoLogo -NoProfile -NonInteractive \
    -ExecutionPolicy Bypass -File "$windows_script" "$@"
}

dotfiles_ensure_scoop_on_path() {
  local scoop_root
  scoop_root="${SCOOP:-$DOTFILES_WINDOWS_HOME/scoop}"
  if [ -d "$scoop_root/shims" ]; then
    case ":$PATH:" in
      *":$scoop_root/shims:"*) ;;
      *) export PATH="$scoop_root/shims:$PATH" ;;
    esac
  fi
}

dotfiles_install_scoop() {
  dotfiles_ensure_scoop_on_path
  if command -v scoop >/dev/null 2>&1; then
    return 0
  fi

  if [ "$DOTFILES_INSTALL_SCOOP" != "1" ]; then
    echo "Scoop is not installed and DOTFILES_INSTALL_SCOOP is not enabled." >&2
    return 1
  fi

  echo "==> Installing Scoop for the current Windows user"
  MSYS_NO_PATHCONV=1 powershell.exe -NoLogo -NoProfile -NonInteractive \
    -ExecutionPolicy Bypass -Command \
    "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression"
  dotfiles_ensure_scoop_on_path
  command -v scoop >/dev/null 2>&1 || {
    echo "Scoop installed but its shims are not visible in this Git Bash session." >&2
    echo "Close and reopen Git Bash, then rerun ./bootstrap.sh." >&2
    return 1
  }
}

dotfiles_scoop_bucket_exists() {
  scoop bucket list 2>/dev/null | awk 'NR > 3 { print $1 }' | grep -Fxq "$1"
}

dotfiles_configure_scoop() {
  dotfiles_install_scoop

  if [ "$DOTFILES_UPDATE_SCOOP" = "1" ]; then
    echo "==> Updating Scoop buckets"
    scoop update
  fi

  local bucket spec name url
  for spec in $DOTFILES_SCOOP_BUCKETS; do
    name=${spec%%=*}
    url=${spec#*=}
    if dotfiles_scoop_bucket_exists "$name"; then
      continue
    fi
    if [ "$name" = "$spec" ]; then
      echo "==> Adding Scoop bucket: $name"
      scoop bucket add "$name"
    else
      echo "==> Adding Scoop bucket: $name"
      scoop bucket add "$name" "$url"
    fi
  done

  if ! dotfiles_scoop_bucket_exists nerd-fonts; then
    echo "==> Adding Scoop bucket: nerd-fonts"
    scoop bucket add nerd-fonts "$DOTFILES_NERD_FONTS_BUCKET_URL"
  fi
}

dotfiles_install_packages() {
  if [ -z "${DOTFILES_SCOOP_PACKAGES//[[:space:]]/}" ]; then
    echo "==> No Scoop packages declared, skipping package installation"
    return 0
  fi
  dotfiles_configure_scoop
  echo "==> Installing declared Scoop packages"
  # Scoop is idempotent: installed packages are upgraded only when explicitly
  # requested by the user through Scoop, not silently during every rebuild.
  # shellcheck disable=SC2086
  scoop install $DOTFILES_SCOOP_PACKAGES
}

dotfiles_install_herdr() {
  if [ "$DOTFILES_INSTALL_HERDR" != "1" ] || command -v herdr >/dev/null 2>&1; then
    return 0
  fi

  echo "==> Installing Herdr's Windows beta"
  MSYS_NO_PATHCONV=1 powershell.exe -NoLogo -NoProfile -NonInteractive \
    -ExecutionPolicy Bypass -Command \
    "Invoke-RestMethod -Uri '$DOTFILES_HERDR_INSTALL_URL' | Invoke-Expression"
}

dotfiles_install_agent_clis() {
  if [ "$DOTFILES_INSTALL_AGENT_CLIS" != "1" ]; then
    return 0
  fi

  if ! command -v npm >/dev/null 2>&1; then
    echo "Agent CLIs requested, but npm is unavailable. Add nodejs to DOTFILES_SCOOP_PACKAGES and rerun." >&2
    return 1
  fi

  echo "==> Installing optional agent CLIs with npm"
  npm install --global --ignore-scripts \
    @anthropic-ai/claude-code \
    @openai/codex \
    @earendil-works/pi-coding-agent \
    opencode-ai
}

dotfiles_install_bash_hook() {
  if [ "$DOTFILES_INSTALL_BASH_HOOK" != "1" ]; then
    return 0
  fi

  local marker_start="# >>> dotfiles managed Git Bash hook >>>"
  local marker_end="# <<< dotfiles managed Git Bash hook <<<"
  local dotfiles_link_git pi_agent_dir_windows
  dotfiles_link_git="$(cygpath -u "$DOTFILES_DOTFILES_LINK")"
  pi_agent_dir_windows="$(dotfiles_to_windows_path "$DOTFILES_PI_AGENT_DIR")"
  local source_line="export DOTFILES_ROOT=\"$dotfiles_link_git\" DOTFILES_EDITOR=\"$DOTFILES_EDITOR\" DOTFILES_VISUAL=\"$DOTFILES_VISUAL\" PI_CODING_AGENT_DIR=\"$pi_agent_dir_windows\"; . \"\$DOTFILES_ROOT/home/.bashrc\""
  local profile file temporary

  for profile in "$HOME/.bashrc" "$HOME/.bash_profile"; do
    mkdir -p "$(dirname "$profile")"
    temporary="${profile}.dotfiles.tmp"
    if [ -f "$profile" ]; then
      awk -v start="$marker_start" -v end="$marker_end" '
        $0 == start { inside = 1; next }
        $0 == end { inside = 0; next }
        !inside { print }
      ' "$profile" > "$temporary"
    else
      : > "$temporary"
    fi
    {
      cat "$temporary"
      printf '\n%s\n%s\n%s\n' "$marker_start" "$source_line" "$marker_end"
    } > "$profile"
    rm -f "$temporary"
  done
}

dotfiles_link_configs() {
  echo "==> Linking Windows application configurations"
  dotfiles_powershell_file "$DOTFILES_ROOT/windows-links.ps1" \
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
    -LinkMode "$DOTFILES_LINK_MODE" \
    -BackupExisting "$DOTFILES_BACKUP_EXISTING"
}

dotfiles_apply_windows_settings() {
  if [ "$DOTFILES_APPLY_WINDOWS_SETTINGS" != "1" ]; then
    return 0
  fi

  echo "==> Applying opted-in Windows settings"
  dotfiles_powershell_file "$DOTFILES_ROOT/windows-settings.ps1" \
    -DarkMode "$DOTFILES_DARK_MODE" \
    -ShowFileExtensions "$DOTFILES_SHOW_FILE_EXTENSIONS" \
    -ShowHiddenFiles "$DOTFILES_SHOW_HIDDEN_FILES" \
    -HideDesktopIcons "$DOTFILES_HIDE_DESKTOP_ICONS" \
    -TaskbarAutoHide "$DOTFILES_TASKBAR_AUTO_HIDE" \
    -KeyboardRepeat "$DOTFILES_KEYBOARD_REPEAT" \
    -KeyboardDelay "$DOTFILES_KEYBOARD_DELAY" \
    -KeyboardSpeed "$DOTFILES_KEYBOARD_SPEED" \
    -RestartExplorer "$DOTFILES_RESTART_EXPLORER"
}

dotfiles_validate_config() {
  local valid_link_modes="junction symbolic"
  case " $valid_link_modes " in
    *" $DOTFILES_LINK_MODE "*) ;;
    *) echo "DOTFILES_LINK_MODE must be junction or symbolic." >&2; return 1 ;;
  esac

  local variable_name
  for variable_name in \
    DOTFILES_INSTALL_SCOOP DOTFILES_UPDATE_SCOOP DOTFILES_INSTALL_HERDR \
    DOTFILES_INSTALL_AGENT_CLIS DOTFILES_BACKUP_EXISTING DOTFILES_INSTALL_BASH_HOOK \
    DOTFILES_APPLY_WINDOWS_SETTINGS DOTFILES_DARK_MODE DOTFILES_SHOW_FILE_EXTENSIONS \
    DOTFILES_SHOW_HIDDEN_FILES DOTFILES_HIDE_DESKTOP_ICONS DOTFILES_TASKBAR_AUTO_HIDE \
    DOTFILES_KEYBOARD_REPEAT DOTFILES_RESTART_EXPLORER; do
    case "${!variable_name}" in
      0|1) ;;
      *) echo "$variable_name must be 0 or 1." >&2; return 1 ;;
    esac
  done

  if ! [[ "$DOTFILES_KEYBOARD_DELAY" =~ ^[0-3]$ ]]; then
    echo "DOTFILES_KEYBOARD_DELAY must be an integer from 0 to 3." >&2
    return 1
  fi
  if ! [[ "$DOTFILES_KEYBOARD_SPEED" =~ ^([0-9]|[12][0-9]|3[01])$ ]]; then
    echo "DOTFILES_KEYBOARD_SPEED must be an integer from 0 to 31." >&2
    return 1
  fi
}
