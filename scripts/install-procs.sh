#!/usr/bin/env bash
# Install the latest stable GitHub release without replacing system packages.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib/install-common.sh"
if [[ ${1:-} == --help ]]; then
  echo 'Usage: bash scripts/install-procs.sh'
  echo 'Install latest stable procs from GitHub for Linux/macOS x86_64/ARM64.'
  exit 0
fi
[[ $# == 0 ]] || { echo 'Unknown argument.' >&2; exit 2; }
for cmd in curl jq unzip; do
  command -v "$cmd" >/dev/null || { echo "Missing dependency: $cmd" >&2; exit 1; }
done
case "$(uname -s)" in
  Linux) system=linux ;;
  Darwin) system=mac ;;
  *) echo 'Supported systems: Linux and macOS.' >&2; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64|amd64) arch=x86_64 ;;
  aarch64|arm64) arch=aarch64 ;;
  *) echo 'Supported architectures: x86_64 and ARM64.' >&2; exit 1 ;;
esac
if command -v sha256sum >/dev/null; then
  checksum() { sha256sum "$1"; }
elif command -v shasum >/dev/null; then
  checksum() { shasum -a 256 "$1"; }
else
  echo 'Missing SHA-256 tool (sha256sum or shasum).' >&2; exit 1
fi
work=$(mktemp -d)
INSTALL_STEP=release-metadata
github_latest_release dalance/procs "$work/release.json"
jq -e '.draft == false and .prerelease == false' "$work/release.json" >/dev/null
version=$(jq -er '.tag_name' "$work/release.json")
[[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Unexpected stable release tag.' >&2; exit 1; }
asset="procs-$version-$arch-$system"
if release_is_current "$version" "$asset" procs; then
  echo "Already current: $version ($asset); archive download skipped."
  exit 0
fi
url=$(jq -er --arg name "$asset.zip" '.assets[] | select(.name == $name) | .browser_download_url' "$work/release.json")
digest=$(jq -er --arg name "$asset.zip" '.assets[] | select(.name == $name) | .digest' "$work/release.json")
[[ "$url" == "https://github.com/dalance/procs/releases/download/$version/$asset.zip" ]] || { echo 'Unexpected release URL.' >&2; exit 1; }
[[ "$digest" =~ ^sha256:[a-fA-F0-9]{64}$ ]] || { echo 'Release has no valid SHA-256 digest.' >&2; exit 1; }
INSTALL_STEP=archive-download
echo "Downloading procs $version ($system/$arch)..."
curl -fL --retry 3 --connect-timeout 15 --max-time 600 "$url" -o "$work/procs.zip"
INSTALL_STEP=checksum
actual=$(checksum "$work/procs.zip")
[[ "${actual%% *}" == "${digest#sha256:}" ]] || { echo 'SHA-256 mismatch; installation stopped.' >&2; exit 1; }
INSTALL_STEP=extract-archive
unzip -q "$work/procs.zip" -d "$work"
INSTALL_STEP=verify-binary
# Verify the downloaded binary before changing the active command.
"$work/procs" --version
mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
target=$(mktemp -d "$HOME/.local/opt/procs-$version-XXXXXXXX")
mkdir -p "$target/bin"
install -m 0755 "$work/procs" "$target/bin/procs"
"$target/bin/procs" --version
printf '%s %s\n' "$version" "$asset" > "$target/.my-shell-release"
INSTALL_STEP=activate-entry
entry="$HOME/.local/bin/procs"
# Do not accidentally move an entire directory at the command path.
[[ ! -d "$entry" ]] || { echo "$entry is a directory; refusing to replace it." >&2; exit 1; }
if [[ -e "$entry" || -L "$entry" ]]; then
  backup_dir=$(mktemp -d "$HOME/.local/opt/procs-entry-backup-XXXXXXXX")
  cp -a "$entry" "$backup_dir/procs"
  echo "Previous command backed up: $backup_dir/procs"
fi
# Stage the link on the same filesystem, then replace only the command entry.
stage=$(mktemp -d "$HOME/.local/bin/.procs-link-XXXXXXXX")
ln -s "$target/bin/procs" "$stage/procs"
mv -f "$stage/procs" "$entry"
rmdir "$stage"
printf 'Installed %s at %s\n' "$version" "$target"
echo 'In your current shell: export PATH="$HOME/.local/bin:$PATH"; rehash (Zsh) or hash -r (Bash).'
