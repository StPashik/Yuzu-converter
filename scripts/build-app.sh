#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
app_arch="${1:-arm64}"
case "$app_arch" in
  arm64) swift_arch=arm64 ;;
  x64) swift_arch=x86_64 ;;
  *) echo 'Usage: scripts/build-app.sh arm64|x64' >&2; exit 2 ;;
esac

app_version=$(/usr/bin/plutil -extract version raw -o - package.json)
plist_version=$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - Resources/Info.plist)
test "$app_version" = "$plist_version"
build_path="$project_root/.build/release-$app_arch"
export CLANG_MODULE_CACHE_PATH="$build_path/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$build_path/ModuleCache"
swift build -c release --arch "$swift_arch" --scratch-path "$build_path"
binary_path=$(swift build -c release --arch "$swift_arch" --scratch-path "$build_path" --show-bin-path)

# Only this build's staging directory is replaced; installed apps are never touched.
stage="$project_root/dist/stage-$app_arch"
rm -rf "$stage"
app="$stage/Yuzu Converter.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Frameworks"
cp "$binary_path/YuzuApp" "$app/Contents/MacOS/YuzuApp"
cp Resources/Info.plist "$app/Contents/Info.plist"
# The public Latest release switches its signed feed and archives together, independent of branch pushes.
/usr/libexec/PlistBuddy -c "Set :SUFeedURL https://github.com/StPashik/Yuzu-converter/releases/latest/download/appcast-$app_arch.xml" "$app/Contents/Info.plist"
cp LICENSE THIRD_PARTY_NOTICES.md "$app/Contents/Resources/"
cp Resources/YuzuAppIcon.icns "$app/Contents/Resources/Yuzu.icns"
cp Sources/YuzuApp/Resources/YuzuMenuBar.pdf "$app/Contents/Resources/YuzuMenuBar.pdf"
cp -R Sources/YuzuApp/Resources/*.lproj "$app/Contents/Resources/"
media="$project_root/.build/media-$app_arch/Tools"
python3 scripts/build-media.py "$app_arch" --reuse
mkdir -p "$app/Contents/Helpers" "$app/Contents/Resources/Media-Licenses"
cp "$media/ffmpeg" "$media/ffprobe" "$app/Contents/Helpers/"
cp Resources/Media-sources.json "$app/Contents/Resources/"
cp docs/licenses/FFmpeg-* docs/licenses/LAME-* docs/licenses/libvpx-* docs/licenses/Opus-* "$app/Contents/Resources/Media-Licenses/"
# Helpers inherit only the parent Sandbox; selected files travel as open descriptors.
for tool in ffmpeg ffprobe; do
  /usr/bin/lipo "$app/Contents/Helpers/$tool" -verify_arch "$swift_arch"
  /usr/bin/codesign --force --sign "${YUZU_SIGN_IDENTITY:--}" --options runtime \
    --identifier "com.stpashik.yuzu-converter.$tool" --entitlements Resources/MediaHelper.entitlements "$app/Contents/Helpers/$tool"
done
sparkle_source="$build_path/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
sparkle="$app/Contents/Frameworks/Sparkle.framework"
/usr/bin/ditto "$sparkle_source" "$sparkle"
cp "$build_path/artifacts/sparkle/Sparkle/LICENSE" "$app/Contents/Resources/Sparkle-LICENSE.txt"
# Sign nested tools before their enclosing framework; --deep would lose service-specific entitlements.
for component in XPCServices/Installer.xpc XPCServices/Downloader.xpc Autoupdate Updater.app; do
  /usr/bin/codesign --force --sign "${YUZU_SIGN_IDENTITY:--}" --options runtime \
    --preserve-metadata=entitlements "$sparkle/Versions/B/$component"
done
/usr/bin/codesign --force --sign "${YUZU_SIGN_IDENTITY:--}" --options runtime "$sparkle"
app_entitlements="$build_path/Yuzu.entitlements"
cp Resources/Yuzu.entitlements "$app_entitlements"
if [ "${YUZU_SIGN_IDENTITY:--}" = '-' ]; then
  # Ad-hoc signatures have no Team ID for dynamic-framework library validation.
  /usr/libexec/PlistBuddy -c 'Add :com.apple.security.cs.disable-library-validation bool true' "$app_entitlements"
fi
/usr/bin/plutil -lint "$app/Contents/Info.plist"
/usr/bin/codesign --force --sign "${YUZU_SIGN_IDENTITY:--}" --options runtime \
  --entitlements "$app_entitlements" "$app"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app"
/usr/bin/lipo "$app/Contents/MacOS/YuzuApp" -verify_arch "$swift_arch"
/usr/bin/ditto -c -k --norsrc --keepParent "$app" "dist/Yuzu-Converter-$app_version-$app_arch.zip"
echo "Built dist/Yuzu-Converter-$app_version-$app_arch.zip"
