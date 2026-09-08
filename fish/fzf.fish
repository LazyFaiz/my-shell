command -q fzf; or return
if not set -q FZF_DEFAULT_COMMAND
    if command -q fd
        set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --exclude .git'
    else if command -q fdfind
        set -gx FZF_DEFAULT_COMMAND 'fdfind --type f --hidden --exclude .git'
    else
        set -gx FZF_DEFAULT_COMMAND "find . -type d -name .git -prune -o -type f -print"
    end
end
set -q FZF_CTRL_T_COMMAND; or set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
set -q FZF_DEFAULT_OPTS; or set -gx FZF_DEFAULT_OPTS '--height=60% --layout=reverse --border=rounded'
if not set -q FZF_CTRL_T_OPTS
    if command -q bat
        set -gx FZF_CTRL_T_OPTS "--preview 'bat --color=always --style=numbers --line-range=:300 -- {}'"
    else if command -q batcat
        set -gx FZF_CTRL_T_OPTS "--preview 'batcat --color=always --style=numbers --line-range=:300 -- {}'"
    end
end
# Use the integration shipped with the installed fzf, never download on startup.
set -l integration (command fzf --fish 2>/dev/null)
if test $status -eq 0; and test (count $integration) -gt 0
    string join \n -- $integration | source
else if functions -q fzf_key_bindings
    fzf_key_bindings
else
    for file in /usr/share/doc/fzf/examples/key-bindings.fish /usr/share/fzf/key-bindings.fish "$HOME/.fzf/shell/key-bindings.fish" /opt/homebrew/opt/fzf/shell/key-bindings.fish /usr/local/opt/fzf/shell/key-bindings.fish
        if test -r "$file"
            source "$file"
            functions -q fzf_key_bindings; and fzf_key_bindings
            break
        end
    end
end

function __my_shell_fzf_no_hidden
    set -lx FZF_CTRL_T_COMMAND "find . -name '.*' ! -name . -prune -o -type f -print"
    if command -q fd
        set FZF_CTRL_T_COMMAND 'fd --type f --exclude .git'
    else if command -q fdfind
        set FZF_CTRL_T_COMMAND 'fdfind --type f --exclude .git'
    end
    fzf-file-widget
end
if functions -q fzf-file-widget
    for mode in default insert
        bind -M $mode ctrl-t fzf-file-widget
        bind -M $mode ctrl-f __my_shell_fzf_no_hidden
    end
end
if functions -q fzf-history-widget
    for mode in default insert
        bind -M $mode ctrl-r fzf-history-widget
    end
end
