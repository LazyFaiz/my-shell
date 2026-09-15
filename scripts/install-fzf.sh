#!/usr/bin/env bash
# Install the latest stable GitHub release without replacing system packages.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib/install-common.sh"
if [[ ${1:-} == --help ]]; then
  echo 'Usage: bash scripts/install-fzf.sh'
  echo 'Install latest stable fzf from GitHub for Linux/macOS x86_64/ARM64.'
  exit 0
fi
[[ $# == 0 ]] || { echo 'Unknown argument.' >&2; exit 2; }
for cmd in curl jq tar; do
  command -v "$cmd" >/dev/null || { echo "Missing dependency: $cmd" >&2; exit 1; }
done
case "$(uname -s)" in
  Linux) system=linux ;;
  Darwin) system=darwin ;;
  *) echo 'Supported systems: Linux and macOS.' >&2; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64|amd64) arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
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
github_latest_release junegunn/fzf "$work/release.json"
jq -e '.draft == false and .prerelease == false' "$work/release.json" >/dev/null
version=$(jq -er '.tag_name' "$work/release.json")
[[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Unexpected stable release tag.' >&2; exit 1; }
asset="fzf-${version#v}-${system}_${arch}"
if release_is_current "$version" "$asset" fzf; then
  echo "Already current: $version ($asset); archive download skipped."
  exit 0
fi
url=$(jq -er --arg name "$asset.tar.gz" '.assets[] | select(.name == $name) | .browser_download_url' "$work/release.json")
digest=$(jq -er --arg name "$asset.tar.gz" '.assets[] | select(.name == $name) | .digest' "$work/release.json")
[[ "$url" == "https://github.com/junegunn/fzf/releases/download/$version/$asset.tar.gz" ]] || { echo 'Unexpected release URL.' >&2; exit 1; }
[[ "$digest" =~ ^sha256:[a-fA-F0-9]{64}$ ]] || { echo 'Release has no valid SHA-256 digest.' >&2; exit 1; }
INSTALL_STEP=archive-download
echo "Downloading fzf $version ($system/$arch)..."
curl -fL --retry 3 --connect-timeout 15 --max-time 600 "$url" -o "$work/fzf.tar.gz"
INSTALL_STEP=checksum
actual=$(checksum "$work/fzf.tar.gz")
[[ "${actual%% *}" == "${digest#sha256:}" ]] || { echo 'SHA-256 mismatch; installation stopped.' >&2; exit 1; }
INSTALL_STEP=extract-archive
tar -xzf "$work/fzf.tar.gz" -C "$work"
INSTALL_STEP=verify-binary
# Verify the downloaded binary before changing the active command.
"$work/fzf" --version
"$work/fzf" --zsh >/dev/null
"$work/fzf" --fish >/dev/null
mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
target=$(mktemp -d "$HOME/.local/opt/fzf-$version-XXXXXXXX")
mkdir -p "$target/bin"
install -m 0755 "$work/fzf" "$target/bin/fzf"
"$target/bin/fzf" --version
printf '%s %s\n' "$version" "$asset" > "$target/.my-shell-release"
INSTALL_STEP=activate-entry
entry="$HOME/.local/bin/fzf"
# Do not accidentally move an entire directory at the command path.
[[ ! -d "$entry" ]] || { echo "$entry is a directory; refusing to replace it." >&2; exit 1; }
if [[ -e "$entry" || -L "$entry" ]]; then
  backup_dir=$(mktemp -d "$HOME/.local/opt/fzf-entry-backup-XXXXXXXX")
  cp -a "$entry" "$backup_dir/fzf"
  echo "Previous command backed up: $backup_dir/fzf"
fi
# Stage the link on the same filesystem, then replace only the command entry.
stage=$(mktemp -d "$HOME/.local/bin/.fzf-link-XXXXXXXX")
ln -s "$target/bin/fzf" "$stage/fzf"
mv -f "$stage/fzf" "$entry"
rmdir "$stage"
printf 'Installed %s at %s\n' "$version" "$target"
echo 'In your current shell: export PATH="$HOME/.local/bin:$PATH"; rehash (Zsh) or hash -r (Bash).'
