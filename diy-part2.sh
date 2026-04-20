#!/bin/bash
# 1. 基础配置：修改默认 IP 为 192.168.1.2
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 解决冲突：物理删除可能导致冲突的旧版插件
rm -rf feeds/luci/applications/luci-app-filebrowser
rm -rf feeds/luci/applications/luci-app-passwall2
rm -rf feeds/packages/net/haproxy

# 3. 拉取天花板组件 (iStore + Lucky + FileBrowser)
# 我们统一放到 package/community 目录下，这是 ImmortalWrt 默认识别度最高的路径
mkdir -p package/community

# iStore 官方插件
git clone --depth=1 https://github.com/linkease/istore.git package/community/istore
# Lucky 反向代理 (针对 XJFNAS 很有用)
git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/community/luci-app-lucky
# 最新版 FileBrowser
git clone --depth=1 https://github.com/xiaozhuai/luci-app-filebrowser.git package/community/luci-app-filebrowser

# 4. 针对 XJFNAS VMM 环境的极致优化 (写入 .config)
cat >> .config <<EOF
CONFIG_VIRTIO=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_BLK=y
CONFIG_PACKAGE_fstrim=y
CONFIG_TARGET_KERNEL_PARTSIZE=64
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
EOF
