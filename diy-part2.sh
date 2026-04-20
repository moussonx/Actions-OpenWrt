#!/bin/bash

# 1. 基础 IP 修改
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 物理拉取 Passwall2 (避开 Git 协议)
mkdir -p package/custom
# 直接下载 zip 压缩包，GitHub 绝不会对公开包的 zip 下载设权限墙
curl -L https://github.com/itdog-cn/openwrt-passwall/archive/refs/heads/main.zip -o passwall.zip
unzip -q passwall.zip
mv openwrt-passwall-main package/custom/passwall
rm -f passwall.zip

# 3. 拉取必要的内核依赖 (同样改用镜像，并确保路径正确)
git clone --depth 1 https://github.com/kenzok8/small.git package/custom/small

# 4. 强制清理冲突并刷新
rm -rf feeds/packages/lang/python/micropython
./scripts/feeds update -a
./scripts/feeds install -a

# 5. NAS VMM 优化与 BBR
echo "CONFIG_VIRTIO=y" >> .config
echo "CONFIG_VIRTIO_NET=y" >> .config
echo "CONFIG_VIRTIO_BLK=y" >> .config
echo "CONFIG_PACKAGE_fstrim=y" >> .config
echo "CONFIG_DEFAULT_TCP_CONG=\"bbr\"" >> .config
