# Use session variables, not persistent universal variables.
for kind in CONFIG CACHE DATA STATE
    set -l key XDG_{$kind}_HOME
    if not set -q $key; or test -z "$$key"
        switch $kind
            case CONFIG
                set -gx $key "$HOME/.config"
            case CACHE
                set -gx $key "$HOME/.cache"
            case DATA
                set -gx $key "$HOME/.local/share"
            case STATE
                set -gx $key "$HOME/.local/state"
        end
    end
end
fish_add_path --global --path --move "$HOME/.local/bin"
if not set -q EDITOR; or test -z "$EDITOR"
    if command -q nvim
        set -gx EDITOR nvim
    else
        set -gx EDITOR vi
    end
end
set -q VISUAL; or set -gx VISUAL "$EDITOR"
set -q STARSHIP_CONFIG; or set -gx STARSHIP_CONFIG "$MY_SHELL_FISH_DIR/starship.toml"
