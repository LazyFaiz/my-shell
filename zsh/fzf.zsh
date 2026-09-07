(( $+commands[fzf] )) || return 0

if (( $+commands[fd] )); then
  export FZF_DEFAULT_COMMAND="${FZF_DEFAULT_COMMAND:-fd --type f --hidden --exclude .git}"
elif (( $+commands[fdfind] )); then
  export FZF_DEFAULT_COMMAND="${FZF_DEFAULT_COMMAND:-fdfind --type f --hidden --exclude .git}"
else
  export FZF_DEFAULT_COMMAND="${FZF_DEFAULT_COMMAND:-find . -type d -name .git -prune -o -type f -print}"
fi
export FZF_CTRL_T_COMMAND="${FZF_CTRL_T_COMMAND:-$FZF_DEFAULT_COMMAND}"
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:---height=60% --layout=reverse --border=rounded}"
# Keep fzf's {} placeholder outside ${...:-...}: Zsh otherwise closes the
# parameter expansion at its }, producing an invalid preview shell command.
if [[ -z "${FZF_CTRL_T_OPTS:-}" ]]; then
  if (( $+commands[bat] )); then
    export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:300 -- {}'"
  elif (( $+commands[batcat] )); then
    export FZF_CTRL_T_OPTS="--preview 'batcat --color=always --style=numbers --line-range=:300 -- {}'"
  fi
fi

_zsh_fzf_init() {
  local integration shell_dir
  # New fzf releases provide their own integration; older packages ship files.
  if integration=$(fzf --zsh 2>/dev/null); then
    eval "$integration"
    return
  fi
  for shell_dir in /opt/homebrew/opt/fzf/shell /usr/local/opt/fzf/shell \
    /usr/share/fzf /usr/share/doc/fzf/examples "$HOME/.fzf/shell"; do
    if [[ -r "$shell_dir/key-bindings.zsh" ]]; then
      source "$shell_dir/key-bindings.zsh"
      [[ ! -r "$shell_dir/completion.zsh" ]] || source "$shell_dir/completion.zsh"
      return 0
    fi
  done
}
_zsh_fzf_init

_fzf_file_no_hidden() {
  local result
  if (( $+commands[fd] )); then
    result=$(command fd --type f --print0 | fzf --read0)
  elif (( $+commands[fdfind] )); then
    result=$(command fdfind --type f --print0 | fzf --read0)
  else
    result=$(find . -name '.*' ! -name . -prune -o -type f -print0 | fzf --read0)
  fi
  # Quote paths containing spaces and shell metacharacters before insertion.
  [[ -z "$result" ]] || LBUFFER+="${(q)result} "
  zle redisplay
}
zle -N _fzf_file_no_hidden
