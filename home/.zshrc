# MSYS2 zsh configuration managed by this repository.
# The MSYS2 startup shim sources this file from the linked dotfiles checkout.

if [[ -n "${DOTFILES_ZSHRC_LOADED:-}" ]]; then
  return 0
fi
export DOTFILES_ZSHRC_LOADED=1

export DOTFILES_ROOT="${DOTFILES_ROOT:-$HOME/.dotfiles}"
export EDITOR="${DOTFILES_EDITOR:-nvim}"
export VISUAL="${DOTFILES_VISUAL:-$EDITOR}"
export PI_CODING_AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
export STARSHIP_CONFIG="${STARSHIP_CONFIG:-$DOTFILES_ROOT/home/.config/starship.toml}"

if (( $+commands[starship] )); then
  eval "$(starship init zsh)"
fi

alias ..='cd ..'
alias add='git add .'
alias push='git push'
alias pull='git pull'
alias m='git switch main'
alias cc='claude --dangerously-skip-permissions'
alias co='codex --full-auto'
