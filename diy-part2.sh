#!/bin/bash

# 1. 修改默认IP为 192.168.1.2 (避开华为 F50 的 1.1)
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 暴力删除导致编译卡死的冲突包 (23.05 版本必做)
rm -rf feeds/packages/lang/python/micropython

# 3. 使用暴力 Git Clone 确保 Passwall2 必入 (最稳方案)
# 直接克隆到 package/custom，跳过 feeds 权限校验
mkdir -p package/custom
git clone --depth 1 https://github.com/xiaorouji/openwrt-passwall.git package/custom/passwall
git clone --depth 1 https://github.com/kenzok8/openwrt-packages.git package/custom/kenzo
git clone --depth 1 https://github.com/kenzok8/small.git package/custom/small

# 4. 针对 DS925+ VMM 虚拟机的底层优化 (保持你原有的配置)
echo "CONFIG_VIRTIO=y" >> .config
echo "CONFIG_VIRTIO_NET=y" >> .config
echo "CONFIG_VIRTIO_BLK=y" >> .config

# 5. 针对 500GB SSD 的寿命保养 (保持原有的 fstrim)
echo "CONFIG_PACKAGE_fstrim=y" >> .config

# 6. 提升抢票响应的内核优化 (保持原有的 BBR)
echo "CONFIG_DEFAULT_TCP_CONG=\"bbr\"" >> .config
