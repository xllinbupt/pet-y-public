#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

repo="${PET_Y_RELEASE_REPO:-xllinbupt/pet-y-public}"
tag="${PET_Y_RUNTIME_VERSION:-latest}"
arch="$(uname -m)"
asset="PetYDesktop-macos-${arch}.tar.gz"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p bin

if [[ "$tag" == "latest" ]]; then
  url="https://github.com/${repo}/releases/latest/download/${asset}"
else
  url="https://github.com/${repo}/releases/download/${tag}/${asset}"
fi

echo "Downloading Pet Y Runtime: $url"
curl -fL "$url" -o "$tmpdir/$asset"
tar -xzf "$tmpdir/$asset" -C bin
chmod +x bin/PetYDesktop
echo "Installed Runtime to bin/PetYDesktop"
