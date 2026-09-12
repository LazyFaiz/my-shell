# Install explicitly with zplugin-install; startup never requires network access.
typeset -g ZPLUGINDIR="${ZPLUGINDIR:-${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins}"
typeset -ga ZSH_PLUGIN_REPOS=(
  zsh-users/zsh-autosuggestions
  zsh-users/zsh-history-substring-search
  jeffreytse/zsh-vi-mode
  zdharma-continuum/fast-syntax-highlighting
)

# Download fully before activating; keep old content until replacement is ready.
_zplugin_fetch() {
  emulate -L zsh
  local repo=$1 target=$2 replace=$3 name=${1:t}
  local stage='' backup='' lock="$ZPLUGINDIR/.${1:t}.install-lock"
  if ! command mkdir -- "$lock" 2>/dev/null; then
    print -u2 "Plugin installation busy: $name. If no installer is running, remove the empty lock with: rmdir -- ${(q)lock}"
    return 1
  fi
  {
    if (( ! replace )) && [[ -e "$target" || -L "$target" ]]; then
      print -u2 "Plugin already exists: $target; use zplugin-reinstall $name."
      return 1
    fi
    stage=$(command mktemp -d "$ZPLUGINDIR/.$name.install-XXXXXXXX") || return 1
    command git clone --depth=1 "https://github.com/$repo.git" "$stage/plugin" || return 1
    if [[ ! -r "$stage/plugin/$name.plugin.zsh" || ! -d "$stage/plugin/.git" ]]; then
      print -u2 "Downloaded plugin is incomplete: $name"
      return 1
    fi
    if [[ -e "$target" || -L "$target" ]]; then
      backup=$(command mktemp -d "$ZPLUGINDIR/.$name.backup-XXXXXXXX") || return 1
      command mv -- "$target" "$backup/plugin" || return 1
      print -r -- "Previous plugin saved: $backup/plugin"
    fi
    if ! command mv -- "$stage/plugin" "$target"; then
      if [[ -n "$backup" && ! -e "$target" && ! -L "$target" ]]; then
        command mv -- "$backup/plugin" "$target" || print -u2 "Restore the previous plugin from $backup/plugin."
      fi
      return 1
    fi
  } always {
    [[ -z "$stage" ]] || command rm -rf -- "$stage"
    command rmdir -- "$lock"
  }
}

zplugin-install() {
  emulate -L zsh
  (( $+commands[git] )) || { print -u2 'Please install git first.'; return 1; }
  command mkdir -p -- "$ZPLUGINDIR" || return 1
  local repo name target failed=0
  for repo in "${ZSH_PLUGIN_REPOS[@]}"; do
    name="${repo:t}"
    target="$ZPLUGINDIR/$name"
    if [[ -e "$target" || -L "$target" ]]; then
      if [[ ! -r "$target/$name.plugin.zsh" || ! -d "$target/.git" ]]; then
        print -u2 "Incomplete plugin: $target. Repair with: zplugin-reinstall $name"
        failed=1
      fi
      continue
    fi
    _zplugin_fetch "$repo" "$target" 0 || failed=1
  done
  print 'Restart zsh to load installed plugins.'
  return "$failed"
}

zplugin-reinstall() {
  emulate -L zsh
  if (( $# != 1 )); then
    print -u2 'Usage: zplugin-reinstall <plugin-name>'
    return 2
  fi
  local repo
  for repo in "${ZSH_PLUGIN_REPOS[@]}"; do
    if [[ $1 == ${repo:t} ]]; then
      (( $+commands[git] )) || { print -u2 'Please install git first.'; return 1; }
      command mkdir -p -- "$ZPLUGINDIR" || return 1
      _zplugin_fetch "$repo" "$ZPLUGINDIR/${repo:t}" 1 || return 1
      print 'Plugin reinstalled. Run exec zsh to load it.'
      return 0
    fi
  done
  print -u2 "Unknown managed plugin: $1"
  return 2
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
