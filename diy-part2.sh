#!/bin/bash

# 1. 基础配置：修改默认管理 IP 为 192.168.1.2
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 解决冲突：物理删除 feeds 里的旧插件，确保纯净环境 (对照：加入了 cloudflared 清理)
rm -rf feeds/luci/applications/luci-app-passwall* \
       feeds/luci/applications/luci-app-filebrowser \
       feeds/luci/applications/luci-app-lucky \
       feeds/luci/applications/luci-app-cloudflared \
       feeds/packages/net/haproxy \
       feeds/packages/net/geoview \
       feeds/packages/net/cloudflared
       feeds/luci/applications/luci-app-transmission \
       feeds/packages/net/transmission \
       feeds/packages/net/aria2

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
# 对照补强：注入 Cloudflare Tunnel 源码 (对应 config 中的三剑客需求)
git clone --depth=1 https://github.com/sbwml/luci-app-cloudflared package/community/luci-app-cloudflared

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

# 【权限固化】确保组网脚本有执行权限 (对照：补强了 Tailscale 的权限检查)
chmod +x package/feeds/luci/luci-app-zerotier/root/etc/init.d/zerotier 2>/dev/null
[ -d package/community/luci-app-tailscale ] && chmod +x package/community/luci-app-tailscale/root/etc/init.d/tailscale 2>/dev/null

# 【权限固化】确保 Transmission 脚本和网页控制台正常
chmod +x feeds/packages/net/transmission/files/transmission.init 2>/dev/null

# 【NAS 极致优化：提高文件系统响应】优化 FSTRIM 周期，延长虚拟磁盘寿命
sed -i '/fstrim/d' package/base-files/files/etc/crontabs/root 2>/dev/null
echo "0 4 * * 1 /usr/sbin/fstrim -av" >> package/base-files/files/etc/crontabs/root

# 7. 确保固件能被搬运工看到
# ================== 📦 终极固件装箱逻辑 ==================
find bin/targets/x86/64/ -name "*.img*" -exec cp {} ./final_xjf_firmware.img \;
find bin/targets/x86/64/ -name "*.img.gz" -exec cp {} ./final_xjf_firmware.img.gz \;

# 验证产物
echo "=== 检查搬运结果 ==="
ls -lh ./final_xjf_firmware.* || echo "警告：依然没找到固件，请检查编译日志"
# =======================================================
