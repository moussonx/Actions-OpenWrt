#!/bin/bash
# 修改默认 IP 为你喜欢的网段 (比如 192.168.1.67)
sed -i 's/192.168.1.1/192.168.1.67/g' package/base-files/files/bin/config_generate

# 🟢 [核心修复] 突破 OpenWrt 内部 CMake 3.22 版本限制
# 使用高级正则捕获组 \1，仅精准替换版本号为 3.20，绝对不破坏后续的 FATAL_ERROR 或 project() 等语法结构
find feeds/ package/ -type f -name "CMakeLists.txt" -exec sed -i -E 's/(cmake_minimum_required\s*\(\s*VERSION\s+)[0-9\.]+(\.\.\.[0-9\.]+)?/\13.20/Ig' {} \; 2>/dev/null || true
