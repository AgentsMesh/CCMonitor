#!/bin/bash
# 将 CCMonitor 打包为 macOS .app bundle
# 用法: ./scripts/build-app.sh [release|debug]

set -euo pipefail

BUILD_CONFIG="${1:-release}"
APP_NAME="CCMonitor"
BUNDLE_ID="com.ccmonitor.app"
APP_DIR="build/${APP_NAME}.app"

echo "🔨 Building ${APP_NAME} (${BUILD_CONFIG})..."

if [ "$BUILD_CONFIG" = "release" ]; then
    swift build -c release
    BINARY_PATH=".build/release/${APP_NAME}"
else
    swift build
    BINARY_PATH=".build/debug/${APP_NAME}"
fi

echo "📦 Creating ${APP_NAME}.app bundle..."

# 清理旧 bundle
rm -rf "${APP_DIR}"

# 创建 .app 目录结构
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# 复制二进制
cp "${BINARY_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# 复制 Bundle 资源（如果存在）
RESOURCE_BUNDLE=$(find .build -name "CCMonitor_CCMonitor.bundle" -type d 2>/dev/null | head -1)
if [ -n "$RESOURCE_BUNDLE" ]; then
    cp -R "${RESOURCE_BUNDLE}" "${APP_DIR}/Contents/Resources/"
    echo "  ✅ Copied resource bundle"
fi

# 复制应用图标
ICON_FILE="Sources/CCMonitor/Resources/AppIcon.icns"
if [ -f "$ICON_FILE" ]; then
    cp "$ICON_FILE" "${APP_DIR}/Contents/Resources/AppIcon.icns"
    echo "  ✅ Copied app icon"
fi

# 创建 Info.plist
cat > "${APP_DIR}/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>CCMonitor</string>
    <key>CFBundleDisplayName</key>
    <string>CCMonitor</string>
    <key>CFBundleIdentifier</key>
    <string>com.ccmonitor.app</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>CCMonitor</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
PLIST

echo "✅ Built ${APP_DIR}"
echo ""
echo "📋 使用方式:"
echo "  1. 运行: open ${APP_DIR}"
echo "  2. 安装到 /Applications: cp -R ${APP_DIR} /Applications/"
echo "  3. 安装后在 Settings 中开启「Launch at Login」即可开机自启动"
echo ""
echo "💡 SMAppService 要求 app 位于 /Applications 目录才能注册开机启动"
