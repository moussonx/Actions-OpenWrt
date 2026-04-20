#!/bin/bash

# 1. 修改默认IP为 192.168.1.2 (避开华为 F50 的 1.1)
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 暴力删除导致编译卡死的冲突包 (23.05 版本必做，解决 micropython 报错)
rm -rf feeds/packages/lang/python/micropython

# 3. 强制拉取 Passwall2 及其完整依赖 (核心修改：使用镜像源规避权限错误)
# 我们直接克隆到 package/custom 目录下，让编译系统强制扫描
mkdir -p package/custom
git clone --depth 1 https://github.com/itdog-cn/openwrt-passwall.git package/custom/passwall
git clone --depth 1 https://github.com/kenzok8/openwrt-packages.git package/custom/kenzo
git clone --depth 1 https://github.com/kenzok8/small.git package/custom/small

# 4. 针对你的 XJFNAS (192.168.1.26) 虚拟机环境的底层优化
echo "CONFIG_VIRTIO=y" >> .config
echo "CONFIG_VIRTIO_NET=y" >> .config
echo "CONFIG_VIRTIO_BLK=y" >> .config

# 5. 针对 500GB SSD 的寿命保养 (配置 fstrim)
echo "CONFIG_PACKAGE_fstrim=y" >> .config

# 6. 开启内核 BBR 加速 (提升抢票和高并发响应)
echo "CONFIG_DEFAULT_TCP_CONG=\"bbr\"" >> .config
