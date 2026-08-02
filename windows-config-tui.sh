#!/usr/bin/env bash
# Dependency-free interactive configuration UI for Git Bash on Windows.

dotfiles_apply_config_defaults() {
  local detected_home detected_local_appdata detected_appdata

  detected_home="$(dotfiles_windows_env_path USERPROFILE 2>/dev/null || true)"
  detected_local_appdata="$(dotfiles_windows_env_path LOCALAPPDATA 2>/dev/null || true)"
  detected_appdata="$(dotfiles_windows_env_path APPDATA 2>/dev/null || true)"

  DOTFILES_WINDOWS_HOME="${DOTFILES_WINDOWS_HOME:-${detected_home:-$HOME}}"
  DOTFILES_LOCAL_APPDATA="${DOTFILES_LOCAL_APPDATA:-${detected_local_appdata:-$DOTFILES_WINDOWS_HOME/AppData/Local}}"
  DOTFILES_APPDATA="${DOTFILES_APPDATA:-${detected_appdata:-$DOTFILES_WINDOWS_HOME/AppData/Roaming}}"
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

dotfiles_tui_add_item() {
  DOTFILES_TUI_ITEM_KINDS+=("$1")
  DOTFILES_TUI_ITEM_KEYS+=("$2")
  DOTFILES_TUI_ITEM_LABELS+=("$3")
  DOTFILES_TUI_ITEM_DESCRIPTIONS+=("$4")
}

dotfiles_tui_add_action() {
  dotfiles_tui_add_item action "$1" "$2" "$3"
}

dotfiles_tui_page_title() {
  case "$1" in
    0) printf 'Tools and packages' ;;
    1) printf 'Optional installers' ;;
    2) printf 'File locations' ;;
    3) printf 'Shell and links' ;;
    4) printf 'Windows settings' ;;
    *) printf 'Review your choices' ;;
  esac
}

dotfiles_tui_page_intro() {
  case "$1" in
    0) printf 'Choose the tools Scoop should install. Space toggles a choice; custom entries stay space-separated.' ;;
    1) printf 'These installers are optional. URLs are editable so you can review the source before continuing.' ;;
    2) printf 'Defaults are detected from Windows. Use Git Bash paths such as /c/Users/name; press Enter to edit.' ;;
    3) printf 'Choose how repository files are linked and which editor commands Git Bash should use.' ;;
    4) printf 'Registry changes are opt-in. Leave the master switch off to make this section a no-op.' ;;
    *) printf 'Nothing is saved until you choose Save configuration. Go back to adjust any section.' ;;
  esac
}

dotfiles_tui_normalize_words() {
  local list=$1 item result=''
  for item in $list; do
    if [ -n "$result" ]; then
      result="$result $item"
    else
      result=$item
    fi
  done
  printf '%s' "$result"
}

dotfiles_tui_initialize_collections() {
  local package index found bucket

  DOTFILES_TUI_PACKAGE_OPTIONS=(git neovim wezterm starship ripgrep fd fzf jq lazygit nodejs Hack-NF)
  DOTFILES_TUI_PACKAGE_LABELS=('Git for Windows' 'Neovim' 'WezTerm' 'Starship' 'ripgrep' 'fd' 'fzf' 'jq' 'lazygit' 'Node.js' 'Hack Nerd Font')
  DOTFILES_TUI_PACKAGE_DESCRIPTIONS=(
    'Git and Git Bash, used by the repository and daily development.'
    'The terminal editor configured in home/.config/nvim.'
    'The terminal emulator configured in home/.config/wezterm.'
    'The shell prompt used by the managed Git Bash configuration.'
    'Fast recursive search for files and text.'
    'A fast, user-friendly alternative to find.'
    'Fuzzy finder used by shell and editor workflows.'
    'Command-line JSON processing.'
    'A terminal UI for Git repositories.'
    'The runtime needed by optional agent CLI installers.'
    'The font family used by the terminal and editor configuration.'
  )
  DOTFILES_TUI_PACKAGE_SELECTED=()
  for index in "${!DOTFILES_TUI_PACKAGE_OPTIONS[@]}"; do
    DOTFILES_TUI_PACKAGE_SELECTED[$index]=0
  done
  DOTFILES_TUI_CUSTOM_PACKAGES=''

  for package in $DOTFILES_SCOOP_PACKAGES; do
    found=0
    for index in "${!DOTFILES_TUI_PACKAGE_OPTIONS[@]}"; do
      if [ "${DOTFILES_TUI_PACKAGE_OPTIONS[$index]}" = "$package" ]; then
        DOTFILES_TUI_PACKAGE_SELECTED[$index]=1
        found=1
        break
      fi
    done
    if [ "$found" = 0 ]; then
      if [ -n "$DOTFILES_TUI_CUSTOM_PACKAGES" ]; then
        DOTFILES_TUI_CUSTOM_PACKAGES="$DOTFILES_TUI_CUSTOM_PACKAGES $package"
      else
        DOTFILES_TUI_CUSTOM_PACKAGES=$package
      fi
    fi
  done

  DOTFILES_TUI_BUCKET_EXTRAS=0
  DOTFILES_TUI_CUSTOM_BUCKETS=''
  for bucket in $DOTFILES_SCOOP_BUCKETS; do
    if [ "$bucket" = extras ]; then
      DOTFILES_TUI_BUCKET_EXTRAS=1
    elif [ -n "$DOTFILES_TUI_CUSTOM_BUCKETS" ]; then
      DOTFILES_TUI_CUSTOM_BUCKETS="$DOTFILES_TUI_CUSTOM_BUCKETS $bucket"
    else
      DOTFILES_TUI_CUSTOM_BUCKETS=$bucket
    fi
  done
}

