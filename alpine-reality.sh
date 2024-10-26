#!/bin/sh
# 介绍信息
printf "\e[92m"
printf "                       |\\__/,|   (\\\\ \n"
printf "                     _.|o o  |_   ) )\n"
printf "       -------------(((---(((-------------------\n"
printf "                    alpine-catmi \n"
printf "       -----------------------------------------\n"
printf "\e[0m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"

red() {
    printf "\033[31m\033[01m$1\033[0m\n"
}

green() {
    printf "\033[32m\033[01m$1\033[0m\n"
}

yellow() {
    printf "\033[33m\033[01m$1\033[0m\n"
}

print_error() {
    red "$1"
}

# 获取当前架构
CORE_ARCH=$(uname -m)

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
    echo "正在下载 Xray 版本 ${VERSION}..."
    curl -L "https://github.com/XTLS/Xray-core/releases/download/${VERSION}/Xray-linux-${ARCH}.zip" -o Xray-linux-${ARCH}.zip || { print_error "下载 Xray 失败"; exit 1; }
    unzip Xray-linux-${ARCH}.zip || { print_error "解压 Xray 失败"; exit 1; }
    mv xray /usr/local/bin/xrayR || { print_error "移动文件失败"; exit 1; }
    rm -f Xray-linux-${ARCH}.zip  # 清理下载的 zip 文件

    chmod +x /usr/local/bin/xrayR || { print_error "修改权限失败"; exit 1; }
}

# 执行安装函数
install_xray

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
    
    # 输出选择的域名
    echo "${domains[$random_index]}"
}

# 确保配置目录存在
mkdir -p /root/Xray

# 端口号输入及验证
read -p "请输入reality端口号：" port
sign=false
until $sign; do
    if [ -z "$port" ]; then
        red "错误：端口号不能为空，请输入可用端口号!"
        read -p "请重新输入reality端口号：" port
        continue
    fi
    if ! echo "$port" | grep -qE '^[0-9]+$';then
        red "错误：端口号必须是数字!"
        read -p "请重新输入reality端口号：" port
        continue
    fi
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        red "错误：端口号必须介于1~65535之间!"
        read -p "请重新输入reality端口号：" port
        continue
    fi
    if ! nc -z 127.0.0.1 "$port" 2>/dev/null; then
        green "成功：端口号 $port 可用!"
        sign=true
    else
        red "错误：$port 已被占用！"
        read -p "请重新输入reality端口号：" port
    fi
done

# 生成 UUID 和密钥
UUID=$(cat /proc/sys/kernel/random/uuid)
read -rp "请输入回落域名: " dest_server
[ -z "$dest_server" ] && dest_server=$(random_website)
short_id=$(dd bs=4 count=2 if=/dev/urandom | xxd -p -c 8)
keys=$(/usr/local/bin/xrayR x25519)
private_key=$(echo "$keys" | awk '{print $3}')
public_key=$(echo "$keys" | awk '{print $6}')
green "private_key: $private_key"
green "public_key: $public_key"
green "short_id: $short_id"

# 生成 Xray 配置文件
rm -f /root/Xray/config.json
cat << EOF > /root/Xray/config.json
{
  "inbounds": [
      {
          "listen": "0.0.0.0",
          "port": $port,
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
green "您的IP为：$IP"

# 生成分享链接
share_link="vless://$UUID@$IP:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$dest_server&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#Reality"
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
    port: $port
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

# 启动服务
rc-update add xrayR default
service xrayR start

green "安装完成！"
green "分享链接已保存至 /root/Xray/share-link.txt"
