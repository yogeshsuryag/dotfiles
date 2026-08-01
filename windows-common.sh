#!/usr/bin/env bash
# Shared Windows setup functions. Source this from bootstrap.sh or rebuild.sh.
set -euo pipefail

dotfiles_prompt_value() {
  local variable_name=$1 label=$2 default_value=$3 answer

  if [ ! -t 0 ]; then
    echo "Cannot configure $variable_name without an interactive terminal." >&2
    echo "Copy windows-config.example.env to windows-config.env or rerun from Git Bash." >&2
    return 1
  fi

  printf '%s [%s]: ' "$label" "$default_value" >&2
  IFS= read -r answer || return 1
  printf -v "$variable_name" '%s' "${answer:-$default_value}"
}

dotfiles_write_config_value() {
  local variable_name=$1
  printf '%s=%q\n' "$variable_name" "${!variable_name}"
}

dotfiles_create_config_interactively() {
  local requested_config=$1
  local detected_home detected_local_appdata detected_appdata
  local default_home default_local_appdata default_appdata default_xdg_config_home
  local default_dotfiles_link default_nvim default_wezterm_dir default_wezterm_file
  local default_herdr default_claude default_codex default_opencode default_pi
  local temporary

  detected_home="$(dotfiles_windows_env_path USERPROFILE 2>/dev/null || true)"
  detected_local_appdata="$(dotfiles_windows_env_path LOCALAPPDATA 2>/dev/null || true)"
  detected_appdata="$(dotfiles_windows_env_path APPDATA 2>/dev/null || true)"
  default_home="${DOTFILES_WINDOWS_HOME:-${detected_home:-$HOME}}"
  default_local_appdata="${DOTFILES_LOCAL_APPDATA:-${detected_local_appdata:-$default_home/AppData/Local}}"
  default_appdata="${DOTFILES_APPDATA:-${detected_appdata:-$default_home/AppData/Roaming}}"
  default_xdg_config_home="${DOTFILES_XDG_CONFIG_HOME:-$default_home/.config}"
  default_dotfiles_link="${DOTFILES_DOTFILES_LINK:-$default_home/.dotfiles}"
  default_nvim="${DOTFILES_NVIM_CONFIG_DIR:-$default_local_appdata/nvim}"
  default_wezterm_dir="${DOTFILES_WEZTERM_CONFIG_DIR:-$default_xdg_config_home/wezterm}"
  default_wezterm_file="${DOTFILES_WEZTERM_CONFIG_FILE:-$default_home/.wezterm.lua}"
  default_herdr="${DOTFILES_HERDR_CONFIG_DIR:-$default_appdata/herdr}"
  default_claude="${DOTFILES_CLAUDE_CONFIG_DIR:-$default_home/.claude}"
  default_codex="${DOTFILES_CODEX_CONFIG_DIR:-$default_home/.codex}"
  default_opencode="${DOTFILES_OPENCODE_CONFIG_DIR:-$default_xdg_config_home/opencode}"
  default_pi="${DOTFILES_PI_AGENT_DIR:-$default_home/.pi/agent}"

  echo "==> Configure Windows dotfiles"
  echo "    Press Enter to accept each default. These values are saved locally in $requested_config."
  echo ""
  echo "Scoop and optional installers"
  dotfiles_prompt_value DOTFILES_INSTALL_SCOOP "DOTFILES_INSTALL_SCOOP (0/1)" "${DOTFILES_INSTALL_SCOOP:-1}"
  dotfiles_prompt_value DOTFILES_SCOOP_BUCKETS "DOTFILES_SCOOP_BUCKETS (space-separated)" "${DOTFILES_SCOOP_BUCKETS:-extras}"
  dotfiles_prompt_value DOTFILES_NERD_FONTS_BUCKET_URL "DOTFILES_NERD_FONTS_BUCKET_URL" "${DOTFILES_NERD_FONTS_BUCKET_URL:-https://github.com/matthewjberger/scoop-nerd-fonts}"
  dotfiles_prompt_value DOTFILES_SCOOP_PACKAGES "DOTFILES_SCOOP_PACKAGES (space-separated)" "${DOTFILES_SCOOP_PACKAGES:-git neovim wezterm starship ripgrep fd fzf jq lazygit nodejs Hack-NF}"
  dotfiles_prompt_value DOTFILES_UPDATE_SCOOP "DOTFILES_UPDATE_SCOOP (0/1)" "${DOTFILES_UPDATE_SCOOP:-0}"
  dotfiles_prompt_value DOTFILES_INSTALL_HERDR "DOTFILES_INSTALL_HERDR (0/1)" "${DOTFILES_INSTALL_HERDR:-1}"
  dotfiles_prompt_value DOTFILES_HERDR_INSTALL_URL "DOTFILES_HERDR_INSTALL_URL" "${DOTFILES_HERDR_INSTALL_URL:-https://herdr.dev/install.ps1}"
  dotfiles_prompt_value DOTFILES_INSTALL_AGENT_CLIS "DOTFILES_INSTALL_AGENT_CLIS (0/1)" "${DOTFILES_INSTALL_AGENT_CLIS:-0}"

  echo ""
  echo "Windows paths (Git Bash path format)"
  dotfiles_prompt_value DOTFILES_WINDOWS_HOME "DOTFILES_WINDOWS_HOME" "$default_home"
  dotfiles_prompt_value DOTFILES_LOCAL_APPDATA "DOTFILES_LOCAL_APPDATA" "$default_local_appdata"
  dotfiles_prompt_value DOTFILES_APPDATA "DOTFILES_APPDATA" "$default_appdata"
  dotfiles_prompt_value DOTFILES_XDG_CONFIG_HOME "DOTFILES_XDG_CONFIG_HOME" "$default_xdg_config_home"
  dotfiles_prompt_value DOTFILES_DOTFILES_LINK "DOTFILES_DOTFILES_LINK" "$default_dotfiles_link"
  dotfiles_prompt_value DOTFILES_NVIM_CONFIG_DIR "DOTFILES_NVIM_CONFIG_DIR" "$default_nvim"
  dotfiles_prompt_value DOTFILES_WEZTERM_CONFIG_DIR "DOTFILES_WEZTERM_CONFIG_DIR" "$default_wezterm_dir"
  dotfiles_prompt_value DOTFILES_WEZTERM_CONFIG_FILE "DOTFILES_WEZTERM_CONFIG_FILE" "$default_wezterm_file"
  dotfiles_prompt_value DOTFILES_HERDR_CONFIG_DIR "DOTFILES_HERDR_CONFIG_DIR" "$default_herdr"
  dotfiles_prompt_value DOTFILES_CLAUDE_CONFIG_DIR "DOTFILES_CLAUDE_CONFIG_DIR" "$default_claude"
  dotfiles_prompt_value DOTFILES_CODEX_CONFIG_DIR "DOTFILES_CODEX_CONFIG_DIR" "$default_codex"
  dotfiles_prompt_value DOTFILES_OPENCODE_CONFIG_DIR "DOTFILES_OPENCODE_CONFIG_DIR" "$default_opencode"
  dotfiles_prompt_value DOTFILES_PI_AGENT_DIR "DOTFILES_PI_AGENT_DIR" "$default_pi"

  echo ""
  echo "Linking and Git Bash"
  dotfiles_prompt_value DOTFILES_LINK_MODE "DOTFILES_LINK_MODE (junction/symbolic)" "${DOTFILES_LINK_MODE:-junction}"
  dotfiles_prompt_value DOTFILES_BACKUP_EXISTING "DOTFILES_BACKUP_EXISTING (0/1)" "${DOTFILES_BACKUP_EXISTING:-1}"
  dotfiles_prompt_value DOTFILES_INSTALL_BASH_HOOK "DOTFILES_INSTALL_BASH_HOOK (0/1)" "${DOTFILES_INSTALL_BASH_HOOK:-1}"
  dotfiles_prompt_value DOTFILES_EDITOR "DOTFILES_EDITOR" "${DOTFILES_EDITOR:-nvim}"
  dotfiles_prompt_value DOTFILES_VISUAL "DOTFILES_VISUAL" "${DOTFILES_VISUAL:-${DOTFILES_EDITOR:-nvim}}"

  echo ""
  echo "Opt-in Windows settings"
  dotfiles_prompt_value DOTFILES_APPLY_WINDOWS_SETTINGS "DOTFILES_APPLY_WINDOWS_SETTINGS (0/1)" "${DOTFILES_APPLY_WINDOWS_SETTINGS:-0}"
  dotfiles_prompt_value DOTFILES_DARK_MODE "DOTFILES_DARK_MODE (0/1)" "${DOTFILES_DARK_MODE:-0}"
  dotfiles_prompt_value DOTFILES_SHOW_FILE_EXTENSIONS "DOTFILES_SHOW_FILE_EXTENSIONS (0/1)" "${DOTFILES_SHOW_FILE_EXTENSIONS:-0}"
  dotfiles_prompt_value DOTFILES_SHOW_HIDDEN_FILES "DOTFILES_SHOW_HIDDEN_FILES (0/1)" "${DOTFILES_SHOW_HIDDEN_FILES:-0}"
  dotfiles_prompt_value DOTFILES_HIDE_DESKTOP_ICONS "DOTFILES_HIDE_DESKTOP_ICONS (0/1)" "${DOTFILES_HIDE_DESKTOP_ICONS:-0}"
  dotfiles_prompt_value DOTFILES_TASKBAR_AUTO_HIDE "DOTFILES_TASKBAR_AUTO_HIDE (0/1)" "${DOTFILES_TASKBAR_AUTO_HIDE:-0}"
  dotfiles_prompt_value DOTFILES_KEYBOARD_REPEAT "DOTFILES_KEYBOARD_REPEAT (0/1)" "${DOTFILES_KEYBOARD_REPEAT:-0}"
  dotfiles_prompt_value DOTFILES_KEYBOARD_DELAY "DOTFILES_KEYBOARD_DELAY (0-3)" "${DOTFILES_KEYBOARD_DELAY:-0}"
  dotfiles_prompt_value DOTFILES_KEYBOARD_SPEED "DOTFILES_KEYBOARD_SPEED (0-31)" "${DOTFILES_KEYBOARD_SPEED:-31}"
  dotfiles_prompt_value DOTFILES_RESTART_EXPLORER "DOTFILES_RESTART_EXPLORER (0/1)" "${DOTFILES_RESTART_EXPLORER:-0}"

  mkdir -p "$(dirname "$requested_config")"
  temporary="${requested_config}.tmp.$$"
  {
    printf '# Generated by the dotfiles setup wizard. This file is local and ignored by Git.\n'
    printf '# Review it before running the setup again.\n\n'
    dotfiles_write_config_value DOTFILES_INSTALL_SCOOP
    dotfiles_write_config_value DOTFILES_SCOOP_BUCKETS
    dotfiles_write_config_value DOTFILES_NERD_FONTS_BUCKET_URL
    dotfiles_write_config_value DOTFILES_SCOOP_PACKAGES
    dotfiles_write_config_value DOTFILES_UPDATE_SCOOP
    dotfiles_write_config_value DOTFILES_INSTALL_HERDR
    dotfiles_write_config_value DOTFILES_HERDR_INSTALL_URL
    dotfiles_write_config_value DOTFILES_INSTALL_AGENT_CLIS
    dotfiles_write_config_value DOTFILES_WINDOWS_HOME
    dotfiles_write_config_value DOTFILES_LOCAL_APPDATA
    dotfiles_write_config_value DOTFILES_APPDATA
    dotfiles_write_config_value DOTFILES_XDG_CONFIG_HOME
    dotfiles_write_config_value DOTFILES_DOTFILES_LINK
    dotfiles_write_config_value DOTFILES_NVIM_CONFIG_DIR
    dotfiles_write_config_value DOTFILES_WEZTERM_CONFIG_DIR
    dotfiles_write_config_value DOTFILES_WEZTERM_CONFIG_FILE
    dotfiles_write_config_value DOTFILES_HERDR_CONFIG_DIR
    dotfiles_write_config_value DOTFILES_CLAUDE_CONFIG_DIR
    dotfiles_write_config_value DOTFILES_CODEX_CONFIG_DIR
    dotfiles_write_config_value DOTFILES_OPENCODE_CONFIG_DIR
    dotfiles_write_config_value DOTFILES_PI_AGENT_DIR
    dotfiles_write_config_value DOTFILES_LINK_MODE
    dotfiles_write_config_value DOTFILES_BACKUP_EXISTING
    dotfiles_write_config_value DOTFILES_INSTALL_BASH_HOOK
    dotfiles_write_config_value DOTFILES_EDITOR
    dotfiles_write_config_value DOTFILES_VISUAL
    dotfiles_write_config_value DOTFILES_APPLY_WINDOWS_SETTINGS
    dotfiles_write_config_value DOTFILES_DARK_MODE
    dotfiles_write_config_value DOTFILES_SHOW_FILE_EXTENSIONS
    dotfiles_write_config_value DOTFILES_SHOW_HIDDEN_FILES
    dotfiles_write_config_value DOTFILES_HIDE_DESKTOP_ICONS
    dotfiles_write_config_value DOTFILES_TASKBAR_AUTO_HIDE
    dotfiles_write_config_value DOTFILES_KEYBOARD_REPEAT
    dotfiles_write_config_value DOTFILES_KEYBOARD_DELAY
    dotfiles_write_config_value DOTFILES_KEYBOARD_SPEED
    dotfiles_write_config_value DOTFILES_RESTART_EXPLORER
  } > "$temporary"
  mv -f "$temporary" "$requested_config"
  echo "==> Saved $requested_config"
}

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

  DOTFILES_INSTALL_SCOOP="${DOTFILES_INSTALL_SCOOP:-1}"
  DOTFILES_SCOOP_BUCKETS="${DOTFILES_SCOOP_BUCKETS:-extras}"
  DOTFILES_NERD_FONTS_BUCKET_URL="${DOTFILES_NERD_FONTS_BUCKET_URL:-https://github.com/matthewjberger/scoop-nerd-fonts}"
  DOTFILES_SCOOP_PACKAGES="${DOTFILES_SCOOP_PACKAGES:-git neovim wezterm starship ripgrep fd fzf jq lazygit nodejs Hack-NF}"
  DOTFILES_UPDATE_SCOOP="${DOTFILES_UPDATE_SCOOP:-0}"
  DOTFILES_INSTALL_HERDR="${DOTFILES_INSTALL_HERDR:-1}"
  DOTFILES_HERDR_INSTALL_URL="${DOTFILES_HERDR_INSTALL_URL:-https://herdr.dev/install.ps1}"
  DOTFILES_INSTALL_AGENT_CLIS="${DOTFILES_INSTALL_AGENT_CLIS:-0}"
  DOTFILES_LINK_MODE="${DOTFILES_LINK_MODE:-junction}"
  DOTFILES_BACKUP_EXISTING="${DOTFILES_BACKUP_EXISTING:-1}"
  DOTFILES_DOTFILES_LINK="${DOTFILES_DOTFILES_LINK:-}"
  DOTFILES_INSTALL_BASH_HOOK="${DOTFILES_INSTALL_BASH_HOOK:-1}"
  DOTFILES_EDITOR="${DOTFILES_EDITOR:-nvim}"
  DOTFILES_VISUAL="${DOTFILES_VISUAL:-$DOTFILES_EDITOR}"
  DOTFILES_APPLY_WINDOWS_SETTINGS="${DOTFILES_APPLY_WINDOWS_SETTINGS:-0}"
  DOTFILES_DARK_MODE="${DOTFILES_DARK_MODE:-0}"
  DOTFILES_SHOW_FILE_EXTENSIONS="${DOTFILES_SHOW_FILE_EXTENSIONS:-0}"
  DOTFILES_SHOW_HIDDEN_FILES="${DOTFILES_SHOW_HIDDEN_FILES:-0}"
  DOTFILES_HIDE_DESKTOP_ICONS="${DOTFILES_HIDE_DESKTOP_ICONS:-0}"
  DOTFILES_TASKBAR_AUTO_HIDE="${DOTFILES_TASKBAR_AUTO_HIDE:-0}"
  DOTFILES_KEYBOARD_REPEAT="${DOTFILES_KEYBOARD_REPEAT:-0}"
  DOTFILES_KEYBOARD_DELAY="${DOTFILES_KEYBOARD_DELAY:-0}"
  DOTFILES_KEYBOARD_SPEED="${DOTFILES_KEYBOARD_SPEED:-31}"
  DOTFILES_RESTART_EXPLORER="${DOTFILES_RESTART_EXPLORER:-0}"
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
  local pi_agent_dir_windows
  pi_agent_dir_windows="$(dotfiles_to_windows_path "$DOTFILES_PI_AGENT_DIR")"
  local source_line="export DOTFILES_ROOT=\"$DOTFILES_DOTFILES_LINK\" DOTFILES_EDITOR=\"$DOTFILES_EDITOR\" DOTFILES_VISUAL=\"$DOTFILES_VISUAL\" PI_CODING_AGENT_DIR=\"$pi_agent_dir_windows\"; . \"\$DOTFILES_ROOT/home/.bashrc\""
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
