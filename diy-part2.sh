#!/bin/bash
# 1. 基础配置：修改默认 IP 为 192.168.1.2
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 物理注入 Passwall2 源码 (版本 26.4.20-1)
mkdir -p package/custom/passwall
curl -L https://github.com/Openwrt-Passwall/openwrt-passwall2/archive/refs/tags/26.4.20-1.zip -o pw2.zip
unzip -q pw2.zip
mv openwrt-passwall2-26.4.20-1/* package/custom/passwall/
rm -rf pw2.zip openwrt-passwall2-26.4.20-1

# 3. 彻底删除会导致报错的 haproxy 源码（物理避坑）
rm -rf feeds/packages/net/haproxy

# 4. 刷新并安装插件源
./scripts/feeds update -a
./scripts/feeds install -a

# 5. 针对 XJFNAS VMM 环境的定向优化
cat >> .config <<EOF
CONFIG_VIRTIO=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_BLK=y
CONFIG_PACKAGE_fstrim=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_PACKAGE_luci-app-wol=y
CONFIG_PACKAGE_luci-app-alist=y
EOF
