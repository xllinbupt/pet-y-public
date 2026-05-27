#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

repo="${PET_Y_RELEASE_REPO:-xllinbupt/pet-y-public}"
tag="${PET_Y_RUNTIME_VERSION:-latest}"
app_support="${PET_Y_APP_SUPPORT:-$HOME/Library/Application Support/PetY}"
runtime_dir="${PET_Y_RUNTIME_DIR:-$app_support/Runtime}"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"; [[ -n "${mount_point:-}" && -d "$mount_point" ]] && hdiutil detach "$mount_point" -quiet || true' EXIT

curl_args=(-fL --retry 2 --connect-timeout 20)
if [[ "${PET_Y_BYPASS_PROXY:-0}" == "1" ]]; then
  curl_args+=(--noproxy '*')
fi
if [[ -n "${PET_Y_CURL_OPTS:-}" ]]; then
  # shellcheck disable=SC2206
  extra_curl_args=(${PET_Y_CURL_OPTS})
  curl_args+=("${extra_curl_args[@]}")
fi

# Discover DMG download URL. The asset name carries the version (PetY-<x.y.z>.dmg),
# so for "latest" we ask the GitHub API instead of guessing the filename.
if [[ "$tag" == "latest" ]]; then
  api="https://api.github.com/repos/${repo}/releases/latest"
else
  api="https://api.github.com/repos/${repo}/releases/tags/${tag}"
fi

echo "Looking up Pet Y Runtime release from: $api"
release_json="$tmpdir/release.json"
if ! curl "${curl_args[@]}" -H 'Accept: application/vnd.github+json' "$api" -o "$release_json"; then
  cat <<EOF >&2
Failed to query GitHub releases.

Common causes:
  - Network forces an authenticated proxy. Try:
      PET_Y_BYPASS_PROXY=1 ./scripts/install-runtime.sh
  - GitHub rate limit on unauthenticated requests. Try again in a minute.
  - Custom proxy flags can be passed via PET_Y_CURL_OPTS.
EOF
  exit 1
fi

url="$(grep -E '"browser_download_url".*\.dmg"' "$release_json" \
  | head -1 \
  | sed -E 's/.*"(https[^"]+)".*/\1/')"

if [[ -z "$url" ]]; then
  echo "Release found but no .dmg asset attached." >&2
  exit 1
fi

dmg_path="$tmpdir/PetY.dmg"
echo "Downloading: $url"
if ! curl "${curl_args[@]}" "$url" -o "$dmg_path"; then
  echo "Failed to download Pet Y DMG." >&2
  exit 1
fi

# Mount, copy, unmount.
mount_point="$tmpdir/mount"
mkdir -p "$mount_point"
hdiutil attach "$dmg_path" -nobrowse -readonly -mountpoint "$mount_point" -quiet

if [[ ! -d "$mount_point/PetY.app" ]]; then
  echo "DMG mounted but PetY.app not found inside." >&2
  exit 1
fi

mkdir -p "$runtime_dir"
target="$runtime_dir/PetY.app"
rm -rf "$target.tmp"
cp -R "$mount_point/PetY.app" "$target.tmp"
rm -rf "$target"
mv "$target.tmp" "$target"

hdiutil detach "$mount_point" -quiet
mount_point=""

echo "Installed Runtime to $target"
