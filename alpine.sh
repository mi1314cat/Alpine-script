#!/bin/bash
# 介绍信息
printf "\e[92m"
printf "                       |\\__/,|   (\\\\ \n"
printf "                     _.|o o  |_   ) )\n"
printf "       -------------(((---(((-------------------\n"
printf "                     catmi-alpine \n"
printf "       -----------------------------------------\n"
printf "\e[0m"
apk add update
apk add iproute2
apk add wget bash curl sudo
# 按回车继续执行安装kejilion工具箱脚本
read -p "按回车继续执行安装kejilion工具箱脚本（输入n跳过）..." input
if [[ "$input" != "n" ]]; then
    clear
    curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
fi
# 添加回车等待
# 按回车继续执行安装kejilion工具箱脚本
read -p "按回车继续执行安装alpine-hysteria2（输入n跳过）..." input
if [[ "$input" != "n" ]]; then
    clear
   bash <(curl -fsSL https://github.com/mi1314cat/Alpine-script/raw/refs/heads/main/alpine-hysteria2.sh)
fi

read -p "按回车继续执行安装安装xray（输入n跳过）..." input
if [[ "$input" != "n" ]]; then
    clear
    bash <(curl -fsSL https://github.com/mi1314cat/Alpine-script/raw/refs/heads/main/bbr.sh)
   bash <(curl -fsSL https://github.com/mi1314cat/Alpine-script/raw/refs/heads/main/allxray.sh)


fi
read -p "按回车继续执行安装安装sing-box（输入n跳过）..." input
if [[ "$input" != "n" ]]; then
    clear
    bash <(curl -fsSL https://github.com/mi1314cat/sing-box-max/raw/refs/heads/main/sing-box.sh)


fi

