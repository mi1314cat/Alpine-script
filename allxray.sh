#!/bin/sh

# 定义颜色代码
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"

# 定义彩色输出函数
print_color() {
    printf "\033[3%sm$1\033[0m\n" "$2"
}

print_red() {
    print_color "red" "$1"
}

print_green() {
    print_color "green" "$1"
}

print_yellow() {
    print_color "yellow" "$1"
}

# 定义错误输出函数
print_error() {
    print_red "错误：$1"
}

# 获取当前架构
CORE_ARCH=$(uname -m)

# 安装 Xray
install_xray() {
    # 获取最新版本号
    VERSION=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$VERSION" ]; then
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
    print_yellow "正在下载 Xray 版本 ${VERSION}..."
    curl -L "https://github.com/XTLS/Xray-core/releases/download/${VERSION}/Xray-linux-${ARCH}.zip" -o Xray-linux-${ARCH}.zip || { print_error "下载 Xray 失败"; exit 1; }
    unzip Xray-linux-${ARCH}.zip || { print_error "解压 Xray 失败"; exit 1; }
    mv xray /usr/local/bin/xrayR || { print_error "移动文件失败"; exit 1; }
    rm -f Xray-linux-${ARCH}.zip  # 清理下载的 zip 文件

    chmod +x /usr/local/bin/xrayR || { print_error "修改权限失败"; exit 1; }
}

# 执行安装函数
install_xray
apk add iproute2

# 创建 openrc 服务文件
cat <<EOF >/etc/init.d/xrayR
#!/sbin/openrc-run

description="XrayR Service"

command="/usr/local/bin/xrayR"
command_args="-c /root/Xray/config.json"
pidfile="/run/xrayR.pid"

depend() {
    need net
}

start_pre() {
    checkpath --directory /run
}

start() {
    ebegin "Starting XrayR"
    start-stop-daemon --start --make-pidfile --pidfile "\${pidfile}" --background --exec "\${command}" -- \${command_args}
    eend \$?
}

stop() {
    ebegin "Stopping XrayR"
    start-stop-daemon --stop --pidfile "\${pidfile}"
    eend \$?
}
EOF
chmod +x /etc/init.d/xrayR

