#!/bin/bash

# 修改默认 IP
sed -i 's/192.168.1.1/192.168.1.46/g' package/base-files/files/bin/config_generate

# 修改主机名
sed -i "s/hostname='ImmortalWrt'/hostname='XGATE'/g" package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt/XGATE/g' include/target.mk
sed -i 's/ImmortalWrt/XGATE/g' package/base-files/files/etc/banner

# 切换默认主题
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 🟢【核心修复】突破 OpenWrt 内部 CMake 3.22 限制
# 使用捕获组 \1 仅替换版本号，完美保留 FATAL_ERROR、project() 等语法，确保核心插件正常编译
find feeds/ package/ -type f -name "CMakeLists.txt" -exec sed -i -E 's/(cmake_minimum_required\s*\(\s*VERSION\s+)[0-9\.]+(\.\.\.[0-9\.]+)?/\13.20/Ig' {} \; 2>/dev/null || true
