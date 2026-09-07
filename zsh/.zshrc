# Inspired by https://github.com/radleylewis/zsh (see LICENSE).
[[ -o interactive ]] || return

# Resolve this file, including symlinks; also supports sourcing it manually.
typeset -g ZSH_CONFIG_DIR="${${(%):-%N}:A:h}"
source "$ZSH_CONFIG_DIR/.zshenv"

mkdir -p -- "$XDG_STATE_HOME/zsh" "$XDG_CACHE_HOME/zsh"
HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=100000
SAVEHIST=100000
setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE
setopt HIST_EXPIRE_DUPS_FIRST HIST_FIND_NO_DUPS
setopt AUTO_CD NO_BEEP NUMERIC_GLOB_SORT INTERACTIVE_COMMENTS

[[ -t 0 ]] && export GPG_TTY="$(tty)"

autoload -Uz compinit
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION"
zmodload zsh/complist
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Define hooks before loading zsh-vi-mode, which resets key bindings.
source "$ZSH_CONFIG_DIR/aliases.zsh"
source "$ZSH_CONFIG_DIR/fzf.zsh"
source "$ZSH_CONFIG_DIR/bindings.zsh"
source "$ZSH_CONFIG_DIR/plugins.zsh"
_zsh_apply_bindings

(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
source "$ZSH_CONFIG_DIR/prompt.zsh"
[[ ! -f "$ZSH_CONFIG_DIR/local.zsh" ]] || source "$ZSH_CONFIG_DIR/local.zsh"