dotfiles_tui_selected_packages() {
  local index result=''
  for index in "${!DOTFILES_TUI_PACKAGE_OPTIONS[@]}"; do
    if [ "${DOTFILES_TUI_PACKAGE_SELECTED[$index]}" = 1 ]; then
      if [ -n "$result" ]; then
        result="$result ${DOTFILES_TUI_PACKAGE_OPTIONS[$index]}"
      else
        result=${DOTFILES_TUI_PACKAGE_OPTIONS[$index]}
      fi
    fi
  done
  if [ -n "$DOTFILES_TUI_CUSTOM_PACKAGES" ]; then
    if [ -n "$result" ]; then
      result="$result $(dotfiles_tui_normalize_words "$DOTFILES_TUI_CUSTOM_PACKAGES")"
    else
      result=$(dotfiles_tui_normalize_words "$DOTFILES_TUI_CUSTOM_PACKAGES")
    fi
  fi
  printf '%s' "$result"
}

dotfiles_tui_selected_buckets() {
  local result=''
  if [ "$DOTFILES_TUI_BUCKET_EXTRAS" = 1 ]; then
    result=extras
  fi
  if [ -n "$DOTFILES_TUI_CUSTOM_BUCKETS" ]; then
    if [ -n "$result" ]; then
      result="$result $(dotfiles_tui_normalize_words "$DOTFILES_TUI_CUSTOM_BUCKETS")"
    else
      result=$(dotfiles_tui_normalize_words "$DOTFILES_TUI_CUSTOM_BUCKETS")
    fi
  fi
  printf '%s' "$result"
}

dotfiles_tui_commit_collections() {
  DOTFILES_SCOOP_PACKAGES="$(dotfiles_tui_selected_packages)"
  DOTFILES_SCOOP_BUCKETS="$(dotfiles_tui_selected_buckets)"
}

dotfiles_tui_package_selected() {
  local package=$1 index
  for index in "${!DOTFILES_TUI_PACKAGE_OPTIONS[@]}"; do
    if [ "${DOTFILES_TUI_PACKAGE_OPTIONS[$index]}" = "$package" ]; then
      printf '%s' "${DOTFILES_TUI_PACKAGE_SELECTED[$index]}"
      return 0
    fi
  done
  printf '0'
}

dotfiles_tui_get_text_value() {
  case "$1" in
    __custom_packages) printf '%s' "$DOTFILES_TUI_CUSTOM_PACKAGES" ;;
    __custom_buckets) printf '%s' "$DOTFILES_TUI_CUSTOM_BUCKETS" ;;
    *) printf '%s' "${!1}" ;;
  esac
}

dotfiles_tui_set_text_value() {
  case "$1" in
    __custom_packages) DOTFILES_TUI_CUSTOM_PACKAGES=$2 ;;
    __custom_buckets) DOTFILES_TUI_CUSTOM_BUCKETS=$2 ;;
    *) printf -v "$1" '%s' "$2" ;;
  esac
}

dotfiles_tui_choice_label() {
  case "$1:$2" in
    DOTFILES_LINK_MODE:junction) printf 'Windows junctions (recommended)' ;;
    DOTFILES_LINK_MODE:symbolic) printf 'Symbolic links' ;;
    *) printf '%s' "$2" ;;
  esac
}

dotfiles_tui_item_value() {
  local kind=$1 key=$2
  case "$kind" in
    toggle)
      if [ "${!key}" = 1 ]; then printf 'ON'; else printf 'OFF'; fi
      ;;
    package) dotfiles_tui_package_selected "$key" ;;
    bucket)
      if [ "$DOTFILES_TUI_BUCKET_EXTRAS" = 1 ]; then printf 'ON'; else printf 'OFF'; fi
      ;;
    choice)
      dotfiles_tui_choice_label "$key" "${!key}"
      ;;
    number) printf '%s' "${!key}" ;;
    text) dotfiles_tui_get_text_value "$key" ;;
    action) printf '' ;;
    *) printf '' ;;
  esac
}

dotfiles_tui_add_packages_page() {
  local index
  dotfiles_tui_add_item toggle DOTFILES_INSTALL_SCOOP 'Install Scoop' 'Windows package manager used to install the selected tools below.'
  dotfiles_tui_add_item toggle DOTFILES_UPDATE_SCOOP 'Update Scoop before installing' 'Refresh Scoop metadata first. This is slower but useful on an existing setup.'
  dotfiles_tui_add_item bucket extras 'Add the extras bucket' "Enables Scoop's community extras bucket for additional package manifests."
  dotfiles_tui_add_item text __custom_buckets 'Additional Scoop buckets' 'Optional space-separated bucket names or name=URL values.'
  dotfiles_tui_add_item text DOTFILES_NERD_FONTS_BUCKET_URL 'Nerd Fonts source' 'Repository used when the setup adds the Nerd Fonts Scoop bucket.'
  for index in "${!DOTFILES_TUI_PACKAGE_OPTIONS[@]}"; do
    dotfiles_tui_add_item package "${DOTFILES_TUI_PACKAGE_OPTIONS[$index]}" "${DOTFILES_TUI_PACKAGE_LABELS[$index]}" "${DOTFILES_TUI_PACKAGE_DESCRIPTIONS[$index]}"
  done
  dotfiles_tui_add_item text __custom_packages 'Additional Scoop packages' 'Optional space-separated package names not shown in the checklist.'
  dotfiles_tui_add_action next 'Continue to optional installers' 'Save these choices temporarily and open the next section.'
}

