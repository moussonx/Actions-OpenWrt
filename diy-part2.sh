#!/bin/bash
# ============================================
# XGATE V2 固件定制脚本 (终极完整版)
# ============================================

# ----------------- 基础个性化设置 -----------------

# 修改默认 IP (防冲突神器)
sed -i 's/192.168.1.1/192.168.1.72/g' package/base-files/files/bin/config_generate

# 修改主机名
sed -i "s/hostname='ImmortalWrt'/hostname='XGATE'/g" package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt/XGATE/g' include/target.mk
sed -i 's/ImmortalWrt/XGATE/g' package/base-files/files/etc/banner

# 切换默认主题
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# 🟢【核心修复】突破 OpenWrt 内部 CMake 3.22 限制
# 使用捕获组 \1 仅替换版本号，完美保留 FATAL_ERROR、project() 等语法，确保核心插件正常编译
find feeds/ package/ -type f -name "CMakeLists.txt" -exec sed -i -E 's/(cmake_minimum_required\s*\(\s*VERSION\s+)[0-9\.]+(\.\.\.[0-9\.]+)?/\13.20/Ig' {} \; 2>/dev/null || true


# ----------------- 高级网络与旁路由优化 -----------------

# 1. 预置防火墙动态伪装（解决旁路由回包丢弃问题）
echo "iptables -t nat -I POSTROUTING -o br-lan -j MASQUERADE" >> package/network/config/firewall/files/firewall.user

# 2. 预下载 OpenClash Meta 内核（解决首次启动无法下载的死结）
mkdir -p files/etc/openclash/core
wget -qO- https://github.com/MetaCubeX/mihomo/releases/download/v1.18.1/mihomo-linux-amd64-v1.19.24.gz | gzip -d > files/etc/openclash/core/clash_meta
chmod +x files/etc/openclash/core/clash_meta

# 3. 关闭 HTTPS 重定向（防止首次开机证书生成死锁）
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-disable-https-redirect << 'EOF'
#!/bin/sh
uci set uhttpd.main.redirect_https='0'
uci commit uhttpd
exit 0
EOF
chmod +x files/etc/uci-defaults/99-disable-https-redirect

# 4. IPv6 可控配置（保留物理打洞能力，但禁止向内网设备分配公网 IPv6）
mkdir -p files/etc/config
cat >> files/etc/config/dhcp << 'EOF'

# XGATE V2: IPv6可控模式
config dhcp 'lan'
    option ra 'disabled'
    option dhcpv6 'disabled'
    option ndp 'disabled'
EOF

# 5. 修复 LuCI 网页端对 # 号校验过严的 Bug
# 逻辑：将 MosDNS 和 OpenClash 配置文件中对 IP 地址的强制校验从 ip4addr 改为 string
# 这样网页端就不会因为输入 127.0.0.1#5335 而报错标红
find feeds/luci/luci-app-mosdns -name "*.htm" | xargs sed -i 's/datatype="ip4addr"/datatype="string"/g' 2>/dev/null
find feeds/luci/luci-app-openclash -name "*.js" | xargs sed -i 's/datatype="ip4addr"/datatype="string"/g' 2>/dev/null

echo "✅ XGATE V2 固件定制脚本全量加载完成"

# ----------------- 增量修复：网页校验与节点命名 -----------------
