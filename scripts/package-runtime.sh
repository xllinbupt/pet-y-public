#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

mkdir -p .build/release .build/module-cache dist

build_runtime() {
  local arch="$1"
  local output=".build/release/PetYDesktop-${arch}"
  swiftc \
    -target "${arch}-apple-macosx13.0" \
    -module-cache-path .build/module-cache \
    macos-runtime/PetYDesktop.swift \
    -o "$output" \
    -framework AppKit
  rm -rf ".build/package-${arch}"
  mkdir -p ".build/package-${arch}"
  cp "$output" ".build/package-${arch}/PetYDesktop"
  chmod +x ".build/package-${arch}/PetYDesktop"
  tar -czf "dist/PetYDesktop-macos-${arch}.tar.gz" -C ".build/package-${arch}" PetYDesktop
  echo "Packaged dist/PetYDesktop-macos-${arch}.tar.gz"
}

build_runtime arm64

if swiftc -target x86_64-apple-macosx13.0 -version >/dev/null 2>&1; then
  build_runtime x86_64
fi
