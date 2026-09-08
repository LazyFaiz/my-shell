#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib/install-common.sh"
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
shell_kind=zsh
if [[ ${1:-} == --shell ]]; then
  shell_kind=${2:-}
  case "$shell_kind" in zsh|fish) ;; *) echo 'Unknown shell; use zsh or fish.' >&2; exit 2 ;; esac
  shift 2
fi
case ${1:---help} in
  --help|-h)
    printf '%s\n' 'Usage: bash scripts/update.sh [--shell zsh|fish] config|plugins|tools|all [neovim|zellij|yazi|tealdeer|zoxide|fish ...]' \
      'config: fast-forward repository and install configuration (preserves personal settings).' \
      'plugins: update installed plugins only.' \
      'tools: update managed tools only; optional tool names select a subset.' \
      'all: config, plugins and managed tools; never upgrades OS packages.'
    exit 0 ;;
  config|plugins|tools|all) mode=$1; shift ;;
  *) echo 'Unknown update category; use --help.' >&2; exit 2 ;;
esac
if [[ "$mode" != tools && $# != 0 ]]; then echo 'Tool names are only valid with tools.' >&2; exit 2; fi
for tool in "$@"; do
  case "$tool" in neovim|zellij|yazi|tealdeer|zoxide|fish) ;; *) echo "Unknown tool: $tool" >&2; exit 2 ;; esac
done
if [[ "$mode" == config || "$mode" == all ]]; then
  INSTALL_STEP=repository-update
  [[ -z $(git -C "$repo_dir" status --porcelain) ]] || { echo 'Repository has local changes; commit or stash them before updating.' >&2; exit 1; }
  git -C "$repo_dir" pull --ff-only
  # Re-enter the updated installer/update script so new code is used consistently.
  if [[ $shell_kind == fish ]]; then
    bash "$repo_dir/scripts/install-fish-config.sh" --config-only
  else
    bash "$repo_dir/scripts/install-config.sh"
  fi
  if [[ "$mode" == all ]]; then
    bash "$repo_dir/scripts/update.sh" --shell "$shell_kind" plugins
    bash "$repo_dir/scripts/update.sh" --shell "$shell_kind" tools
  fi
  echo "Configuration updated. Run exec $shell_kind to load it."
  exit 0
fi
if [[ "$mode" == plugins ]]; then
  if [[ $shell_kind == fish ]]; then
    echo 'Fish uses built-in interactive features; no managed external plugins to update.'
    exit 0
  fi
  INSTALL_STEP=plugin-update
  ZSH_PLUGINS_NO_LOAD=1 zsh -fc 'source "$1"; zplugin-update' -- "$repo_dir/zsh/plugins.zsh"
  echo 'Plugin update finished. Run exec zsh to load it.'
  exit 0
fi
if [[ $# == 0 ]]; then
  set -- neovim zellij yazi tealdeer zoxide
  [[ $shell_kind != fish ]] || set -- "$@" fish
fi
for tool in "$@"; do
  binary=$tool
  [[ "$tool" != neovim ]] || binary=nvim
  [[ "$tool" != tealdeer ]] || binary=tldr
  entry="$HOME/.local/bin/$binary"
  # Only manage entries created by this repository; package-manager tools stay separate.
  if [[ ! -L "$entry" ]]; then echo "Skip $tool: no managed user entry."; continue; fi
  link=$(readlink "$entry")
  case "$link" in "$HOME/.local/opt/$binary-"*/bin/"$binary") ;; *) echo "Skip $tool: external entry."; continue ;; esac
  INSTALL_STEP="update-$tool"
  bash "$repo_dir/scripts/install-$tool.sh"
done
