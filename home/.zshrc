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

# Persistent history shared across MSYS2 zsh sessions.
HISTFILE="${ZDOTDIR:-$HOME}/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY
setopt HIST_IGNORE_SPACE

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

# fzf key bindings and completion. Ctrl+R searches history, Ctrl+T picks files,
# and Alt+C jumps into a directory, all themed to the selected color scheme.
if (( $+commands[fzf] )); then
  case "${DOTFILES_OH_MY_POSH_THEME:-tokyo-night-storm}" in
    rose-pine-moon)
      export FZF_DEFAULT_OPTS='--color=fg:#e0def4,bg:#232136,hl:#c4a7e7,fg+:#e0def4,bg+:#2a273f,hl+:#9ccfd8,info:#c4a7e7,pointer:#9ccfd8,marker:#9ccfd8,prompt:#eb6f92,spinner:#eb6f92,header:#eb6f92'
      export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6e6a86'
      ;;
    *)
      export FZF_DEFAULT_OPTS='--color=fg:#c0caf5,bg:#16161e,hl:#bb9af7,fg+:#c0caf5,bg+:#1f2335,hl+:#7dcfff,info:#7aa2f7,pointer:#7dcfff,marker:#7dcfff,prompt:#7aa2f7,spinner:#7aa2f7,header:#7aa2f7'
      export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#565f89'
      ;;
  esac
  eval "$(fzf --zsh)"
fi

alias ..='cd ..'
alias add='git add .'
alias push='git push'
alias pull='git pull'
alias m='git switch main'
alias cc='claude --dangerously-skip-permissions'
alias co='codex --full-auto'

# Autocomplete plugins installed alongside zsh by the bootstrap. Sourced last
# so syntax highlighting sees the aliases defined above.
if [[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
if [[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
