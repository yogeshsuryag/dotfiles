# dotfiles

A Windows version of [Kun's dotfiles](https://github.com/kunchenguid/dotfiles),
which manages a Mac with nix-darwin and home-manager. This repo keeps the same
goals - one repo, one command, and a fresh machine configured the same way every
time - on Windows. Setup is managed from PowerShell with Scoop as the default
package manager and WinGet available as an alternative, all driven by a single
native PowerShell engine in `scripts/`. The repository keeps application
configuration in `home/` and links it into the Windows locations expected by
each application. Git Bash remains a supported shell through the managed
`~/.bashrc` hook; the setup logic itself is PowerShell-only.

## What you get

Running the bootstrap installs and configures:

- The same feature areas as the original Mac setup, ported to Windows: a shared
  prompt, a themed editor, a themed terminal, and shared agent configs
- Git for Windows and Git Bash, installed through the default Scoop manager
- Neovim with the Tokyo Night (default) or Rose Pine Moon color scheme and locked lazy.nvim plugins
- PowerShell 7 (installed through WinGet when only Windows PowerShell is present), with a minimal profile that initializes the Starship prompt
- Starship as the shared prompt for PowerShell, Git Bash, and zsh
- Windows Terminal styled with the chosen color theme (Tokyo Night by default, Rose Pine Moon as the alternative), merged into your existing settings, with PowerShell 7 as the default profile and a managed `zsh (MSYS2)` profile when zsh is enabled
- ripgrep, fd, fzf, jq, lazygit, and Node.js LTS, each in its own versioned directory under `~/scoop/apps/<name>/current`
- psmux, a tmux-compatible terminal multiplexer for Windows, from its dedicated Scoop bucket
- GitHub AXI, Chrome DevTools AXI, and Lavish AXI skills installed globally for detected agents
- no-mistakes, which checks code with AI before pushing, fixes safe issues, and creates clean PRs without interrupting your work
- gnhf, which lets AI agents make small committed improvements autonomously while you sleep and keeps a full activity log
- Optional MSYS2 zsh with zsh-autosuggestions and zsh-syntax-highlighting, launched from the MSYS2 shell or its Windows Terminal profile
- Optional Oh My Posh prompt in Tokyo Night or Rose Pine Moon colors for zsh
- Herdr's Windows beta installer, unless disabled in the local config
- Claude, Codex, opencode, and Pi configuration files
- Optional Pi theme, extensions, model overrides, and Calm presentation mode

The setup wizard opens a keyboard-driven terminal UI instead of asking for raw
environment variable names. It groups choices into tools, optional installers,
file locations, shell/link behavior, Kun Chen's agentic engineering setup, and
Windows settings. Use
`.\bootstrap.ps1 --configure` or `.\rebuild.ps1 --configure` to review all
choices again; manual editing of `windows-config.env` is not required.

Agent CLIs are not installed by default. Select them in the setup UI, or enable
them in `windows-config.env`, only when you want the bootstrap to run their npm
installers.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or PowerShell 7 (`pwsh`). The bootstrap installs
  PowerShell 7 through WinGet when only Windows PowerShell is available.
- Git for Windows if you use Git Bash as a shell before the bootstrap (the
  bootstrap itself installs portable Git and configures Git Bash)
- Network access for WinGet, package downloads, and Neovim's first plugin sync
- No elevation is needed for the default junction and hard-link mode when the
  repository and Windows profile are on the same volume. Symbolic-link mode
  requires Windows Developer Mode or administrator permission. The one
  exception is the initial PowerShell 7 installation, which raises a single
  user account control prompt because the WinGet machine-scope package is an MSI.

Clone this repository from Windows PowerShell, then bootstrap:

## Fresh-machine setup

```powershell
git clone https://github.com/yogeshsuryag/dotfiles.git
Set-Location dotfiles
.\bootstrap.ps1
```

If script execution is restricted, invoke it explicitly with a process-scoped
policy override:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1
```

On the first run, the setup wizard opens a full-screen terminal UI. Use the
arrow keys or Tab to move, Space to toggle checkboxes, Enter to edit or select,
and Shift+Tab to move backward. Press Escape or `q` to cancel. Package choices
are individual checkboxes, and additional package or bucket names can be typed
in the custom fields. The answers are saved in the local, ignored
`windows-config.env` file, and Git Bash paths use forms such as
`/c/Users/your-name`. Run `.\bootstrap.ps1 --configure` or
`.\rebuild.ps1 --configure` to run the UI again.

The bootstrap script is idempotent and will:

1. Validate the local configuration and detected Windows paths.
2. Install PowerShell 7 through WinGet when only Windows PowerShell is present, then continue under `pwsh`.
3. Check whether every declared tool is already available - on PATH, in Scoop (`scoop list`), or in WinGet (`winget list`) - and show a review page with the recommended action per tool (Skip for existing tools, Install for missing ones). Space changes a tool's action (Install/Skip/Replace), Enter continues, Esc cancels without installing anything. Non-interactive runs skip the page and apply the recommendations automatically.
4. Install only the approved packages through the default Scoop manager, each into its own versioned directory under `~/scoop/apps/<name>/current` with a shim on PATH; WinGet mode instead installs user-scope zip packages and extracts the official portable archives for Git, Node.js, Neovim, and Starship into `%LOCALAPPDATA%\Programs`.
5. Install the selected global agent skills with noninteractive `npx --yes skills add ... -g -y` commands, including GitHub AXI, Chrome DevTools AXI, and Lavish AXI when enabled, then install no-mistakes with its user-scoped PowerShell installer and gnhf with `npm install -g gnhf` when enabled.
6. Install Herdr's Windows beta through its official installer when enabled.
7. Install MSYS2 through Scoop (or WinGet in WinGet mode), its zsh package through pacman, and the autocomplete plugins from their official repositories when `DOTFILES_INSTALL_ZSH=1`.
8. Add managed shell startup blocks and a source block to `~/.bashrc` and `~/.bash_profile`.
9. Link the shared PowerShell profile into Windows PowerShell 5.1 and PowerShell 7, create the Windows application links, and preserve existing targets as backups.
10. Merge the tracked styling for the chosen color theme into the Windows Terminal settings, backing up the original file once, and add the managed `zsh (MSYS2)` profile when zsh is enabled.
11. Apply only the Windows registry settings explicitly enabled in the config.

Validate configuration without installing or changing anything:

```powershell
.\bootstrap.ps1 --check
```

`--check` never creates or edits `windows-config.env`. It also prints which
declared tools are already installed, so you can preview what the bootstrap
would skip and install.

## Daily use

Edit files under `home/` directly, then re-apply links and optional settings:

```powershell
.\rebuild.ps1
```

Restart Git Bash after the first bootstrap so the managed shell hook is loaded.
Restart PowerShell after bootstrap so the PowerShell 7 profile and the Starship
prompt are picked up. Git Bash remains available independently.

The PowerShell profile is intentionally minimal: it initializes the Starship
prompt and nothing else, so native PowerShell stays the shell and behaves
predictably. If you enabled `DOTFILES_INSTALL_ZSH`, launch the MSYS2 zsh shell
from the MSYS2 entry in the Windows Start menu or from the `zsh (MSYS2)` profile
in Windows Terminal; zsh runs with the full Windows
PATH, so tools installed for Windows (such as `herdr`, `pwsh`, and `nvim`) work
inside it.

## Uninstall and restore

Run the automatic uninstall:

```powershell
.\uninstall.ps1
```

The script asks for confirmation, removes only links that resolve back to this
repository, removes only the managed Git Bash hook block, and restores the newest
matching `.dotfiles-backup-*` target when the destination is empty. Use
`.\uninstall.ps1 --configure` to review configuration in the interactive UI,
`--keep-backups` to leave backups untouched, or `--yes` after reviewing targets,
for example `.\uninstall.ps1 --yes`.

The uninstaller does not remove WinGet or Scoop packages, Herdr, agent CLIs,
Windows Terminal styling, or registry settings.

## Configuration variables

The tracked `windows-config.example.env` documents every supported variable for
manual or non-interactive setup. Both frontends read the same file, and either
interactive UI presents the same values
with plain-language descriptions and keeps the environment variable names out
of the selection flow.
The most useful values are:

- `DOTFILES_PACKAGE_MANAGER` - `scoop` (default): every app installs into its own versioned directory under `~/scoop/apps/<name>/current` with a shim on PATH, so installs stay self-contained and never require elevation. `winget` is the alternative
- `DOTFILES_WINGET_PACKAGES` - the WinGet package IDs in WinGet mode, where `git`, `node`, `neovim`, and `starship` are aliases for the official portable archive installs
- `DOTFILES_LOCAL_TOOLS_DIR` - where the portable Git and Node.js archives are extracted in WinGet mode (default `%LOCALAPPDATA%\Programs`)
- `DOTFILES_UPDATE_PACKAGES` - run `winget upgrade --all` before installing new packages in WinGet mode
- `DOTFILES_SCOOP_PACKAGES` - the Scoop package list (the default package manager)
- `DOTFILES_SCOOP_BUCKETS` - normal Scoop buckets, separated by spaces
- `DOTFILES_NERD_FONTS_BUCKET_URL` - the Nerd Fonts bucket source
- `DOTFILES_INSTALL_PSMUX` - install psmux and its dedicated Scoop bucket for tmux-compatible terminal multiplexing on Windows
- `DOTFILES_INSTALL_GH_AXI` - install the global `gh-axi` skill from `kunchenguid/gh-axi`
- `DOTFILES_INSTALL_CHROME_DEVTOOLS_AXI` - install the global `chrome-devtools-axi` skill from `kunchenguid/chrome-devtools-axi`
- `DOTFILES_INSTALL_LAVISH_AXI` - install the global `lavish` skill from `kunchenguid/lavish-axi`
- `DOTFILES_INSTALL_NO_MISTAKES` - install no-mistakes into the current user's LocalAppData without elevation
- `DOTFILES_INSTALL_GNHF` - install gnhf globally with npm; requires Node.js 20 or newer
- `DOTFILES_INSTALL_HERDR` - enable or disable the Herdr Windows installer
- `DOTFILES_INSTALL_AGENT_CLIS` - opt in to npm installation of agent CLIs
- `DOTFILES_INSTALL_ZSH` - install MSYS2 and pacman zsh with the autocomplete plugins, launched on demand from the MSYS2 shell
- `DOTFILES_INSTALL_OH_MY_POSH` - opt in to the Oh My Posh prompt in zsh (installable through the setup UI)
- `DOTFILES_COLOR_THEME` - choose `tokyo-night` (default) or `rose-pine-moon`; the choice is shared by Windows Terminal, Neovim, Herdr, zsh, and the prompt, and overrides `DOTFILES_OH_MY_POSH_THEME`
- `DOTFILES_OH_MY_POSH_THEME` - the Oh My Posh theme (`tokyo-night-storm` or `rose-pine-moon`); derived from `DOTFILES_COLOR_THEME` when not set
- `DOTFILES_WINDOWS_HOME`, `DOTFILES_LOCAL_APPDATA`, and `DOTFILES_APPDATA` - override detected Windows paths; Git Bash and Windows path forms are accepted
- `DOTFILES_CLAUDE_CONFIG_DIR` and the other `*_CONFIG_DIR` overrides - point an application at a custom config location; when overriding Claude's directory, also update the hard-coded `%USERPROFILE%` path in `home/.claude/settings.json` so the status line keeps working
- `DOTFILES_LINK_MODE` - use junctions for directories and hard links for files by default, or symbolic links for all links
- `DOTFILES_BACKUP_EXISTING` - preserve real targets before linking
- `DOTFILES_APPLY_WINDOWS_SETTINGS` - master switch for registry changes

No credentials or API keys belong in this repository or in the example config.
Keep secrets in the application's own credential store or in a separate local
environment file that is not tracked.

## Windows settings

Registry changes are opt-in. Set `DOTFILES_APPLY_WINDOWS_SETTINGS=1`, then
enable the individual settings you want:

- `DOTFILES_DARK_MODE=1` enables dark mode for Windows and applications.
- `DOTFILES_SHOW_FILE_EXTENSIONS=1` shows file extensions in Explorer.
- `DOTFILES_SHOW_HIDDEN_FILES=1` shows hidden files in Explorer.
- `DOTFILES_HIDE_DESKTOP_ICONS=1` hides desktop icons.
- `DOTFILES_TASKBAR_AUTO_HIDE=1` enables taskbar auto-hide where Windows exposes the required setting.
- `DOTFILES_KEYBOARD_REPEAT=1` applies the configured keyboard delay and speed.
- `DOTFILES_RESTART_EXPLORER=1` restarts Explorer after Explorer or taskbar changes.

Finder-style list view, trackpad tap-to-click, and menu-bar behavior do not have
reliable Windows equivalents and are intentionally not automated.

## Linked locations

The native Windows helper links these repository paths:

- `home/.config/nvim` -> `%LOCALAPPDATA%\nvim`
- `home/.config/oh-my-posh` -> `%USERPROFILE%\.config\oh-my-posh`
- `home/.config/powershell\Microsoft.PowerShell_profile.ps1` -> both the Windows PowerShell 5.1 and PowerShell 7 profile locations
- `home/.config/herdr` -> `%APPDATA%\herdr`
- `home/.claude` files -> `%USERPROFILE%\.claude`
- `home/.pi/agent` authored files -> `%USERPROFILE%\.pi\agent`
- `home/AGENTS.md` -> Claude, Codex, and opencode instruction locations

The Pi agent directory itself is not linked as a whole. Authentication, sessions,
caches, package trees, and the Calm state file remain local runtime data.

## Optional agent configuration

Pi is configured but remains an optional CLI. Install it separately or enable
`DOTFILES_INSTALL_AGENT_CLIS=1`. Pi's pinned package declarations live in
`home/.pi/agent/settings.json`; runtime package trees and credentials are never
managed by this repository.

The `cc` and `co` aliases intentionally run Claude and Codex with high-agency
permissions. Review them before using them.

## Neovim, Windows Terminal, and the shell prompt

The first Neovim launch clones lazy.nvim and its plugins from GitHub. This needs
network access once. The shared PowerShell profile (linked into both Windows
PowerShell 5.1 and PowerShell 7) initializes the Starship prompt only; the same
Starship configuration is sourced by Git Bash through the managed `~/.bashrc`
hook and by zsh through `home/.zshrc`.

Windows Terminal gets a tracked styling driven by `DOTFILES_COLOR_THEME`:
the profile defaults (color scheme, bar cursor, translucent acrylic, padding),
the matching color scheme, and a matching theme are merged into your existing
`settings.json` on every bootstrap and rebuild. The merge never touches your
other profiles, unrelated settings, or the default profile; the first merge
backs the original file up as `settings.json.dotfiles-backup-*`, and uninstall
restores that backup. When zsh is enabled, the merge also adds a managed
`zsh (MSYS2)` profile (named, iconed, and pointed at the MSYS2 launcher) that
uninstall removes again.

If you opt into MSYS2 zsh, the setup installs zsh through pacman and clones
`zsh-autosuggestions` and `zsh-syntax-highlighting` from their official
repositories next to zsh, and `.zshrc` enables their plugins plus the fzf key
bindings (Ctrl+R searches history, Ctrl+T picks files, Alt+C jumps to a
directory), all tinted to the selected theme. Selecting Oh My Posh in the setup
UI (or setting `DOTFILES_INSTALL_OH_MY_POSH=1`) installs it and applies the
matching Tokyo Night or Rose Pine Moon theme in zsh. Without it, Starship
remains the prompt everywhere.

## Testing

From PowerShell, run the native Windows setup suite:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\windows.test.ps1
```

It covers the configuration round-trip, WinGet install arguments, links,
hooks, MSYS2/zsh, prompts, the Windows Terminal settings merge, and the Node
configuration helpers, and targets Windows PowerShell 5.1 (no PowerShell 7-only
syntax), so it can also be run with `pwsh`.

From Git Bash, run the full-suite runner plus the Pi Calm suite. The runner
(`tests/windows.test.sh`) invokes the PowerShell suite and then checks that the
managed Git Bash hook actually works when sourced:

```bash
bash tests/windows.test.sh
bash tests/pi-calm.test.sh
```

After bootstrap, validate `home/.zshrc` from the MSYS2 shell with
`zsh -n "$DOTFILES_ROOT/home/.zshrc"`; Git Bash intentionally does not use or
provide the MSYS2 zsh binary.

The Pi test suite skips integration checks when Node, Pi, tmux, or the required
package is not installed. The bootstrap's `--check` mode only validates the
local configuration and detected Windows paths.

## License

This repository is licensed under MIT No Attribution. See `LICENSE`.
