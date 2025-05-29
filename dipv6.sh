#!/bin/sh

echo "==> 正在永久禁用 IPv6..."

# 1. 设置 sysctl 配置（运行时和开机启动）
echo "==> 写入 /etc/sysctl.d/disable-ipv6.conf ..."
cat <<EOF > /etc/sysctl.d/disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

# 2. 立即应用设置
echo "==> 立即应用 sysctl 设置 ..."
sysctl -p /etc/sysctl.d/disable-ipv6.conf

# 3. 确保 sysctl 服务在启动时启用
echo "==> 添加 sysctl 到开机启动项 ..."
rc-update add sysctl boot

# 4. 黑名单禁用 IPv6 模块（更彻底）
echo "==> 写入 modprobe 配置以禁止加载 IPv6 模块 ..."
mkdir -p /etc/modprobe.d
echo "options ipv6 disable=1" > /etc/modprobe.d/disable-ipv6.conf
echo "blacklist ipv6" >> /etc/modprobe.d/blacklist.conf

# 5. 提示结果
echo "==> IPv6 已配置为永久禁用。重启后生效更彻底。"

# 6. 检查当前状态
echo "当前 disable_ipv6 值："
cat /proc/sys/net/ipv6/conf/all/disable_ipv6
