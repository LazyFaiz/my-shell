#!/usr/bin/env bash
# Install user configuration and optional latest stable Neovim/Zellij/Yazi from GitHub.
set -euo pipefail

if [[ ${1:-} == --help ]]; then
  printf '%s\n' 'Usage: bash scripts/install-config.sh [--astronvim] [--zellij] [--yazi] [--delta]' \
    'Backs up and installs Zsh configuration for the current user.' \
    '--astronvim: install latest stable Neovim; add AstroNvim only when nvim config is absent.' \
    '--zellij: install latest stable Zellij from GitHub.' \
    '--yazi: install latest stable Yazi and ya from GitHub.' \
    '--delta: configure Git to use delta, backing up existing Git config.'
  exit 0
fi
astro=0
delta=0
zellij=0
yazi=0
for arg in "$@"; do
  case "$arg" in
    --astronvim) astro=1 ;;
    --delta) delta=1 ;;
    --zellij) zellij=1 ;;
    --yazi) yazi=1 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done
for cmd in zsh git; do
  command -v "$cmd" >/dev/null || { printf 'Missing dependency: %s\n' "$cmd" >&2; exit 1; }
done
if (( delta )); then
  command -v delta >/dev/null || { echo 'Install git-delta first.' >&2; exit 1; }
fi
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
config_dir="$XDG_CONFIG_HOME/zsh"
# Keep the source checkout distinct from the installation directory.
mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME/my-shell/backups"
if [[ -d "$config_dir" ]] && [[ $(cd "$config_dir" && pwd -P) == "$repo_dir/zsh" ]]; then
  echo 'Source and destination are identical; clone the repository elsewhere.' >&2
  exit 1
fi
if (( astro )); then
  bash "$repo_dir/scripts/install-neovim.sh"
  export PATH="$HOME/.local/bin:$PATH"
  hash -r
fi
if (( zellij )); then
  bash "$repo_dir/scripts/install-zellij.sh"
  export PATH="$HOME/.local/bin:$PATH"
  hash -r
fi
if (( yazi )); then
  bash "$repo_dir/scripts/install-yazi.sh"
  export PATH="$HOME/.local/bin:$PATH"
  hash -r
fi
backup_dir=$(mktemp -d "$XDG_STATE_HOME/my-shell/backups/install-XXXXXXXX")
backup() {
  if [[ -e "$1" || -L "$1" ]]; then
    cp -a "$1" "$backup_dir/$2"
  fi
}
backup "$config_dir" zsh
backup "$HOME/.zshenv" zshenv
backup "$HOME/.zshrc" zshrc
mkdir -p "$config_dir"
for file in .zshenv .zshrc aliases.zsh bindings.zsh fzf.zsh plugins.zsh prompt.zsh starship.toml local.zsh.example; do
  cp "$repo_dir/zsh/$file" "$config_dir/$file"
done
cp "$repo_dir/LICENSE" "$config_dir/LICENSE"
# Append once; preserve all existing settings and local.zsh.
if ! grep -Fqx '# BEGIN my-shell' "$HOME/.zshenv" 2>/dev/null; then
  cat >> "$HOME/.zshenv" <<'ZSHENV'

# BEGIN my-shell
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
[[ ! -r "$ZDOTDIR/.zshenv" ]] || source "$ZDOTDIR/.zshenv"
# END my-shell
ZSHENV
fi

if (( delta )); then
  backup "${GIT_CONFIG_GLOBAL:-$HOME/.gitconfig}" gitconfig
  backup "$XDG_CONFIG_HOME/git/config" xdg-gitconfig
  git config --global core.pager delta
  git config --global interactive.diffFilter 'delta --color-only'
  git config --global delta.navigate true
  git config --global delta.line-numbers true
  git config --global merge.conflictStyle zdiff3
fi

if (( astro )); then
  if [[ -e "$XDG_CONFIG_HOME/nvim" || -L "$XDG_CONFIG_HOME/nvim" ]]; then
    echo 'Existing nvim configuration preserved; see docs/install.md to replace it.'
  else
    # Download completely before changing any existing Neovim runtime directories.
    git clone --depth 1 https://github.com/AstroNvim/template.git "$backup_dir/astronvim-template"
    for base in "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"; do
      if [[ -e "$base/nvim" || -L "$base/nvim" ]]; then
        mv "$base/nvim" "$base/nvim.bak.$(date +%Y%m%d-%H%M%S).$$"
      fi
    done
    cp -a "$backup_dir/astronvim-template" "$XDG_CONFIG_HOME/nvim"
    # Retain the template Git metadata for provenance; no Go pack is added.
  fi
fi
printf '\nConfiguration installed. Backup: %s\n' "$backup_dir"
printf '%s\n' 'Next: start zsh, run zplugin-install, then exec zsh.' \
  'AstroNvim: open nvim, run :Lazy sync and :checkhealth.' \
  'The default login shell is unchanged. See docs/install.md for chsh.'
