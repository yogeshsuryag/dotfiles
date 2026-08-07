#!/usr/bin/env bash
# End-to-end checks for the Windows setup. The setup engine is native
# PowerShell; this suite runs the full PowerShell setup suite and then checks
# that the managed Git Bash hook really works when sourced.
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
  bash -n "$ROOT/home/.bashrc" "$ROOT/tests/lib.sh" "$ROOT/tests/pi-calm.test.sh" \
    "$ROOT/tests/windows.test.sh"
  pass "Bash scripts parse"
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

test_bash_hook() {
  local hook_home hook_link hook_script marker_count expected_pi_dir actual_pi_dir
  hook_home="$TMP_ROOT/bash-home"
  hook_link="$TMP_ROOT/custom-dotfiles-link"
  mkdir -p "$hook_home"
  mkdir -p "$hook_link/home"
  cp "$ROOT/home/.bashrc" "$hook_link/home/.bashrc"

  hook_script="$TMP_ROOT/install-hook.ps1"
  cat > "$hook_script" <<'PS'
$ErrorActionPreference = 'Stop'
$root = $env:DOTFILES_TEST_ROOT
. (Join-Path $root 'scripts/windows-common.ps1')
$config = @{}
Initialize-DotfilesConfigDefaults $config | Out-Null
$config.DOTFILES_WINDOWS_HOME = $env:DOTFILES_TEST_HOOK_HOME
$config.DOTFILES_DOTFILES_LINK = $env:DOTFILES_TEST_HOOK_LINK
$config.DOTFILES_PI_AGENT_DIR = Join-Path $config.DOTFILES_WINDOWS_HOME '.pi/agent'
Install-DotfilesBashHook $root $config
Install-DotfilesBashHook $root $config
PS
  MSYS_NO_PATHCONV=1 \
    DOTFILES_TEST_ROOT="$(cygpath -w "$ROOT")" \
    DOTFILES_TEST_HOOK_HOME="$(cygpath -w "$hook_home")" \
    DOTFILES_TEST_HOOK_LINK="$(cygpath -w "$hook_link")" \
    powershell.exe -NoLogo -NoProfile -NonInteractive \
    -ExecutionPolicy Bypass -File "$(cygpath -w "$hook_script")"

  marker_count=$(grep -c '^# >>> dotfiles managed Git Bash hook >>>$' "$hook_home/.bashrc")
  [ "$marker_count" -eq 1 ] || fail "Git Bash hook was duplicated"
  local windows_link drive rest expected_root
  # Mirror ConvertTo-GitBashPath in scripts/windows-common.ps1: lowercase drive
  # letter, backslashes to slashes. cygpath -u would rewrite through the /tmp
  # mount, which does not match the engine's pure string conversion.
  windows_link="$(cygpath -w "$hook_link")"
  drive="${windows_link%%:*}"
  rest="${windows_link#*:}"
  rest="${rest#\\}"
  expected_root="/${drive,,}/${rest//\\//}"
  grep -Fq "DOTFILES_ROOT=\"$expected_root\"" "$hook_home/.bashrc" \
    || fail "Git Bash hook did not honor the configured dotfiles link"
  grep -Fq 'PI_CODING_AGENT_DIR=' "$hook_home/.bashrc" \
    || fail "Git Bash hook did not export the configured Pi directory"

  expected_pi_dir="$(cygpath -w "$hook_home/.pi/agent")"
  actual_pi_dir="$(HOME="$hook_home" bash --noprofile --norc -c '. "$HOME/.bashrc"; printf "%s" "$PI_CODING_AGENT_DIR"')"
  [ "$actual_pi_dir" = "$expected_pi_dir" ] \
    || fail "Git Bash hook exported the wrong Pi directory: $actual_pi_dir"
  pass "Git Bash hooks are idempotent and honor configured paths"
}

test_shell_syntax
test_native_power_shell_suite
test_bash_hook
