bindkey -v
KEYTIMEOUT=10
ZVM_VI_HIGHLIGHT_BACKGROUND=none
ZVM_VI_HIGHLIGHT_FOREGROUND=none
ZVM_VI_HIGHLIGHT_EXTRASTYLE=none

_zsh_apply_bindings() {
  local map up_widget=up-line-or-beginning-search down_widget=down-line-or-beginning-search
  autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
  zle -N up-line-or-beginning-search
  zle -N down-line-or-beginning-search
  if (( $+widgets[history-substring-search-up] )); then
    up_widget=history-substring-search-up
    down_widget=history-substring-search-down
  fi
  # zsh-vi-mode may have reinitialized the keymaps.
  (( $+functions[fzf-history-widget] )) && zle -N fzf-history-widget
  (( $+functions[fzf-file-widget] )) && zle -N fzf-file-widget
  for map in emacs viins; do
    bindkey -M "$map" '^[[1;5C' forward-word
    bindkey -M "$map" '^[[1;5D' backward-word
    bindkey -M "$map" '^[[A' "$up_widget"
    bindkey -M "$map" '^[[B' "$down_widget"
    bindkey -M "$map" '^R' history-incremental-search-backward
    (( $+widgets[fzf-history-widget] )) && bindkey -M "$map" '^R' fzf-history-widget
    (( $+widgets[fzf-file-widget] )) && bindkey -M "$map" '^T' fzf-file-widget
    (( $+widgets[_fzf_file_no_hidden] )) && bindkey -M "$map" '^F' _fzf_file_no_hidden
    (( $+widgets[autosuggest-toggle] )) && bindkey -M "$map" '^\' autosuggest-toggle
  done
  return 0
}

zvm_after_init() {
  _zsh_apply_bindings
}
