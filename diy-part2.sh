#!/bin/bash

# 1. 基础配置：修改默认 IP 为 192.168.1.2
sed -i 's/192.168.1.1/192.168.1.2/g' package/base-files/files/bin/config_generate

# 2. 解决冲突：物理删除 feeds 里的旧插件
rm -rf feeds/luci/applications/luci-app-passwall*
rm -rf feeds/luci/applications/luci-app-filebrowser
rm -rf feeds/luci/applications/luci-app-lucky
rm -rf feeds/packages/net/haproxy

# ================== 🚑 核心抢救：抓内鬼补丁 ==================
# 修复1：强降 rpcd-mod-luci 的 CMake 版本要求 (解决最后的 Error 2 致命报错)
find feeds/luci/ -name "CMakeLists.txt" -exec sed -i 's/cmake_minimum_required(VERSION 3.31)/cmake_minimum_required(VERSION 3.25)/g' {} \;

# 3. 物理注入超级版源码 (PassWall 2)
mkdir -p package/community
curl -L https://github.com/Openwrt-Passwall/openwrt-passwall2/archive/refs/tags/26.4.20-1.zip -o pw2.zip
unzip -q pw2.zip
mv openwrt-passwall2-26.4.20-1/luci-app-passwall2 package/community/
rm -rf pw2.zip openwrt-passwall2-26.4.20-1

# 修复2：剔除 PassWall2 中的 tuic-client 依赖，防止编译 Rust 导致内存爆炸 (解决 rust 报错)
sed -i '/tuic-client/d' package/community/luci-app-passwall2/Makefile
# ==============================================================

# 4. 拉取其他天花板组件 (iStore + Lucky + FileBrowser)
git clone --depth=1 https://github.com/linkease/istore.git package/community/istore
git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/community/luci-app-lucky
git clone --depth=1 https://github.com/xiaozhuai/luci-app-filebrowser.git package/community/luci-app-filebrowser

# 5. 针对 XJFNAS VMM 环境的极致优化及排雷
cat >> .config <<EOF
CONFIG_VIRTIO=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_BLK=y
CONFIG_PACKAGE_fstrim=y
CONFIG_TARGET_KERNEL_PARTSIZE=64
CONFIG_TARGET_ROOTFS_PARTSIZE=1024

# ================== 🌟 核心引擎强制保活 ==================
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_SingBox=y
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Xray=y

# ================== 🚑 终极排雷补丁 (封杀 Rust) ==================
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Shadowsocks_Rust_Client=n
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_Shadowsocks_Rust_Server=n
CONFIG_PACKAGE_luci-app-passwall2_INCLUDE_tuic_client=n
EOF


# 额外顺手清理下可能导致冲突的旧版 golang 依赖（如果有）
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 23.x feeds/packages/lang/golang


# ================== 终极消灭内鬼 (nginx-util) ==================
# 既然系统非要编它又编不过，咱们直接物理删除源码目录，强行跳过
rm -rf feeds/packages/net/nginx-util

# 验证抹除结果
echo "=== 正在验证 nginx-util 是否已被抹除 ==="
if [ ! -d "feeds/packages/net/nginx-util" ]; then
    echo "nginx-util 已彻底从地球上消失，这次稳了！"
else
    echo "警告：抹除失败，请检查路径！"
fi

# 7. 确保固件能被搬运工看到
# 我们把生成的固件直接拷贝到根目录下，起个响亮的名字
find bin/targets/x86/64/ -name "*.img.gz" -exec cp {} ./final_xjf_firmware.img.gz \;

# 验证一下文件在不在
echo "=== 正在检查固件是否就位 ==="
ls -lh ./final_xjf_firmware.img.gz || echo "警告：还没看到固件，可能还在编译中"
