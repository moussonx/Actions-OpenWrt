#!/bin/bash

# 1. 基础配置：修改默认管理 IP 为 192.168.1.2
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 解决冲突：精准删除旧插件，防止依赖撞车
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-filebrowser
rm -rf feeds/luci/applications/luci-app-lucky
rm -rf feeds/luci/applications/luci-app-cloudflared
rm -rf feeds/packages/net/haproxy
rm -rf feeds/packages/net/haproxy-rust
rm -rf feeds/packages/net/geoview
rm -rf feeds/luci/applications/luci-app-geoview
rm -rf feeds/packages/net/transmission
rm -rf feeds/luci/applications/luci-app-transmission
rm -rf feeds/packages/net/aria2
rm -rf feeds/packages/net/nginx-util

# 【修复 1】彻底删除引起 Kconfig 递归依赖报错的元凶 (解决服务菜单为空的根本原因)
rm -rf feeds/packages/net/shorewall
rm -rf feeds/packages/net/shorewall6
# 【修复 2】删除不需要的电话通信包，解决 tiff/host 依赖缺失报错
rm -rf feeds/telephony

# 2.1 强力清场：清理 feeds 索引残留
./scripts/feeds clean
./scripts/feeds update -a && ./scripts/feeds install -a

# 3. 核心补丁预备：构建 pcre2 编译环境
# 【修复 3.1】删除了原版这里重复了三次的冗余代码，保留一次即可
mkdir -p staging_dir/target-x86_64_musl/usr/include/pcre2/
cp -rf feeds/packages/libs/pcre2/include/* staging_dir/target-x86_64_musl/usr/include/ 2>/dev/null
cp -rf feeds/packages/libs/pcre2/include/* staging_dir/target-x86_64_musl/usr/include/pcre2/ 2>/dev/null
ln -sf pcre2/pcre2.h staging_dir/target-x86_64_musl/usr/include/pcre.h 2>/dev/null
chmod -R 755 staging_dir/target-x86_64_musl/usr/include/pcre* 2>/dev/null

# 4. 环境升级：解决 CMake 报错与升级 Golang 25.x (去重并强刷索引)
find feeds/luci/ -name "CMakeLists.txt" -exec sed -i 's/cmake_minimum_required(VERSION 3\..*)/cmake_minimum_required(VERSION 3.25)/g' {} \;
rm -rf feeds/packages/lang/golang
git clone --depth 1 https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang
./scripts/feeds install -p packages -f golang

# 5. AdGuardHome 精准降级 (避开新版 Go 强制要求)
sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=0.107.52/g' feeds/packages/net/adguardhome/Makefile
sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/g' feeds/packages/net/adguardhome/Makefile

# 6. 物理注入组件 (PassWall 2)
mkdir -p package/community
curl -L https://github.com/Openwrt-Passwall/openwrt-passwall2/archive/refs/tags/26.4.20-1.zip -o pw2.zip
unzip -q pw2.zip && mv openwrt-passwall2-26.4.20-1/luci-app-passwall2 package/community/ && rm -rf pw2.zip openwrt-passwall2-26.4.20-1
# 修复 Passwall 2 依赖与菜单显示
sed -i '/tuic-client/d' package/community/luci-app-passwall2/Makefile
./scripts/feeds install -p community -f luci-app-passwall2

# 7. Cloudflared 注入 (换成更稳的 git clone 方式)
rm -rf package/community/luci-app-cloudflared
git clone --depth=1
