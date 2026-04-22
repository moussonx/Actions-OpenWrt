#!/bin/bash

# =================================================================
# 1. 核心工程函数定义 (吸收优秀的日志与重试机制)
# =================================================================

# 绿色高亮日志打印
log() {
    echo -e "\e[32m[$(date +"%Y-%m-%d %H:%M:%S")] $1\e[0m"
}

# 网络请求重试机制 (最多尝试 3 次，每次间隔 2 秒)
retry() {
    local n=1
    local max=3
    local delay=2
    while true; do
        "$@" && return 0 || {
            echo -e "\e[33m[Warning] 命令执行失败: $@ (尝试 $n/$max)\e[0m"
            if [[ $n -lt $max ]]; then
                n=$((n + 1))
                sleep $delay
            else
                echo -e "\e[31m[Error] 达到最大重试次数，放弃执行: $@\e[0m"
                return 1
            fi
        }
    done
}

# =================================================================
# 2. 正式执行流
# =================================================================

log "开始执行: 基础配置与 IP 修改"
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

log "开始执行: Feeds 源刷新与冲突清理"
retry ./scripts/feeds update -a
rm -rf feeds/packages/net/shorewall*
rm -rf feeds/telephony
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-filebrowser
rm -rf feeds/luci/applications/luci-app-lucky
rm -rf feeds/luci/applications/luci-app-cloudflared
rm -rf tmp
retry ./scripts/feeds install -a

log "开始执行: 升级 Golang (支持高性能插件编译)"
rm -rf feeds/packages/lang/golang
retry git clone --depth 1 https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang
retry ./scripts/feeds install -p packages -f golang

log "开始执行: 拉取社区精选全家桶 (带重试保护)"
mkdir -p package/community
# 独立下载与解压 Passwall 2
retry curl -L https://github.com/Openwrt-Passwall/openwrt-passwall2/archive/refs/tags/26.4.20-1.zip -o pw2.zip
unzip -q pw2.zip && mv openwrt-passwall2-26.4.20-1/luci-app-passwall2 package/community/ && rm -rf pw2.zip openwrt-passwall2-26.4.20-1

# 批量拉取其余插件
retry git clone --depth=1 https://github.com/linkease/istore.git package/community/istore
retry git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/community/luci-app-lucky
retry git clone --depth=1 https://github.com/xiaozhuai/luci-app-filebrowser.git package/community/luci-app-filebrowser
retry git clone --depth=1 https://github.com/sbwml/luci-app-cloudflared.git package/community/luci-app-cloudflared
retry git clone --depth=1 https://github.com/asvow/luci-app-tailscale.git package/community/luci-app-tailscale
retry git clone --depth=1 https://github.com/brvphoenix/luci-app-wrtbwmon.git package/community/luci-app-wrtbwmon
retry git clone --depth=1 https://github.com/rufengsuixing/luci-app-onliner.git package/community/luci-app-onliner

log "开始执行: 界面定制与 XGATE 命名"
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
sed -i "s/DISTRIB_DESCRIPTION='.*'/DISTRIB_DESCRIPTION='XGATE'/g" package/base-files/files/etc/openwrt_release

log "开始执行: 底层依赖与兼容性补丁修复 (PCRE2 / TurboACC)"
sed -i 's/kmod-shortcut-fe-cm/kmod-shortcut-fe/g' package/feeds/luci/luci-app-turboacc/Makefile 2>/dev/null
mkdir -p staging_dir/target-x86_64_musl/usr/include/pcre2/
cp -rf feeds/packages/libs/pcre2/include/* staging_dir/target-x86_64_musl/usr/include/ 2>/dev/null
ln -sf pcre2/pcre2.h staging_dir/target-x86_64_musl/usr/include/pcre.h 2>/dev/null
find feeds/ package/ -type f -name "Makefile" -exec sed -i \
's/+libpcre/+libpcre2/g; s/+libpcre22/+libpcre2/g; s/+libcrypt-compat/+libxcrypt/g' {} + 2>/dev/null

log "开始执行: 最终权限赋予与环境装载"
find package/community -type f -name "*.sh" -exec chmod +x {} \;
chmod -R +x package/community/
retry ./scripts/feeds install -a

log "DIY 脚本全部执行完毕，准备进入编译流程！"
