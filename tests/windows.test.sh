#!/usr/bin/env bash
# Static and disposable end-to-end checks for the native Windows setup.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-windows.XXXXXX")"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

pass() {
  printf 'ok - %s\n' "$1"
}

case "${OSTYPE:-}" in
  cygwin*|msys*|mingw*) ;;
  *) fail "Windows tests must run from Git Bash" ;;
esac

command -v cygpath >/dev/null 2>&1 || fail "cygpath is unavailable"
command -v powershell.exe >/dev/null 2>&1 || fail "powershell.exe is unavailable"

test_shell_syntax() {
  bash -n "$ROOT/bootstrap.sh" "$ROOT/rebuild.sh" "$ROOT/windows-common.sh" \
    "$ROOT/windows-config-tui.sh" "$ROOT/uninstall.sh" \
    "$ROOT/home/.bashrc" "$ROOT/tests/lib.sh" "$ROOT/tests/pi-calm.test.sh" \
    "$ROOT/tests/windows.test.sh"
  pass "Bash scripts parse"
}

test_power_shell_syntax() {
  local script tokens errors script_win
  for script in "$ROOT"/*.ps1 "$ROOT/tests/windows.test.ps1" "$ROOT"/home/.config/powershell/*.ps1; do
    tokens="$(mktemp)"
    errors="$(mktemp)"
    script_win="$(cygpath -w "$script")"
    MSYS_NO_PATHCONV=1 DOTFILES_TEST_PS_SCRIPT="$script_win" powershell.exe \
      -NoLogo -NoProfile -NonInteractive \
      -Command '$tokens = $null; $errors = $null; [System.Management.Automation.Language.Parser]::ParseFile($env:DOTFILES_TEST_PS_SCRIPT, [ref]$tokens, [ref]$errors) | Out-Null; if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Error $_.Message }; exit 1 }' \
      >"$tokens" 2>"$errors" \
      || fail "PowerShell script does not parse: $script"
    [ ! -s "$errors" ] || fail "PowerShell parser produced errors for $script"
    rm -f "$tokens" "$errors"
  done
  pass "PowerShell scripts parse"
}

test_native_power_shell_suite() {
  local output
  output="$TMP_ROOT/native-powershell.out"
  MSYS_NO_PATHCONV=1 powershell.exe -NoLogo -NoProfile -NonInteractive \
    -ExecutionPolicy Bypass -File "$(cygpath -w "$ROOT/tests/windows.test.ps1")" \
    >"$output" 2>&1 \
    || fail "native PowerShell test suite failed: $(cat "$output")"
  grep -Fq 'ok - PowerShell scripts parse under Windows PowerShell' "$output" \
    || fail "native PowerShell test suite did not run its parser checks"
  pass "Native PowerShell setup suite passes"
}

test_json_and_status_line() {
  node --check "$ROOT/home/.claude/status-line.js"
  node --check "$ROOT/home/.pi/agent/extensions/terminal-status-title.js"
  local output
  output=$(printf '%s\n' '{"model":{"display_name":"Test Model"},"context_window":{"used_percentage":42.4}}' | node "$ROOT/home/.claude/status-line.js")
  [ "$output" = 'Test Model | ctx: 42% used' ] || fail "Claude status line output changed: $output"
  pass "Node configuration helpers parse and render"
}

run_links() {
  local root_win user_win local_win appdata_win xdg_win
  root_win="$(cygpath -w "$ROOT")"
  user_win="$(cygpath -w "$TMP_ROOT/user")"
  local_win="$(cygpath -w "$TMP_ROOT/local")"
  appdata_win="$(cygpath -w "$TMP_ROOT/appdata")"
  xdg_win="$(cygpath -w "$TMP_ROOT/xdg")"

  MSYS_NO_PATHCONV=1 powershell.exe -NoLogo -NoProfile -NonInteractive \
    -ExecutionPolicy Bypass -File "$(cygpath -w "$ROOT/windows-links.ps1")" \
    -RepoRoot "$root_win" \
    -UserHome "$user_win" \
    -LocalAppData "$local_win" \
    -AppData "$appdata_win" \
    -XdgConfigHome "$xdg_win" \
    -DotfilesLinkPath "$(cygpath -w "$TMP_ROOT/user/.dotfiles")" \
    -NvimConfigDir "$(cygpath -w "$TMP_ROOT/local/nvim")" \
    -DocumentsDir "$(cygpath -w "$TMP_ROOT/documents")" \
    -HerdrConfigDir "$(cygpath -w "$TMP_ROOT/appdata/herdr")" \
    -ClaudeConfigDir "$(cygpath -w "$TMP_ROOT/user/.claude")" \
    -CodexConfigDir "$(cygpath -w "$TMP_ROOT/user/.codex")" \
    -OpencodeConfigDir "$(cygpath -w "$TMP_ROOT/xdg/opencode")" \
    -PiAgentDir "$(cygpath -w "$TMP_ROOT/user/.pi/agent")" \
    -LinkMode junction -BackupExisting 1
}

test_links_and_backups() {
  mkdir -p "$TMP_ROOT/user/.claude"
  printf 'pre-existing settings\n' >"$TMP_ROOT/user/.claude/settings.json"

  run_links >/dev/null
  [ -f "$TMP_ROOT/user/.claude/settings.json" ] || fail "settings link was not created"
  [ -n "$(find "$TMP_ROOT/user/.claude" -maxdepth 1 -name 'settings.json.dotfiles-backup-*' -print -quit)" ] \
    || fail "pre-existing settings were not backed up"

  local backup_count
  backup_count=$(find "$TMP_ROOT/user/.claude" -maxdepth 1 -name 'settings.json.dotfiles-backup-*' -print | wc -l)
  run_links >/dev/null
  [ "$(find "$TMP_ROOT/user/.claude" -maxdepth 1 -name 'settings.json.dotfiles-backup-*' -print | wc -l)" -eq "$backup_count" ] \
    || fail "reapplying links created an unnecessary backup"
  pass "Windows links are disposable, repeatable, and preserve existing files"
}

test_bootstrap_check() {
  local config_existed=0
  [ -e "$ROOT/windows-config.env" ] && config_existed=1
  bash "$ROOT/bootstrap.sh" --check >/dev/null \
    || fail "bootstrap --check rejected the example configuration"
  [ "$config_existed" -eq 1 ] || [ ! -e "$ROOT/windows-config.env" ] \
    || fail "--check created a local configuration file"
  bash "$ROOT/rebuild.sh" --check >/dev/null \
    || fail "rebuild --check rejected the example configuration"
  [ "$config_existed" -eq 1 ] || [ ! -e "$ROOT/windows-config.env" ] \
    || fail "rebuild --check created a local configuration file"
  pass "Bootstrap and rebuild validate the example configuration"
}

test_uninstall_check() {
  local config_existed=0
  [ -e "$ROOT/windows-config.env" ] && config_existed=1
  bash "$ROOT/uninstall.sh" --check >/dev/null \
    || fail "uninstall --check rejected the example configuration"
  [ "$config_existed" -eq 1 ] || [ ! -e "$ROOT/windows-config.env" ] \
    || fail "uninstall --check created a local configuration file"
  pass "Uninstall preflight validates configuration without creating local state"
}

test_config_wizard_coverage() {
  local variable generated_config rendered_ui
  generated_config="$TMP_ROOT/generated-windows-config.env"
  rendered_ui="$TMP_ROOT/rendered-config-ui.txt"

  (
    export DOTFILES_ROOT="$ROOT"
    export DOTFILES_CONFIG_FILE="$ROOT/windows-config.example.env"
    export DOTFILES_SKIP_CONFIG_CREATE=1
    export DOTFILES_TEST_CONFIG="$generated_config"
    export DOTFILES_TEST_RENDERED="$rendered_ui"
    # shellcheck source=../windows-common.sh
    . "$ROOT/windows-common.sh"
    dotfiles_load_config
    dotfiles_tui_initialize_collections
    DOTFILES_TUI_PACKAGE_SELECTED[0]=0
    DOTFILES_TUI_CUSTOM_PACKAGES='bat  delta'
    DOTFILES_TUI_BUCKET_EXTRAS=0
    DOTFILES_TUI_CUSTOM_BUCKETS='main=https://example.invalid/bucket'
    dotfiles_tui_commit_collections
    dotfiles_tui_write_config "$DOTFILES_TEST_CONFIG"
    DOTFILES_TUI_TTY=/dev/stdout
    DOTFILES_TUI_BOLD=''
    DOTFILES_TUI_ACCENT=''
    DOTFILES_TUI_RESET=''
    DOTFILES_TUI_PAGE=0
    DOTFILES_TUI_SELECTED=0
    dotfiles_tui_load_items
    rendered_ui_output="$(dotfiles_tui_render_page)"
    printf '%s' "$rendered_ui_output" > "$DOTFILES_TEST_RENDERED"
    DOTFILES_TUI_PAGE=3
    dotfiles_tui_load_items
    [ "${DOTFILES_TUI_ITEM_KEYS[0]}" = DOTFILES_DEFAULT_SHELL ]
    dotfiles_tui_toggle_item choice DOTFILES_DEFAULT_SHELL
    [ "$DOTFILES_DEFAULT_SHELL" = powershell ]
    dotfiles_tui_toggle_item choice DOTFILES_DEFAULT_SHELL
    [ "$DOTFILES_DEFAULT_SHELL" = zsh ]
    dotfiles_tui_toggle_item choice DOTFILES_OH_MY_POSH_THEME
    [ "$DOTFILES_OH_MY_POSH_THEME" = rose-pine-moon ]
  ) || fail "configuration TUI serialization failed"

  [ -f "$generated_config" ] || fail "configuration TUI did not write a config file"
  grep -Fq 'Install Scoop' "$rendered_ui" || fail "configuration TUI did not render a human-readable label"
  grep -Fq 'Windows package manager' "$rendered_ui" || fail "configuration TUI did not render a clear description"
  grep -Fq 'DOTFILES_INSTALL_SCOOP' "$rendered_ui" && fail "configuration TUI exposed a raw environment variable name"
  while IFS= read -r variable; do
    grep -Eq "^${variable}=" "$generated_config" \
      || fail "configuration TUI did not save $variable"
  done < <(sed -nE 's/^(DOTFILES_[A-Z0-9_]+)=.*/\1/p' "$ROOT/windows-config.example.env")
  (
    # shellcheck disable=SC1090
    . "$generated_config"
    [ "$DOTFILES_INSTALL_ZSH" = 1 ]
    [ "$DOTFILES_DEFAULT_SHELL" = zsh ]
    [ "$DOTFILES_OH_MY_POSH_THEME" = tokyo-night-storm ]
    [ "$DOTFILES_SCOOP_PACKAGES" = 'neovim starship ripgrep fd fzf jq lazygit nodejs Hack-NF bat delta' ]
    [ "$DOTFILES_SCOOP_BUCKETS" = 'main=https://example.invalid/bucket' ]
  ) || fail "package and bucket selections were not serialized correctly"
  for label in \
    'Install Scoop' 'Install MSYS2 zsh' 'Additional Scoop packages' 'Windows home directory' \
    'Oh My Posh' 'Prompt theme' 'Default shell' 'Link repository paths using' 'Apply Windows settings' 'Review your choices'; do
    grep -Fq "$label" "$ROOT/windows-config-tui.sh" \
      || fail "configuration TUI is missing the human-readable label: $label"
  done
  grep -Fq 'stty -icanon -echo' "$ROOT/windows-config-tui.sh" \
    || fail "configuration TUI does not configure raw keyboard input"
  grep -Fq 'DOTFILES_OH_MY_POSH_THEME' "$ROOT/windows-config-tui.sh" \
    || fail "configuration TUI does not expose the prompt theme setting"
  grep -Fq 'DOTFILES_DEFAULT_SHELL' "$ROOT/windows-config-tui.sh" \
    || fail "configuration TUI does not expose the default shell setting"
  grep -Fq -- '--configure' "$ROOT/bootstrap.sh" || fail "bootstrap lacks --configure"
  grep -Fq -- '--configure' "$ROOT/rebuild.sh" || fail "rebuild lacks --configure"
  grep -Fq -- '--configure' "$ROOT/uninstall.sh" || fail "uninstall lacks --configure"
  pass "Configuration TUI explains choices and saves every documented variable"
}

