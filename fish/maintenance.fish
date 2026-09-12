function shell-doctor --description 'Check the current Fish session (no network)'
    set -l warnings 0
    printf 'Fish %s | %s %s\n' "$version" (uname -s) (uname -m)
    printf 'Config: %s\n' "$MY_SHELL_FISH_DIR"
    echo '--- Commands and versions ---'
    for tool in fish git starship fzf fd bat eza nvim zellij yazi ya btop jq tldr delta zoxide rg file
        set -l resolved $tool
        if not command -q $resolved
            switch $tool
                case fd
                    set resolved fdfind
                case bat
                    set resolved batcat
            end
        end
        if not command -q $resolved
            echo "[WARN] $tool not installed (optional tools can be skipped)."
            set warnings (math $warnings + 1)
            continue
        end
        set -l output (command $resolved --version 2>&1)
        if test $status -ne 0
            echo "[WARN] $tool exists but --version failed."
            set warnings (math $warnings + 1)
            continue
        end
        set -l summary "$output[1]"
        if contains -- $tool yazi ya
            set -l detail (string match -r 'Version:\s*(\S+)' -- $output)
            if test (count $detail) -ge 2
                set summary "$summary $detail[2]"
            end
        end
        printf '[OK] %s: %s | %s\n' $tool "$summary" (command -s $resolved)
        set -l number (string match -r '(\d+)\.(\d+)(?:\.(\d+))?' -- "$summary")
        if test (count $number) -ge 3
            set -l old 0
            switch $tool
                case fish
                    test "$number[2]" -lt 4; and set old 1
                case nvim
                    test "$number[2]" -eq 0; and test "$number[3]" -lt 11; and set old 1
                case fzf
                    test "$number[2]" -eq 0; and test "$number[3]" -lt 53; and set old 1
                case tldr
                    if string match -q '*tealdeer*' -- "$summary"
                        test "$number[2]" -eq 1; and test "$number[3]" -lt 8; and set old 1
                    end
            end
            if test $old -eq 1
                echo "[WARN] $tool is too old for this configuration or upstream cache; see fish/README.md."
                set warnings (math $warnings + 1)
            end
        end
    end
    echo '--- PATH and configuration ---'
    if not contains -- "$HOME/.local/bin" $PATH
        echo '[WARN] ~/.local/bin is not in PATH.'
        set warnings (math $warnings + 1)
    end
    for tool in fish nvim zellij yazi ya tldr zoxide
        set -l resolved_path (command -s $tool)
        if test -x "$HOME/.local/bin/$tool"; and test "$resolved_path" != "$HOME/.local/bin/$tool"
            echo "[WARN] $tool user installation is shadowed by PATH."
            set warnings (math $warnings + 1)
        end
    end
    for file in config.fish env.fish aliases.fish bindings.fish fzf.fish prompt.fish maintenance.fish starship.toml
        if not test -r "$MY_SHELL_FISH_DIR/$file"
            echo "[WARN] Missing configuration: $file"
            set warnings (math $warnings + 1)
        end
    end
    echo '[INFO] Autosuggestions, highlighting, completion and Vi mode are built into Fish.'
    printf '[INFO] Key bindings: %s\n' "$fish_key_bindings"
    if command -q fzf; and not functions -q fzf-file-widget fzf-history-widget
        echo '[WARN] fzf Fish bindings are not loaded; install a current fzf and restart Fish.'
        set warnings (math $warnings + 1)
    end
    echo '--- Optional preview tools ---'
    for tool in ffmpeg pdftoppm resvg
        if command -q $tool
            echo "[OK] Optional: $tool"
        else
            echo "[INFO] Optional: $tool absent"
        end
    end
    if command -q 7zz; or command -q 7z
        echo '[OK] Optional: 7-Zip'
    else
        echo '[INFO] Optional: 7zz / 7z absent'
    end
    printf 'Warnings: %s. Test fzf preview, terminal images and clipboard manually.\n' $warnings
    test $warnings -eq 0
end

function shell-update --description 'Update Fish configuration or managed tools'
    set -l repo "$MY_SHELL_REPO"
    if test -z "$repo"; and test -r "$MY_SHELL_FISH_DIR/repository"
        read repo < "$MY_SHELL_FISH_DIR/repository"
    end
    if not test -f "$repo/scripts/update.sh"
        echo 'Repository not found. Set MY_SHELL_REPO, or rerun install-fish-config.sh.' >&2
        return 1
    end
    command bash "$repo/scripts/update.sh" --shell fish $argv
end
