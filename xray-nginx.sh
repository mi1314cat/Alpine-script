#!/bin/bash

set -e

ipsl() {
    IP_CHOICE=$(grep '^IP_CHOICE' /root/catmi/install_info.txt | sed 's/.*[:：]//' | tr -d '[:space:]')
    if ! [[ "$IP_CHOICE" =~ ^[0-9]+$ ]]; then
        echo "无效的 IP_CHOICE 值：$IP_CHOICE"
        exit 1
    fi
    if [ "$IP_CHOICE" -eq 1 ]; then
        VALUE=""
    elif [ "$IP_CHOICE" -eq 2 ]; then
        VALUE="[::]:"
    else
        echo "无效选择，退出脚本"
        exit 1
    fi
    export VALUE
}

ssl_dns() {
    echo "请选择要执行的操作："
    echo "1) 有80和443端口"
    echo "2) 无80和443端口"
    read -p "请输入选项 (1 或 2): " choice

    read -p "请输入域名: " DOMAIN
    DOMAIN_LOWER=$(echo "$DOMAIN" | tr '[:upper:]' '[:lower:]')
    read -p "请输入电子邮件地址: " EMAIL

    TARGET_DIR="/root/catmi"
    mkdir -p "$TARGET_DIR"

    if [ "$choice" -eq 1 ]; then
        apk update && apk upgrade
        apk add ufw
        apk add --no-cache curl socat git bash openssl
        ufw disable
        curl https://get.acme.sh | sh
        export PATH="$HOME/.acme.sh:$PATH"
        "$HOME/.acme.sh/acme.sh" --register-account -m "$EMAIL"

        if ! "$HOME/.acme.sh/acme.sh" --issue --standalone -d "$DOMAIN_LOWER"; then
            echo "证书申请失败"
            "$HOME/.acme.sh/acme.sh" --remove -d "$DOMAIN_LOWER"
            exit 1
        fi

        "$HOME/.acme.sh/acme.sh" --installcert -d "$DOMAIN_LOWER" \
            --key-file       "$TARGET_DIR/${DOMAIN_LOWER}.key" \
            --fullchain-file "$TARGET_DIR/${DOMAIN_LOWER}.crt"

        cat << EOF > /root/renew_cert.sh
#!/bin/sh
export PATH="\$HOME/.acme.sh:\$PATH"
\$HOME/.acme.sh/acme.sh --renew -d "$DOMAIN_LOWER" --key-file "$TARGET_DIR/${DOMAIN_LOWER}.key" --fullchain-file "$TARGET_DIR/${DOMAIN_LOWER}.crt"
EOF
        chmod +x /root/renew_cert.sh
        (crontab -l 2>/dev/null; echo "0 0 * * * /root/renew_cert.sh >> /var/log/renew_cert.log 2>&1") | crontab -

        echo "证书安装完成。"
        CERT_PATH="$TARGET_DIR/${DOMAIN_LOWER}.crt"
        KEY_PATH="$TARGET_DIR/${DOMAIN_LOWER}.key"

    elif [ "$choice" -eq 2 ]; then
        apk add certbot
        certbot certonly --manual --preferred-challenges dns -d "$DOMAIN_LOWER"
        CERT_PATH="/etc/letsencrypt/live/$DOMAIN_LOWER/fullchain.pem"
        KEY_PATH="/etc/letsencrypt/live/$DOMAIN_LOWER/privkey.pem"
        (crontab -l 2>/dev/null; echo "0 0 * * * certbot renew") | crontab -
    else
        echo "无效选择"
        exit 1
    fi

    export CERT_PATH KEY_PATH DOMAIN_LOWER
}

ssl_sd() {
    CERT_DIR="/etc/catmi"
    CERT_PATH="${CERT_DIR}/server.crt"
    KEY_PATH="${CERT_DIR}/server.key"
    mkdir -p "$CERT_DIR"

    read -p "请输入申请证书的域名: " DOMAIN_LOWER

    echo "📄 粘贴证书内容（以 -----BEGIN CERTIFICATE----- 开头），Ctrl+D 结束："
    CERT_CONTENT=$(</dev/stdin)
    [ -z "$CERT_CONTENT" ] && echo "❌ 证书内容不能为空！" && exit 1
    echo "$CERT_CONTENT" > "$CERT_PATH"

    echo "🔑 粘贴私钥内容（以 -----BEGIN PRIVATE KEY----- 开头），Ctrl+D 结束："
    KEY_CONTENT=$(</dev/stdin)
    [ -z "$KEY_CONTENT" ] && echo "❌ 私钥内容不能为空！" && exit 1
    echo "$KEY_CONTENT" > "$KEY_PATH"

    chmod 644 "$CERT_PATH" "$KEY_PATH"
    export CERT_PATH KEY_PATH DOMAIN_LOWER
}