dotfiles_tui_load_items() {
  DOTFILES_TUI_ITEM_KINDS=()
  DOTFILES_TUI_ITEM_KEYS=()
  DOTFILES_TUI_ITEM_LABELS=()
  DOTFILES_TUI_ITEM_DESCRIPTIONS=()

  case "$DOTFILES_TUI_PAGE" in
    0) dotfiles_tui_add_packages_page ;;
    1)
      dotfiles_tui_add_item toggle DOTFILES_INSTALL_HERDR 'Install Herdr' "Install Herdr's Windows beta using the source below when it is not already available."
      dotfiles_tui_add_item text DOTFILES_HERDR_INSTALL_URL 'Herdr installer source' 'PowerShell installer URL used for the optional Herdr installation.'
      dotfiles_tui_add_item toggle DOTFILES_INSTALL_AGENT_CLIS 'Install optional AI command-line tools' 'Install Claude, Codex, Pi, and opencode with npm. Credentials remain local to each tool.'
      dotfiles_tui_add_action back 'Back to tools and packages' 'Return to the previous section without losing these choices.'
      dotfiles_tui_add_action next 'Continue to file locations' 'Open the detected Windows paths and application locations.'
      ;;
    2)
      dotfiles_tui_add_item text DOTFILES_WINDOWS_HOME 'Windows home directory' 'The main user directory used for dotfiles, agent settings, and shell files.'
      dotfiles_tui_add_item text DOTFILES_LOCAL_APPDATA 'Local application data' 'Windows local application data directory; Neovim is linked below it by default.'
      dotfiles_tui_add_item text DOTFILES_APPDATA 'Roaming application data' 'Windows roaming application data directory; Herdr is linked below it by default.'
      dotfiles_tui_add_item text DOTFILES_XDG_CONFIG_HOME 'Shared config directory' 'Git Bash-style config home used by WezTerm and opencode.'
      dotfiles_tui_add_item text DOTFILES_DOTFILES_LINK 'Repository link location' 'Convenient path exposed in the shell as the active dotfiles checkout.'
      dotfiles_tui_add_item text DOTFILES_NVIM_CONFIG_DIR 'Neovim configuration directory' "Destination for the repository's Neovim configuration."
      dotfiles_tui_add_item text DOTFILES_WEZTERM_CONFIG_DIR 'WezTerm configuration directory' "Destination for the repository's WezTerm configuration directory."
      dotfiles_tui_add_item text DOTFILES_WEZTERM_CONFIG_FILE 'WezTerm single-file config' 'Destination for the top-level WezTerm configuration file.'
      dotfiles_tui_add_item text DOTFILES_HERDR_CONFIG_DIR 'Herdr configuration directory' "Destination for the repository's Herdr configuration."
      dotfiles_tui_add_item text DOTFILES_CLAUDE_CONFIG_DIR 'Claude configuration directory' 'Destination for authored Claude configuration files.'
      dotfiles_tui_add_item text DOTFILES_CODEX_CONFIG_DIR 'Codex configuration directory' 'Destination for shared Codex instruction files.'
      dotfiles_tui_add_item text DOTFILES_OPENCODE_CONFIG_DIR 'opencode configuration directory' 'Destination for shared opencode instruction and configuration files.'
      dotfiles_tui_add_item text DOTFILES_PI_AGENT_DIR 'Pi agent configuration directory' 'Destination for authored Pi settings, themes, and extensions.'
      dotfiles_tui_add_action back 'Back to optional installers' 'Return to the previous section without losing these paths.'
      dotfiles_tui_add_action next 'Continue to shell and links' 'Open link behavior and Git Bash integration.'
      ;;
    3)
      dotfiles_tui_add_item choice DOTFILES_LINK_MODE 'Link directories using' 'Junctions are the Windows-friendly default; symbolic links require the appropriate privilege.'
      dotfiles_tui_add_item toggle DOTFILES_BACKUP_EXISTING 'Back up existing files' 'Move real files and directories aside before creating managed links.'
      dotfiles_tui_add_item toggle DOTFILES_INSTALL_BASH_HOOK 'Install Git Bash integration' 'Add a managed block to .bashrc and .bash_profile for the repository and editor settings.'
      dotfiles_tui_add_item text DOTFILES_EDITOR 'Editor command' 'Command used when shell tools open an editor, such as nvim.'
      dotfiles_tui_add_item text DOTFILES_VISUAL 'Visual editor command' 'Fallback visual editor command used by programs that distinguish it from the editor.'
      dotfiles_tui_add_action back 'Back to file locations' 'Return to the previous section without losing these choices.'
      dotfiles_tui_add_action next 'Continue to Windows settings' 'Open the optional registry-backed settings.'
      ;;
    4)
      dotfiles_tui_add_item toggle DOTFILES_APPLY_WINDOWS_SETTINGS 'Apply Windows settings' 'Master switch. Keep this off to avoid registry changes during bootstrap or rebuild.'
      dotfiles_tui_add_item toggle DOTFILES_DARK_MODE 'Use dark mode' 'Use dark mode for Windows and supported applications.'
      dotfiles_tui_add_item toggle DOTFILES_SHOW_FILE_EXTENSIONS 'Show file extensions' 'Show filename extensions in File Explorer.'
      dotfiles_tui_add_item toggle DOTFILES_SHOW_HIDDEN_FILES 'Show hidden files' 'Show hidden files in File Explorer.'
      dotfiles_tui_add_item toggle DOTFILES_HIDE_DESKTOP_ICONS 'Hide desktop icons' 'Hide desktop icons without deleting anything from the Desktop folder.'
      dotfiles_tui_add_item toggle DOTFILES_TASKBAR_AUTO_HIDE 'Auto-hide the taskbar' 'Enable taskbar auto-hide where Windows exposes the required setting.'
      dotfiles_tui_add_item toggle DOTFILES_KEYBOARD_REPEAT 'Tune keyboard repeat' 'Apply the delay and speed values below to keyboard repeat behavior.'
      dotfiles_tui_add_item number DOTFILES_KEYBOARD_DELAY 'Keyboard repeat delay' 'Delay value from 0 to 3. Use Left and Right to adjust it.'
      dotfiles_tui_add_item number DOTFILES_KEYBOARD_SPEED 'Keyboard repeat speed' 'Speed value from 0 to 31. Use Left and Right to adjust it.'
      dotfiles_tui_add_item toggle DOTFILES_RESTART_EXPLORER 'Restart Explorer after changes' 'Restart Explorer after Explorer or taskbar settings are applied.'
      dotfiles_tui_add_item action back 'Back to shell and links' 'Return to the previous section without losing these choices.'
      dotfiles_tui_add_action next 'Review all choices' 'Show a concise summary before anything is written.'
      ;;
  esac
}

