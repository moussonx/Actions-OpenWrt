#!/bin/bash

# 1. 基础配置
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 绕过 Git 权限，直接从 Release 页面抓取源码
# 既然这个页面没 404，我们就用 curl 强拉
mkdir -p package/custom/passwall
curl -L https://github.com/Openwrt-Passwall/openwrt-passwall2/archive/refs/tags/26.4.20-1.zip -o pw2.zip
unzip -q pw2.zip
mv openwrt-passwall2-26.4.20-1/* package/custom/passwall/
rm -rf pw2.zip openwrt-passwall2-26.4.20-1

# 3. 刷新系统
./scripts/feeds update -a
./scripts/feeds install -a

# 4. VMM 优化 (针对你的 XJFNAS)
echo "CONFIG_VIRTIO=y" >> .config
echo "CONFIG_VIRTIO_NET=y" >> .config
echo "CONFIG_VIRTIO_BLK=y" >> .config
echo "CONFIG_PACKAGE_fstrim=y" >> .config
echo "CONFIG_DEFAULT_TCP_CONG=\"bbr\"" >> .config

rm -rf feeds/packages/net/haproxy
