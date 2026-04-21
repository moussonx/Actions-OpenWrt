#!/bin/bash

# 1. 基础配置：修改默认管理 IP 为 192.168.1.2
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 解决冲突：精准删除，严禁使用星号以免误伤底层库
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-filebrowser
rm -rf feeds/luci/applications/luci-app-lucky
rm -rf feeds/luci/applications/luci-app-cloudflared
rm -rf feeds/packages/net/haproxy
rm -rf feeds/packages/net/geoview
rm -rf feeds/luci/applications/luci-app-transmission
rm -rf feeds/packages/net/transmission
rm -rf feeds/packages/net/aria2

# 强制修复 libpcre 依赖丢失问题
sed -i 's/DEPENDS:=+libpcre/DEPENDS:=+libpcre2/g' feeds/packages/net/aircrack-ng/Makefile 2>/dev/null
# 强制补齐被误伤的底层依赖库，消灭日志里的 WARNING
git clone --depth=1 https://github.com/openwrt/packages.git ./temp_packages
cp -r ./temp_packages/libs/pcre package/libs/ 2>/dev/null
cp -r ./temp_packages/libs/pcre2 package/libs/ 2>/dev/null
rm -rf ./temp_packages

# ================== 🚑 核心抢救：抓内鬼与环境升级 ==================

# 修复1：强降 rpcd-mod-luci 的 CMake 版本要求 (解决最后的 Error 2 致命报错)
find feeds/luci/ -name "CMakeLists.txt" -exec sed -i 's/cmake_minimum_required(VERSION 3\..*)/cmake_minimum_required(VERSION 3.25)/g' {} \;

# 修复2：升级 Golang 到 24.x (彻底解决 #33 任务中 geoview 要求的 Go 1.24 报错)
# 暴力升级 Golang 到 25.x (解决 Xray-core v25 依赖问题)
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang

# 3. 物理注入超级版源码 (PassWall 2)
mkdir -p package/community
curl -L https://github.com/Openwrt-Passwall/openwrt-passwall2/archive/refs/tags/26.4.20-1.zip -o pw2.zip
unzip -q pw2.zip
mv openwrt-passwall2-26.4.20-1/luci-app-passwall2 package/community/
rm -rf pw2.zip openwrt-passwall2-26.4.20-1

# 修复3：剔除 PassWall2 中的 tuic-client 依赖，防止编译 Rust 导致内存爆炸
sed -i '/tuic-client/d' package/community/luci-app-passwall2/Makefile

# ==============================================================

# 4. 拉取天花板组件 (iStore + Lucky + FileBrowser + Tailscale + Cloudflared)
git clone --depth=1 https://github.com/linkease/istore.git package/community/istore
git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/community/luci-app-lucky
git clone --depth=1 https://github.com/xiaozhuai/luci-app-filebrowser.git package/community/luci-app-filebrowser
git clone --depth=1 https://github.com/asvow/luci-app-tailscale.git package/community/luci-app-tailscale

# 放弃 git clone，直接下载源码包解压，解决 Username 报错
mkdir -p package/community/luci-app-cloudflared
curl -Lf https://github.com/sbwml/luci-app-cloudflared/archive/refs/heads/main.tar.gz | tar xz -C package/community/luci-app-cloudflared --strip-components=1

# 5. 针对 XJFNAS VMM 环境的极致优化及排雷
cat >> .config <<EOF
CONFIG_VIRTIO=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_BLK=y
CONFIG_PACKAGE_fstrim=y
CONFIG_TARGET_KERNEL_PARTSIZE=64
CONFIG_TARGET_ROOTFS_PARTSIZE=1024

# ================== 🌟 核心引擎强制保活 (对应 .config 新规) ==================
CONFIG_PACKAGE_xray-core=y
CONFIG_PACKAGE_sing-box=y

# ================== 🚑 终极排雷补丁 (封杀 Rust) ==================
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Shadowsocks_Rust_Client=n
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Shadowsocks_Rust_Server=n
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_tuic_client=n
EOF

# 6. 终极消灭内鬼 (nginx-util)
rm -rf feeds/packages/net/nginx-util

# 验证抹除结果
echo "=== 正在验证 nginx-util 是否已被抹除 ==="
if [ ! -d "feeds/packages/net/nginx-util" ]; then
    echo "nginx-util 已彻底从地球上消失，这次稳了！"
else
    echo "警告：抹除失败，请检查路径！"
fi

# === 极致兼容性补丁 (针对大满贯插件优化) ===

# 【终端极致定制】默认 Shell 改为 Zsh，并开启彩色提示符
sed -i 's/\/bin\/ash/\/bin\/zsh/g' package/base-files/files/etc/passwd
# 预设一个简单的 Zsh 主题，让 SSH 进去后不只是白字
echo "export PS1='%F{cyan}%n%f@%F{green}%m%f:%F{blue}%~%f$ '" >> package/base-files/files/etc/profile

# 【Argon 主题极致定制】强制预设 Argon 为默认主题
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 【Statistics 统计分析修复】解决统计图表不显示的问题
sed -i 's/pcollectd/collectd/g' feeds/luci/applications/luci-app-statistics/Makefile 2>/dev/null

# 【权限固化】全盘扫描并加固所有 community 和 feeds 插件的启动脚本权限
find package/community feeds/luci -type f -path "*/etc/init.d/*" -exec chmod +x {} \;
find feeds/packages/net/transmission -type f -name "*.init" -exec chmod +x {} \; 2>/dev/null

# 7. 预设定时重启 (每天凌晨4点)
mkdir -p package/base-files/files/etc/crontabs
echo "0 4 * * * sleep 5 && touch /etc/banner && reboot" > package/base-files/files/etc/crontabs/root

# 8. 修改主机名为 NOGATE
sed -i 's/OpenWrt/NOGATE/g' package/base-files/files/bin/config_generate

# 9. 修改版本描述
sed -i "s/DISTRIB_DESCRIPTION='.*'/DISTRIB_DESCRIPTION='NOGATE V0 (Built by Actions)'/g" package/base-files/files/etc/openwrt_release
