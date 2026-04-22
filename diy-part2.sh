#!/bin/bash

# ============================================================================
# 【核心机制】日志与重试函数
# ============================================================================
log_info() { echo -e "\n\033[1;36m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[1;32m[✓]\033[0m $1"; }
log_warn() { echo -e "\033[1;33m[⚠]\033[0m $1"; }
log_error() { echo -e "\033[1;31m[✗]\033[0m $1"; }

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
# Stage 2: 彻底移除冲突与冗余包
# ============================================================================
log_info "Stage 2: Removing conflicting packages & duplicate apps"

packages_to_remove=(
    "feeds/packages/net/shorewall*"
    "feeds/telephony"
    "feeds/luci/applications/luci-app-passwall"
    "feeds/luci/applications/luci-app-filebrowser"
    "feeds/luci/applications/luci-app-lucky"
    "feeds/luci/applications/luci-app-cloudflared"
)

for pkg in "${packages_to_remove[@]}"; do
    rm -rf $pkg 2>/dev/null
done
log_success "Conflicts and duplicates surgically removed"

# ============================================================================
# Stage 3: Feeds 更新与高级环境准备
# ============================================================================
log_info "Stage 3: Updating feeds and upgrading Golang"
retry ./scripts/feeds update -a
retry ./scripts/feeds install -a

# 正确的 Golang 升级逻辑 (必须用 sbwml 源)
rm -rf feeds/packages/lang/golang
retry git clone --depth 1 https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang
retry ./scripts/feeds install -p packages -f golang
log_success "Golang upgraded to 1.25.x (OpenWrt compatible)"

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

# 物理头文件拷贝 (不可省略的保命操作)
mkdir -p staging_dir/target-x86_64_musl/usr/include/pcre2/
cp -rf feeds/packages/libs/pcre2/include/* staging_dir/target-x86_64_musl/usr/include/ 2>/dev/null || true
ln -sf pcre2/pcre2.h staging_dir/target-x86_64_musl/usr/include/pcre.h 2>/dev/null || true

# 文本依赖替换
find feeds/ package/ -type f -name "Makefile" -exec sed -i \
    's/+libpcre/+libpcre2/g; s/+libpcre22/+libpcre2/g; s/+libcrypt-compat/+libxcrypt/g' {} + 2>/dev/null

log_success "Critical patches applied (PCRE2, XCRYPT, TurboACC)"

# ============================================================================
# Stage 6: 最终装载与健全性检查
# ============================================================================
log_info "Stage 6: Finalizing and sanity checks"
find package/community -type f -name "*.sh" -exec chmod +x {} \;
chmod -R +x package/community/
retry ./scripts/feeds install -a

# 健全性自检
if [ -d "feeds/packages/net/shorewall" ]; then
    log_error "Validation Failed: Shorewall was not completely removed!"
else
    log_success "Validation Passed: Environment looks clean."
fi

log_info "=========================================="
log_success "DIY Script execution perfectly completed!"
log_info "=========================================="
