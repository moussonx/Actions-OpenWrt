#!/bin/bash

# 1. 基础配置：修改默认管理 IP 为 192.168.1.2
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 解决冲突：精准删除旧插件，防止依赖撞车（关键：必须先删干净）
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-filebrowser
rm -rf feeds/luci/applications/luci-app-lucky
rm -rf feeds/luci/applications/luci-app-cloudflared
rm -rf feeds/packages/net/haproxy
rm -rf feeds/packages/net/geoview
rm -rf feeds/luci/applications/luci-app-transmission
rm -rf feeds/packages/net/transmission
rm -rf feeds/packages/net/aria2

# 3. 核心补丁：修复 libpcre 依赖并补齐底层库（消灭日志 WARNING）
sed -i 's/DEPENDS:=+libpcre/DEPENDS:=+libpcre2/g' feeds/packages/net/aircrack-ng/Makefile 2>/dev/null
git clone --depth=1 https://github.com/openwrt/packages.git ./temp_packages
cp -r ./temp_packages/libs/pcre package/libs/ 2>/dev/null
cp -r ./temp_packages/libs/pcre2 package/libs/ 2>/dev/null
rm -rf ./temp_packages
# 强行链接头文件，彻底解决 aircrack-ng 编译报错
mkdir -p staging_dir/target-x86_64_musl/usr/include/
cp -r package/libs/pcre2/include/* staging_dir/target-x86_64_musl/usr/include/ 2>/dev/null

# 4. 环境升级：解决 CMake 报错与升级 Golang 25.x
# 强降 rpcd-mod-luci 的 CMake 版本要求 (解决最后的 Error 2 致命报错)
find feeds/luci/ -name "CMakeLists.txt" -exec sed -i 's/cmake_minimum_required(VERSION 3\..*)/cmake_minimum_required(VERSION 3.25)/g' {} \;
# 暴力升级 Golang 25.x
rm -rf feeds/packages/lang/golang
git clone --depth 1 https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang

# 5. 物理注入组件 (PassWall 2 + Cloudflared)
mkdir -p package/community
# PassWall 2 (剔除 tuic 依赖防止内存爆炸)
curl -L https://github.com/Openwrt-Passwall/openwrt-passwall2/archive/refs/tags/26.4.20-1.zip -o pw2.zip
unzip -q pw2.zip && mv openwrt-passwall2-26.4.20-1/luci-app-passwall2 package/community/ && rm -rf pw2.zip openwrt-passwall2-26.4.20-1
sed -i '/tuic-client/d' package/community/luci-app-passwall2/Makefile

# 6. AdGuardHome 精准降级 (解决 Go 版本过低导致的编译失败)
rm -rf feeds/packages/net/adguardhome
git clone --depth 1 -b v0.107.52 https://github.com/AdguardTeam/AdGuardHome.git feeds/packages/net/adguardhome

# 7. Cloudflared (彻底根治 Username 报错：先杀后拉)
rm -rf package/community/luci-app-cloudflared
mkdir -p package/community/luci-app-cloudflared
curl -Lf https://github.com/sbwml/luci-app-cloudflared/archive/refs/heads/main.tar.gz | tar xz -C package/community/luci-app-cloudflared --strip-components=1

# 8. 其他天花板组件拉取
git clone --depth=1 https://github.com/linkease/istore.git package/community/istore
git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/community/luci-app-lucky
git clone --depth=1 https://github.com/xiaozhuai/luci-app-filebrowser.git package/community/luci-app-filebrowser
git clone --depth=1 https://github.com/asvow/luci-app-tailscale.git package/community/luci-app-tailscale

# 9. 针对 VMM 环境与日志优化的极致配置
cat >> .config <<EOF
# 核心加速与虚拟机驱动
CONFIG_VIRTIO=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_BLK=y
CONFIG_PACKAGE_fstrim=y
CONFIG_PACKAGE_luci-app-turboacc=y
CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_OFFLOADING=y
CONFIG_PACKAGE_luci-app-turboacc_INCLUDE_BBR_CCA=y

# 存储与分区
CONFIG_TARGET_KERNEL_PARTSIZE=64
CONFIG_TARGET_ROOTFS_PARTSIZE=1024

# 科学上网核心
CONFIG_PACKAGE_xray-core=y
CONFIG_PACKAGE_sing-box=y
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Shadowsocks_Rust_Client=n
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Shadowsocks_Rust_Server=n
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_tuic_client=n

# 新增：减少“尝试连接”报错日志的优化项
# 1. 禁用不必要的日志记录
# CONFIG_KMOD_PCIE_ASPM_DEBUG is not set
# 2. 优化 DNSMASQ，防止 IPv6 解析死循环导致的日志刷屏
CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
# 3. 开启连接追踪优化，减少失效连接挂死
CONFIG_NF_CONNTRACK_EVENTS=y
CONFIG_NF_CONNTRACK_TIMEOUT=y
EOF

# 10. 终端及定制：Shell 改 Zsh + Argon 主题 + 权限加固
sed -i 's/\/bin\/ash/\/bin\/zsh/g' package/base-files/files/etc/passwd
echo "export PS1='%F{cyan}%n%f@%F{green}%m%f:%F{blue}%~%f$ '" >> package/base-files/files/etc/profile
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
sed -i 's/pcollectd/collectd/g' feeds/luci/applications/luci-app-statistics/Makefile 2>/dev/null
find package/community feeds/luci -type f -path "*/etc/init.d/*" -exec chmod +x {} \;

# 11. 预设定时重启与 XGATE 命名（放置在最后，确保最高优先级）
mkdir -p package/base-files/files/etc/crontabs
echo "0 4 * * * sleep 5 && touch /etc/banner && reboot" > package/base-files/files/etc/crontabs/root
sed -i 's/OpenWrt/XGATE/g' package/base-files/files/bin/config_generate
sed -i "s/DISTRIB_DESCRIPTION='.*'/DISTRIB_DESCRIPTION='XGATE V0 (Built by Actions)'/g" package/base-files/files/etc/openwrt_release
