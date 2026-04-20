#!/bin/bash

# 1. 基础配置
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 【核心暴力修正】把所有 feeds 里的 xiaorouji 链接全部强制换成 itdog 镜像
# 这样管它代码从哪出来的，只要遇到原厂地址，一律强制走镜像
sed -i 's|https://github.com/xiaorouji/openwrt-passwall|https://github.com/itdog-cn/openwrt-passwall.git|g' feeds.conf.default

# 3. 再次强制刷新并安装 (双重保险)
./scripts/feeds update -a
./scripts/feeds install -a

# 4. 清理残留冲突
rm -rf feeds/packages/lang/python/micropython

# 5. VMM 优化与 BBR
echo "CONFIG_VIRTIO=y" >> .config
echo "CONFIG_VIRTIO_NET=y" >> .config
echo "CONFIG_VIRTIO_BLK=y" >> .config
echo "CONFIG_PACKAGE_fstrim=y" >> .config
echo "CONFIG_DEFAULT_TCP_CONG=\"bbr\"" >> .config
