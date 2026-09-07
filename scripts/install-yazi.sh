#!/usr/bin/env bash
# Install the latest stable GitHub release without replacing system packages.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib/install-common.sh"
if [[ ${1:-} == --help ]]; then
  echo 'Usage: bash scripts/install-yazi.sh'
  echo 'Install latest stable Yazi from GitHub for Linux/macOS x86_64/ARM64.'
  exit 0
fi
[[ $# == 0 ]] || { echo 'Unknown argument.' >&2; exit 2; }
for cmd in curl jq unzip file; do
  command -v "$cmd" >/dev/null || { echo "Missing dependency: $cmd" >&2; exit 1; }
done
case "$(uname -s)" in
  Linux) system=unknown-linux-musl ;;
  Darwin) system=apple-darwin ;;
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
curl -fsSL --retry 3 --connect-timeout 15 --max-time 120 \
  https://api.github.com/repos/sxyazi/yazi/releases/latest -o "$work/release.json"
jq -e '.draft == false and .prerelease == false' "$work/release.json" >/dev/null
version=$(jq -er '.tag_name' "$work/release.json")
[[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Unexpected stable release tag.' >&2; exit 1; }
asset="yazi-$arch-$system"
if release_is_current "$version" "$asset" yazi ya; then
  echo "Already current: $version ($asset); archive download skipped."
  exit 0
fi
url=$(jq -er --arg name "$asset.zip" '.assets[] | select(.name == $name) | .browser_download_url' "$work/release.json")
digest=$(jq -er --arg name "$asset.zip" '.assets[] | select(.name == $name) | .digest' "$work/release.json")
[[ "$url" == "https://github.com/sxyazi/yazi/releases/download/$version/$asset.zip" ]] || { echo 'Unexpected release URL.' >&2; exit 1; }
[[ "$digest" =~ ^sha256:[a-fA-F0-9]{64}$ ]] || { echo 'Release has no valid SHA-256 digest.' >&2; exit 1; }
INSTALL_STEP=archive-download
echo "Downloading Yazi $version ($system/$arch)..."
curl -fL --retry 3 --connect-timeout 15 --max-time 600 "$url" -o "$work/yazi.zip"
INSTALL_STEP=checksum
actual=$(checksum "$work/yazi.zip")
[[ "${actual%% *}" == "${digest#sha256:}" ]] || { echo 'SHA-256 mismatch; installation stopped.' >&2; exit 1; }
INSTALL_STEP=extract-archive
unzip -q "$work/yazi.zip" -d "$work"
INSTALL_STEP=verify-binary
# Verify the downloaded binary before changing the active command.
for binary in yazi ya; do
  "$work/$asset/$binary" --version
  [[ ! -d "$HOME/.local/bin/$binary" ]] || { echo "$binary entry is a directory; refusing to replace it." >&2; exit 1; }
done
mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
target=$(mktemp -d "$HOME/.local/opt/yazi-$version-XXXXXXXX")
mkdir -p "$target/bin"
for binary in yazi ya; do
  install -m 0755 "$work/$asset/$binary" "$target/bin/$binary"
done
printf '%s %s\n' "$version" "$asset" > "$target/.my-shell-release"
INSTALL_STEP=activate-entry
backup_dir=$(mktemp -d "$HOME/.local/opt/yazi-entry-backup-XXXXXXXX")
for binary in yazi ya; do
  entry="$HOME/.local/bin/$binary"
  if [[ -e "$entry" || -L "$entry" ]]; then
    cp -a "$entry" "$backup_dir/$binary"
  fi
done
stage=$(mktemp -d "$HOME/.local/bin/.yazi-link-XXXXXXXX")
for binary in yazi ya; do
  ln -s "$target/bin/$binary" "$stage/$binary"
  mv -f "$stage/$binary" "$HOME/.local/bin/$binary"
done
rmdir "$stage"
# Yazi launches external fd; a Zsh alias alone does not satisfy that dependency.
export PATH="$HOME/.local/bin:$PATH"
if ! command -v fd >/dev/null && command -v fdfind >/dev/null; then
  if [[ ! -e "$HOME/.local/bin/fd" && ! -L "$HOME/.local/bin/fd" ]]; then
    ln -s "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi
fi
printf 'Installed Yazi %s (yazi + ya) at %s\n' "$version" "$target"
printf 'Previous command entries backed up: %s\n' "$backup_dir"
echo 'Restart Zsh, then run y to browse and follow the directory on exit.'
