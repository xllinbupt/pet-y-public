#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

mkdir -p .build/release .build/module-cache dist

version="$(grep -E 'let PetYRuntimeVersion' macos-runtime/PetYDesktop.swift \
  | sed -E 's/.*"v?([0-9.]+)".*/\1/')"
if [[ -z "$version" ]]; then
  echo "Could not parse PetYRuntimeVersion from macos-runtime/PetYDesktop.swift" >&2
  exit 1
fi

# Codesigning identity. Defaults to the SHA-1 of the active Developer ID
# Application cert; override via env when the cert is rotated.
# Find with: security find-identity -v -p codesigning
sign_identity="${PET_Y_SIGN_IDENTITY:-6E38340374227057310258B1874E005DD6DCA4B1}"
notarize_profile="${PET_Y_NOTARIZE_PROFILE:-petY-notarize}"
skip_notarize="${PET_Y_SKIP_NOTARIZE:-0}"

build_arch() {
  local arch="$1"
  local output=".build/release/PetYDesktop-${arch}"
  swiftc \
    -O \
    -target "${arch}-apple-macosx13.0" \
    -module-cache-path .build/module-cache \
    macos-runtime/PetYDesktop.swift \
    -o "$output" \
    -framework AppKit
  echo "$output"
}

arm64_bin="$(build_arch arm64)"

if swiftc -target x86_64-apple-macosx13.0 -version >/dev/null 2>&1; then
  x86_64_bin="$(build_arch x86_64)"
  universal_bin=".build/release/PetYDesktop-universal"
  lipo -create "$arm64_bin" "$x86_64_bin" -output "$universal_bin"
  inner_bin="$universal_bin"
  echo "Built universal binary (arm64 + x86_64)"
else
  inner_bin="$arm64_bin"
  echo "x86_64 toolchain unavailable; .app will be arm64-only"
fi

./scripts/make-icns.sh public/assets/icons/pet-y-icon-1024.png .build/PetY.icns

app_dir="dist/PetY.app"
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"

cp "$inner_bin" "$app_dir/Contents/MacOS/PetYDesktop"
chmod +x "$app_dir/Contents/MacOS/PetYDesktop"
cp .build/PetY.icns "$app_dir/Contents/Resources/PetY.icns"

sed "s/__VERSION__/${version}/g" macos-runtime/Info.plist \
  > "$app_dir/Contents/Info.plist"

echo "Assembled $app_dir (version $version)"

# --- Codesign ---------------------------------------------------------------
echo "Signing with identity: $sign_identity"
codesign \
  --sign "$sign_identity" \
  --options runtime \
  --timestamp \
  --force \
  "$app_dir"
codesign --verify --verbose=2 "$app_dir"
echo "Signed and verified $app_dir"

# --- DMG packaging ----------------------------------------------------------
dmg_path="dist/PetY-${version}.dmg"
staging=".build/dmg-staging"
rm -rf "$staging"
mkdir -p "$staging"
cp -R "$app_dir" "$staging/"
ln -s /Applications "$staging/Applications"

rm -f "$dmg_path"
hdiutil create \
  -volname "Pet Y" \
  -srcfolder "$staging" \
  -ov \
  -format UDZO \
  "$dmg_path" >/dev/null
echo "Built $dmg_path"

# Sign the DMG so Gatekeeper trusts the wrapper before staple lands.
codesign --sign "$sign_identity" --timestamp --force "$dmg_path"

# --- Notarize ---------------------------------------------------------------
if [[ "$skip_notarize" == "1" ]]; then
  echo "PET_Y_SKIP_NOTARIZE=1; skipping notarization and staple."
  echo "Final artifact: $dmg_path (unsigned-by-Apple, will trip Gatekeeper on first launch)"
  exit 0
fi

echo "Submitting $dmg_path to Apple notary service (this usually takes 2-15 minutes)..."
xcrun notarytool submit "$dmg_path" \
  --keychain-profile "$notarize_profile" \
  --wait

# Staple the notary ticket into the DMG (and the .app inside).
xcrun stapler staple "$dmg_path"
xcrun stapler validate "$dmg_path"

# Re-staple the .app inside the staging copy so future runs of the binary
# directly out of dist/PetY.app also pass Gatekeeper.
xcrun stapler staple "$app_dir" || true

echo ""
echo "Done. Final artifact: $dmg_path"
ls -lh "$dmg_path"
