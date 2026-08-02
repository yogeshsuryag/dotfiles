# dotfiles

Windows developer setup managed from Git Bash, Scoop, and a small set of
native PowerShell helpers. The repository keeps application configuration in
`home/` and links it into the Windows locations expected by each application.

## What you get

Running the bootstrap installs and configures:

- Git for Windows and Git Bash
- Neovim with the rose-pine moon theme and locked lazy.nvim plugins
- WezTerm with the rose-pine moon theme
- Starship with the shared prompt configuration
- ripgrep, fd, fzf, jq, lazygit, Node.js, and Hack Nerd Font
- Herdr's Windows beta installer, unless disabled in the local config
- Claude, Codex, opencode, and Pi configuration files
- Optional Pi theme, extensions, model overrides, and Calm presentation mode

The setup wizard asks for every supported `DOTFILES_*` variable. Use
`./bootstrap.sh --configure` or `./rebuild.sh --configure` to review all answers
again; manual editing of `windows-config.env` is not required.

Agent CLIs are not installed by default. Enable them in `windows-config.env`
only when you want the bootstrap to run their npm installers.

## Requirements

- Windows 10 or Windows 11
- Git for Windows with Git Bash
- PowerShell, available in supported Windows installations
- Network access for Scoop, package downloads, and Neovim's first plugin sync
- Windows Developer Mode, or administrator permission, for file symbolic links

Git Bash is required to start the bootstrap. Install Git for Windows first on a
new machine, then open Git Bash and clone this repository. Scoop can keep Git
updated after the bootstrap begins.

## Fresh-machine setup

```bash
git clone https://github.com/yogeshsuryag/dotfiles.git
cd dotfiles
./bootstrap.sh
```

On the first run, the setup wizard asks for every supported configuration
variable. Press Enter to accept a default. The answers are saved in the local,
ignored `windows-config.env` file, and Git Bash paths use forms such as
`/c/Users/your-name`. Run `./bootstrap.sh --configure` or
`./rebuild.sh --configure` to run the wizard again.

`bootstrap.sh` is idempotent. It will:

1. Validate that it is running from Git Bash on Windows.
2. Install Scoop for the current user when needed.
3. Add the configured Scoop buckets and install the configured packages.
4. Install Herdr's Windows beta through its official installer when enabled.
5. Add a managed source block to `~/.bashrc` and `~/.bash_profile`.
6. Create the Windows application links and preserve existing targets as backups.
7. Apply only the Windows registry settings explicitly enabled in the config.

Validate configuration without installing or changing anything:

```bash
./bootstrap.sh --check
```

`--check` never creates or edits `windows-config.env`.

## Daily use

Edit files under `home/` directly, then re-apply links and optional settings:

```bash
./rebuild.sh
```

Restart Git Bash after the first bootstrap so the managed shell hook is loaded.

## Uninstall and restore

Run the automatic uninstall from Git Bash:

```bash
./uninstall.sh
```

The script asks for confirmation, removes only links that resolve back to this
repository, removes only the managed hook block, and restores the newest
matching `.dotfiles-backup-*` target when the destination is empty. Use
`./uninstall.sh --configure` to ask for every configuration variable again,
`--keep-backups` to leave backups untouched, or `--yes` after reviewing targets.

The uninstaller does not remove Scoop packages, Herdr, agent CLIs, or registry settings.

## Configuration variables

The tracked `windows-config.example.env` documents every supported variable.
The most useful values are:

- `DOTFILES_SCOOP_PACKAGES` - the Scoop package list
- `DOTFILES_SCOOP_BUCKETS` - normal Scoop buckets, separated by spaces
- `DOTFILES_NERD_FONTS_BUCKET_URL` - the Nerd Fonts bucket source
- `DOTFILES_INSTALL_HERDR` - enable or disable the Herdr Windows installer
- `DOTFILES_INSTALL_AGENT_CLIS` - opt in to npm installation of agent CLIs
- `DOTFILES_WINDOWS_HOME`, `DOTFILES_LOCAL_APPDATA`, and `DOTFILES_APPDATA` - override detected Windows paths
- `DOTFILES_LINK_MODE` - use `junction` for directories or `symbolic` for all links
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
- `home/.config/wezterm` -> `%USERPROFILE%\.config\wezterm`
- `home/.config/wezterm/wezterm.lua` -> `%USERPROFILE%\.wezterm.lua`
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

## Neovim and WezTerm

The first Neovim launch clones lazy.nvim and its plugins from GitHub. This needs
network access once. The terminal and editor use the same rose-pine moon visual
language and Hack Nerd Font.

## Testing

From Git Bash, run the static checks that do not install packages or modify
Windows settings:

```bash
bash -n bootstrap.sh rebuild.sh windows-common.sh uninstall.sh tests/lib.sh tests/pi-calm.test.sh
./bootstrap.sh --check
./uninstall.sh --check
bash tests/windows.test.sh
bash tests/pi-calm.test.sh
```

The Pi test suite skips integration checks when Node, Pi, tmux, or the required
package is not installed. The bootstrap's `--check` mode only validates the
local configuration and detected Windows paths.

## License

This repository is licensed under MIT No Attribution. See `LICENSE`.
