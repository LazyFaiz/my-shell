#!/usr/bin/env bash
# Install the latest stable GitHub release without replacing system packages.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib/install-common.sh"
if [[ ${1:-} == --help ]]; then
  echo 'Usage: bash scripts/install-fish.sh'
  echo 'Install latest stable Fish from GitHub for Linux/macOS x86_64/ARM64.'
  exit 0
fi
[[ $# == 0 ]] || { echo 'Unknown argument.' >&2; exit 2; }
for cmd in curl jq tar; do
  command -v "$cmd" >/dev/null || { echo "Missing dependency: $cmd" >&2; exit 1; }
done
case "$(uname -s)" in
  Linux) system=linux ;;
  Darwin) system=macos ;;
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
github_latest_release fish-shell/fish-shell "$work/release.json"
jq -e '.draft == false and .prerelease == false' "$work/release.json" >/dev/null
version=$(jq -er '.tag_name' "$work/release.json")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Unexpected stable release tag.' >&2; exit 1; }
if [[ $system == linux ]]; then
  command -v xz >/dev/null || { echo 'Missing dependency: xz' >&2; exit 1; }
  asset="fish-$version-linux-$arch.tar.xz"
else
  command -v unzip >/dev/null || { echo 'Missing dependency: unzip' >&2; exit 1; }
  asset="fish-$version.app.zip"
fi
if release_is_current "$version" "$asset" fish fish_indent fish_key_reader; then
  echo "Already current: $version ($asset); archive download skipped."
  exit 0
fi
url=$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .browser_download_url' "$work/release.json")
digest=$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .digest' "$work/release.json")
[[ "$url" == "https://github.com/fish-shell/fish-shell/releases/download/$version/$asset" ]] || { echo 'Unexpected release URL.' >&2; exit 1; }
[[ "$digest" =~ ^sha256:[a-fA-F0-9]{64}$ ]] || { echo 'Release has no valid SHA-256 digest.' >&2; exit 1; }
INSTALL_STEP=archive-download
echo "Downloading Fish $version ($system/$arch)..."
curl -fL --retry 3 --connect-timeout 15 --max-time 600 "$url" -o "$work/archive"
INSTALL_STEP=checksum
actual=$(checksum "$work/archive")
[[ "${actual%% *}" == "${digest#sha256:}" ]] || { echo 'SHA-256 mismatch; installation stopped.' >&2; exit 1; }
INSTALL_STEP=extract-archive
if [[ $system == linux ]]; then
  tar -xJf "$work/archive" -C "$work"
  prefix="$work/prefix"
  mkdir -p "$prefix/bin"
  install -m 0755 "$work/fish" "$prefix/bin/fish"
  ln -s fish "$prefix/bin/fish_indent"
  ln -s fish "$prefix/bin/fish_key_reader"
else
  unzip -q "$work/archive" -d "$work"
  prefix="$work/fish-$version.app/Contents/Resources/base/usr/local"
fi
INSTALL_STEP=verify-binary
# Verify the downloaded binary before changing the active command.
for binary in fish fish_indent fish_key_reader; do
  "$prefix/bin/$binary" --version
  [[ ! -d "$HOME/.local/bin/$binary" ]] || { echo "$binary entry is a directory." >&2; exit 1; }
done
"$prefix/bin/fish" --no-config -c 'functions -q fish_add_path; and functions -q fish_vi_key_bindings'
mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
target=$(mktemp -d "$HOME/.local/opt/fish-$version-XXXXXXXX")
cp -a "$prefix/." "$target/"
printf '%s %s\n' "$version" "$asset" > "$target/.my-shell-release"
INSTALL_STEP=activate-entry
backup_dir=$(mktemp -d "$HOME/.local/opt/fish-entry-backup-XXXXXXXX")
for binary in fish fish_indent fish_key_reader; do
  entry="$HOME/.local/bin/$binary"
  if [[ -e "$entry" || -L "$entry" ]]; then cp -a "$entry" "$backup_dir/$binary"; fi
done
stage=$(mktemp -d "$HOME/.local/bin/.fish-link-XXXXXXXX")
for binary in fish fish_indent fish_key_reader; do
  ln -s "$target/bin/$binary" "$stage/$binary"
  mv -f "$stage/$binary" "$HOME/.local/bin/$binary"
done
rmdir "$stage"
printf 'Previous command entries backed up: %s\n' "$backup_dir"
printf 'Installed %s at %s\n' "$version" "$target"
echo 'Default login shell unchanged. In Bash/Zsh: export PATH="$HOME/.local/bin:$PATH"; rehash (Zsh) or hash -r (Bash).'
