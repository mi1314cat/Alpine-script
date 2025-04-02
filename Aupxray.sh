
    VERSION=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ -z "$VERSION" ]]; then
        print_error "无法获取 Xray 最新版本信息"
        exit 1
    fi

    # 设置适合架构的下载链接
    case $CORE_ARCH in
        x86_64)
            ARCH="64"
            ;;
        aarch64)
            ARCH="arm64-v8a"
            ;;
        armv7l)
            ARCH="armv7a"
            ;;
        *)
            print_error "不支持的架构: ${CORE_ARCH}"
            exit 1
            ;;
    esac

    # 下载并解压 Xray
    echo "正在下载 Xray 版本 ${VERSION}..."
    curl -L "https://github.com/XTLS/Xray-core/releases/download/${VERSION}/Xray-linux-${ARCH}.zip" -o Xray-linux-${ARCH}.zip || { print_error "下载 Xray 失败"; exit 1; }
    unzip Xray-linux-${ARCH}.zip || { print_error "解压 Xray 失败"; exit 1; }
    mv xray /usr/local/bin/xrayS || { print_error "移动文件失败"; exit 1; }
    rm -f Xray-linux-${ARCH}.zip  # 清理下载的 zip 文件

    chmod +x /usr/local/bin/xrayS || { print_error "修改权限失败"; exit 1; }


# 执行安装函数
install_xray
rc-service xrayS restart 
rc-service xrayS status
