# This entry also supports: source /path/to/my-shell/fish/config.fish
set -g MY_SHELL_FISH_DIR (path dirname (status filename))
source "$MY_SHELL_FISH_DIR/env.fish"

status is-interactive; or return
set -g fish_greeting
for module in aliases bindings fzf prompt maintenance
    source "$MY_SHELL_FISH_DIR/$module.fish"
end
if test -r "$MY_SHELL_FISH_DIR/local.fish"
    source "$MY_SHELL_FISH_DIR/local.fish"
end
