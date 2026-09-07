#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib/install-common.sh"
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
case ${1:---help} in
  --help|-h)
    printf '%s\n' 'Usage: shell-update config|plugins|tools|all [neovim|zellij|yazi ...]' \
      'config: fast-forward repository and install configuration (preserves local.zsh).' \
      'plugins: update installed plugins only.' \
      'tools: update managed tools only; optional tool names select a subset.' \
      'all: config, plugins and managed tools; never upgrades OS packages.'
    exit 0 ;;
  config|plugins|tools|all) mode=$1; shift ;;
  *) echo 'Unknown update category; use --help.' >&2; exit 2 ;;
esac
if [[ "$mode" != tools && $# != 0 ]]; then echo 'Tool names are only valid with tools.' >&2; exit 2; fi
for tool in "$@"; do
  case "$tool" in neovim|zellij|yazi) ;; *) echo "Unknown tool: $tool" >&2; exit 2 ;; esac
done
if [[ "$mode" == config || "$mode" == all ]]; then
  INSTALL_STEP=repository-update
  [[ -z $(git -C "$repo_dir" status --porcelain) ]] || { echo 'Repository has local changes; commit or stash them before updating.' >&2; exit 1; }
  git -C "$repo_dir" pull --ff-only
  # Re-enter the updated installer/update script so new code is used consistently.
  bash "$repo_dir/scripts/install-config.sh"
  if [[ "$mode" == all ]]; then
    bash "$repo_dir/scripts/update.sh" plugins
    bash "$repo_dir/scripts/update.sh" tools
  fi
  echo 'Configuration updated. Run exec zsh to load it.'
  exit 0
fi
if [[ "$mode" == plugins ]]; then
  INSTALL_STEP=plugin-update
  ZSH_PLUGINS_NO_LOAD=1 zsh -fc 'source "$1"; zplugin-update' -- "$repo_dir/zsh/plugins.zsh"
  echo 'Plugin update finished. Run exec zsh to load it.'
  exit 0
fi
[[ $# != 0 ]] || set -- neovim zellij yazi
for tool in "$@"; do
  binary=$tool
  [[ "$tool" != neovim ]] || binary=nvim
  entry="$HOME/.local/bin/$binary"
  # Only manage entries created by this repository; package-manager tools stay separate.
  if [[ ! -L "$entry" ]]; then echo "Skip $tool: no managed user entry."; continue; fi
  link=$(readlink "$entry")
  case "$link" in "$HOME/.local/opt/$binary-"*/bin/"$binary") ;; *) echo "Skip $tool: external entry."; continue ;; esac
  INSTALL_STEP="update-$tool"
  bash "$repo_dir/scripts/install-$tool.sh"
done
