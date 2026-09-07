# Install explicitly with zplugin-install; startup never requires network access.
typeset -g ZPLUGINDIR="${ZPLUGINDIR:-$XDG_DATA_HOME/zsh/plugins}"
typeset -ga ZSH_PLUGIN_REPOS=(
  zsh-users/zsh-autosuggestions
  zsh-users/zsh-history-substring-search
  jeffreytse/zsh-vi-mode
  zdharma-continuum/fast-syntax-highlighting
)

zplugin-install() {
  (( $+commands[git] )) || { print -u2 'Please install git first.'; return 1; }
  mkdir -p -- "$ZPLUGINDIR" || return 1
  local repo name target failed=0
  for repo in "${ZSH_PLUGIN_REPOS[@]}"; do
    name="${repo:t}"
    target="$ZPLUGINDIR/$name"
    if [[ -e "$target" ]]; then
      [[ -r "$target/$name.plugin.zsh" ]] || { print -u2 "Incomplete plugin: $target"; failed=1; }
      continue
    fi
    command git clone --depth=1 "https://github.com/$repo.git" "$target" || failed=1
  done
  print 'Restart zsh to load installed plugins.'
  return "$failed"
}

zplugin-update() {
  (( $+commands[git] )) || return 1
  local repo target failed=0
  for repo in "${ZSH_PLUGIN_REPOS[@]}"; do
    target="$ZPLUGINDIR/${repo:t}"
    [[ -d "$target/.git" ]] || continue
    command git -C "$target" pull --ff-only || failed=1
  done
  return "$failed"
}

_zsh_load_plugins() {
  local repo file
  for repo in "${ZSH_PLUGIN_REPOS[@]}"; do
    file="$ZPLUGINDIR/${repo:t}/${repo:t}.plugin.zsh"
    [[ ! -r "$file" ]] || source "$file"
  done
}
_zsh_load_plugins
