#!/bin/sh

# 提供操作选项供用户选择
echo "请选择要执行的操作："
echo "1) 安装更新、克隆仓库并执行 acme_2.0.sh 脚本"
echo "2) 手动获取 SSL 证书并将其移动到 /catmi 文件夹"
read -p "请输入选项 (1 或 2): " choice

if [ "$choice" -eq 1 ]; then
    # 选项 1: 安装更新、克隆仓库并执行脚本
    echo "执行安装更新、克隆仓库并运行 acme_2.0.sh 脚本..."
    apk update
    apk add curl
    curl -o /tmp/alpine-ssh.sh https://github.com/mi1314cat/SSL-Renewal/raw/refs/heads/main/alpine-ssh.sh
    chmod +x /tmp/alpine-ssh.sh
    sh /tmp/alpine-ssh.sh

elif [ "$choice" -eq 2 ]; then
    # 选项 2: 手动获取 SSL 证书并移动到 /catmi 文件夹
    echo "将进行手动获取 SSL 证书并移动到 /catmi 文件夹..."

    # 提示用户输入域名
    read -p "请输入您的域名: " DOMAIN

    # 安装 Certbot
    apk update
    apk add certbot

    # 手动获取证书
    certbot certonly --manual --preferred-challenges dns -d $DOMAIN

    # 在 root 目录下创建 catmi 文件夹
    CERT_PATH="/catmi"
    mkdir -p $CERT_PATH

    # 移动生成的证书到 /catmi 文件夹中
    mv /etc/letsencrypt/live/$DOMAIN/fullchain.pem $CERT_PATH/fullchain.pem
    mv /etc/letsencrypt/live/$DOMAIN/privkey.pem $CERT_PATH/privkey.pem

    echo "SSL 证书已安装并移动至根目录的 /catmi 文件夹中"

else
    echo "无效选项，请输入 1 或 2."
fi
