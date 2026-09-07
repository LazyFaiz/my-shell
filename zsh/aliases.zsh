if (( $+commands[eza] )); then
  alias ls='eza --icons=auto'
  alias ll='eza -lah --icons=auto --git'
  alias la='eza -lah --icons=auto --git'
  alias tree='eza --tree --icons=auto'
  compdef eza=ls
else
  alias ll='ls -lah'
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

# Optional tools: define aliases only when the commands exist.
(( $+commands[eza] )) && alias lt='eza --tree --level=2 --icons=auto --group-directories-first'
(( $+commands[rg] )) && alias rgh='rg --hidden'
(( $+commands[tldr] )) && alias t='tldr'
(( $+commands[jq] )) && alias jqp='jq .'
alias disk='df -h'
if (( $+commands[ss] )); then
  alias ports='ss -tuln'
elif (( $+commands[lsof] )); then
  alias ports='lsof -nP -iTCP -sTCP:LISTEN'
fi
if (( $+commands[free] )); then
  alias mem='free -h'
elif (( $+commands[vm_stat] )); then
  alias mem='vm_stat'
fi
if (( $+commands[zellij] )); then
  alias zj='zellij'
  alias za='zellij attach --create'
  alias zl='zellij list-sessions'
fi

# Extract into a new directory beside the archive; keep the original file.
extract() {
  if (( $# != 1 )) || [[ ! -f "$1" ]]; then
    print -u2 'Usage: extract <archive-file>'
    return 2
  fi
  local archive="${1:A}" destination="${1:A}.extracted" extractor
  case "${archive:l}" in
    *.tar|*.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz) extractor=tar ;;
    *.zip) extractor=unzip ;;
    *.7z|*.rar)
      if (( $+commands[7zz] )); then extractor=7zz; else extractor=7z; fi ;;
    *) print -u2 'Supported: tar, tar.gz, tar.bz2, tar.xz, zip, 7z, rar'; return 2 ;;
  esac
  (( $+commands[$extractor] )) || { print -u2 "Missing dependency: $extractor"; return 127; }
  # Refuse existing directories so a second extraction cannot overwrite files.
  command mkdir -- "$destination" || return
  case "$extractor" in
    tar) command tar -xf "$archive" -C "$destination" ;;
    unzip) command unzip -n "$archive" -d "$destination" ;;
    *) command "$extractor" x -aos "-o$destination" "$archive" ;;
  esac
}

# Follow Yazi's last directory on normal exit; Q leaves the cwd file empty.
y() {
  (( $+commands[yazi] )) || { print -u2 'Yazi is not installed; use --yazi.'; return 127; }
  local tmp cwd exit_code=0
  tmp=$(mktemp -t yazi-cwd.XXXXXXXX) || return
  {
    command yazi "$@" --cwd-file="$tmp" || exit_code=$?
    if (( exit_code == 0 )); then
      IFS= read -r -d '' cwd < "$tmp" || true
      if [[ -n "$cwd" && "$cwd" != "$PWD" && -d "$cwd" ]]; then
        builtin cd -- "$cwd" || exit_code=$?
      fi
    fi
  } always {
    command rm -f -- "$tmp"
  }
  return "$exit_code"
}
