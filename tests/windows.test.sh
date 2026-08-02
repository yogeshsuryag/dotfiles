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
  msys*|mingw*) ;;
  *) fail "Windows tests must run from Git Bash" ;;
esac

command -v cygpath >/dev/null 2>&1 || fail "cygpath is unavailable"
command -v powershell.exe >/dev/null 2>&1 || fail "powershell.exe is unavailable"

test_shell_syntax() {
  bash -n "$ROOT/bootstrap.sh" "$ROOT/rebuild.sh" "$ROOT/windows-common.sh" \
    "$ROOT/uninstall.sh" \
    "$ROOT/home/.bashrc" "$ROOT/tests/lib.sh" "$ROOT/tests/pi-calm.test.sh" \
    "$ROOT/tests/windows.test.sh"
  pass "Bash scripts parse"
}

test_power_shell_syntax() {
  local script tokens errors script_win
  for script in "$ROOT/windows-links.ps1" "$ROOT/windows-uninstall.ps1" "$ROOT/windows-settings.ps1"; do
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
  pass "PowerShell helpers parse"
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
    -WeztermConfigDir "$(cygpath -w "$TMP_ROOT/xdg/wezterm")" \
    -WeztermConfigFile "$(cygpath -w "$TMP_ROOT/user/.wezterm.lua")" \
    -HerdrConfigDir "$(cygpath -w "$TMP_ROOT/appdata/herdr")" \
    -ClaudeConfigDir "$(cygpath -w "$TMP_ROOT/user/.claude")" \
    -CodexConfigDir "$(cygpath -w "$TMP_ROOT/user/.codex")" \
    -OpencodeConfigDir "$(cygpath -w "$TMP_ROOT/xdg/opencode")" \
    -PiAgentDir "$(cygpath -w "$TMP_ROOT/user/.pi/agent")" \
    -LinkMode junction -BackupExisting 1
}

symbolic_links_available() {
  local probe_dir probe_source probe_target
  probe_dir="$TMP_ROOT/symbolic-link-probe"
  probe_source="$probe_dir/source.txt"
  probe_target="$probe_dir/target.txt"
  mkdir -p "$probe_dir"
  printf 'probe\n' >"$probe_source"
  if DOTFILES_LINK_PROBE_TARGET="$(cygpath -w "$probe_target")" \
    DOTFILES_LINK_PROBE_SOURCE="$(cygpath -w "$probe_source")" \
    MSYS_NO_PATHCONV=1 powershell.exe -NoLogo -NoProfile -NonInteractive \
      -Command '$ErrorActionPreference = "Stop"; New-Item -ItemType SymbolicLink -Path $env:DOTFILES_LINK_PROBE_TARGET -Target $env:DOTFILES_LINK_PROBE_SOURCE | Out-Null' \
      >/dev/null 2>&1; then
    rm -f "$probe_target"
    return 0
  fi
  return 1
}

test_links_and_backups() {
  mkdir -p "$TMP_ROOT/user/.claude"
  printf 'pre-existing settings\n' >"$TMP_ROOT/user/.claude/settings.json"

  if ! symbolic_links_available; then
    echo "skip: Windows symbolic-link privilege is unavailable; enable Developer Mode or run Git Bash elevated for link E2E"
    return 0
  fi

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
  local variable
  while IFS= read -r variable; do
    grep -Fq "dotfiles_prompt_value $variable " "$ROOT/windows-common.sh" \
      || fail "config wizard does not prompt for $variable"
    grep -Fq "dotfiles_write_config_value $variable" "$ROOT/windows-common.sh" \
      || fail "config wizard does not save $variable"
  done < <(sed -nE 's/^(DOTFILES_[A-Z0-9_]+)=.*/\1/p' "$ROOT/windows-config.example.env")
  grep -Fq -- '--configure' "$ROOT/bootstrap.sh" || fail "bootstrap lacks --configure"
  grep -Fq -- '--configure' "$ROOT/rebuild.sh" || fail "rebuild lacks --configure"
  grep -Fq -- '--configure' "$ROOT/uninstall.sh" || fail "uninstall lacks --configure"
  pass "Config wizard prompts for and saves every documented variable"
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
test_json_and_status_line
test_links_and_backups
test_bootstrap_check
test_config_wizard_coverage
test_script_arguments
test_bash_hook
test_settings_noop
test_uninstall_check
