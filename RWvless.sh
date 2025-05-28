#!/bin/bash

# 颜色变量定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误：${PLAIN}必须使用root用户运行此脚本！\n"
    exit 1
fi

# 系统信息
SYSTEM_NAME=$(cat /etc/os-release | grep -i pretty_name | cut -d \" -f2)
CORE_ARCH=$(arch)
INSTALL_DIR="/root/catmi/xray"
mkdir -p $INSTALL_DIR
# 介绍信息
clear
cat << "EOF"
                       |\__/,|   (\\
                     _.|o o  |_   ) )
       -------------(((---(((-------------------
                    catmi.xrayS
       -----------------------------------------
EOF
echo -e "${GREEN}System: ${PLAIN}${SYSTEM_NAME}"
echo -e "${GREEN}Architecture: ${PLAIN}${CORE_ARCH}"
echo -e "${GREEN}Version: ${PLAIN}1.0.0"
echo -e "----------------------------------------"

# 打印带颜色的消息
print_info() {
    echo -e "${GREEN}[Info]${PLAIN} $1"
}

print_error() {
    echo -e "${RED}[Error]${PLAIN} $1"
}

# 随机生成 UUID
generate_uuid() {
    cat /proc/sys/kernel/random/uuid
}

# 随机生成 WS 路径
generate_ws_path() {
    echo "/$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 10)"
}
apk add iproute2

# 下载并安装最新 Xray 版本的函数
install_xray() {
    # 获取最新版本号
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
    mv xray $INSTALL_DIR/xrayS || { print_error "移动文件失败"; exit 1; }
    rm -f Xray-linux-${ARCH}.zip  # 清理下载的 zip 文件

    chmod +x $INSTALL_DIR/xrayS || { print_error "修改权限失败"; exit 1; }
}

# 执行安装函数
install_xray

# 创建 openrc 服务文件
cat <<EOF >/etc/init.d/xrayS
#!/sbin/openrc-run

description="XrayS Service"

command="$INSTALL_DIR/xrayS"
command_args="-c $INSTALL_DIR/config.json"
pidfile="/run/xrayS.pid"

depend() {
    need net
}

start_pre() {
    checkpath --directory /run
}

start() {
    ebegin "Starting XrayS"
    start-stop-daemon --start --make-pidfile --pidfile "\${pidfile}" --background --exec "\${command}" -- \${command_args}
    eend \$?
}

stop() {
    ebegin "Stopping XrayS"
    start-stop-daemon --stop --pidfile "\${pidfile}"
    eend \$?
}
EOF

chmod +x /etc/init.d/xrayS
rc-update add xrayS default

# 生成端口的函数
generate_port() {
    local protocol="$1"
    local port user_input

    while :; do
        read -p "请为 ${protocol} 输入监听端口(留空则自动生成): " user_input

        if [[ -z "$user_input" ]]; then
            # 用户没输入，尝试随机找一个未被占用的端口
            while :; do
                port=$((RANDOM % 10001 + 10000))
                if ! ss -tuln | grep -q ":$port\b"; then
                    echo "$port"
                    return 0
                fi
            done
        else
            # 用户输入了端口，判断是否为数字
            if ! [[ "$user_input" =~ ^[0-9]+$ ]]; then
                echo -e "❌ 请输入有效的数字端口号\n"
                continue
            fi

            port=$user_input
            if ! ss -tuln | grep -q ":$port\b"; then
                echo "$port"
                return 0
            else
                echo -e "❌ 端口 $port 被占用，请输入其他端口\n"
            fi
        fi
    done
}

bash <(curl -fsSL https://github.com/mi1314cat/One-click-script/raw/refs/heads/main/domains.sh)

dest_server=$(grep '^dest_server' /root/catmi/dest_server.txt | sed 's/.*[:：]//')

# 生成随机 ID
short_id=$(dd bs=4 count=2 if=/dev/urandom | xxd -p -c 8)

getkey() {
    echo "正在生成私钥和公钥，请妥善保管好..."
    mkdir -p /usr/local/etc/xray

    # 生成密钥并保存到文件
    $INSTALL_DIR/xrayS x25519 > /usr/local/etc/xray/key || {
        print_error "生成密钥失败"
        return 1
    }

    # 提取私钥和公钥
    private_key=$(awk 'NR==1 {print $3}' /usr/local/etc/xray/key)
    public_key=$(awk 'NR==2 {print $3}' /usr/local/etc/xray/key)

    # 保存密钥到文件
    echo "$private_key" > /usr/local/etc/xray/privatekey
    echo "$public_key" > /usr/local/etc/xray/publickey

    # 输出密钥
    KEY=$(cat /usr/local/etc/xray/key)
    print_blue "$KEY"

    echo ""
}
getkey

# 提示输入监听端口号

port=$(generate_port "reality")
VMES_PORT=$(generate_port "vless")

# 获取公网 IP 地址
PUBLIC_IP_V4=$(curl -s https://api.ipify.org)
PUBLIC_IP_V6=$(curl -s https://api64.ipify.org)

# 选择使用哪个公网 IP 地址
echo "请选择要使用的公网 IP 地址:"
echo "1. $PUBLIC_IP_V4"
echo "2. $PUBLIC_IP_V6"
read -p "请输入对应的数字选择 [默认1]: " IP_CHOICE

# 如果没有输入（即回车），则默认选择1
IP_CHOICE=${IP_CHOICE:-1}

# 选择公网 IP 地址
if [ "$IP_CHOICE" -eq 1 ]; then
    PUBLIC_IP=$PUBLIC_IP_V4
    # 设置第二个变量为“空”
    VALUE=""
    link_ip="$PUBLIC_IP"
elif [ "$IP_CHOICE" -eq 2 ]; then
    PUBLIC_IP=$PUBLIC_IP_V6
    # 设置第二个变量为 "[::]:"
    VALUE="[::]:"
    link_ip="[$PUBLIC_IP]"
else
    echo "无效选择，退出脚本"
    exit 1
fi

# 生成 UUID 和 WS 路径
UUID=$(generate_uuid)
WS_PATH=$(generate_ws_path)
WS_PATH1=$(generate_ws_path)
WS_PATH2=$(generate_ws_path)



cat <<EOF > $INSTALL_DIR/config.json
{
    "log": {
        "disabled": false,
        "level": "info",
        "timestamp": true
    },
    "inbounds": [
        {
            "listen": "127.0.0.1",
            "port": 9998,
            "tag": "VLESS-WS",
            "protocol": "VLESS",
            "settings": {
                "clients": [
                    {
                        "id": "${UUID}",
                        "alterId": 64
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "${WS_PATH1}"
                }
            }
        },
        {
           "listen": "127.0.0.1",
            "port": 9999,
            "tag": "VEESS-WS",
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
            "listen": "127.0.0.1",
            "port": 9997,
            "protocol": "vless",
            "settings": {
                "decryption": "none",
                "clients": [
                    {
                        "id": "${UUID}"
                    }
                ]
            },
            "streamSettings": {
                "network": "xhttp",
                "xhttpSettings": {
                    "path": "${WS_PATH2}"
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ]
            },
            "tag": "in1"
        },
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
              "decryption": "none",
              "fallbacks": [
          { 
            
            "dest": 9997
          }
        ]
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
                  "privateKey": "$(cat /usr/local/etc/xray/privatekey)",
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
            "settings": {}
        }
    ]
}
EOF

# 启动XrayS服务
rc-service xrayS start || { print_error "启动 xrayS 服务失败"; exit 1; }
IP=$(wget -qO- --no-check-certificate -U Mozilla https://api.ip.sb/geoip | sed -n 's/.*"ip": *"\([^"]*\).*/\1/p')
green "您的IP为：$IP"
{
    echo "xray 安装完成！"
    echo "服务器地址：${PUBLIC_IP}"
    echo "IP_CHOICE：${IP_CHOICE}"
    echo "端口：${PORT}"
    echo "UUID：${UUID}"
    echo "vless WS 路径：${WS_PATH1}"
    echo "vmess WS 路径：${WS_PATH}"
    echo "xhttp 路径：${WS_PATH2}"
    
} > "/root/catmi/install_info.txt"
bash <(curl -fsSL https://github.com/mi1314cat/Alpine-script/raw/refs/heads/main/xray-nginx.sh)

DOMAIN_LOWER=$(grep '^DOMAIN_LOWER' /root/catmi/DOMAIN_LOWER.txt | sed 's/.*[:：]//')
# 生成分享链接
share_link="
vless://$UUID@$link_ip:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$dest_server&fp=chrome&pbk=$(cat /usr/local/etc/xray/publickey)&sid=$short_id&type=tcp&headerType=none#Reality
vless://$UUID@$DOMAIN_LOWER:443?encryption=none&security=tls&sni=$DOMAIN_LOWER&allowInsecure=1&type=ws&host=$DOMAIN_LOWER&path=${WS_PATH1}#vless-ws-tls
vless://$UUID@$DOMAIN_LOWER:443?encryption=none&security=tls&sni=$DOMAIN_LOWER&type=xhttp&host=$DOMAIN_LOWER&path=${WS_PATH2}&mode=auto#vless-xhttp-tls
vmess://$UUID@$DOMAIN_LOWER:443?encryption=none&security=tls&sni=$DOMAIN_LOWER&allowInsecure=1&type=ws&host=$DOMAIN_LOWER&path=${WS_PATH}#vmess-ws-tls
"
echo "${share_link}" > $INSTALL_DIR/v2ray.txt

# 生成 Clash Meta 配置文件
cat << EOF > $INSTALL_DIR/clash-meta.yaml
  - name: Reality
    port: $port
    server: $PUBLIC_IP
    type: vless
    network: tcp
    udp: true
    tls: true
    servername: $dest_server
    skip-cert-verify: true
    reality-opts:
      public-key: $(cat /usr/local/etc/xray/publickey)
      short-id: $short_id
    uuid: $UUID
    flow: xtls-rprx-vision
    client-fingerprint: chrome
  - name: vmess-ws-tls
    type: vmess
    server: $DOMAIN_LOWER
    port: 443
    cipher: auto
    uuid: $UUID
    alterId: 0
    tls: true
    network: ws
    ws-opts:
      path: ${WS_PATH}
      headers:
        Host: $DOMAIN_LOWER
    servername: $DOMAIN_LOWER
  - name: vless-ws-tls
    type: vless
    server: $DOMAIN_LOWER
    port: 443
    uuid: $UUID
    tls: true
    skip-cert-verify: true
    network: ws
    alterId: 0
    cipher: auto
    ws-opts:
      headers:
        Host: $DOMAIN_LOWER
      path: ${WS_PATH1}
    servername: $DOMAIN_LOWER
EOF

cat << EOF > $INSTALL_DIR/xhttp.json
{
    "downloadSettings": {
      "address": "$IP", 
      "port": $port, 
      "network": "xhttp", 
      "xhttpSettings": {
        "path": "${WS_PATH2}", 
        "mode": "auto"
      },
      "security": "reality", 
      "realitySettings":  {
        "serverName": "$dest_server",
        "fingerprint": "chrome",
        "show": false,
        "publicKey": "$(cat /usr/local/etc/xray/publickey)",
        "shortId": "$short_id",
        "spiderX": ""
      }
    }
  }



{
  "downloadSettings": {
    "address": "$DOMAIN_LOWER", 
    "port": 443, 
    "network": "xhttp", 
    "security": "tls", 
    "tlsSettings": {
      "serverName": "$DOMAIN_LOWER", 
      "allowInsecure": false
    }, 
    "xhttpSettings": {
      "path": "${WS_PATH2}", 
      "mode": "auto"
    }
  }
}
EOF




rc-service xrayS status

cat $INSTALL_DIR/v2ray.txt
