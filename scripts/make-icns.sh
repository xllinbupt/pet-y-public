#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

source_png="${1:-public/assets/icons/pet-y-icon-1024.png}"
output_icns="${2:-.build/PetY.icns}"

if [[ ! -f "$source_png" ]]; then
  echo "Source icon not found: $source_png" >&2
  exit 1
fi

iconset_dir="$(mktemp -d)/PetY.iconset"
mkdir -p "$iconset_dir"

sips -z 16 16     "$source_png" --out "$iconset_dir/icon_16x16.png"      >/dev/null
sips -z 32 32     "$source_png" --out "$iconset_dir/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     "$source_png" --out "$iconset_dir/icon_32x32.png"      >/dev/null
sips -z 64 64     "$source_png" --out "$iconset_dir/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   "$source_png" --out "$iconset_dir/icon_128x128.png"    >/dev/null
sips -z 256 256   "$source_png" --out "$iconset_dir/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$source_png" --out "$iconset_dir/icon_256x256.png"    >/dev/null
sips -z 512 512   "$source_png" --out "$iconset_dir/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$source_png" --out "$iconset_dir/icon_512x512.png"    >/dev/null
cp "$source_png"                       "$iconset_dir/icon_512x512@2x.png"

mkdir -p "$(dirname "$output_icns")"
iconutil -c icns "$iconset_dir" -o "$output_icns"
echo "Built $output_icns"