dotfiles_tui_clip() {
  local value=$1 max_length=${2:-68} tail_length=18
  if [ "${#value}" -le "$max_length" ]; then
    printf '%s' "$value"
  elif [ "$max_length" -le 24 ]; then
    printf '%s' "${value:0:max_length}"
  else
    printf '%s...%s' "${value:0:max_length-tail_length-3}" "${value: -$tail_length}"
  fi
}

dotfiles_tui_clear_screen() {
  printf '\033[2J\033[H' > "$DOTFILES_TUI_TTY"
}

dotfiles_tui_render_page() {
  local index kind key label description value marker state current_state
  dotfiles_tui_clear_screen
  printf '%s%sWindows dotfiles setup%s\n' "$DOTFILES_TUI_BOLD" "$DOTFILES_TUI_ACCENT" "$DOTFILES_TUI_RESET" > "$DOTFILES_TUI_TTY"
  printf 'Step %d of 5: %s\n' "$((DOTFILES_TUI_PAGE + 1))" "$(dotfiles_tui_page_title "$DOTFILES_TUI_PAGE")" > "$DOTFILES_TUI_TTY"
  printf '%s\n\n' "$(dotfiles_tui_page_intro "$DOTFILES_TUI_PAGE")" > "$DOTFILES_TUI_TTY"

  for index in "${!DOTFILES_TUI_ITEM_KINDS[@]}"; do
    kind=${DOTFILES_TUI_ITEM_KINDS[$index]}
    key=${DOTFILES_TUI_ITEM_KEYS[$index]}
    label=${DOTFILES_TUI_ITEM_LABELS[$index]}
    description=${DOTFILES_TUI_ITEM_DESCRIPTIONS[$index]}
    marker=' '
    if [ "$index" -eq "$DOTFILES_TUI_SELECTED" ]; then
      marker='>'
    fi

    if [ "$kind" = action ]; then
      if [ "$index" -eq "$DOTFILES_TUI_SELECTED" ]; then
        printf '%s%s %s[%s]%s\n' "$DOTFILES_TUI_ACCENT" "$marker" "$DOTFILES_TUI_BOLD" "$label" "$DOTFILES_TUI_RESET" > "$DOTFILES_TUI_TTY"
      else
        printf '  [%s]\n' "$label" > "$DOTFILES_TUI_TTY"
      fi
    else
      state=$(dotfiles_tui_item_value "$kind" "$key")
      if [ "$kind" = package ] || [ "$kind" = bucket ]; then
        if [ "$state" = 1 ] || [ "$state" = ON ]; then
          value='[x]'
        else
          value='[ ]'
        fi
      elif [ "$kind" = toggle ]; then
        value="$state"
      else
        value=$(dotfiles_tui_clip "$state" 42)
        if [ -z "$value" ]; then value='(none)'; fi
      fi
      if [ "$index" -eq "$DOTFILES_TUI_SELECTED" ]; then
        current_state=$state
        if [ "$kind" = package ]; then
          if [ "$state" = 1 ]; then current_state='selected'; else current_state='not selected'; fi
        elif [ "$kind" = bucket ]; then
          if [ "$state" = ON ]; then current_state='enabled'; else current_state='not enabled'; fi
        elif [ -z "$current_state" ]; then
          current_state='none'
        fi
        printf '%s%s %-37s %s%s%s\n' "$DOTFILES_TUI_ACCENT" "$marker" "$label" "$DOTFILES_TUI_BOLD" "$value" "$DOTFILES_TUI_RESET" > "$DOTFILES_TUI_TTY"
        printf '    %s\n' "$description" > "$DOTFILES_TUI_TTY"
        printf '    Current: %s\n' "$(dotfiles_tui_clip "$current_state" 68)" > "$DOTFILES_TUI_TTY"
      else
        printf '  %-37s %s\n' "$label" "$value" > "$DOTFILES_TUI_TTY"
      fi
    fi
  done

  printf '\n%sUp/Down%s move  %sSpace%s toggle  %sEnter%s edit/select  %sTab%s next  %sLeft/Right%s adjust choices  %sEsc/q%s cancel\n' \
    "$DOTFILES_TUI_BOLD" "$DOTFILES_TUI_RESET" "$DOTFILES_TUI_BOLD" "$DOTFILES_TUI_RESET" \
    "$DOTFILES_TUI_BOLD" "$DOTFILES_TUI_RESET" "$DOTFILES_TUI_BOLD" "$DOTFILES_TUI_RESET" \
    "$DOTFILES_TUI_BOLD" "$DOTFILES_TUI_RESET" "$DOTFILES_TUI_BOLD" "$DOTFILES_TUI_RESET" > "$DOTFILES_TUI_TTY"
}

