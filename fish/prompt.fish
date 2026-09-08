set -gx VIRTUAL_ENV_DISABLE_PROMPT 1
if command -q starship; and test "$TERM" != dumb
    starship init fish | source
end
if command -q zoxide
    # Older zoxide expects an on-disk cd.fish; Fish 4.9 embeds it.
    # Seed the internal copy using Fish's function API before loading zoxide.
    if not functions -q __zoxide_cd_internal
        functions -c cd __zoxide_cd_internal
    end
    zoxide init fish | source
end
