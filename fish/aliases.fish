if command -q eza
    alias ls 'eza --icons=auto'
    alias ll 'eza -lah --icons=auto --git'
    alias la 'eza -lah --icons=auto --git'
    alias tree 'eza --tree --icons=auto'
    alias lt 'eza --tree --level=2 --icons=auto --group-directories-first'
else
    alias ll 'ls -lah'
    alias la 'ls -lah'
end

if command -q bat
    alias c bat
else if command -q batcat
    alias bat batcat
    alias c batcat
end
if not command -q fd; and command -q fdfind
    alias fd fdfind
end
command -q nvim; and alias vim nvim
command -q rg; and alias rgh 'rg --hidden'
command -q tldr; and alias t tldr
command -q jq; and alias jqp 'jq .'
alias df 'df -h'
alias disk 'df -h'
alias .. 'cd ..'
alias ... 'cd ../..'
alias gs 'git status --short --branch'
alias ga 'git add'
alias gd 'git diff'
alias gc 'git commit'
alias glog 'git log --oneline --decorate --graph'
alias gadog 'git log --all --oneline --decorate --graph'
if command -q ss
    alias ports 'ss -tuln'
else if command -q lsof
    alias ports 'lsof -nP -iTCP -sTCP:LISTEN'
end
if command -q free
    alias mem 'free -h'
else if command -q vm_stat
    alias mem vm_stat
end
if command -q zellij
    alias zj zellij
    alias za 'zellij attach --create'
    alias zl 'zellij list-sessions'
    alias zk 'zellij kill-session'
end

function mkcd --description 'Create and enter a directory'
    if test (count $argv) -ne 1
        echo 'Usage: mkcd <directory>' >&2
        return 2
    end
    command mkdir -p -- "$argv[1]"; and cd -- "$argv[1]"
end

function extract --description 'Extract a trusted archive into a new directory'
    if test (count $argv) -ne 1; or not test -f "$argv[1]"
        echo 'Usage: extract <archive-file>' >&2
        return 2
    end
    set -l archive (path resolve -Z -- "$argv[1]" | string split0)
    set -l destination "$archive.extracted"
    set -l extractor
    switch (string lower -- "$archive" | string collect)
        case '*.tar' '*.tar.gz' '*.tgz' '*.tar.bz2' '*.tbz2' '*.tar.xz' '*.txz'
            set extractor tar
        case '*.zip'
            set extractor unzip
        case '*.7z' '*.rar'
            if command -q 7zz
                set extractor 7zz
            else
                set extractor 7z
            end
        case '*'
            echo 'Supported: tar, tar.gz, tar.bz2, tar.xz, zip, 7z, rar' >&2
            return 2
    end
    if not command -q $extractor
        echo "Missing dependency: $extractor" >&2
        return 127
    end
    command mkdir -- "$destination"; or return
    switch $extractor
        case tar
            command tar -xf "$archive" -C "$destination"
        case unzip
            command unzip -n "$archive" -d "$destination"
        case '*'
            command $extractor x -aos "-o$destination" "$archive"
    end
end

function y --description 'Open Yazi; q follows its directory, Q keeps this directory'
    if not command -q yazi
        echo 'Yazi is not installed; use bash scripts/install-yazi.sh.' >&2
        return 127
    end
    set -l tmp (command mktemp -t yazi-cwd.XXXXXXXX); or return
    command yazi $argv --cwd-file="$tmp"
    set -l result $status
    if test $result -eq 0
        set -l cwd
        # Read through EOF as one value, preserving spaces and embedded/trailing newlines.
        read --null cwd < "$tmp"
        if test -n "$cwd"; and test -d "$cwd"; and test "$cwd" != "$PWD"
            cd -- "$cwd"
            set result $status
        end
    end
    command rm -f -- "$tmp"
    return $result
end
