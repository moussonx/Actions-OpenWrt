#!/bin/bash

# 日志与重试机制
log_info() { echo -e "\n\e[1;36m[INFO]\e[0m $1"; }
log_success() { echo -e "\e[1;32m[✓]\e[0m $1"; }
retry() {
    local n=1 max=3 delay=2
    while true; do
        "$@" && return 0 || {
            if [[ $n -lt $max ]]; then n=$((n + 1)); sleep $delay; else return 1; fi
        }
    done
}

# Stage 1: IP 与环境清理
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate
rm -rf tmp

# Stage 2: 核心源更新
log_info "Updating feeds..."
retry ./scripts/feeds update -a

# Stage 3: 彻底移除冲突包
log_info "Removing conflicting packages..."
packages=(
    "feeds/packages/net/shorewall*"
    "feeds/telephony"
    "feeds/luci/applications/luci-app-passwall"
    "feeds/luci/applications/luci-app-filebrowser"
    "feeds/packages/lang/golang"
)
for pkg in "${packages[@]}"; do rm -rf $pkg 2>/dev/null; done

# Stage 4: 升级 Golang 至 26.x
log_info "Upgrading Golang to 26.x..."
retry git clone --depth 1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# Stage 5: 拉取社区精选全家桶
log_info "Fetching community packages..."
mkdir -p package/community

# 独立处理 Passwall 2
retry curl -L https://github.com/Openwrt-Passwall/openwrt-passwall2/archive/refs/tags/26.4.20-1.zip -o pw2.zip
unzip -q pw2.zip && mv openwrt-passwall2-26.4.20-1/luci-app-passwall2 package/community/ && rm -rf pw2.zip openwrt-passwall2-26.4.20-1

retry git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/community/luci-app-lucky
retry git clone --depth=1 https://github.com/linkease/istore.git package/community/istore

# =================================================================
# 关键修复 A：清空缓存索引，彻底消灭 Shorewall 的幽灵依赖
# =================================================================
log_info "Clearing feed index cache..."
rm -rf tmp/

# 装载包
retry ./scripts/feeds install -p packages -f golang
retry ./scripts/feeds install -a

# Stage 6: 终极兼容性补丁
log_info "Applying critical patches..."

# =================================================================
# 关键修复 B：CMake 文本降维打击（安全向下兼容，不打破沙盒）
# =================================================================
find feeds/ -type f -name "CMakeLists.txt" -exec sed -i 's/cmake_minimum_required(VERSION 3.3[0-9]/cmake_minimum_required(VERSION 3.25/g' {} +

# 修复 PCRE2 与 libxcrypt 依赖
find feeds/ package/ -type f -name "Makefile" -exec sed -i \
    's/+libpcre/+libpcre2/g; s/+libpcre22/+libpcre2/g; s/+libcrypt-compat/+libxcrypt/g' {} + 2>/dev/null

# 修复 TurboACC
find feeds/ package/ -type f -name "Makefile" -exec sed -i 's/kmod-shortcut-fe-cm/kmod-shortcut-fe/g' {} + 2>/dev/null

# 界面主题与命名
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
sed -i "s/DISTRIB_DESCRIPTION='.*'/DISTRIB_DESCRIPTION='XGATE'/g" package/base-files/files/etc/openwrt_release

log_success "DIY Script execution completed!"
