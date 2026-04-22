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

# 3. 核心补丁：修复 libpcre 依赖并补齐底层库
sed -i 's/DEPENDS:=+libpcre/DEPENDS:=+libpcre2/g' feeds/packages/net/aircrack-ng/Makefile 2>/dev/null
git clone --depth=1 https://github.com/openwrt/packages.git ./temp_packages
cp -r ./temp_packages/libs/pcre package/libs/ 2>/dev/null
cp -r ./temp_packages/libs/pcre2 package/libs/ 2>/dev/null
rm -rf ./temp_packages
# 增强补丁：确保头文件精准对齐，消灭 aircrack-ng 等插件的编译幻觉
if [ -d "package/libs/pcre2/include" ]; then
    mkdir -p staging_dir/target-x86_64_musl/usr/include/
    cp -rf package/libs/pcre2/include/* staging_dir/target-x86_64_musl/usr/include/ 2>/dev/null
fi

# 4. 环境升级：解决 CMake 报错与升级 Golang 25.x
find feeds/luci/ -name "CMakeLists.txt" -exec sed -i 's/cmake_minimum_required(VERSION 3\..*)/cmake_minimum_required(VERSION 3.25)/g' {} \;
rm -rf feeds/packages/lang/golang
git clone --depth 1 https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang

# 5. AdGuardHome 精准降级 (解决 Go 版本过低导致的编译失败)
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

# 8. 针对 VMM 环境与日志优化的极致配置 (在 96708bc 基础上再增强)
cat >> .config <<EOF
# 核心加速与虚拟机驱动
CONFIG_VIRTIO=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_BLK=y
CONFIG_PACKAGE_fstrim=y
CONFIG_PACKAGE_luci-app-turboacc=y
CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_OFFLOADING=y
CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_BBR_CCA=y

# 存储增强：支持群晖 NFS/Samba 挂载及 SSD 优化
CONFIG_PACKAGE_kmod-fs-nfs=y
CONFIG_PACKAGE_kmod-fs-nfs-v3=y
CONFIG_PACKAGE_kmod-fs-nfs-v4=y
CONFIG_PACKAGE_kmod-fs-autofs4=y

# 内存优化：开启 ZRAM 压缩（让 DS920+ 运行更从容）
CONFIG_PACKAGE_zram-config=y
CONFIG_PACKAGE_kmod-zram=y

# 科学上网与日志降噪（核心：彻底封印 IPv6 报错日志）
CONFIG_PACKAGE_xray-core=y
CONFIG_PACKAGE_sing-box=y
CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
CONFIG_PACKAGE_dnsmasq_full_filter_aaaa=y
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Shadowsocks_Rust_Client=n
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Shadowsocks_Rust_Server=n

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