dotfiles_tui_render_summary() {
  local selected_packages selected_buckets package_count index
  selected_packages=$(dotfiles_tui_selected_packages)
  selected_buckets=$(dotfiles_tui_selected_buckets)
  package_count=0
  for index in "${!DOTFILES_TUI_PACKAGE_OPTIONS[@]}"; do
    if [ "${DOTFILES_TUI_PACKAGE_SELECTED[$index]}" = 1 ]; then
      package_count=$((package_count + 1))
    fi
  done
  for index in $DOTFILES_TUI_CUSTOM_PACKAGES; do
    if [ -n "$index" ]; then
      package_count=$((package_count + 1))
    fi
  done

  dotfiles_tui_clear_screen
  printf '%s%sWindows dotfiles setup%s\n' "$DOTFILES_TUI_BOLD" "$DOTFILES_TUI_ACCENT" "$DOTFILES_TUI_RESET" > "$DOTFILES_TUI_TTY"
  printf 'Review your choices before saving\n\n' > "$DOTFILES_TUI_TTY"
  printf '  Package manager: %s\n' "$(dotfiles_tui_item_value toggle DOTFILES_INSTALL_SCOOP)" > "$DOTFILES_TUI_TTY"
  printf '  Packages selected: %d\n' "$package_count" > "$DOTFILES_TUI_TTY"
  printf '  Package list: %s\n' "$(dotfiles_tui_clip "${selected_packages:-none}" 68)" > "$DOTFILES_TUI_TTY"
  printf '  Scoop buckets: %s\n' "$(dotfiles_tui_clip "${selected_buckets:-none}" 68)" > "$DOTFILES_TUI_TTY"
  printf '  Optional installers: Herdr %s, AI tools %s\n' \
    "$(dotfiles_tui_item_value toggle DOTFILES_INSTALL_HERDR)" \
    "$(dotfiles_tui_item_value toggle DOTFILES_INSTALL_AGENT_CLIS)" > "$DOTFILES_TUI_TTY"
  printf '  Main home: %s\n' "$(dotfiles_tui_clip "$DOTFILES_WINDOWS_HOME" 68)" > "$DOTFILES_TUI_TTY"
  printf '  Repository link: %s\n' "$(dotfiles_tui_clip "$DOTFILES_DOTFILES_LINK" 68)" > "$DOTFILES_TUI_TTY"
  printf '  Linking: %s, backups %s, Git Bash integration %s\n' \
    "$(dotfiles_tui_choice_label DOTFILES_LINK_MODE "$DOTFILES_LINK_MODE")" \
    "$(dotfiles_tui_item_value toggle DOTFILES_BACKUP_EXISTING)" \
    "$(dotfiles_tui_item_value toggle DOTFILES_INSTALL_BASH_HOOK)" > "$DOTFILES_TUI_TTY"
  printf '  Windows settings: %s\n' "$(dotfiles_tui_item_value toggle DOTFILES_APPLY_WINDOWS_SETTINGS)" > "$DOTFILES_TUI_TTY"
  printf '  Save target: %s\n\n' "$(dotfiles_tui_clip "${DOTFILES_TUI_REQUESTED_CONFIG:-windows-config.env}" 68)" > "$DOTFILES_TUI_TTY"

  if [ "$DOTFILES_TUI_REVIEW_SELECTED" -eq 0 ]; then
    printf '%s> [Save configuration]%s\n' "$DOTFILES_TUI_ACCENT" "$DOTFILES_TUI_RESET" > "$DOTFILES_TUI_TTY"
  else
    printf '  [Save configuration]\n' > "$DOTFILES_TUI_TTY"
  fi
  if [ "$DOTFILES_TUI_REVIEW_SELECTED" -eq 1 ]; then
    printf '%s> [Back to Windows settings]%s\n' "$DOTFILES_TUI_ACCENT" "$DOTFILES_TUI_RESET" > "$DOTFILES_TUI_TTY"
  else
    printf '  [Back to Windows settings]\n' > "$DOTFILES_TUI_TTY"
  fi
  if [ "$DOTFILES_TUI_REVIEW_SELECTED" -eq 2 ]; then
    printf '%s> [Cancel without saving]%s\n' "$DOTFILES_TUI_ACCENT" "$DOTFILES_TUI_RESET" > "$DOTFILES_TUI_TTY"
  else
    printf '  [Cancel without saving]\n' > "$DOTFILES_TUI_TTY"
  fi
  printf '\n%sUp/Down%s or %sTab%s move  %sEnter/Space%s select  %sEsc/q%s cancel\n' \
    "$DOTFILES_TUI_BOLD" "$DOTFILES_TUI_RESET" "$DOTFILES_TUI_BOLD" "$DOTFILES_TUI_RESET" \
    "$DOTFILES_TUI_BOLD" "$DOTFILES_TUI_RESET" "$DOTFILES_TUI_BOLD" "$DOTFILES_TUI_RESET" > "$DOTFILES_TUI_TTY"
}