test_config_tui_keyboard_flow() {
  local input_file output_file sequence down enter space tab index
  input_file="$TMP_ROOT/tui-input"
  output_file="$TMP_ROOT/tui-output"
  sequence=''
  down=$'\033[B'
  enter=$'\r'
  space=' '
  tab=$'\t'

  sequence="${sequence}${space}${space}${tab}${space}"
  for index in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16; do
    sequence="${sequence}${down}"
  done
  sequence="${sequence}${enter}"
  sequence="${sequence}${tab}${enter}${tab}${space}"
  for index in 1 2; do sequence="${sequence}${down}"; done
  sequence="${sequence}${enter}"
  for index in 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do sequence="${sequence}${down}"; done
  sequence="${sequence}${enter}"
  for index in 1 2 3 4 5 6; do sequence="${sequence}${down}"; done
  sequence="${sequence}${enter}"
  for index in 1 2 3 4 5 6 7 8 9 10 11; do sequence="${sequence}${down}"; done
  sequence="${sequence}${enter}${enter}"
  printf '%s' "$sequence" >"$input_file"

  (
    export DOTFILES_ROOT="$ROOT"
    export DOTFILES_CONFIG_FILE="$ROOT/windows-config.example.env"
    export DOTFILES_SKIP_CONFIG_CREATE=1
    # shellcheck source=../windows-common.sh
    . "$ROOT/windows-common.sh"
    dotfiles_load_config
    dotfiles_tui_initialize_collections
    DOTFILES_TUI_TTY="$output_file"
    DOTFILES_TUI_INPUT="$input_file"
    DOTFILES_TUI_BOLD=''
    DOTFILES_TUI_ACCENT=''
    DOTFILES_TUI_RESET=''
    exec 9<"$DOTFILES_TUI_INPUT"
    dotfiles_tui_run_pages
    dotfiles_tui_commit_collections
    dotfiles_tui_run_review
    [ "$DOTFILES_SCOOP_PACKAGES" = 'git neovim oh-my-posh starship ripgrep fd fzf jq lazygit nodejs Hack-NF' ]
    [ "$DOTFILES_UPDATE_SCOOP" = 1 ]
    [ "$DOTFILES_INSTALL_AGENT_CLIS" = 1 ]
    [ "$DOTFILES_INSTALL_OH_MY_POSH" = 1 ]
    exec 9<&-
  ) || fail "configuration TUI did not accept arrow and Enter navigation"
  pass "Configuration TUI accepts arrows, Space, Tab, and Enter navigation"
}

