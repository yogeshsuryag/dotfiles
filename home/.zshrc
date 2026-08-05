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

if [[ "${DOTFILES_INSTALL_OH_MY_POSH:-0}" == "1" ]] && (( $+commands[oh-my-posh] )); then
  omp_theme="${DOTFILES_OH_MY_POSH_THEME:-tokyo-night-storm}"
  omp_theme_file="$DOTFILES_ROOT/home/.config/oh-my-posh/$omp_theme.omp.json"
  if [[ -f "$omp_theme_file" ]]; then
    export OH_MY_POSH_CONFIG="$(cygpath -m "$omp_theme_file")"
    eval "$(oh-my-posh init zsh --config "$OH_MY_POSH_CONFIG")"
  else
    eval "$(oh-my-posh init zsh)"
  fi
else
  export STARSHIP_CONFIG="${STARSHIP_CONFIG:-$DOTFILES_ROOT/home/.config/starship.toml}"
  if (( $+commands[starship] )); then
    eval "$(starship init zsh)"
  fi
fi

alias ..='cd ..'
alias add='git add .'
alias push='git push'
alias pull='git pull'
alias m='git switch main'
alias cc='claude --dangerously-skip-permissions'
alias co='codex --full-auto'