dotfiles_tui_read_key() {
  local first second third fourth
  DOTFILES_TUI_KEY=''
  DOTFILES_TUI_CHAR=''
  IFS= read -r -s -n 1 first <&9 || return 1
  case "$first" in
    $'\033')
      if ! IFS= read -r -s -n 1 -t 0.05 second <&9; then
        DOTFILES_TUI_KEY=escape
        return 0
      fi
      if [ "$second" = '[' ]; then
        if ! IFS= read -r -s -n 1 -t 0.05 third <&9; then
          DOTFILES_TUI_KEY=escape
          return 0
        fi
        case "$third" in
          A) DOTFILES_TUI_KEY=up ;;
          B) DOTFILES_TUI_KEY=down ;;
          C) DOTFILES_TUI_KEY=right ;;
          D) DOTFILES_TUI_KEY=left ;;
          H) DOTFILES_TUI_KEY=home ;;
          F) DOTFILES_TUI_KEY=end ;;
          Z) DOTFILES_TUI_KEY=backtab ;;
          3)
            if IFS= read -r -s -n 1 -t 0.05 fourth <&9 && [ "$fourth" = '~' ]; then
              DOTFILES_TUI_KEY=delete
            else
              DOTFILES_TUI_KEY=escape
            fi
            ;;
          *) DOTFILES_TUI_KEY=escape ;;
        esac
      elif [ "$second" = 'O' ]; then
        if ! IFS= read -r -s -n 1 -t 0.05 third <&9; then
          DOTFILES_TUI_KEY=escape
          return 0
        fi
        case "$third" in
          H) DOTFILES_TUI_KEY=home ;;
          F) DOTFILES_TUI_KEY=end ;;
          *) DOTFILES_TUI_KEY=escape ;;
        esac
      else
        DOTFILES_TUI_KEY=escape
      fi
      ;;
    $'\r'|$'\n') DOTFILES_TUI_KEY=enter ;;
    $'\t') DOTFILES_TUI_KEY=tab ;;
    ' ') DOTFILES_TUI_KEY=space ;;
    $'\177'|$'\b') DOTFILES_TUI_KEY=backspace ;;
    $'\003') DOTFILES_TUI_KEY=cancel ;;
    $'\025') DOTFILES_TUI_KEY=clear_line ;;
    *)
      DOTFILES_TUI_KEY=char
      DOTFILES_TUI_CHAR=$first
      ;;
  esac
}

dotfiles_tui_edit_text() {
  local key=$1 label=$2 description=$3 value cursor left_length
  DOTFILES_TUI_EDIT_ACTION=cancel
  value=$(dotfiles_tui_get_text_value "$key")
  cursor=${#value}

  while :; do
    dotfiles_tui_clear_screen
    printf '%s%sEdit value%s\n' "$DOTFILES_TUI_BOLD" "$DOTFILES_TUI_ACCENT" "$DOTFILES_TUI_RESET" > "$DOTFILES_TUI_TTY"
    printf '%s\n\n' "$label" > "$DOTFILES_TUI_TTY"
    printf '%s\n' "$description" > "$DOTFILES_TUI_TTY"
    printf '\n  %s|%s\n' "${value:0:cursor}" "${value:cursor}" > "$DOTFILES_TUI_TTY"
    printf '\n%sLeft/Right%s move  %sBackspace%s delete  %sEnter/Tab%s accept  %sEsc%s cancel\n' \
      "$DOTFILES_TUI_BOLD" "$DOTFILES_TUI_RESET" "$DOTFILES_TUI_BOLD" "$DOTFILES_TUI_RESET" \
      "$DOTFILES_TUI_BOLD" "$DOTFILES_TUI_RESET" "$DOTFILES_TUI_BOLD" "$DOTFILES_TUI_RESET" > "$DOTFILES_TUI_TTY"

    dotfiles_tui_read_key || return 1
    case "$DOTFILES_TUI_KEY" in
      char)
        value="${value:0:cursor}${DOTFILES_TUI_CHAR}${value:cursor}"
        cursor=$((cursor + 1))
        ;;
      left)
        if [ "$cursor" -gt 0 ]; then cursor=$((cursor - 1)); fi
        ;;
      right)
        if [ "$cursor" -lt "${#value}" ]; then cursor=$((cursor + 1)); fi
        ;;
      home) cursor=0 ;;
      end) cursor=${#value} ;;
      backspace)
        if [ "$cursor" -gt 0 ]; then
          left_length=$((cursor - 1))
          value="${value:0:left_length}${value:cursor}"
          cursor=$left_length
        fi
        ;;
      delete)
        if [ "$cursor" -lt "${#value}" ]; then
          value="${value:0:cursor}${value:cursor+1}"
        fi
        ;;
      clear_line) value=''; cursor=0 ;;
      enter) dotfiles_tui_set_text_value "$key" "$value"; DOTFILES_TUI_EDIT_ACTION=enter; return 0 ;;
      tab) dotfiles_tui_set_text_value "$key" "$value"; DOTFILES_TUI_EDIT_ACTION=tab; return 0 ;;
      escape|cancel) DOTFILES_TUI_EDIT_ACTION=cancel; return 0 ;;
    esac
  done
}

