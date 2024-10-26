根据您的要求，我已经将脚本修改适配为 Alpine Linux 系统。以下是修改后的脚本：

```bash
#!/bin/bash
# REALITY一键安装脚本
printf "\e[92m"
printf "                       |\\__/,|   (\\\\ \n"
printf "                     _.|o o  |_   ) )\n"
printf "       -------------(((---(((-------------------\n"
printf "                 catmi.REALITY-xray \n"
printf "       -----------------------------------------\n"
printf "\e[0m"

RED="\033[31m"      # Error message
GREEN="\033[32m"    # Success message
YELLOW="\033[33m"   # Warning message
BLUE="\033[36m"     # Info message
PLAIN='\033[0m'

NAME="xray"
CONFIG_FILE="/etc/${NAME}/config.json"
SERVICE_FILE="/etc/init.d/${NAME}"

colorEcho() {
    echo -e "${1}${@:2}${PLAIN}"
}

checkSystem() {
    if [[ $(id -u) -ne 0 ]]; then
        colorEcho $RED " 请以root身份执行该脚本"
        exit 1
    fi

    if ! command -v apk &> /dev/null; then
        colorEcho $RED " 不受支持的Linux系统"
        exit 1
    fi

    apk update &> /dev/null
}

status() {
    export PATH=/usr/local/bin:$PATH
    cmd="$(command -v xray)"
    if [[ "$cmd" = "" ]]; then
        echo 0
        return
    fi
    if [[ ! -f $CONFIG_FILE ]]; then
        echo 1
        return
    fi
    port=`grep -o '"port": [0-9]*' $CONFIG_FILE | awk '{print $2}'`
    if [[ -n "$port" ]]; then
        res=`ss -ntlp| grep ${port} | grep xray`
        if [[ -z "$res" ]]; then
            echo 2
        else
            echo 3
        fi
    else
        echo 2
    fi
}

statusText() {
    res=`status`
    case $res in
        2)
            echo -e ${GREEN}已安装xray${PLAIN} ${RED}未运行${PLAIN}
            ;;
        3)
            echo -e ${GREEN}已安装xray${PLAIN} ${GREEN}正在运行${PLAIN}
            ;;
        *)
            echo -e ${RED}未安装xray${PLAIN}
            ;;
    esac
}

preinstall() {
    apk upgrade &> /dev/null
    echo ""
    echo "安装必要软件，请等待..."
    apk add curl openssl qrencode jq &> /dev/null
    echo ""
}

# 定义函数，返回随机选择的域名
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
    echo "${domains[random_index]}"
}

# 安装 Xray内核
installXray() {
    echo ""
    echo "正在安装Xray..."
    apk add xray &> /dev/null
    colorEcho $BLUE "xray内核已安装完成"
    sleep 5
}

# 更新 Xray内核
updateXray() {
    echo ""
    echo "正在更新Xray..."
    apk upgrade xray &> /dev/null
    colorEcho $BLUE "xray内核已更新完成"
    sleep 5
}

removeXray() {
    echo ""
    echo "正在卸载Xray..."
    apk del xray &> /dev/null
    rm -rf /etc/${NAME} /var/log/${NAME} /usr/local/etc/${NAME} /usr/local/share/${NAME} &> /dev/null
    colorEcho $RED "已完成xray卸载"
    sleep 5
}

# 填写或生成 UUID
getuuid() {
    echo ""
    echo "正在生成UUID..."
    /usr/local/bin/xray uuid > /usr/local/etc/xray/uuid
    USER_UUID=`cat /usr/local/etc/xray/uuid`
    colorEcho $BLUE "UUID：$USER_UUID"
    echo ""
}

# 指定节点名称
getname() {
    read -p "请输入您的节点名称，如果留空将保持默认：" USER_NAME
    [[ -z "$USER_NAME" ]] && USER_NAME="Reality-xray"
    colorEcho $BLUE "节点名称：$USER_NAME"
    echo "$USER_NAME" > /usr/local/etc/xray/name
    echo ""
}

# 生成私钥和公钥
getkey() {
    echo "正在生成私钥和公钥，请妥善保管好..."
    /usr/local/bin/xray x25519 > /usr/local/etc/xray/key
    private_key=$(cat /usr/local/etc/xray/key | head -n 1 | awk '{print $3}')
    public_key=$(cat /usr/local/etc/xray/key | sed -n '2p' | awk '{print $3}')
    echo "$private_key" > /usr/local/etc/xray/privatekey
    echo "$public_key" > /usr/local/etc/xray/publickey
    KEY=`cat /usr/local/etc/xray/key`
    colorEcho $BLUE "$KEY"
    echo ""
}

getip() {
    # 尝试获取 IP 地址
    LOCAL_IPv4=$(curl -s -4 https://api.ipify.org)
    LOCAL_IPv6=$(curl -s -6 https://api64.ipify.org)

    # 检查 IPv是否存在且合法
    if [[ -n "$LOCAL_IPv4" && "$LOCAL_IPv4" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # 检查 IPv6 是否存在且合法
        if [[ -n "$LOCAL_IPv6" && "$LOCAL_IPv6" =~ ^([0-9a-fA-F:]+)$ ]]; then
            colorEcho $YELLOW "本机 IPv4 地址："$LOCAL_IPv4""
            colorEcho $YELLOW "本机 IPv6 地址："$LOCAL_IPv6""
            read -p "请确定你的节点ip，默认ipv4（0：ipv4；1：ipv6）:" USER_IP
            if [[ $USER_IP == 1 ]]; then
                LOCAL_IP=$LOCAL_IPv6
                colorEcho $BLUE "节点ip："$LOCAL_IP""
            else
                LOCAL_IP=$LOCAL_IPv4
                colorEcho $BLUE "节点ip："$LOCAL_IP""
            fi
        else
            colorEcho $YELLOW "本机仅有 IPv4 地址："$LOCAL_IPv4""
            LOCAL_IP=$LOCAL_IPv4
            colorEcho $BLUE "节点ip："$LOCAL_IP""
        fi
    else
        if [[ -n "$LOCAL_IPv6" && "$LOCAL_IPv6" =~ ^([0-9a-fA-F:]+)$ ]]; then
            colorEcho $YELLOW "本机仅有 IPv6 地址："$LOCAL_IPv6""
            LOCAL_IP=$LOCAL_IPv6
            colorEcho $BLUE "节点ip："$LOCAL_IP""
        else
            colorEcho $RED "未能获取到有效的公网 IP 地址。"
        fi
    fi
    # 将 IP 地址写入文件
    echo "$LOCAL_IP" > /usr/local/etc/xray/ip
}

getport() {
    echo ""
    while true
    do
        read -p "请设置XRAY的端口号[1025-65535]，不输入则随机生成:" PORT
        [[ -z "$PORT" ]] && PORT=`shuf -i1025-65000 -n1`
        if [[ "${PORT:0:1}" = "0" ]]; then
            echo -e " ${RED}端口不能以0开头${PLAIN}"
            exit 1
        fi
        expr $PORT + 0 &>/dev/null
        if [[ $? -eq 0 ]]; then
            if [[ $PORT -ge 1025 ]] && [[ $PORT -le 65535 ]]; then
                echo "$PORT" > /usr/local/etc/xray/port
                colorEcho $BLUE "端口号：$PORT"
                break
            else
                colorEcho $RED "输入错误，端口号为1025-65535的数字"
            fi
        else
            colorEcho $RED "输入错误，端口号为1025-65535的数字"
        fi
    done
}

setFirewall() {
    echo ""
    echo "正在开启$PORT端口..."
    if command -v iptables &> /dev/null; then
        iptables -I INPUT -p tcp --dport $PORT -j ACCEPT &> /dev/null
        iptables -I INPUT -p udp --dport $PORT -j ACCEPT &> /dev/null
        colorEcho $YELLOW "$PORT端口已成功开启"
    else
        echo "无法配置防火墙规则。请手动配置以确保新xray端口可用!"
    fi
}

# 生成或获取 dest
getdest() {
    echo ""
    read -p "请输入您的 dest 地址并确保该域名在国内的连通性（例如：www.amazon.com），如果留空将随机生成：" USER_DEST
    if [[ -z "$USER_DEST" ]]; then
        # 反复随机选择域名，直到符合条件
        while true; do
            # 调用函数获取随机域名
            domain=$(random_website)
            # 使用 OpenSSL 检查域名的 TLS 信息
            check_num=$(echo QUIT | stdbuf -oL openssl s_client -connect "${domain}:443" -tls1_3 -alpn h2 2>&1 | grep -Eoi '(TLSv1.3)|(^ALPN\s+protocol:\s+h2$)|(X25519)' | sort -u | wc -l)
            # 如果 check_num 等于 3，表示符合条件，跳出循环
            if [ "$check_num" -eq 3 ]; then
                USER_DEST="$domain"
                break
            fi
        done

        echo $USER_DEST:443 > /usr/local/etc/xray/dest
        echo $USER_DEST > /usr/local/etc/xray/servername
        colorEcho $BLUE "选中的符合条件的网站是： $USER_DEST"
    else
        echo "正在检查 \"${USER_DEST}\" 是否支持 TLSv1.3与h2"
        # 检查是否支持 TLSv1.3与h2
        check_num=$(echo QUIT | stdbuf -oL openssl s_client -connect "${USER_DEST}:443" -tls1_3 -alpn h2 2>&1 | grep -Eoi '(TLSv1.3)|(^ALPN\s+protocol:\s+h2$)|(X25519)' | sort -u | wc -l)
        if [[ ${check_num} -eq 3 ]]; then
            echo $USER_DEST:443 > /usr/local/etc/xray/dest
            echo $USER_DEST > /usr/local/etc/xray/servername
            colorEcho $YELLOW "目标网址：\"${USER_DEST}\" 支持 TLSv1.3 与 h2"
        else
            colorEcho $YELLOW "目标网址：\"${USER_DEST}\" 不支持 TLSv1.3 与 h2，将在默认域名组中随机挑选域名"
            # 反复随机选择域名，直到符合条件
            while true; do
                # 调用函数获取随机域名
                domain=$(random_website)
                # 使用 OpenSSL 检查域名的 TLS 信息
                check_num=$(echo QUIT | stdbuf -oL openssl s_client -connect "${domain}:443" -tls1_3 -alpn h2 2>&1 | grep -Eoi '(TLSv1.3)|(^ALPN\s+protocol:\s+h2$)|(X25519)' | sort -u | wc -l)
                # 如果 check_num 等于 3，表示符合条件，跳出循环
                if [ "$check_num" -eq 3 ]; then
                    USER_DEST="$domain"
                    break
                fi
            done

            echo $USER_DEST:443 > /usr/local/etc/xray/dest
            echo $USER_DEST > /usr/local/etc/xray/servername
            colorEcho $BLUE "选中的符合条件的网站是： $USER_DEST"
        fi
    fi
}

# 生成 short ID
getsid() {
    echo ""
    echo "正在生成shortID..."
    USER_SID=$(openssl rand -hex 8)
    echo $USER_SID > /usr/local/etc/xray/sid
    colorEcho $BLUE "shortID： $USER_SID"
    echo ""
}

# 创建配置文件 config.json
generate_config() {
    cat << EOF > /usr/local/etc/xray/config.json
{
    "log": {
        "loglevel": "debug"
    },
    "inbounds": [
        {
            "port": $(cat /usr/local/etc/xray/port),
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$(cat /usr/local/etc/xray/uuid)",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "dest": "$(cat /usr/local/etc/xray/dest)",
                    "serverNames": [
                        "$(cat /usr/local/etc/xray/servername)"
                    ],
                    "privateKey": "$(cat /usr/local/etc/xray/privatekey)",
                    "shortIds": [
                        "",
                        "$(cat /usr/local/etc/xray/sid)"
                    ]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ],
                "routeOnly": true
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        }
    ]
}
EOF
    echo "创建配置文件完成..."
    echo ""
}

# 输出 VLESS 配置
print_config() {
    # Print the server details
    echo ""
    colorEcho $BLUE "reality节点配置信息如下："
    colorEcho $YELLOW "Server IP: ${PLAIN}$(cat /usr/local/etc/xray/ip)"
    colorEcho $YELLOW "Listen Port: ${PLAIN}$(cat /usr/local/etc/xray/port)"
    colorEcho $YELLOW "Server Name: ${PLAIN}$(cat /usr/local/etc/xray/servername)"
    colorEcho $YELLOW "Public Key: ${PLAIN}$(cat /usr/local/etc/xray/publickey)"
    colorEcho $YELLOW "Short ID: ${PLAIN}$(cat /usr/local/etc/xray/sid)"
    colorEcho $YELLOW "UUID: ${PLAIN}$(cat /usr/local/etc/xray/uuid)"
    echo ""
    echo ""
}

# 输出 VLESS 链接
generate_link() {
    LOCAL_IP=`cat /usr/local/etc/xray/ip`
    if [[ "$LOCAL_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        LINK="vless://$(cat /usr/local/etc/xray/uuid)@$(cat /usr/local/etc/xray/ip):$(cat /usr/local/etc/xray/port)?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$(cat /usr/local/etc/xray/servername)&fp=chrome&pbk=$(cat /usr/local/etc/xray/publickey)&sid=$(cat /usr/local/etc/xray/sid)&type=tcp&headerType=none#$(cat /usr/local/etc/xray/name)"
    elif [[ "$LOCAL_IP" =~ ^([0-9a-fA-F:]+)$ ]]; then
        LINK="vless://$(cat /usr/local/etc/xray/uuid)@[$(cat /usr/local/etc/xray/ip)]:$(cat /usr/local/etc/xray/port)?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$(cat /usr/local/etc/x
