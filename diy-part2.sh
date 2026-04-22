#!/bin/bash

# 1. 基础配置：修改默认管理 IP 为 192.168.1.2
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 解决冲突：精准删除旧插件，防止依赖撞车
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-filebrowser
rm -rf feeds/luci/applications/luci-app-lucky
rm -rf feeds/luci/applications/luci-app-cloudflared
rm -rf feeds/packages/net/haproxy
rm -rf feeds/packages/net/geoview
rm -rf feeds/luci/applications/luci-app-transmission
rm -rf feeds/packages/net/transmission
rm -rf feeds/packages/net/aria2
rm -rf feeds/packages/net/nginx-util
# 2.1 彻底清理 feeds 索引残留，防止 #44 中的 Makefile 覆盖警告
./scripts/feeds clean
./scripts/feeds update -a && ./scripts/feeds install -a

# 3. 核心补丁：硬核对齐 pcre2 环境 (修复 #44 日志中的编译预警)
sed -i 's/DEPENDS:=+libpcre/DEPENDS:=+libpcre2/g' feeds/packages/net/aircrack-ng/Makefile 2>/dev/null
# 强制创建交叉编译器的搜索路径并对齐头文件
mkdir -p staging_dir/target-x86_64_musl/usr/include/pcre2/
cp -rf feeds/packages/libs/pcre2/include/* staging_dir/target-x86_64_musl/usr/include/ 2>/dev/null
cp -rf feeds/packages/libs/pcre2/include/* staging_dir/target-x86_64_musl/usr/include/pcre2/ 2>/dev/null
ln -sf pcre2/pcre2.h staging_dir/target-x86_64_musl/usr/include/pcre.h 2>/dev/null

# 4. 环境升级：解决 CMake 报错与升级 Golang 25.x
find feeds/luci/ -name "CMakeLists.txt" -exec sed -i 's/cmake_minimum_required(VERSION 3\..*)/cmake_minimum_required(VERSION 3.25)/g' {} \;
rm -rf feeds/packages/lang/golang
git clone --depth 1 https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang

# 5. AdGuardHome 精准降级 (核心：避开 Go 1.26 强制要求)
rm -rf feeds/packages/net/adguardhome
git clone --depth 1 -b v0.107.52 https://github.com/AdguardTeam/AdGuardHome.git feeds/packages/net/adguardhome

# 6. 物理注入组件 (PassWall 2 + Cloudflared)
mkdir -p package/community
curl -L https://github.com/Openwrt-Passwall/openwrt-passwall2/archive/refs/tags/26.4.20-1.zip -o pw2.zip
unzip -q pw2.zip && mv openwrt-passwall2-26.4.20-1/luci-app-passwall2 package/community/ && rm -rf pw2.zip openwrt-passwall2-26.4.20-1
sed -i '/tuic-client/d' package/community/luci-app-passwall2/Makefile

rm -rf package/community/luci-app-cloudflared
mkdir -p package/community/luci-app-cloudflared
curl -Lf https://github.com/sbwml/luci-app-cloudflared/archive/refs/heads/main.tar.gz | tar xz -C package/community/luci-app-cloudflared --strip-components=1

# 7. 其他天花板组件拉取
git clone --depth=1 https://github.com/linkease/istore.git package/community/istore
git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/community/luci-app-lucky
git clone --depth=1 https://github.com/xiaozhuai/luci-app-filebrowser.git package/community/luci-app-filebrowser
git clone --depth=1 https://github.com/asvow/luci-app-tailscale.git package/community/luci-app-tailscale

# 8. 针对 VMM 环境与日志优化的极致配置 (合并优化版)
cat >> .config <<EOF
# 虚拟机驱动与核心加速
CONFIG_VIRTIO=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_BLK=y
CONFIG_PACKAGE_fstrim=y
CONFIG_PACKAGE_kmod-lib-crc32c=y
CONFIG_PACKAGE_luci-app-turboacc=y
CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_OFFLOADING=y
CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_BBR_CCA=y

# 存储与内存优化 (解决编译 OOM 关键)
CONFIG_PACKAGE_kmod-fs-nfs=y
CONFIG_PACKAGE_kmod-fs-nfs-v3=y
CONFIG_PACKAGE_kmod-fs-nfs-v4=y
CONFIG_PACKAGE_kmod-fs-autofs4=y
CONFIG_PACKAGE_zram-config=y
CONFIG_PACKAGE_kmod-zram=y

# 科学上网与日志降噪
CONFIG_PACKAGE_xray-core=y
CONFIG_PACKAGE_sing-box=y
CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
CONFIG_PACKAGE_dnsmasq_full_filter_aaaa=y

# 科学上网精准锁定 (防止 #44 日志中的核心冲突)
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Xray_Binary=y
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Xray_Plugin=n
# 显式关闭冗余的 Trojan 支持（Xray 已包含）
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Trojan_Plus=n
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Trojan_GO=n

# 终端与洁癖级优化 (彻底干掉无线组件)
CONFIG_PACKAGE_zsh-completion=y
CONFIG_PACKAGE_zsh-terminfo=y
CONFIG_PACKAGE_wpad-basic-wolfssl=n
CONFIG_PACKAGE_kmod-cfg80211=n
CONFIG_PACKAGE_kmod-mac80211=n
# CONFIG_PACKAGE_kmod-brcmfmac is not set
# CONFIG_PACKAGE_kmod-iwlwifi is not set
# CONFIG_PACKAGE_kmod-rtw88 is not set
# CONFIG_WIFI_SUPPORT is not set

# 固件分区优化
CONFIG_TARGET_KERNEL_PARTSIZE=64
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
CONFIG_NF_CONNTRACK_EVENTS=y
CONFIG_NF_CONNTRACK_TIMEOUT=y
EOF

# 9. 终端及定制
sed -i 's/\/bin\/ash/\/bin\/zsh/g' package/base-files/files/etc/passwd
echo "export PS1='%F{cyan}%n%f@%F{green}%m%f:%F{blue}%~%f$ '" >> package/base-files/files/etc/profile
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
sed -i 's/pcollectd/collectd/g' feeds/luci/applications/luci-app-statistics/Makefile 2>/dev/null
find package/community feeds/luci -type f -path "*/etc/init.d/*" -exec chmod +x {} \;

# 10. 预设定时重启与 XGATE 冠名
mkdir -p package/base-files/files/etc/crontabs
echo "0 4 * * * sleep 5 && touch /etc/banner && reboot" > package/base-files/files/etc/crontabs/root
sed -i 's/OpenWrt/XGATE/g' package/base-files/files/bin/config_generate
sed -i "s/DISTRIB_DESCRIPTION='.*'/DISTRIB_DESCRIPTION='XGATE V1 (Built by Actions)'/g" package/base-files/files/etc/openwrt_release

# 11. 终极护航：强制修复所有二进制文件的执行权限，确保 AGH 等插件在 VMM 运行不报权限错
find package/community feeds/packages/net/adguardhome -type f -name "*.sh" -exec chmod +x {} \;
find package/community feeds/packages/net/adguardhome -type f -path "*/scripts/*" -exec chmod +x {} \;
