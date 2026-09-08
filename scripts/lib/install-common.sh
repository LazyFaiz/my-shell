# Shared installer diagnostics and installed-release checks (Bash 3.2+).
INSTALL_STEP=preflight
# Never inherit cleanup paths from the caller's environment.
work=''
stage=''
target=''
backup_dir=''
install_exit() {
  local result=$?
  trap - EXIT
  if (( result != 0 )); then
    printf '\n[FAILED] %s: step=%s, exit=%s\n' "${0##*/}" "$INSTALL_STEP" "$result" >&2
    [[ -z ${backup_dir:-} ]] || printf 'Backup: %s\n' "$backup_dir" >&2
    [[ -z ${target:-} ]] || printf 'Downloaded version directory: %s\n' "$target" >&2
    printf 'Earlier steps may have completed. Recovery: docs/maintenance.md\n' >&2
    printf 'Correct the reported error and rerun the same command.\n' >&2
  fi
  [[ -z ${work:-} ]] || rm -rf -- "$work"
  [[ -z ${stage:-} ]] || rm -rf -- "$stage"
  exit "$result"
}
trap install_exit EXIT

# Check both the version reported by each executable and the release asset.
# A broken executable or a different platform asset must not be skipped.
release_is_current() {
  local expected=$1 expected_asset=$2 binary entry link installed output parsed
  shift 2
  for binary in "$@"; do
    entry="$HOME/.local/bin/$binary"
    [[ -x "$entry" && -L "$entry" ]] || return 1
    link=$(readlink "$entry") || return 1
    installed="$(dirname "$(dirname "$link")")/.my-shell-release"
    [[ -r "$installed" ]] || return 1
    [[ $(cat "$installed") == "$expected $expected_asset" ]] || return 1
    output=$("$entry" --version 2>/dev/null) || return 1
    parsed=$(printf '%s\n' "$output" | sed -n 's/^[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | sed -n '1p')
    [[ "$parsed" == "${expected#v}" ]] || return 1
  done
  return 0
}

# Config backups must remain snapshots when dotfiles are symlinked.
# Dereference existing links (including nested links); preserve a dangling root
# link as there is no content to snapshot. Nested broken/cyclic links fail the
# backup before configuration copying begins.
backup_config_snapshot() {
  if [[ -e "$1" ]]; then
    cp -aL -- "$1" "$2"
  elif [[ -L "$1" ]]; then
    cp -a -- "$1" "$2"
  fi
}
