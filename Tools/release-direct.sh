#!/bin/zsh
# Builds the GitHub / direct-download DMG (configuration "Direct": no StoreKit, Pro links to the Mac App Store).
#
#   Tools/release-direct.sh                      # sign with "Developer ID Application", notarize if NOTARY_PROFILE is set
#   NOTARY_PROFILE=hypeshot Tools/release-direct.sh
#   Tools/release-direct.sh CODE_SIGN_IDENTITY="Apple Development: Mohamed Shafi (3V5L6HA7T7)"   # local test build only
#
# Extra arguments are passed to xcodebuild. Output: build/direct/<timestamp>/Hypeshot-<version>.dmg and its sha256.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)"/\1/p' project.yml | head -1)
OUT="build/direct/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT/dmg"

xcodegen generate >/dev/null
xcodebuild -scheme Hypeshot-Direct -configuration Direct -destination 'platform=macOS' \
  -archivePath "$OUT/Hypeshot.xcarchive" archive "$@" | grep -E "error|ARCHIVE" || true

APP="$OUT/Hypeshot.xcarchive/Products/Applications/Hypeshot.app"
[[ -d "$APP" ]] || { echo "archive failed"; exit 1; }

# Self-check: the direct build must be sandboxed and hardened.
codesign -d --entitlements - "$APP" 2>&1 | grep -q "com.apple.security.app-sandbox" || { echo "sandbox entitlement missing"; exit 1; }
codesign -dv "$APP" 2>&1 | grep -q "runtime" || { echo "hardened runtime missing"; exit 1; }

cp -R "$APP" "$OUT/dmg/"
ln -s /Applications "$OUT/dmg/Applications"
DMG="$OUT/Hypeshot-$VERSION.dmg"
hdiutil create -volname "Hypeshot" -srcfolder "$OUT/dmg" -ov -format UDZO "$DMG" >/dev/null

if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  codesign --sign "Developer ID Application" --timestamp "$DMG"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  spctl -a -t open --context context:primary-signature -vv "$DMG"
else
  echo "NOTARY_PROFILE not set: DMG is NOT notarized. Set it up once with:"
  echo "  xcrun notarytool store-credentials hypeshot --apple-id <apple-id> --team-id 2EQKU4538X --password <app-specific-password>"
fi

echo
ls -la "$DMG"
shasum -a 256 "$DMG"
