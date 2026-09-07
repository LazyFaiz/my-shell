# Install explicitly with zplugin-install; startup never requires network access.
typeset -g ZPLUGINDIR="${ZPLUGINDIR:-${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins}"
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
  local repo target failed=0 installed=0
  for repo in "${ZSH_PLUGIN_REPOS[@]}"; do
    target="$ZPLUGINDIR/${repo:t}"
    if [[ ! -d "$target/.git" ]]; then
      print "Skip ${repo:t}: not installed (use zplugin-install)."
      continue
    fi
    (( installed += 1 ))
    command git -C "$target" pull --ff-only || failed=1
  done
  (( installed )) || print "No installed plugins to update."
  return "$failed"
}

typeset -ga ZSH_LOADED_PLUGINS=()
_zsh_load_plugins() {
  local repo file
  for repo in "${ZSH_PLUGIN_REPOS[@]}"; do
    file="$ZPLUGINDIR/${repo:t}/${repo:t}.plugin.zsh"
    if [[ -r "$file" ]]; then
      if source "$file"; then
        ZSH_LOADED_PLUGINS+=("${repo:t}")
      else
        print -u2 "Plugin failed to load: ${repo:t}"
      fi
    fi
  done
}
[[ ${ZSH_PLUGINS_NO_LOAD:-0} == 1 ]] || _zsh_load_plugins
