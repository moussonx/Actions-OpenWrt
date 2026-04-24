#!/bin/bash
# 修改默认 IP 为你喜欢的网段 (比如 192.168.1.67)
sed -i 's/192.168.1.1/192.168.1.67/g' package/base-files/files/bin/config_generate

# 🟢 [精准修复] 优雅降级 CMake 版本要求，解决部分插件编译报 CMake 版本过低的问题
# 相比直接替换一整行，这里使用正则表达式仅精准替换版本号部分，绝不破坏原有语法结构 (如 project 声明或范围语法)
find feeds/ -type f -name "CMakeLists.txt" -exec sed -i -E 's/cmake_minimum_required\s*\(\s*VERSION\s+[0-9\.]+(\.\.\.[0-9\.]+)?/cmake_minimum_required(VERSION 3.20/Ig' {} \;