dotfiles_tui_toggle_item() {
  local kind=$1 key=$2 index
  case "$kind" in
    toggle)
      if [ "${!key}" = 1 ]; then printf -v "$key" '%s' 0; else printf -v "$key" '%s' 1; fi
      ;;
    package)
      for index in "${!DOTFILES_TUI_PACKAGE_OPTIONS[@]}"; do
        if [ "${DOTFILES_TUI_PACKAGE_OPTIONS[$index]}" = "$key" ]; then
          if [ "${DOTFILES_TUI_PACKAGE_SELECTED[$index]}" = 1 ]; then
            DOTFILES_TUI_PACKAGE_SELECTED[$index]=0
          else
            DOTFILES_TUI_PACKAGE_SELECTED[$index]=1
          fi
          return 0
        fi
      done
      ;;
    bucket)
      if [ "$DOTFILES_TUI_BUCKET_EXTRAS" = 1 ]; then DOTFILES_TUI_BUCKET_EXTRAS=0; else DOTFILES_TUI_BUCKET_EXTRAS=1; fi
      ;;
    choice)
      if [ "${!key}" = junction ]; then printf -v "$key" '%s' symbolic; else printf -v "$key" '%s' junction; fi
      ;;
  esac
}

dotfiles_tui_adjust_item() {
  local kind=$1 key=$2 direction=$3 value
  case "$kind" in
    choice) dotfiles_tui_toggle_item "$kind" "$key" ;;
    number)
      value=${!key}
      if [ "$direction" = left ] && [ "$value" -gt 0 ]; then value=$((value - 1)); fi
      if [ "$direction" = right ]; then
        if [ "$key" = DOTFILES_KEYBOARD_DELAY ] && [ "$value" -lt 3 ]; then value=$((value + 1)); fi
        if [ "$key" = DOTFILES_KEYBOARD_SPEED ] && [ "$value" -lt 31 ]; then value=$((value + 1)); fi
      fi
      printf -v "$key" '%s' "$value"
      ;;
  esac
}

dotfiles_tui_move_selection() {
  local direction=$1 count=${#DOTFILES_TUI_ITEM_KINDS[@]}
  if [ "$direction" = next ]; then
    DOTFILES_TUI_SELECTED=$(( (DOTFILES_TUI_SELECTED + 1) % count ))
  else
    DOTFILES_TUI_SELECTED=$(( (DOTFILES_TUI_SELECTED - 1 + count) % count ))
  fi
}

dotfiles_tui_activate_current() {
  local kind=${DOTFILES_TUI_ITEM_KINDS[$DOTFILES_TUI_SELECTED]}
  local key=${DOTFILES_TUI_ITEM_KEYS[$DOTFILES_TUI_SELECTED]}
  DOTFILES_TUI_ACTION=''
  case "$kind" in
    action) DOTFILES_TUI_ACTION=$key ;;
    text)
      dotfiles_tui_edit_text "$key" "${DOTFILES_TUI_ITEM_LABELS[$DOTFILES_TUI_SELECTED]}" "${DOTFILES_TUI_ITEM_DESCRIPTIONS[$DOTFILES_TUI_SELECTED]}"
      if [ "$DOTFILES_TUI_EDIT_ACTION" = tab ]; then dotfiles_tui_move_selection next; fi
      ;;
    toggle|package|bucket|choice) dotfiles_tui_toggle_item "$kind" "$key" ;;
  esac
}

dotfiles_tui_run_pages() {
  DOTFILES_TUI_PAGE=0
  DOTFILES_TUI_SELECTED=0
  dotfiles_tui_load_items

  while [ "$DOTFILES_TUI_PAGE" -lt 5 ]; do
    DOTFILES_TUI_ACTION=''
    dotfiles_tui_render_page
    dotfiles_tui_read_key || return 1
    case "$DOTFILES_TUI_KEY" in
      up|backtab) dotfiles_tui_move_selection previous ;;
      down|tab) dotfiles_tui_move_selection next ;;
      left|right)
        dotfiles_tui_adjust_item "${DOTFILES_TUI_ITEM_KINDS[$DOTFILES_TUI_SELECTED]}" \
          "${DOTFILES_TUI_ITEM_KEYS[$DOTFILES_TUI_SELECTED]}" "$DOTFILES_TUI_KEY"
        ;;
      space) dotfiles_tui_toggle_item "${DOTFILES_TUI_ITEM_KINDS[$DOTFILES_TUI_SELECTED]}" "${DOTFILES_TUI_ITEM_KEYS[$DOTFILES_TUI_SELECTED]}" ;;
      enter) dotfiles_tui_activate_current ;;
      escape|cancel) return 1 ;;
      char)
        case "$DOTFILES_TUI_CHAR" in
          q|Q) return 1 ;;
        esac
        ;;
    esac

    case "$DOTFILES_TUI_ACTION" in
      next)
        DOTFILES_TUI_PAGE=$((DOTFILES_TUI_PAGE + 1))
        DOTFILES_TUI_SELECTED=0
        dotfiles_tui_load_items
        ;;
      back)
        DOTFILES_TUI_PAGE=$((DOTFILES_TUI_PAGE - 1))
        DOTFILES_TUI_SELECTED=0
        dotfiles_tui_load_items
        ;;
    esac
  done
}

