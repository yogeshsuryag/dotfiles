# Git Bash shell configuration managed by this repository.
# This file is sourced through ~/.dotfiles/home/.bashrc.

if [[ -n "${DOTFILES_BASHRC_LOADED:-}" ]]; then
  return 0
fi
export DOTFILES_BASHRC_LOADED=1

export DOTFILES_ROOT="${DOTFILES_ROOT:-$HOME/.dotfiles}"
export EDITOR="${DOTFILES_EDITOR:-nvim}"
export VISUAL="${DOTFILES_VISUAL:-$EDITOR}"
export PI_CODING_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
export STARSHIP_CONFIG="${STARSHIP_CONFIG:-$DOTFILES_ROOT/home/.config/starship.toml}"

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

alias ..='cd ..'
alias add='git add .'
alias push='git push'
alias pull='git pull'
alias m='git switch main'
alias cc='claude --dangerously-skip-permissions'
alias co='codex --full-auto'
