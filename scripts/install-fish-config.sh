#!/usr/bin/env bash
# Fish setup is independent of Zsh; default action installs latest stable Fish and zoxide.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib/install-common.sh"
if [[ ${1:-} == --help ]]; then
  printf '%s\n' 'Usage: bash scripts/install-fish-config.sh [--config-only] [--astronvim] [--zellij] [--yazi] [--tealdeer] [--zoxide] [--delta]' \
    'Default: install latest stable Fish and zoxide; back up/install Fish configuration.' \
    '--config-only: skip default Fish/zoxide binary installations; requires Fish 4+ already installed.' \
    'Optional tools use the same stable-release installers as Zsh. No login-shell change.'
  exit 0
fi
config_only=0 astro=0 delta=0 zellij=0 yazi=0 tealdeer=0 zoxide=0
for arg in "$@"; do
  case "$arg" in
    --config-only) config_only=1 ;;
    --astronvim) astro=1 ;;
    --delta) delta=1 ;;
    --zellij) zellij=1 ;;
    --yazi) yazi=1 ;;
    --tealdeer) tealdeer=1 ;;
    --zoxide) zoxide=1 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export PATH="$HOME/.local/bin:$PATH"
config_dir="$XDG_CONFIG_HOME/fish"
module_dir="$config_dir/my-shell"
for candidate in "$config_dir" "$module_dir"; do
  if [[ -d "$candidate" && $(cd "$candidate" && pwd -P) == "$repo_dir/fish" ]]; then
    echo 'Source and destination overlap; clone the repository elsewhere.' >&2
    exit 1
  fi
done
if (( delta )); then command -v delta >/dev/null || { echo 'Install git-delta first.' >&2; exit 1; }; fi
if (( astro || delta )); then command -v git >/dev/null || { echo 'Install git first.' >&2; exit 1; }; fi
if (( ! config_only )); then
  INSTALL_STEP=install-fish
  bash "$repo_dir/scripts/install-fish.sh"
  zoxide=1
fi
fish_bin=${FISH_BIN:-$(command -v fish)}
fish_version=$("$fish_bin" --no-config --version)
[[ $fish_version =~ ([0-9]+)\.[0-9]+\.[0-9]+ ]] && (( BASH_REMATCH[1] >= 4 )) || {
  echo 'Fish 4+ is required. Run without --config-only to install latest stable.' >&2; exit 1;
}
# Validate every module before modifying the installed configuration.
for file in "$repo_dir"/fish/*.fish; do "$fish_bin" --no-config --no-execute "$file"; done
for tool in neovim zellij yazi tealdeer zoxide; do
  selected=0
  case "$tool" in neovim) selected=$astro ;; zellij) selected=$zellij ;; yazi) selected=$yazi ;; tealdeer) selected=$tealdeer ;; zoxide) selected=$zoxide ;; esac
  if (( selected )); then
    INSTALL_STEP="install-$tool"
    bash "$repo_dir/scripts/install-$tool.sh"
  fi
done
INSTALL_STEP=backup-config
mkdir -p "$XDG_STATE_HOME/my-shell/backups"
backup_dir=$(mktemp -d "$XDG_STATE_HOME/my-shell/backups/fish-XXXXXXXX")
backup_config_snapshot "$config_dir" "$backup_dir/fish"
INSTALL_STEP=copy-config
mkdir -p "$module_dir"
for file in config.fish env.fish aliases.fish bindings.fish fzf.fish prompt.fish maintenance.fish starship.toml local.fish.example; do
  cp "$repo_dir/fish/$file" "$module_dir/$file"
done
cp "$repo_dir/LICENSE" "$module_dir/LICENSE"
printf '%s\n' "$repo_dir" > "$module_dir/repository"
# Preserve existing config contents, universal variables, conf.d and local.fish.
if ! grep -Fqx '# BEGIN my-shell fish' "$config_dir/config.fish" 2>/dev/null; then
  stage=$(mktemp -d "$config_dir/.my-shell-entry-XXXXXXXX")
  if [[ -f "$config_dir/config.fish" ]]; then cat "$config_dir/config.fish" > "$stage/config.fish"; fi
  cat >> "$stage/config.fish" <<'FISH'

# BEGIN my-shell fish
source "$__fish_config_dir/my-shell/config.fish"
# END my-shell fish
FISH
  "$fish_bin" --no-config --no-execute "$stage/config.fish"
  mv -f "$stage/config.fish" "$config_dir/config.fish"
  rmdir "$stage"
fi
if (( delta )); then
  INSTALL_STEP=configure-delta
  for file in "${GIT_CONFIG_GLOBAL:-$HOME/.gitconfig}" "$XDG_CONFIG_HOME/git/config"; do
    if [[ -e "$file" ]]; then
      name=gitconfig
      [[ "$file" != "$XDG_CONFIG_HOME/git/config" ]] || name=xdg-gitconfig
      backup_config_snapshot "$file" "$backup_dir/$name"
    fi
  done
  git config --global core.pager delta
  git config --global interactive.diffFilter 'delta --color-only'
  git config --global delta.navigate true
  git config --global delta.line-numbers true
  git config --global merge.conflictStyle zdiff3
fi
if (( astro )); then
  INSTALL_STEP=astronvim-template
  if [[ -e "$XDG_CONFIG_HOME/nvim" || -L "$XDG_CONFIG_HOME/nvim" ]]; then
    echo 'Existing nvim configuration preserved.'
  else
    git clone --depth 1 https://github.com/AstroNvim/template.git "$backup_dir/astronvim-template"
    for base in "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"; do
      if [[ -e "$base/nvim" || -L "$base/nvim" ]]; then
        mv "$base/nvim" "$base/nvim.bak.$(date +%Y%m%d-%H%M%S).$$"
      fi
    done
    cp -a "$backup_dir/astronvim-template" "$XDG_CONFIG_HOME/nvim"
  fi
fi
printf '\nFish configuration installed. Backup: %s\n' "$backup_dir"
printf '%s\n' 'Next: exec "$HOME/.local/bin/fish" (or your existing Fish with --config-only), then shell-doctor.' \
  'No Fish plugins are required. Personal settings: ~/.config/fish/my-shell/local.fish.' \
  'The default login shell is unchanged. See fish/README.md.'