dotfiles_tui_run_review() {
  DOTFILES_TUI_REVIEW_SELECTED=0
  while :; do
    dotfiles_tui_render_summary
    dotfiles_tui_read_key || return 1
    case "$DOTFILES_TUI_KEY" in
      up|backtab) DOTFILES_TUI_REVIEW_SELECTED=$(( (DOTFILES_TUI_REVIEW_SELECTED - 1 + 3) % 3 )) ;;
      down|tab) DOTFILES_TUI_REVIEW_SELECTED=$(( (DOTFILES_TUI_REVIEW_SELECTED + 1) % 3 )) ;;
      enter|space)
        case "$DOTFILES_TUI_REVIEW_SELECTED" in
          0) return 0 ;;
          1) return 2 ;;
          2) return 1 ;;
        esac
        ;;
      escape|cancel) return 1 ;;
      char)
        case "$DOTFILES_TUI_CHAR" in
          q|Q) return 1 ;;
        esac
        ;;
    esac
  done
}

dotfiles_tui_write_config() {
  local requested_config=$1 temporary
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
}

dotfiles_tui_start() {
  if [ ! -t 0 ] || [ ! -t 1 ] || [ ! -r /dev/tty ]; then
    echo 'Cannot open the interactive configuration UI without a terminal.' >&2
    echo 'Copy windows-config.example.env to windows-config.env or rerun from Git Bash.' >&2
    return 1
  fi
  DOTFILES_TUI_TTY=/dev/tty
  DOTFILES_TUI_INPUT=$DOTFILES_TUI_TTY
  if ! DOTFILES_TUI_STTY_STATE="$(stty -g < "$DOTFILES_TUI_TTY")"; then
    echo 'Cannot read terminal settings for the configuration UI.' >&2
    return 1
  fi
  if ! stty -icanon -echo min 1 time 0 < "$DOTFILES_TUI_TTY"; then
    echo 'Cannot prepare the terminal for the configuration UI.' >&2
    return 1
  fi
  if ! exec 9< "$DOTFILES_TUI_INPUT"; then
    stty "$DOTFILES_TUI_STTY_STATE" < "$DOTFILES_TUI_TTY" 2>/dev/null || true
    echo 'Cannot open the terminal input for the configuration UI.' >&2
    return 1
  fi
  DOTFILES_TUI_ACTIVE=1
  if [ "${TERM:-}" = dumb ]; then
    DOTFILES_TUI_BOLD=''
    DOTFILES_TUI_ACCENT=''
    DOTFILES_TUI_RESET=''
  else
    DOTFILES_TUI_BOLD=$'\033[1m'
    DOTFILES_TUI_ACCENT=$'\033[36m'
    DOTFILES_TUI_RESET=$'\033[0m'
  fi
  trap 'dotfiles_tui_cleanup' EXIT
  trap 'dotfiles_tui_abort' INT TERM
  printf '\033[?25l' > "$DOTFILES_TUI_TTY"
}

dotfiles_tui_cleanup() {
  if [ "${DOTFILES_TUI_ACTIVE:-0}" = 1 ]; then
    stty "${DOTFILES_TUI_STTY_STATE:-sane}" < "${DOTFILES_TUI_TTY:-/dev/tty}" 2>/dev/null || stty sane < "${DOTFILES_TUI_TTY:-/dev/tty}" 2>/dev/null || true
    exec 9<&- 2>/dev/null || true
    printf '\033[?25h\033[0m\n' > "${DOTFILES_TUI_TTY:-/dev/tty}" 2>/dev/null || true
    DOTFILES_TUI_ACTIVE=0
  fi
}

dotfiles_tui_abort() {
  dotfiles_tui_cleanup
  exit 130
}

dotfiles_tui_end() {
  dotfiles_tui_cleanup
  trap - EXIT INT TERM
}

dotfiles_create_config_interactively() {
  local requested_config=$1 review_result

  dotfiles_apply_config_defaults
  dotfiles_tui_initialize_collections
  DOTFILES_TUI_REQUESTED_CONFIG=$requested_config
  dotfiles_tui_start || return 1

  if ! dotfiles_tui_run_pages; then
    dotfiles_tui_end
    echo 'Configuration cancelled. No changes were saved.' >&2
    return 1
  fi
  dotfiles_tui_commit_collections

  if dotfiles_tui_run_review; then
    review_result=0
  else
    review_result=$?
  fi
  if [ "$review_result" = 2 ]; then
    dotfiles_tui_end
    dotfiles_create_config_interactively "$requested_config"
    return $?
  fi
  if [ "$review_result" != 0 ]; then
    dotfiles_tui_end
    echo 'Configuration cancelled. No changes were saved.' >&2
    return 1
  fi

  dotfiles_tui_end
  dotfiles_tui_commit_collections
  if ! dotfiles_validate_config; then
    echo 'Configuration could not be saved because one or more values are invalid.' >&2
    return 1
  fi
  dotfiles_tui_write_config "$requested_config"
  echo "==> Saved $requested_config"
}
