#!/bin/bash

# 1. 基础配置：修改默认 IP 为 192.168.1.2
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 解决冲突：物理删除 feeds 里的旧插件，防止它们“抢戏”
rm -rf feeds/luci/applications/luci-app-passwall*
rm -rf feeds/luci/applications/luci-app-filebrowser
rm -rf feeds/luci/applications/luci-app-lucky
rm -rf feeds/packages/net/haproxy

# 3. 物理注入超级版源码 (PassWall 2)
mkdir -p package/community
curl -L https://github.com/Openwrt-Passwall/openwrt-passwall2/archive/refs/tags/26.4.20-1.zip -o pw2.zip
unzip -q pw2.zip
mv openwrt-passwall2-26.4.20-1/luci-app-passwall2 package/community/
rm -rf pw2.zip openwrt-passwall2-26.4.20-1

# 4. 拉取其他天花板组件 (iStore + Lucky + FileBrowser)
git clone --depth=1 https://github.com/linkease/istore.git package/community/istore
git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/community/luci-app-lucky
git clone --depth=1 https://github.com/xiaozhuai/luci-app-filebrowser.git package/community/luci-app-filebrowser

# 5. 针对 XJFNAS VMM 环境的极致优化
cat >> .config <<EOF
CONFIG_VIRTIO=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_BLK=y
CONFIG_PACKAGE_fstrim=y
CONFIG_TARGET_KERNEL_PARTSIZE=64
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
EOF
