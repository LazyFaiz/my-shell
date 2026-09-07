#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
for cmd in bash python3 jq unzip file; do command -v "$cmd" >/dev/null; done
zsh_bin=${ZSH_BIN:-$(command -v zsh)}
export ZSH_BIN="$zsh_bin"
for script in scripts/*.sh scripts/lib/*.sh; do bash -n "$script"; done
syntax_dir=$(mktemp -d)
trap 'rm -rf -- "$syntax_dir"' EXIT
"$zsh_bin" -fc '[[ -z ${ZSH_TEST_MODULE_PATH:-} ]] || module_path=("$ZSH_TEST_MODULE_PATH" $module_path); zcompile -U "$@"' -- "$syntax_dir/check.zwc" zsh/.zshrc zsh/.zshenv zsh/*.zsh
python3 -B -m unittest discover -s tests -v
git diff --check
