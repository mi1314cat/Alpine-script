#!/bin/sh

# 检查内核版本是否支持 BBR
echo "Checking kernel version..."
KERNEL_VERSION=$(uname -r | awk -F. '{print $1$2}')
if [ "$KERNEL_VERSION" -lt 49 ]; then
  echo "Kernel version is below 4.9. Please update the kernel to enable BBR."
  exit 1
else
  echo "Kernel version is $KERNEL_VERSION. Proceeding with BBR setup..."
fi

# 添加 BBR 所需的参数到 /etc/sysctl.conf 文件
echo "Configuring BBR parameters..."
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

# 立即应用参数
sysctl -p

# 检查是否启用了 BBR
echo "Verifying BBR activation..."
BBR_STATUS=$(sysctl net.ipv4.tcp_congestion_control | grep bbr)
if [ -n "$BBR_STATUS" ]; then
  echo "BBR is successfully enabled: $BBR_STATUS"
else
  echo "Failed to enable BBR. Please check the configuration."
fi

# 检查 BBR 模块是否已加载
echo "Checking if BBR module is loaded..."
lsmod | grep bbr || echo "BBR module is not loaded. You may need to reboot."

echo "BBR setup complete on Alpine."
