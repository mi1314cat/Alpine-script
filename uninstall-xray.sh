service xrayR stop
rc-update del xrayR default
rm -f /etc/init.d/xrayR
rm -f /usr/local/bin/xrayR
rm -rf /root/Xray
rm -rf /usr/local/etc/xray
