#!/bin/bash
# 1. 基础配置：修改默认 IP 为 192.168.1.2
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 物理注入 Passwall2 源码 (保持 26.4.20-1)
mkdir -p package/custom/passwall
curl -L https://github.com/Openwrt-Passwall/openwrt-passwall2/archive/refs/tags/26.4.20-1.zip -o pw2.zip
unzip -q pw2.zip
mv openwrt-passwall2-26.4.20-1/* package/custom/passwall/
rm -rf pw2.zip openwrt-passwall2-26.4.20-1

# 3. 解决 haproxy 报错：物理删除冲突源码
rm -rf feeds/packages/net/haproxy

# 4. 拉取天花板组件源码 (iStore 商店界面 + UA2F 抢号伪装)
# 统一存放在 custom 目录下，保持代码整洁
git clone https://github.com/linkease/istore.git package/custom/istore
git clone https://github.com/Zxilly/UA2F.git package/custom/ua2f

# 5. 刷新并安装插件源
./scripts/feeds update -a
./scripts/feeds install -a

# 6. 针对 XJFNAS VMM 环境的定向优化
cat >> .config <<EOF
CONFIG_VIRTIO=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_BLK=y
CONFIG_PACKAGE_fstrim=y
CONFIG_DEFAULT_TCP_CONG="bbr"
EOF
