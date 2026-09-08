# These functions inspect the current Zsh session, not a new login shell.
shell-doctor() {
  emulate -L zsh
  local tool output summary plugin file warnings=0
  local -a match
  local mbegin mend
  print -- "Zsh $ZSH_VERSION | $(uname -s) $(uname -m)"
  print -- "Config: ${ZSH_CONFIG_DIR:-${ZDOTDIR:-$HOME/.config/zsh}}"
  print -- '--- Commands and versions ---'
  for tool in zsh git starship fzf fd bat nvim zellij yazi ya btop jq tldr delta zoxide rg file; do
    local resolved=$tool
    (( $+commands[$resolved] )) || {
      [[ $tool != fd ]] || resolved=fdfind
      [[ $tool != bat ]] || resolved=batcat
    }
    if (( $+commands[$resolved] )); then
      output=$(command "$resolved" --version 2>&1)
      if (( $? == 0 )); then
        summary=${output%%$'\n'*}
        if [[ $tool == yazi || $tool == ya ]] && [[ "$output" =~ 'Version:[[:space:]]*([^[:space:]]+)' ]]; then
          summary="$summary $match[1]"
        fi
        print -r -- "[OK] $tool: $summary | $commands[$resolved]"
        if [[ $tool == tldr && "$output" == *tealdeer* ]] && [[ "$output" =~ '([0-9]+)\.([0-9]+)\.([0-9]+)' ]]; then
          if (( match[1] < 1 || (match[1] == 1 && match[2] < 8) )); then
            print '[WARN] Old tealdeer may fail to update cache. Run bash scripts/install-tealdeer.sh from your repository, then rehash.'
            (( warnings++ ))
          fi
        fi
        if [[ $tool == nvim || $tool == fzf ]] && [[ "$output" =~ '([0-9]+)\.([0-9]+)\.([0-9]+)' ]]; then
          if [[ $match[1] == 0 ]] && { [[ $tool == nvim ]] && (( match[2] < 11 )) || [[ $tool == fzf ]] && (( match[2] < 53 )); }; then
            print -- "[WARN] $tool version is too old for AstroNvim / Yazi fzf navigation."
            (( warnings++ ))
          fi
        fi
      else
        print -r -- "[WARN] $tool exists but --version failed: $commands[$resolved]"
        (( warnings++ ))
      fi
    else
      print -- "[WARN] $tool not installed (optional tools can be skipped)."
      (( warnings++ ))
    fi
  done
  print -- '--- PATH and configuration ---'
  if [[ ${path[(Ie)$HOME/.local/bin]} == 0 ]]; then
    print '[WARN] ~/.local/bin is not in PATH.'; (( warnings++ ))
  fi
  for tool in nvim zellij yazi ya tldr zoxide; do
    if [[ -x "$HOME/.local/bin/$tool" && ${commands[$tool]:-} != "$HOME/.local/bin/$tool" ]]; then
      print -- "[WARN] $tool user installation is shadowed; put ~/.local/bin first and run rehash."
      (( warnings++ ))
    fi
  done
  for file in .zshrc .zshenv aliases.zsh bindings.zsh plugins.zsh fzf.zsh maintenance.zsh starship.toml; do
    [[ -r "${ZSH_CONFIG_DIR:-${ZDOTDIR:-$HOME/.config/zsh}}/$file" ]] || {
      print -- "[WARN] Missing configuration: $file"; (( warnings++ ))
    }
  done
  print -- '--- Plugins in this session ---'
  for plugin in zsh-autosuggestions zsh-history-substring-search zsh-vi-mode fast-syntax-highlighting; do
    if [[ ${ZSH_LOADED_PLUGINS[(Ie)$plugin]} != 0 ]]; then
      print -- "[OK] $plugin loaded"
    elif [[ -r "${ZPLUGINDIR:-${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins}/$plugin/$plugin.plugin.zsh" ]]; then
      print -- "[WARN] $plugin installed but not confirmed loaded; run exec zsh."; (( warnings++ ))
    else
      print -- "[WARN] $plugin missing; run zplugin-install."; (( warnings++ ))
    fi
  done
  print -- '--- fzf preview and optional media ---'
  if [[ -n ${FZF_CTRL_T_OPTS:-} ]]; then
    # Parse option quoting only; do not execute a user's preview command.
    if ! (print -r -- "${(z)FZF_CTRL_T_OPTS}" >/dev/null) 2>/dev/null; then
      print '[WARN] Invalid fzf option quoting; unset FZF_CTRL_T_OPTS, then exec zsh.'; (( warnings++ ))
    elif [[ $FZF_CTRL_T_OPTS == *"'}"* ]]; then
      print '[WARN] Old broken fzf preview detected; unset FZF_CTRL_T_OPTS, then exec zsh.'; (( warnings++ ))
    else
      print '[OK] fzf option quoting checked (preview not executed).'
    fi
  else
    print '[WARN] No Ctrl+T preview configured; install bat/batcat and restart Zsh.'; (( warnings++ ))
  fi
  for tool in ffmpeg pdftoppm resvg 7zz 7z; do
    if (( $+commands[$tool] )); then print -- "[OK] Optional: $tool"; else print -- "[INFO] Optional: $tool absent"; fi
  done
  print -- "Warnings: $warnings. Optional tools are not required; terminal images/clipboard need manual verification."
  (( warnings == 0 ))
}

shell-update() {
  emulate -L zsh
  local repo=${MY_SHELL_REPO:-} config=${ZSH_CONFIG_DIR:-${ZDOTDIR:-$HOME/.config/zsh}}
  if [[ -z "$repo" && -r "$config/repository" ]]; then
    IFS= read -r repo < "$config/repository"
  fi
  if [[ ! -f "$repo/scripts/update.sh" ]]; then
    print -u2 'Repository not found. Set MY_SHELL_REPO to your checkout, or rerun install-config.sh.'
    return 1
  fi
  ZPLUGINDIR="${ZPLUGINDIR:-${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins}" command bash "$repo/scripts/update.sh" "$@"
}
