#!/bin/bash
# 修改默认 IP 为你喜欢的网段 (比如 192.168.1.67)
sed -i 's/192.168.1.1/192.168.1.67/g' package/base-files/files/bin/config_generate

# [终极正则]：匹配 VERSION 后面直到右括号的所有内容，然后整体替换！
find feeds/ package/ -type f -name "CMakeLists.txt" -exec sed -i -E 's/cmake_minimum_required\s*\(\s*VERSION\s+[^)]+\)/cmake_minimum_required(VERSION 3.20)/Ig' {} \; 2>/dev/null || true
