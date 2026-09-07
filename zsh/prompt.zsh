export VIRTUAL_ENV_DISABLE_PROMPT=1
if (( $+commands[starship] )) && [[ "$TERM" != dumb ]]; then
  eval "$(starship init zsh)"
else
  # A usable prompt when Starship has not been installed yet.
  PROMPT='%F{cyan}%~%f %(?.%F{green}.%F{red})%#%f '
fi
