#!/bin/sh
set -e

# Build and package Spektra as a signed, notarized DMG for distribution.
#
# Prerequisites:
#   brew install create-dmg
#   brew install librtlsdr
#
# Environment variables (optional — prompted if missing):
#   APPLE_ID        — your Apple ID email for notarization
#   TEAM_ID         — your Apple Developer team ID (default: 84CC987JU3)
#   APP_PASSWORD    — app-specific password for notarytool
#
# Usage:
#   ./Scripts/create-dmg.sh                   # full build + sign + notarize
#   ./Scripts/create-dmg.sh --skip-notarize   # build + sign only

APP_NAME="Spektra"
BUNDLE_ID="com.subversivesoftware.Spektra"
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"

# ── Auto-increment build number ──────────────────────────────────
PLIST="$PROJECT_DIR/Info.plist"
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
NEW_BUILD=$((CURRENT_BUILD + 1))
echo "==> Incrementing build number: $CURRENT_BUILD → $NEW_BUILD"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$PLIST"

DMG_NAME="Spektra-${VERSION}-b${NEW_BUILD}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"
STAGING_DIR="$BUILD_DIR/dmg-staging"
NOTARIZE_TIMEOUT="15m"

SKIP_NOTARIZE=false
if [ "${1:-}" = "--skip-notarize" ]; then
    SKIP_NOTARIZE=true
fi

# ── Find Developer ID certificate ────────────────────────────────
IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')
if [ -z "$IDENTITY" ]; then
    echo "Error: No 'Developer ID Application' certificate found in keychain."
    if [ "$SKIP_NOTARIZE" = true ]; then
        echo "Continuing with ad-hoc signing..."
        IDENTITY=""
    else
        exit 1
    fi
fi

# ── Notarization credentials ─────────────────────────────────────
if [ "$SKIP_NOTARIZE" = false ] && [ -n "$IDENTITY" ]; then
    TEAM_ID="${TEAM_ID:-84CC987JU3}"

    if [ -z "$APPLE_ID" ]; then
        printf "Apple ID (email) for notarization: "
        read -r APPLE_ID
    fi
    if [ -z "$APP_PASSWORD" ]; then
        printf "App-specific password: "
        stty -echo
        read -r APP_PASSWORD
        stty echo
        echo ""
    fi
fi

cd "$PROJECT_DIR"

# ── Build (arm64) ────────────────────────────────────────────────
echo "==> Building $APP_NAME v$VERSION build $NEW_BUILD (Release, arm64)..."
xcodebuild -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    ARCHS="arm64" \
    ONLY_ACTIVE_ARCH=NO \
    DEVELOPMENT_TEAM="${TEAM_ID:-84CC987JU3}" \
    clean build \
    | tail -5

APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Error: Build failed — $APP_NAME.app not found"
    exit 1
fi

if [ ! -f "$APP_PATH/Contents/MacOS/$APP_NAME" ]; then
    echo "Error: Build produced an app bundle but the binary is missing!"
    echo "Check the full build log for compiler errors."
    exit 1
fi

# ── Embed librtlsdr ──────────────────────────────────────────────
RTLSDR_LIB=$(find /opt/homebrew/lib /usr/local/lib -name "librtlsdr.dylib" 2>/dev/null | head -1)
if [ -n "$RTLSDR_LIB" ]; then
    echo "==> Embedding librtlsdr from $RTLSDR_LIB..."
    FRAMEWORKS_DIR="$APP_PATH/Contents/Frameworks"
    mkdir -p "$FRAMEWORKS_DIR"
    cp "$RTLSDR_LIB" "$FRAMEWORKS_DIR/"

    LIBUSB=$(otool -L "$RTLSDR_LIB" | grep libusb | awk '{print $1}')
    if [ -n "$LIBUSB" ] && [ -f "$LIBUSB" ]; then
        cp "$LIBUSB" "$FRAMEWORKS_DIR/"
        install_name_tool -change "$LIBUSB" "@executable_path/../Frameworks/$(basename "$LIBUSB")" "$FRAMEWORKS_DIR/librtlsdr.dylib"
    fi

    RTLSDR_REF=$(otool -L "$APP_PATH/Contents/MacOS/$APP_NAME" | grep librtlsdr | awk '{print $1}')
    if [ -n "$RTLSDR_REF" ]; then
        install_name_tool -change "$RTLSDR_REF" "@executable_path/../Frameworks/librtlsdr.dylib" "$APP_PATH/Contents/MacOS/$APP_NAME"
    fi

    install_name_tool -id "@executable_path/../Frameworks/librtlsdr.dylib" "$FRAMEWORKS_DIR/librtlsdr.dylib"