# 随机生成域名
random_website() {
    domains=(
        "one-piece.com"
        "lovelive-anime.jp"
        "swift.com"
        "academy.nvidia.com"
        "cisco.com"
        "samsung.com"
        "amd.com"
        "apple.com"
        "music.apple.com"
        "amazon.com"
        "fandom.com"
        "tidal.com"
        "zoro.to"
        "pixiv.co.jp"
        "mora.jp"
        "j-wave.co.jp"
        "dmm.com"
        "booth.pm"
        "ivi.tv"
        "leercapitulo.com"
        "sky.com"
        "itunes.apple.com"
        "download-installer.cdn.mozilla.net"
        "images-na.ssl-images-amazon.com"
        "swdist.apple.com"
        "swcdn.apple.com"
        "updates.cdn-apple.com"
        "mensura.cdn-apple.com"
        "osxapps.itunes.apple.com"
        "aod.itunes.apple.com"
        "www.google-analytics.com"
        "dl.google.com"
    )

    total_domains=${#domains[@]}
    random_index=$((RANDOM % total_domains))
    echo "${domains[$random_index]}"
}

# 确保配置目录存在
mkdir -p /root/Xray

# 随机生成 UUID
generate_uuid() {
    cat /proc/sys/kernel/random/uuid
}

# 随机生成 WS 路径
generate_ws_path() {
    echo "/$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 10)"
}
apk add iproute2



# 生成随机端口
generate_random_port() {
    while :; do
        port=$((RANDOM % 10001 + 10000))
        read -p "请为 $1 输入监听端口(默认为随机生成): " user_input
        port=${user_input:-$port}
        if ! ss -tuln | grep -q ":$port\b"; then
            echo "$port"
            return
        fi
        print_error "端口 $port 被占用，请输入其他端口"
    done
}
reality_PORT=$(generate_random_port "reality")
SOCKS_PORT=$(generate_random_port "socks5")
VMES_PORT=$(generate_random_port "vmess")
# SOCKS 配置
DEFAULT_SOCKS_USERNAME="userb"
DEFAULT_SOCKS_PASSWORD="passwordb"
read -p "SOCKS 账号 (默认 $DEFAULT_SOCKS_USERNAME): " SOCKS_USERNAME
SOCKS_USERNAME=${SOCKS_USERNAME:-$DEFAULT_SOCKS_USERNAME}
read -p "SOCKS 密码 (默认 $DEFAULT_SOCKS_PASSWORD): " SOCKS_PASSWORD
SOCKS_PASSWORD=${SOCKS_PASSWORD:-$DEFAULT_SOCKS_PASSWORD}
# 生成 UUID 和 WS 路径
UUID=$(generate_uuid)
WS_PATH=$(generate_ws_path)



# 提示输入回落域名
read -rp "请输入回落域名: " dest_server
[ -z "$dest_server" ] && dest_server=$(random_website)

# 生成随机 ID
short_id=$(dd bs=4 count=2 if=/dev/urandom | xxd -p -c 8)

# 生成密钥
keys=$(/usr/local/bin/xrayR x25519)
private_key=$(echo "$keys" | awk '{print $3}')
public_key=$(echo "$keys" | awk '{print $6}')

# 输出密钥和 ID
print_green "private_key: $private_key"
print_green "public_key: $public_key"
print_green "short_id: $short_id"

# 生成 Xray 配置文件
rm -f /root/Xray/config.json
cat << EOF > /root/Xray/config.json
{
  "inbounds": [
    {
      "port": ${VMES_PORT},
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "alterId": 64
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "${WS_PATH}"
        }
      }
    },
    {
      "listen": "::",
      "port": ${SOCKS_PORT},
      "protocol": "socks",
      "settings": {
        "auth": "password",
        "accounts": [
          {
            "user": "${SOCKS_USERNAME}",
            "pass": "${SOCKS_PASSWORD}"
          }
        ]
      }
    },
    {
      "listen": "0.0.0.0",
      "port": ${reality_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": true,
          "dest": "$dest_server:443",
          "xver": 0,
          "serverNames": [
            "$dest_server"
          ],
          "privateKey": "$private_key",
          "minClientVer": "",
          "maxClientVer": "",
          "maxTimeDiff": 0,
          "shortIds": [
            "$short_id"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ],
  "policy": {
    "handshake": 4,
    "connIdle": 300,
    "uplinkOnly": 2,
    "downlinkOnly": 5,
    "statsUserUplink": false,
    "statsUserDownlink": false,
    "bufferSize": 1024
  }
}
EOF

# 获取外部 IP
IP=$(wget -qO- --no-check-certificate -U Mozilla https://api.ip.sb/geoip | sed -n 's/.*"ip": *"\([^"]*\).*/\1/p')
print_green "您的IP为：$IP"

# 生成分享链接
share_link="vless://$UUID@$IP:${reality_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$dest_server&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#Reality"
echo "${share_link}" > /root/Xray/share-link.txt

# 生成 Clash Meta 配置文件
cat << EOF > /root/Xray/clash-meta.yaml
port: 7890
socks-port: 7891
allow-lan: true
mode: Rule
log-level: info
external-controller: :9090
dns:
    enable: true
    ipv6: false
    default-nameserver: [223.5.5.5, 119.29.29.29]
    enhanced-mode: redir
    fake-ip-filter: ["geoip:cn","http://geosite.geosite.dat"]
proxy-groups:
  - name: "Auto"
    type: url-test
    url: "http://www.gstatic.com/generate_204"
    interval: 300
    proxies:
      - "自定义"
      - "clash"
      - "gfw"
  - name: "自定义"
    type: select
    proxies:
      - "Auto"
      - "clash"
      - "gfw"
proxies:
  - name: "gfw"
    type: vless
    server: "$IP"
    port: ${reality_PORT}
    uuid: "$UUID"
    alterId: 0
    cipher: "none"
    tls: true
    skip-cert-verify: true
    server-name: "$dest_server"
    network: "tcp"
    tcp-options:
      type: "none"
    udp: true
    # 这里可以添加其他的设置...
EOF
# 保存信息到文件
OUTPUT_DIR="/root/xray"
mkdir -p "$OUTPUT_DIR"
{
    echo "xray 安装完成！"
    echo "服务器地址：${PUBLIC_IP}"
    echo "vmess 端口：${VMES_PORT}"
    echo "vmess UUID：${UUID}"
    echo "vmess WS 路径：${WS_PATH}"
    echo "socks5 端口：${SOCKS_PORT}"
    echo "socks5 账号：${SOCKS_USERNAME}"
    echo "socks5 密码：${SOCKS_PASSWORD}"
    echo "配置文件已保存到：/root/xray/xrayR.txt"
} > "$OUTPUT_DIR/xrayS.txt"

print_info "xray 安装完成！"
print_info "服务器地址：${PUBLIC_IP}"
print_info "vmess 端口：${VMES_PORT}"
print_info "vmess UUID：${UUID}"
print_info "vmess WS 路径：${WS_PATH}"
print_info "socks5 端口：${SOCKS_PORT}"
print_info "socks5 账号：${SOCKS_USERNAME}"
print_info "socks5 密码：${SOCKS_PASSWORD}"
print_info "配置文件已保存到：/root/xray"
# 启动服务
rc-update add xrayR default
service xrayR start

print_green "安装完成！"
