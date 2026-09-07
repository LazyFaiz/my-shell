if (( $+commands[eza] )); then
  alias ls='eza --icons=auto'
  alias ll='eza -lh --icons=auto --git'
  alias la='eza -lah --icons=auto --git'
  alias tree='eza --tree --icons=auto'
  compdef eza=ls
else
  alias ll='ls -lh'
  alias la='ls -lah'
fi

# Keep cat/grep unchanged: bat and rg have different command-line semantics.
if (( $+commands[bat] )); then
  alias c='bat'
elif (( $+commands[batcat] )); then
  alias bat='batcat'
  alias c='batcat'
fi
(( $+commands[fd] )) || { (( $+commands[fdfind] )) && alias fd='fdfind'; }
(( $+commands[nvim] )) && alias vim='nvim'
alias df='df -h'
alias ..='cd ..'
alias ...='cd ../..'
alias -- -='cd -'
alias gs='git status --short --branch'
alias ga='git add'
alias gd='git diff'
alias gc='git commit'
alias glog='git log --oneline --decorate --graph'
alias gadog='git log --all --oneline --decorate --graph'

mkcd() {
  if (( $# != 1 )); then
    print -u2 'Usage: mkcd <directory>'
    return 2
  fi
  mkdir -p -- "$1" && builtin cd -- "$1"
}
