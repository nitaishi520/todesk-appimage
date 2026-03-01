#!/bin/bash
# ToDesk AppImage 构建脚本
# 版本: 4.8.5.1
# 功能: 自动检测发行版，适配不同系统

set -e

VERSION="4.8.5.1"
GITHUB_USER="nitaishi520"
REPO_NAME="todesk-appimage"
TOOL_NAME="obsolete-appimagetool-x86_64.AppImage"
TOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/13/${TOOL_NAME}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   ToDesk AppImage 构建脚本 v${VERSION}   ${NC}"
echo -e "${GREEN}========================================${NC}"

# ==================== 发行版检测 ====================
detect_distro() {
    echo -e "\n${BLUE}[系统检测] 识别当前发行版...${NC}"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        DISTRO_LIKE=$ID_LIKE
        DISTRO_VERSION=$VERSION_ID
        echo -e "${GREEN}✓ 发行版: $PRETTY_NAME${NC}"
    else
        DISTRO="unknown"
        echo -e "${YELLOW}⚠ 无法识别发行版，使用通用模式${NC}"
    fi

    # 判断发行版家族
    case $DISTRO in
        arch|manjaro|arcolinux|endeavouros)
            DISTRO_FAMILY="arch"
            ;;
        ubuntu|debian|linuxmint|pop|elementary|zorin)
            DISTRO_FAMILY="debian"
            ;;
        fedora|rhel|centos|rocky|alma)
            DISTRO_FAMILY="redhat"
            ;;
        opensuse*|suse)
            DISTRO_FAMILY="suse"
            ;;
        *)
            # 根据 ID_LIKE 判断
            if [[ "$DISTRO_LIKE" == *"arch"* ]]; then
                DISTRO_FAMILY="arch"
            elif [[ "$DISTRO_LIKE" == *"debian"* ]]; then
                DISTRO_FAMILY="debian"
            elif [[ "$DISTRO_LIKE" == *"fedora"* ]]; then
                DISTRO_FAMILY="redhat"
            else
                DISTRO_FAMILY="unknown"
            fi
            ;;
    esac

    echo -e "${GREEN}✓ 发行版家族: $DISTRO_FAMILY${NC}"
}

# ==================== 安装依赖 ====================
install_deps() {
    echo -e "\n${BLUE}[依赖安装] 检查必要工具...${NC}"

    # 基础工具（所有发行版都需要）
    NEEDED_TOOLS="wget ar tar file"
    MISSING_TOOLS=""

    for tool in $NEEDED_TOOLS; do
        if ! command -v $tool &> /dev/null; then
            case $tool in
                ar) MISSING_TOOLS="$MISSING_TOOLS binutils" ;;
                *) MISSING_TOOLS="$MISSING_TOOLS $tool" ;;
            esac
        fi
    done

    if [ -n "$MISSING_TOOLS" ]; then
        echo -e "${YELLOW}缺少工具: $MISSING_TOOLS${NC}"

        case $DISTRO_FAMILY in
            arch)
                echo -e "${BLUE}使用 pacman 安装...${NC}"
                sudo pacman -S --noconfirm $MISSING_TOOLS
                ;;
            debian)
                echo -e "${BLUE}使用 apt 安装...${NC}"
                sudo apt update
                sudo apt install -y $MISSING_TOOLS
                ;;
            redhat)
                echo -e "${BLUE}使用 dnf 安装...${NC}"
                sudo dnf install -y $MISSING_TOOLS
                ;;
            suse)
                echo -e "${BLUE}使用 zypper 安装...${NC}"
                sudo zypper install -y $MISSING_TOOLS
                ;;
            *)
                echo -e "${RED}错误: 无法自动安装依赖，请手动安装: $MISSING_TOOLS${NC}"
                exit 1
                ;;
        esac
    else
        echo -e "${GREEN}✓ 所有必要工具已存在${NC}"
    fi
}

