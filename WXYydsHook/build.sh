#!/bin/bash
# 编译 WXYyds.framework (x86_64) — 轻量：FreezeLock + 聊天内撤回标记
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/Rely/Plugin/WXYyds.framework/Versions/A"
OUT="$OUT_DIR/WXYyds"
SRC_DIR="$ROOT/WXYydsHook"

mkdir -p "$OUT_DIR/Resources"

SOURCES=(
  "$SRC_DIR/WXCommon.mm"
  "$SRC_DIR/WXSwizzle.mm"
  "$SRC_DIR/WXYydsMain.mm"
  "$SRC_DIR/Modules/WXFreezeLock.mm"
  "$SRC_DIR/Modules/WXRevokeMarker.mm"
)

echo "Building WXYyds.framework for x86_64 (stability / FreezeLock) ..."
clang++ -dynamiclib \
    -arch x86_64 \
    -mmacosx-version-min=10.15 \
    -framework Foundation \
    -framework AppKit \
    -framework UserNotifications \
    -I"$SRC_DIR" \
    -std=c++17 \
    -fobjc-arc \
    -O2 \
    -o "$OUT" \
    "${SOURCES[@]}"

cat > "$OUT_DIR/Resources/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.wxyyds.hook</string>
    <key>CFBundleName</key>
    <string>WXYyds</string>
    <key>CFBundleVersion</key>
    <string>0.4.1</string>
    <key>CFBundleExecutable</key>
    <string>WXYyds</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
</dict>
</plist>
PLIST

cd "$ROOT/Rely/Plugin/WXYyds.framework"
ln -sf Versions/A/WXYyds WXYyds 2>/dev/null || true
ln -sf Versions/A/Resources Resources 2>/dev/null || true
cd Versions && ln -sf A Current 2>/dev/null || true

codesign -f -s - "$OUT" 2>/dev/null || true
echo "Built: $OUT"
file "$OUT"