nginxsl() {
    # 更新包管理器索引
apk update

# 安装编译工具和依赖项
apk add build-base openssl-dev pcre-dev zlib-dev

# 下载并解压 Nginx 源码
wget https://nginx.org/download/nginx-1.24.0.tar.gz
tar -xzvf nginx-1.24.0.tar.gz
cd nginx-1.24.0

# 清理上一次编译产生的文件
make clean

# 配置 Nginx 以启用 HTTP/2 和 SSL 模块
./configure --with-http_v2_module --with-http_ssl_module

# 编译 Nginx
make

# 安装 Nginx
sudo make install

# 验证 Nginx 版本
/usr/local/nginx/sbin/nginx -v
[ -z "$CERT_PATH" ] && echo "证书路径为空" && exit 1
[ -z "$KEY_PATH" ] && echo "私钥路径为空" && exit 1
[ -z "$PORT" ] && echo "端口为空" && exit 1

Disguised="www.wikipedia.org"
# 创建 nginx 配置文件
    cat <<EOF > /usr/local/nginx/conf/nginx.conf
user nginx;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    gzip on;
    error_log /var/log/nginx/error.log;
    access_log /var/log/nginx/access.log;

    server {
        listen ${VALUE}${PORT} ssl;
        server_name ${DOMAIN_LOWER};
        http2 on;
        ssl_certificate       "${CERT_PATH}";
        ssl_certificate_key   "${KEY_PATH}";

        ssl_session_timeout 1d;
        ssl_session_cache shared:MozSSL:10m;
        ssl_session_tickets off;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers off;

        location / {
            proxy_pass https://${Disguised};
            proxy_redirect off;
            proxy_ssl_server_name on;
            sub_filter_once off;
            sub_filter "${Disguised}" \$server_name;
            proxy_set_header Host "${Disguised}";
            proxy_set_header Referer \$http_referer;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header User-Agent \$http_user_agent;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header Accept-Encoding "";
            proxy_set_header Accept-Language "zh-CN";
        }

        location ${WS_PATH} {
            proxy_pass http://127.0.0.1:9999;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
        }

        location ${WS_PATH1} {
            proxy_pass http://127.0.0.1:9998;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
        }

        location ${WS_PATH2} {
            grpc_pass grpc://127.0.0.1:9997;
            grpc_set_header Host \$host;
            grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
    }
}
EOF

sudo touch /var/run/nginx.pid
sudo chown nginx:nginx /var/run/nginx.pid
sudo /usr/local/nginx/sbin/nginx

sudo /usr/local/nginx/sbin/nginx -s reload
}

# ------------------ 主流程 ------------------
ipsl

echo "请选择申请证书的方式:"
echo "1. 自动 DNS验证 "
echo "2. 手动输入 "
read -p "请输入对应的数字选择 [默认1]: " Certificate
Certificate=${Certificate:-1}

if [ "$Certificate" -eq 1 ]; then
    ssl_dns
elif [ "$Certificate" -eq 2 ]; then
    ssl_sd
else
    echo "无效选择，退出脚本"
    exit 1
fi

PORT=$(grep '^端口' /root/catmi/install_info.txt | sed 's/.*[:：]//')
WS_PATH=$(grep '^vmess WS 路径' /root/catmi/install_info.txt | sed 's/.*[:：]//')
WS_PATH1=$(grep '^vless WS 路径' /root/catmi/install_info.txt | sed 's/.*[:：]//')
WS_PATH2=$(grep '^xhttp 路径' /root/catmi/install_info.txt | sed 's/.*[:：]//')

echo "DOMAIN_LOWER：${DOMAIN_LOWER}" > "/root/catmi/DOMAIN_LOWER.txt"

nginxsl
