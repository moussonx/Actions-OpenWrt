#!/bin/bash

# 1. 在脚本运行阶段直接注入 Passwall2 和插件源
echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main' >> feeds.conf.default
echo 'src-git kenzo https://github.com/kenzok8/openwrt-packages.git;main' >> feeds.conf.default
echo 'src-git small https://github.com/kenzok8/small.git;main' >> feeds.conf.default

# 2. 修改默认IP为 192.168.1.2 (避开华为 F50 的 1.1)
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 3. 强制更新 Feeds (确保刚才注入的源生效)
./scripts/feeds update -a
./scripts/feeds install -a

# 4. 暴力删除导致编译卡死的冲突包 (23.05 版本必做)
rm -rf feeds/packages/lang/python/micropython

# 5. 针对 DS925+ VMM 虚拟机的底层优化
echo "CONFIG_VIRTIO=y" >> .config
echo "CONFIG_VIRTIO_NET=y" >> .config
echo "CONFIG_VIRTIO_BLK=y" >> .config

# 6. 针对 500GB SSD 的寿命保养
echo "CONFIG_PACKAGE_fstrim=y" >> .config

# 7. 提升抢票响应的内核优化
echo "CONFIG_DEFAULT_TCP_CONG=\"bbr\"" >> .config
