#!/bin/bash

# 1. 基础配置
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 移除故障包 (解决菜单空白的头等大事)
rm -rf feeds/packages/net/shorewall
rm -rf feeds/packages/net/shorewall6
rm -rf feeds/telephony

# 3. 清理同名冲突插件
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-filebrowser
rm -rf feeds/luci/applications/luci-app-lucky
rm -rf feeds/luci/applications/luci-app-cloudflared

# 4. 刷新 Feeds
./scripts/feeds clean
./scripts/feeds update -a && ./scripts/feeds install -a

# 5. 升级 Golang 25.x
rm -rf feeds/packages/lang/golang
git clone --depth 1 https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang
./scripts/feeds install -p packages -f golang

# 6. 拉取社区全家桶
mkdir -p package/community
curl -L https://github.com/Openwrt-Passwall/openwrt-passwall2/archive/refs/tags/26.4.20-1.zip -o pw2.zip
unzip -q pw2.zip && mv openwrt-passwall2-26.4.20-1/luci-app-passwall2 package/community/ && rm -rf pw2.zip openwrt-passwall2-26.4.20-1
git clone --depth=1 https://github.com/linkease/istore.git package/community/istore
git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/community/luci-app-lucky
git clone --depth=1 https://github.com/xiaozhuai/luci-app-filebrowser.git package/community/luci-app-filebrowser
git clone --depth=1 https://github.com/sbwml/luci-app-cloudflared.git package/community/luci-app-cloudflared
git clone --depth=1 https://github.com/asvow/luci-app-tailscale.git package/community/luci-app-tailscale
git clone --depth=1 https://github.com/brvphoenix/luci-app-wrtbwmon.git package/community/luci-app-wrtbwmon

# 7. 界面定制
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
sed -i "s/DISTRIB_DESCRIPTION='.*'/DISTRIB_DESCRIPTION='XGATE V1-Max (Safe)'/g" package/base-files/files/etc/openwrt_release

# 8. 终极兼容补丁：修复 libpcre 缺失及依赖断裂
# 必须放在脚本末尾执行，确保覆盖所有新拉取的组件
mkdir -p staging_dir/target-x86_64_musl/usr/include/pcre2/
cp -rf feeds/packages/libs/pcre2/include/* staging_dir/target-x86_64_musl/usr/include/ 2>/dev/null
ln -sf pcre2/pcre2.h staging_dir/target-x86_64_musl/usr/include/pcre.h 2>/dev/null
find feeds/ package/ -type f -name "Makefile" -exec sed -i \
's/+libpcre/+libpcre2/g; s/+libpcre22/+libpcre2/g; s/+libcrypt-compat/+libxcrypt/g' {} + 2>/dev/null

# 9. 赋权同步
find package/community -type f -name "*.sh" -exec chmod +x {} \;
chmod -R +x package/community/
./scripts/feeds install -a