# ==================== 下载工具 ====================
download_tool() {
    echo -e "\n${BLUE}[工具准备] 检查打包工具...${NC}"

    if [ ! -f "$TOOL_NAME" ]; then
        echo -e "${YELLOW}未找到 ${TOOL_NAME}，正在下载...${NC}"

        # 根据发行版选择下载工具
        case $DISTRO_FAMILY in
            arch)
                # Arch 可以用 curl 或 wget
                if command -v curl &> /dev/null; then
                    curl -L -o "$TOOL_NAME" "$TOOL_URL"
                else
                    wget -O "$TOOL_NAME" "$TOOL_URL"
                fi
                ;;
            *)
                # 默认用 wget
                wget -O "$TOOL_NAME" "$TOOL_URL"
                ;;
        esac

        if [ $? -ne 0 ]; then
            echo -e "${RED}下载失败！${NC}"
            exit 1
        fi

        chmod +x "$TOOL_NAME"
        echo -e "${GREEN}✓ 打包工具下载完成${NC}"
    else
        echo -e "${GREEN}✓ 使用已存在的打包工具${NC}"
    fi
}

# ==================== 获取 deb 包 ====================
get_deb_package() {
    echo -e "\n${BLUE}[获取源文件] 下载 ToDesk ${VERSION} deb 包...${NC}"

    # 优先使用本地文件
    if [ -f "todesk-v${VERSION}-amd64.deb" ]; then
        echo -e "${GREEN}使用本地 deb 包: todesk-v${VERSION}-amd64.deb${NC}"
        cp "todesk-v${VERSION}-amd64.deb" "todesk.deb"
    else
        echo -e "${YELLOW}从 GitHub Release 下载...${NC}"
        DOWNLOAD_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}/releases/download/v${VERSION}/todesk-v${VERSION}-amd64.deb"

        case $DISTRO_FAMILY in
            arch)
                if command -v curl &> /dev/null; then
                    curl -L -o "todesk.deb" "$DOWNLOAD_URL"
                else
                    wget -O "todesk.deb" "$DOWNLOAD_URL"
                fi
                ;;
            *)
                wget -O "todesk.deb" "$DOWNLOAD_URL"
                ;;
        esac

        if [ $? -ne 0 ]; then
            echo -e "${RED}下载失败！请检查用户名和 Release。${NC}"
            exit 1
        fi
    fi

    # 验证 deb 包
    echo -e "${YELLOW}验证 deb 包...${NC}"
    if ! file "todesk.deb" | grep -q "Debian binary package"; then
        echo -e "${RED}错误: 不是有效的 deb 包${NC}"
        file "todesk.deb"
        exit 1
    fi
    echo -e "${GREEN}✓ deb 包验证通过${NC}"
}

# ==================== 解压 deb ====================
extract_deb() {
    echo -e "\n${BLUE}[解压] 解压 deb 包...${NC}"

    ar x "todesk.deb"
    echo -e "${GREEN}✓ ar x 完成${NC}"

    # 识别 data 文件
    DATA_FILE=""
    for ext in tar.xz tar.gz tar.bz2 tar.zst; do
        if [ -f "data.${ext}" ]; then
            DATA_FILE="data.${ext}"
            echo -e "${GREEN}找到: ${DATA_FILE}${NC}"
            break
        fi
    done

    if [ -z "$DATA_FILE" ]; then
        echo -e "${RED}错误: 未找到 data 文件${NC}"
        ls -la
        exit 1
    fi

    # 解压 data 文件
    echo -e "${YELLOW}解压 ${DATA_FILE}...${NC}"
    case $DATA_FILE in
        *.tar.xz) tar -xf "$DATA_FILE" ;;
        *.tar.gz) tar -xzf "$DATA_FILE" ;;
        *.tar.bz2) tar -xjf "$DATA_FILE" ;;
        *.tar.zst) tar --zstd -xf "$DATA_FILE" ;;
        *) echo -e "${RED}不支持的格式${NC}"; exit 1 ;;
    esac
    echo -e "${GREEN}✓ 解压完成${NC}"
}

