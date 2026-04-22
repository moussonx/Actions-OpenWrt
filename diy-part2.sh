#!/bin/bash

# 1. 基础配置
# 修改默认管理 IP 为 192.168.1.2
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 彻底移除冲突包 (根治 Kconfig 递归报错)
# 针对 #52 日志中的 shorewall 报错，采用更彻底的通配符删除
rm -rf feeds/packages/net/shorewall*
rm -rf feeds/telephony
# 强行清理编译临时索引，确保 Kconfig 重新扫描
rm -rf tmp

# 3. 清理同名冲突插件
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-filebrowser
rm -rf feeds/luci/applications/luci-app-lucky
rm -rf feeds/luci/applications/luci-app-cloudflared

# 4. 刷新 Feeds
./scripts/feeds clean
./scripts/feeds update -a && ./scripts/feeds install -a

# 5. 升级 Golang 25.x (确保新版插件高性能编译)
rm -rf feeds/packages/lang/golang
git clone --depth 1 https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang
./scripts/feeds install -p packages -f golang

# 6. 拉取社区全家桶
mkdir -p package/community
# Passwall 2
curl -L https://github.com/Openwrt-Passwall/openwrt-passwall2/archive/refs/tags/26.4.20-1.zip -o pw2.zip
unzip -q pw2.zip && mv openwrt-passwall2-26.4.20-1/luci-app-passwall2 package/community/ && rm -rf pw2.zip openwrt-passwall2-26.4.20-1
# 其他热门插件
git clone --depth=1 https://github.com/linkease/istore.git package/community/istore
git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/community/luci-app-lucky
git clone --depth=1 https://github.com/xiaozhuai/luci-app-filebrowser.git package/community/luci-app-filebrowser
git clone --depth=1 https://github.com/sbwml/luci-app-cloudflared.git package/community/luci-app-cloudflared
git clone --depth=1 https://github.com/asvow/luci-app-tailscale.git package/community/luci-app-tailscale
git clone --depth=1 https://github.com/brvphoenix/luci-app-wrtbwmon.git package/community/luci-app-wrtbwmon
git clone --depth=1 https://github.com/ruobin/luci-app-onliner.git package/community/luci-app-onliner

# 7. 界面定制与命名 (极简 XGATE 版)
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
sed -i "s/DISTRIB_DESCRIPTION='.*'/DISTRIB_DESCRIPTION='XGATE'/g" package/base-files/files/etc/openwrt_release

# 8. 兼容性补丁 (修复硬件加速与底层依赖)
# 修复 TurboACC 找不到内核模块的问题
sed -i 's/kmod-shortcut-fe-cm/kmod-shortcut-fe/g' package/feeds/luci/luci-app-turboacc/Makefile 2>/dev/null
# 修复 PCRE/XCRYPT 依赖断裂
mkdir -p staging_dir/target-x86_64_musl/usr/include/pcre2/
cp -rf feeds/packages/libs/pcre2/include/* staging_dir/target-x86_64_musl/usr/include/ 2>/dev/null
ln -sf pcre2/pcre2.h staging_dir/target-x86_64_musl/usr/include/pcre.h 2>/dev/null
find feeds/ package/ -type f -name "Makefile" -exec sed -i \
's/+libpcre/+libpcre2/g; s/+libpcre22/+libpcre2/g; s/+libcrypt-compat/+libxcrypt/g' {} + 2>/dev/null

# 9. 赋权同步与最终安装
find package/community -type f -name "*.sh" -exec chmod +x {} \;
chmod -R +x package/community/
./scripts/feeds install -a