test_noninteractive_config_refusal() {
  local config_file="$TMP_ROOT/noninteractive-windows-config.env"
  if DOTFILES_CONFIG_FILE="$config_file" bash "$ROOT/bootstrap.sh" </dev/null >"$TMP_ROOT/noninteractive.out" 2>&1; then
    fail "bootstrap unexpectedly configured without a terminal"
  fi
  [ ! -e "$config_file" ] || fail "noninteractive bootstrap created a configuration file"
  grep -Fq 'interactive configuration UI' "$TMP_ROOT/noninteractive.out" \
    || fail "noninteractive bootstrap did not explain how to configure"
  pass "Noninteractive setup refuses to create configuration state"
}

test_script_arguments() {
  if bash "$ROOT/bootstrap.sh" --unsupported >/dev/null 2>&1; then
    fail "bootstrap accepted an unsupported argument"
  fi
  if bash "$ROOT/rebuild.sh" --unsupported >/dev/null 2>&1; then
    fail "rebuild accepted an unsupported argument"
  fi
  if bash "$ROOT/uninstall.sh" --unsupported >/dev/null 2>&1; then
    fail "uninstall accepted an unsupported argument"
  fi
  pass "Bootstrap, rebuild, and uninstall reject unsupported arguments"
}

test_bash_hook() {
  local hook_home hook_link marker_count expected_pi_dir actual_pi_dir
  hook_home="$TMP_ROOT/bash-home"
  hook_link="$TMP_ROOT/custom-dotfiles-link"
  mkdir -p "$hook_home"
  mkdir -p "$hook_link/home"
  cp "$ROOT/home/.bashrc" "$hook_link/home/.bashrc"
  HOME="$hook_home" DOTFILES_WINDOWS_HOME="$TMP_ROOT/windows-home" \
    DOTFILES_CONFIG_FILE="$ROOT/windows-config.example.env" \
    DOTFILES_DOTFILES_LINK="$hook_link" DOTFILES_TEST_LINK="$hook_link" DOTFILES_SKIP_CONFIG_CREATE=1 \
    DOTFILES_ROOT="$ROOT" bash -c '
    . "$DOTFILES_ROOT/windows-common.sh"
      dotfiles_load_config
      DOTFILES_DOTFILES_LINK="$DOTFILES_TEST_LINK"
      dotfiles_setup_paths
      dotfiles_install_bash_hook
      dotfiles_install_bash_hook
    '
  marker_count=$(grep -c '^# >>> dotfiles managed Git Bash hook >>>$' "$hook_home/.bashrc")
  [ "$marker_count" -eq 1 ] || fail "Git Bash hook was duplicated"
  grep -Fq "DOTFILES_ROOT=\"$hook_link\"" "$hook_home/.bashrc" \
    || fail "Git Bash hook did not honor the configured dotfiles link"
  grep -Fq 'PI_CODING_AGENT_DIR=' "$hook_home/.bashrc" \
    || fail "Git Bash hook did not export the configured Pi directory"
  expected_pi_dir="$(cygpath -w "$TMP_ROOT/windows-home/.pi/agent")"
  actual_pi_dir="$(HOME="$hook_home" bash --noprofile --norc -c '. "$HOME/.bashrc"; printf "%s" "$PI_CODING_AGENT_DIR"')"
  [ "$actual_pi_dir" = "$expected_pi_dir" ] \
    || fail "Git Bash hook exported the wrong Pi directory: $actual_pi_dir"
  pass "Git Bash hooks are idempotent and honor configured paths"
}

