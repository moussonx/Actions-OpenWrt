#!/bin/bash

# 1. 修改默认IP为 192.168.1.2 (避开华为 F50)
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 清理冲突包 (23.05及以上版本编译必做)
rm -rf feeds/packages/lang/python/micropython

# 3. 针对你的 XJFNAS (192.168.1.26) 虚拟机的 VMM 优化
# 开启 VirtIO 驱动，让网卡和磁盘性能跑满
echo "CONFIG_VIRTIO=y" >> .config
echo "CONFIG_VIRTIO_NET=y" >> .config
echo "CONFIG_VIRTIO_BLK=y" >> .config

# 4. 针对 500GB SSD 的寿命保养
echo "CONFIG_PACKAGE_fstrim=y" >> .config

# 5. 开启内核 BBR 加速 (提升网络响应速度)
echo "CONFIG_DEFAULT_TCP_CONG=\"bbr\"" >> .config