# ==================== 创建启动文件 ====================
create_launcher() {
    echo -e "\n${BLUE}[配置] 创建启动文件...${NC}"

    # 检查主程序
    if [ ! -f "opt/todesk/bin/ToDesk" ]; then
        echo -e "${RED}错误: 未找到主程序 opt/todesk/bin/ToDesk${NC}"
        exit 1
    fi

    # 创建 AppRun
    cat > AppRun << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"

# 发行版特定处理
if [ -f /etc/os-release ]; then
    . /etc/os-release
    export TODESK_DISTRO=$ID
fi

export LD_LIBRARY_PATH="$HERE/usr/lib:$HERE/usr/lib/x86_64-linux-gnu:$HERE/opt/todesk/bin:$LD_LIBRARY_PATH"
export LIBVA_DRIVER_NAME=iHD
export LIBVA_DRIVERS_PATH="$HERE/opt/todesk/bin"
export GDK_BACKEND=x11

# 启动服务
"$HERE/opt/todesk/bin/ToDesk_Service" &
SERVICE_PID=$!
"$HERE/opt/todesk/bin/ToDesk_Session" &
SESSION_PID=$!

sleep 1

# 启动主程序
"$HERE/opt/todesk/bin/ToDesk" "$@"
TODESK_EXIT=$?

# 清理
kill $SERVICE_PID $SESSION_PID 2>/dev/null
exit $TODESK_EXIT
EOF
    chmod +x AppRun
    echo -e "${GREEN}✓ AppRun 创建完成${NC}"

    # 创建 desktop 文件
    cat > todesk.desktop << EOF
[Desktop Entry]
Name=ToDesk
Exec=AppRun
Icon=todesk
Type=Application
Categories=Network;
EOF
    echo -e "${GREEN}✓ desktop 文件创建完成${NC}"

    # 复制图标
    ICON_PATH=$(find . -name "todesk.png" -type f 2>/dev/null | head -1)
    if [ -n "$ICON_PATH" ]; then
        cp "$ICON_PATH" ./todesk.png
        echo -e "${GREEN}✓ 图标已复制${NC}"
    else
        echo -e "${YELLOW}⚠ 未找到图标，使用空白占位${NC}"
        touch todesk.png
    fi
}

# ==================== 打包 AppImage ====================
package_appimage() {
    echo -e "\n${BLUE}[打包] 创建 AppImage...${NC}"

    # 创建 AppDir
    mkdir -p ToDesk.AppDir
    cp -r usr ToDesk.AppDir/ 2>/dev/null || true
    cp -r opt ToDesk.AppDir/ 2>/dev/null || true
    cp AppRun todesk.desktop todesk.png ToDesk.AppDir/

    # 显示 AppDir 内容
    echo "AppDir 结构:"
    ls -la ToDesk.AppDir/

    # 打包
    echo -e "${YELLOW}使用 ${TOOL_NAME} 打包...${NC}"
    ARCH=x86_64 "./$TOOL_NAME" ToDesk.AppDir "ToDesk-v${VERSION}-amd64.AppImage"

    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}========================================${NC}"
        echo -e "${GREEN}✅ 构建成功！${NC}"
        echo -e "${GREEN}生成文件: ToDesk-v${VERSION}-amd64.AppImage${NC}"
        echo -e "${GREEN}文件大小: $(du -h ToDesk-v${VERSION}-amd64.AppImage | cut -f1)${NC}"
        echo -e "${GREEN}SHA256: $(sha256sum ToDesk-v${VERSION}-amd64.AppImage | cut -d' ' -f1)${NC}"
        echo -e "${GREEN}========================================${NC}"
    else
        echo -e "${RED}打包失败！${NC}"
        exit 1
    fi
}

# ==================== 清理 ====================
cleanup() {
    read -p "清理临时文件？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf usr opt ToDesk.AppDir todesk.deb data.* control.tar.* debian-binary AppRun todesk.desktop todesk.png
        echo -e "${GREEN}临时文件已清理${NC}"
    fi
}

# ==================== 主函数 ====================
main() {
    detect_distro
    install_deps
    download_tool
    get_deb_package
    extract_deb
    create_launcher
    package_appimage
    cleanup
}

# 运行主函数
main
