#!/bin/bash
# 修改默认 IP 为你喜欢的网段 (比如 192.168.1.67)
sed -i 's/192.168.1.1/192.168.1.67/g' package/base-files/files/bin/config_generate

# 强制降低所有插件的 CMake 版本要求，完美适配 OpenWrt 内部工具链 (3.26.4)
find feeds/ -type f -name "CMakeLists.txt" -exec sed -i 's/cmake_minimum_required.*/cmake_minimum_required(VERSION 3.20)/g' {} \;

# 添加 OpenClash 源
git clone --depth=1 -b master https://github.com/vernesong/OpenClash.git package/luci-app-openclash

# 添加 MosDNS 源
git clone --depth=1 https://github.com/sbwml/luci-app-mosdns.git package/mosdns
git clone --depth=1 https://github.com/sbwml/v2ray-geodata.git package/v2ray-geodata
