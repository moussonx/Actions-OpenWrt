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
rm -rf tmp/info/
# 【微调插入 1】: 在任何操作前提前物理删除，防幽灵索引干扰
find feeds/ -name "shorewall*" -type d -exec rm -rf {} + 2>/dev/null

# ============================================================================
# Stage 2: 核心源更新
# ============================================================================
log_info "Stage 2: Updating feeds"
retry ./scripts/feeds update -a

# ============================================================================
# Stage 3: 彻底移除冲突包
# ============================================================================
log_info "Stage 3: Removing conflicting packages..."
# 【微调插入 2】: 二次强制切除冲突源
find feeds/ -name "shorewall*" -type d -exec rm -rf {} + 2>/dev/null
find feeds/ -name "baresip*" -type d -exec rm -rf {} + 2>/dev/null

packages=(
    "feeds/packages/net/shorewall*"
    "feeds/telephony"
    "feeds/luci/applications/luci-app-passwall"
    "feeds/luci/applications/luci-app-filebrowser"
    "feeds/luci/applications/luci-app-lucky"
    "feeds/luci/applications/luci-app-cloudflared"
    "feeds/packages/lang/golang"
)
for pkg in "${packages[@]}"; do rm -rf $pkg 2>/dev/null; done

# 【微调插入 3】: 确保升级 Golang 至最新的 26.x
log_info "Upgrading Golang to 26.x..."
retry git clone --depth 1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# ============================================================================
# Stage 4: 拉取社区精选全家桶
# ============================================================================
log_info "Stage 4: Fetching community packages"
mkdir -p package/community

# 独立处理 Passwall 2
retry curl -L https://github.com/Openwrt-Passwall/openwrt-passwall2/archive/refs/tags/26.4.20-1.zip -o pw2.zip
unzip -q pw2.zip && mv openwrt-passwall2-26.4.20-1/luci-app-passwall2 package/community/ && rm -rf pw2.zip openwrt-passwall2-26.4.20-1

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

# CMake 文本降维打击（安全向下兼容，解决 rpcd-mod-luci 报错）
find feeds/ -type f -name "CMakeLists.txt" -exec sed -i 's/cmake_minimum_required(VERSION 3.3[0-9]/cmake_minimum_required(VERSION 3.25/g' {} + 2>/dev/null

# 文本依赖替换 (PCRE2 / XCRYPT)
find feeds/ package/ -type f -name "Makefile" -exec sed -i \
    's/+libpcre/+libpcre2/g; s/+libpcre22/+libpcre2/g; s/+libcrypt-compat/+libxcrypt/g' {} + 2>/dev/null

# 【微调插入 4】: 针对 Passwall 2 的特殊依赖修复注入
if [ -d "package/community/luci-app-passwall2" ]; then
    sed -i 's/DEPENDS:=.*/& +libpcre2 +libxcrypt/g' package/community/luci-app-passwall2/Makefile 2>/dev/null
fi

log_success "Critical patches applied"

# ============================================================================
# Stage 6: 最终装载与健全性检查
# ============================================================================
log_info "Stage 6: Finalizing and sanity checks"
find package/community -type f -name "*.sh" -exec chmod +x {} \;
chmod -R +x package/community/

# 【微调插入 5】: 装载前彻底清洗 tmp，破除空壳魔咒
rm -rf tmp/

retry ./scripts/feeds install -p packages -f golang
retry ./scripts/feeds install -a