test_msys2_zsh_setup() {
  local scoop_root msys2_root startup marker_count found_root
  scoop_root="$TMP_ROOT/msys2-scoop"
  msys2_root="$scoop_root/apps/msys2/current"
  mkdir -p "$msys2_root/usr/bin"
  touch "$msys2_root/msys2_shell.cmd" "$msys2_root/usr/bin/bash.exe" \
    "$msys2_root/usr/bin/pacman.exe" "$msys2_root/usr/bin/zsh.exe"

  (
    export DOTFILES_ROOT="$ROOT"
    export DOTFILES_WINDOWS_HOME="$TMP_ROOT/windows-home"
    export DOTFILES_DOTFILES_LINK="$ROOT"
    export DOTFILES_PI_AGENT_DIR="$TMP_ROOT/windows-home/.pi/agent"
    export DOTFILES_EDITOR=nvim
    export DOTFILES_VISUAL=nvim
    export DOTFILES_INSTALL_ZSH=1
    export USERNAME=dotfiles-test-user
    # shellcheck source=../windows-common.sh
    . "$ROOT/windows-common.sh"
    found_root="$(dotfiles_find_msys2_root "$scoop_root")"
    [ "$found_root" = "$msys2_root" ] || exit 1
    dotfiles_install_zsh_startup "$found_root"
    dotfiles_install_zsh_startup "$found_root"
    startup="$(dotfiles_msys2_startup_path "$found_root")"
    marker_count=$(grep -c '^# >>> dotfiles managed MSYS2 zsh startup >>>$' "$startup")
    [ "$marker_count" -eq 1 ] || exit 1
    grep -Fq '. "$DOTFILES_ROOT/home/.zshrc"' "$startup" || exit 1
    dotfiles_zsh_remove_managed_block "$startup"
    ! grep -Fq 'dotfiles managed MSYS2 zsh startup' "$startup"
  ) || fail "MSYS2 discovery and zsh startup helpers failed"

  grep -Fq 'eval "$(starship init zsh)"' "$ROOT/home/.zshrc" \
    || fail "zsh startup does not fall back to Starship"
  grep -Fq 'oh-my-posh init zsh' "$ROOT/home/.zshrc" \
    || fail "zsh startup does not initialize Oh My Posh"
  grep -Fq 'DOTFILES_INSTALL_OH_MY_POSH' "$ROOT/home/.zshrc" \
    || fail "zsh startup does not honor the Oh My Posh opt-in"
  grep -Fq -- '-use-full-path' "$ROOT/home/.config/powershell/Microsoft.PowerShell_profile.ps1" \
    || fail "PowerShell profile does not launch zsh with the full Windows PATH"
  grep -Fq 'function zsh' "$ROOT/home/.config/powershell/Microsoft.PowerShell_profile.ps1" \
    || fail "PowerShell profile does not expose an on-demand zsh entry point"
  grep -Fq 'DOTFILES_DEFAULT_SHELL' "$ROOT/home/.config/powershell/Microsoft.PowerShell_profile.ps1" \
    || fail "PowerShell profile does not honor the default shell choice"
  [ -f "$ROOT/home/.config/powershell/Microsoft.PowerShell_profile.ps1" ] \
    || fail "shared PowerShell profile is missing"
  [ -f "$ROOT/home/.config/oh-my-posh/tokyo-night-storm.omp.json" ] \
    || fail "Tokyo Night Oh My Posh theme is missing"
  [ -f "$ROOT/home/.config/oh-my-posh/rose-pine-moon.omp.json" ] \
    || fail "Rose Pine Moon Oh My Posh theme is missing"
  grep -Fq 'zsh-autosuggestions' "$ROOT/home/.zshrc" \
    || fail "zsh startup does not load zsh-autosuggestions"
  grep -Fq 'zsh-syntax-highlighting' "$ROOT/home/.zshrc" \
    || fail "zsh startup does not load zsh-syntax-highlighting"
  grep -Fq 'fzf --zsh' "$ROOT/home/.zshrc" \
    || fail "zsh startup does not enable fzf key bindings"
  grep -Fq 'zsh-autosuggestions zsh-syntax-highlighting' "$ROOT/windows-common.sh" \
    || fail "MSYS2 pacman does not install the zsh autocomplete plugins"
  grep -Fq 'Set-DotfilesPSReadLineAutocomplete' "$ROOT/home/.config/powershell/Microsoft.PowerShell_profile.ps1" \
    || fail "PowerShell profile does not set up PSReadLine autocomplete"
  grep -Fq 'InlinePrediction' "$ROOT/home/.config/powershell/Microsoft.PowerShell_profile.ps1" \
    || fail "PowerShell profile does not theme inline predictions"
  grep -Fq '"type": "node"' "$ROOT/home/.config/oh-my-posh/tokyo-night-storm.omp.json" \
    || fail "Tokyo Night Oh My Posh theme lacks the node segment"
  grep -Fq '"type": "execution_time"' "$ROOT/home/.config/oh-my-posh/rose-pine-moon.omp.json" \
    || fail "Rose Pine Moon Oh My Posh theme lacks the execution time segment"
  pass "MSYS2 discovery, zsh defaults, and PowerShell prompt configuration are validated"
}

test_settings_noop() {
  MSYS_NO_PATHCONV=1 powershell.exe -NoLogo -NoProfile -NonInteractive \
    -ExecutionPolicy Bypass -File "$(cygpath -w "$ROOT/windows-settings.ps1")" \
    -DarkMode 0 -ShowFileExtensions 0 -ShowHiddenFiles 0 -HideDesktopIcons 0 \
    -TaskbarAutoHide 0 -KeyboardRepeat 0 -RestartExplorer 0 >/dev/null \
    || fail "disabled Windows settings were not a no-op"
  pass "Disabled Windows settings make no system changes"
}

test_shell_syntax
test_power_shell_syntax
test_native_power_shell_suite
test_json_and_status_line
test_links_and_backups
test_bootstrap_check
test_config_wizard_coverage
test_config_tui_keyboard_flow
test_noninteractive_config_refusal
test_script_arguments
test_bash_hook
test_msys2_zsh_setup
test_settings_noop
test_uninstall_check
