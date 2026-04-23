#!/bin/bash

# ============================================================================
# 【核心机制】日志与重试函数
# ============================================================================
log_info() { echo -e "\n\e[1;36m[INFO]\e[0m $1"; }
log_success() { echo -e "\e[1;32m[✓]\e[0m $1"; }
log_warn() { echo -e "\e[1;33m[⚠]\e[0m $1"; }
log_error() { echo -e "\e[1;31m[✗]\e[0m $1"; }

retry() {
    local n=1 max=3 delay=2
    while true; do
        "$@" && return 0 || {
            log_warn "Command failed: $@ (Attempt $n/$max)"
            if [[ $n -lt $max ]]; then
                n=$((n + 1)); sleep $delay
            else
                log_error "Max retries reached. Abandoning: $@"
                return 1
            fi
        }
    done
}

# ============================================================================
# Stage 1: 基础配置与清理
# ============================================================================
log_info "Stage 1: Basic configuration and cache cleanup"
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate
log_success "Modified default gateway IP to 192.168.1.2"

rm -rf tmp .config.old
rm -rf tmp/info/ tmp/.package_compile
log_success "Deep cache and index cleaned"

# ============================================================================
# Stage 2: Feeds 核心源更新 (必须第一步执行，获取最新全量代码)
# ============================================================================
log_info "Stage 2: Updating feeds"
retry ./scripts/feeds update -a

# ============================================================================
# Stage 3: 彻底移除冲突与冗余包 (在 update 之后执行，防止被重新拉取)
# ============================================================================
log_info "Stage 3: Removing conflicting packages & upgrading Golang"

# 【微调 1】使用 find 彻底剿灭带通配符的顽固目录 (解决 Kconfig 递归警告)
find feeds/ -name "shorewall*" -type d -exec rm -rf {} + 2>/dev/null
find feeds/ -name "baresip*" -type d -exec rm -rf {} + 2>/dev/null

# 常规精确目录删除
packages_to_remove=(
    "feeds/telephony"
    "feeds/luci/applications/luci-app-passwall"
    "feeds/luci/applications/luci-app-filebrowser"
    "feeds/luci/applications/luci-app-lucky"
    "feeds/luci/applications/luci-app-cloudflared"
    "feeds/packages/lang/golang" # 一并删除旧版 golang
)

for pkg in "${packages_to_remove[@]}"; do
    rm -rf $pkg 2>/dev/null
done
log_success "Conflicts, duplicates, and old golang surgically removed"

# 【微调 2】拉取最新版 Golang (升级为 26.x)
retry git clone --depth 1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# 清理旧索引并重新挂载所有包
rm -rf tmp
retry ./scripts/feeds install -a
retry ./scripts/feeds install -p packages -f golang
log_success "Feeds installed and Golang upgraded to 1.26.x"

# ============================================================================
# Stage 4: 拉取社区精选全家桶
# ============================================================================
log_info "Stage 4: Fetching community packages"
mkdir -p package/community

# 独立处理 Passwall 2
retry curl -L https://github.com/Openwrt-Passwall/openwrt-passwall2/archive/refs/tags/26.4.20-1.zip -o pw2.zip
unzip -q pw2.zip && mv openwrt-passwall2-26.4.20-1/luci-app-passwall2 package/community/ && rm -rf pw2.zip openwrt-passwall2-26.4.20-1

# 数组化批量拉取其余 Git 插件
git_plugins=(
    "linkease/istore.git"
    "gdy666/luci-app-lucky.git"
    "xiaozhuai/luci-app-filebrowser.git"
    "sbwml/luci-app-cloudflared.git"
    "asvow/luci-app-tailscale.git"
    "brvphoenix/luci-app-wrtbwmon.git"
    "rufengsuixing/luci-app-onliner.git"
)

for plugin in "${git_plugins[@]}"; do
    repo_name=$(basename -s .git "$plugin")
    retry git clone --depth=1 "https://github.com/$plugin" "package/community/$repo_name"
done
log_success "Community packages successfully fetched"

# ============================================================================
# Stage 5: 界面定制与底层依赖硬修复
# ============================================================================
log_info "Stage 5: UI customization and critical compatibility patches"

sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
sed -i "s/DISTRIB_DESCRIPTION='.*'/DISTRIB_DESCRIPTION='XGATE'/g" package/base-files/files/etc/openwrt_release

# TurboACC 修复
sed -i 's/kmod-shortcut-fe-cm/kmod-shortcut-fe/g' package/feeds/luci/luci-app-turboacc/Makefile 2>/dev/null || true

# 【微调 3】CMake 文本降维打击（安全向下兼容，解决 rpcd-mod-luci 报错）
find feeds/ -type f -name "CMakeLists.txt" -exec sed -i 's/cmake_minimum_required(VERSION 3.3[0-9]/cmake_minimum_required(VERSION 3.25/g' {} + 2>/dev/null

# 文本依赖替换 (PCRE2 / XCRYPT)
find feeds/ package/ -type f -name "Makefile" -exec sed -i \
    's/+libpcre/+libpcre2/g; s/+libpcre22/+libpcre2/g; s/+libcrypt-compat/+libxcrypt/g' {} + 2>/dev/null

log_success "Critical patches applied (CMake, PCRE2, XCRYPT, TurboACC)"

# ============================================================================
# Stage 6: 最终装载与健全性检查
# ============================================================================
log_info "Stage 6: Finalizing and sanity