fi

# ── Code signing ──────────────────────────────────────────────────
if [ -n "$IDENTITY" ]; then
    echo "==> Signing with: $IDENTITY"
    if [ -d "$APP_PATH/Contents/Frameworks" ]; then
        find "$APP_PATH/Contents/Frameworks" -type f \( -name "*.dylib" -o -name "*.so" \) | while read -r lib; do
            codesign --force --options runtime --sign "$IDENTITY" --timestamp "$lib"
        done
        find "$APP_PATH/Contents/Frameworks" -type d -name "*.framework" | while read -r fw; do
            codesign --force --options runtime --sign "$IDENTITY" --timestamp "$fw"
        done
    fi
    codesign --force --options runtime \
        --sign "$IDENTITY" \
        --timestamp \
        --entitlements "$PROJECT_DIR/Spektra.entitlements" \
        "$APP_PATH"
    echo "==> Verifying signature..."
    codesign --verify --verbose=2 "$APP_PATH"
    echo "    Signature OK"
fi

# ── Verify binary architecture ────────────────────────────────────
ARCHS=$(lipo -archs "$APP_PATH/Contents/MacOS/$APP_NAME" 2>/dev/null || echo "unknown")
echo "    Architecture: $ARCHS"

# ── Create DMG ───────────────────────────────────────────────────
echo "==> Creating DMG..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
rm -f "$DMG_PATH"

if command -v create-dmg >/dev/null 2>&1; then
    ICON_PATH="$APP_PATH/Contents/Resources/AppIcon.icns"
    VOL_ICON_FLAG=""
    if [ -f "$ICON_PATH" ]; then
        VOL_ICON_FLAG="--volicon $ICON_PATH"
    fi

    create-dmg \
        --volname "$APP_NAME" \
        $VOL_ICON_FLAG \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 175 190 \
        --app-drop-link 425 190 \
        --hide-extension "$APP_NAME.app" \
        "$DMG_PATH" \
        "$STAGING_DIR" \
        || true
    if [ ! -f "$DMG_PATH" ]; then
        echo "Error: create-dmg failed to produce $DMG_NAME"
        exit 1
    fi
else
    ln -sf /Applications "$STAGING_DIR/Applications"
    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$STAGING_DIR" \
        -ov -format UDZO \
        "$DMG_PATH"
fi

if [ -n "$IDENTITY" ]; then
    codesign --force --sign "$IDENTITY" --timestamp "$DMG_PATH"
fi

# ── Notarize ─────────────────────────────────────────────────────
if [ "$SKIP_NOTARIZE" = false ] && [ -n "$IDENTITY" ]; then
    echo "==> Submitting for notarization (timeout: ${NOTARIZE_TIMEOUT})..."
    if xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$APP_PASSWORD" \
        --wait \
        --timeout "$NOTARIZE_TIMEOUT"; then

        echo "==> Stapling..."
        xcrun stapler staple "$DMG_PATH"
    else
        echo ""
        echo "WARNING: Notarization did not complete within ${NOTARIZE_TIMEOUT}."
        echo "Check status: xcrun notarytool history --apple-id $APPLE_ID --team-id $TEAM_ID --password YOUR_PASSWORD"
        echo "Then staple:  xcrun stapler staple $DMG_PATH"
    fi
fi

# ── Cleanup ──────────────────────────────────────────────────────
rm -rf "$STAGING_DIR"

echo ""
echo "Done! DMG created at:"
echo "  $DMG_PATH"
echo "  Version: $VERSION (build $NEW_BUILD)"
echo "  Size: $(ls -lh "$DMG_PATH" | awk '{print $5}')"
echo "  Architectures: $ARCHS"
if [ -n "$IDENTITY" ]; then
    echo "  Signed with: $IDENTITY"
fi

echo ""
echo "Build number $NEW_BUILD has been written to Info.plist."

# ── Git tag ──────────────────────────────────────────────────────
TAG="v${VERSION}-b${NEW_BUILD}"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git add "$PLIST"
    git commit -m "Build $NEW_BUILD for v$VERSION distribution" 2>/dev/null || true
    git tag -a "$TAG" -m "$APP_NAME $VERSION build $NEW_BUILD"
    echo "  Tagged: $TAG"
    echo ""
    echo "Push with: git push && git push --tags"
else
    echo "Not in a git repo — skipping tag."
fi
