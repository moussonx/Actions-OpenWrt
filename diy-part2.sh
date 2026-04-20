#!/bin/bash

# 1. 基础配置：修改默认 IP 为 192.168.1.2
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 解决冲突：物理删除旧版插件，确保源码纯净
rm -rf feeds/luci/applications/luci-app-filebrowser
rm -rf feeds/luci/applications/luci-app-passwall*
rm -rf feeds/luci/applications/luci-app-lucky
rm -rf feeds/luci/applications/luci-app-istore*
rm -rf feeds/packages/net/haproxy

# 3. 强行拉取真正的“超级版本”源码 (注意：去掉了 depth 的空格，补全了路径)
mkdir -p package/community
git clone --depth=1 https://github.com/linkease/istore.git package/community/istore
git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/community/luci-app-lucky
git clone --depth=1 https://github.com/xiaozhuai/luci-app-filebrowser.git package/community/luci-app-filebrowser
# 这一行是 Passwall2 的最新真经
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall2.git package/community/luci-app-passwall2

# 4. 针对 XJFNAS VMM 环境的极致优化 (写入 .config)
cat >> .config <<EOF
CONFIG_VIRTIO=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_BLK=y
CONFIG_PACKAGE_fstrim=y
CONFIG_TARGET_KERNEL_PARTSIZE=64
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
EOF
