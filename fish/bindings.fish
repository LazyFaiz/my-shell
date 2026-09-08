# Native Fish autosuggestions, highlighting, history search and Vi mode.
fish_vi_key_bindings
function __my_shell_toggle_suggestions
    if test "$fish_autosuggestion_enabled" = 0
        set -g fish_autosuggestion_enabled 1
    else
        set -g fish_autosuggestion_enabled 0
    end
    commandline -f repaint
end
for mode in default insert
    bind -M $mode ctrl-left backward-word
    bind -M $mode ctrl-right forward-word
    bind -M $mode up up-or-search
    bind -M $mode down down-or-search
    bind -M $mode ctrl-\\ __my_shell_toggle_suggestions
end
