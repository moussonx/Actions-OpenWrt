#!/bin/bash

# 1. 基础配置
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 【新增核心】强制更新并安装 feeds (确保 feeds.conf.default 生效)
# 这一步是让编译器强制认领 Passwall2 的关键
./scripts/feeds update -a
./scripts/feeds install -a

# 3. 清理冲突
rm -rf feeds/packages/lang/python/micropython

# 4. VMM 优化
echo "CONFIG_VIRTIO=y" >> .config
echo "CONFIG_VIRTIO_NET=y" >> .config
echo "CONFIG_VIRTIO_BLK=y" >> .config
echo "CONFIG_PACKAGE_fstrim=y" >> .config
echo "CONFIG_DEFAULT_TCP_CONG=\"bbr\"" >> .config
