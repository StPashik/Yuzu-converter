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
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_path/YuzuApp" "$app/Contents/MacOS/YuzuApp"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp LICENSE THIRD_PARTY_NOTICES.md "$app/Contents/Resources/"
cp Resources/YuzuAppIcon.icns "$app/Contents/Resources/Yuzu.icns"
cp Sources/YuzuApp/Resources/YuzuMenuBar.pdf "$app/Contents/Resources/YuzuMenuBar.pdf"
cp -R Sources/YuzuApp/Resources/*.lproj "$app/Contents/Resources/"
/usr/bin/plutil -lint "$app/Contents/Info.plist"
/usr/bin/codesign --force --sign "${YUZU_SIGN_IDENTITY:--}" --options runtime \
  --entitlements Resources/Yuzu.entitlements "$app"
/usr/bin/codesign --verify --strict --verbose=2 "$app"
/usr/bin/lipo "$app/Contents/MacOS/YuzuApp" -verify_arch "$swift_arch"
/usr/bin/ditto -c -k --norsrc --keepParent "$app" "dist/Yuzu-Converter-$app_version-$app_arch.zip"
echo "Built dist/Yuzu-Converter-$app_version-$app_arch.zip"
