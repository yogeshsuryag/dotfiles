# Project notes for agents

Deliberate decisions in this repo - do NOT silently revert them:

- The setup logic has ONE implementation: the native PowerShell engine in
  `scripts/` (`windows-common.ps1` loads the shared config/tools/scoop/msys2/
  installers/hooks/apply modules, plus the links/settings/uninstall/manifest/
  TUI helpers), invoked by the `bootstrap.ps1`, `rebuild.ps1`, and
  `uninstall.ps1` entry points. Do not recreate a parallel Bash implementation
  of setup logic. Git Bash is still a supported shell through the managed
  `~/.bashrc` hook, but all setup commands are PowerShell-only.
- Windows registry changes are opt-in through `windows-config.env`; do not make
  them apply by default or hide them inside the normal link step.
- `windows-config.env` is local and ignored. Keep package lists, paths, and
  personal settings in that file rather than embedding machine-specific values
  in tracked source files.
- Never commit `.no-mistakes/` validation evidence to this public repo. `.no-mistakes/` is gitignored; if a validation pipeline stages evidence into a branch, drop it before merging.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
