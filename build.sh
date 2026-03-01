#!/bin/bash
# ToDesk AppImage 构建脚本
# 功能：下载官方 deb，解压，配置服务，打包成 AppImage

set -e

VERSION="4.8.5.1"
DEB_URL="https://dl.todesk.com/linux/todesk-v${VERSION}-amd64.deb"

echo "下载 ToDesk ${VERSION} deb 包..."
wget -O todesk.deb $DEB_URL

echo "解压 deb 包..."
ar x todesk.deb
tar -xf data.tar.xz

echo "创建 AppRun（带服务启动）..."
cat > AppRun << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"

export LD_LIBRARY_PATH="$HERE/usr/lib:$HERE/usr/lib/x86_64-linux-gnu:$HERE/opt/todesk/bin:$LD_LIBRARY_PATH"
export LIBVA_DRIVER_NAME=iHD
export LIBVA_DRIVERS_PATH="$HERE/opt/todesk/bin"
export GDK_BACKEND=x11

# 启动后台服务
"$HERE/opt/todesk/bin/ToDesk_Service" &
SERVICE_PID=$!
"$HERE/opt/todesk/bin/ToDesk_Session" &
SESSION_PID=$!

# 启动主程序
"$HERE/opt/todesk/bin/ToDesk" "$@"
TODESK_EXIT=$?

# 退出时清理服务
kill $SERVICE_PID $SESSION_PID 2>/dev/null
exit $TODESK_EXIT
EOF
chmod +x AppRun

echo "创建 desktop 文件..."
cat > todesk.desktop << 'EOF'
[Desktop Entry]
Name=ToDesk
Exec=AppRun
Icon=todesk
Type=Application
Categories=Network;
EOF

echo "复制图标..."
cp usr/share/icons/hicolor/128x128/apps/todesk.png ./

echo "下载 appimagetool..."
wget -O appimagetool https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool

echo "创建 AppDir..."
mkdir -p ToDesk.AppDir
cp -r usr ToDesk.AppDir/
cp -r opt ToDesk.AppDir/
cp AppRun todesk.desktop todesk.png ToDesk.AppDir/

echo "打包成 AppImage..."
./appimagetool ToDesk.AppDir ToDesk-v${VERSION}-amd64.AppImage

echo "完成！生成文件: ToDesk-v${VERSION}-amd64.AppImage"
echo "SHA256: $(sha256sum ToDesk-v${VERSION}-amd64.AppImage)"
