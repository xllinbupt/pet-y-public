#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

mkdir -p .build/module-cache

swiftc \
  -module-cache-path .build/module-cache \
  macos-runtime/PetYDesktop.swift \
  -o .build/PetYDesktop \
  -framework AppKit

bundle_id="${PET_Y_BUNDLE_ID:-com.xllinbupt.PetY}"
sign_identity="${PET_Y_SIGN_IDENTITY:-6E38340374227057310258B1874E005DD6DCA4B1}"

if security find-identity -v -p codesigning 2>/dev/null \
   | grep -qE "(^| )${sign_identity}( |\")"; then
  codesign \
    --sign "$sign_identity" \
    --identifier "$bundle_id" \
    --options runtime \
    --force \
    .build/PetYDesktop
  echo "Signed .build/PetYDesktop with $sign_identity ($bundle_id)"
else
  echo "Signing identity $sign_identity not found; leaving .build/PetYDesktop ad-hoc signed."
  echo "Keychain prompts will reappear after each rebuild until a stable identity is used."
fi
