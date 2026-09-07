# XDG paths: keep values supplied by the current environment.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

typeset -U path PATH
path=("$HOME/.local/bin" $path)

if [[ -z "$EDITOR" ]]; then
  if (( $+commands[nvim] )); then
    export EDITOR=nvim
  else
    export EDITOR=vi
  fi
fi
export VISUAL="${VISUAL:-$EDITOR}"
export STARSHIP_CONFIG="${STARSHIP_CONFIG:-${${(%):-%N}:A:h}/starship.toml}"
