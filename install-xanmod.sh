#!/bin/bash
# XanMod 内核安装脚本 (分步执行)
# 用法: sudo ./install-xanmod.sh
set -e

[ "$(id -u)" -eq 0 ] || { echo "请用 root 运行 (sudo)"; exit 1; }
[ -f /etc/debian_version ] || { echo "只支持 Debian/Ubuntu"; exit 1; }

# ---------- 系统信息 ----------
CODENAME=$(lsb_release -sc 2>/dev/null || grep ^VERSION_CODENAME= /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || true)
PRETTY=$(grep ^PRETTY_NAME= /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "未知系统")

# ---------- 系统检查 ----------
case "$CODENAME" in
    bookworm) FORCE_LTS=1 ;;
    trixie|forky|sid|noble|plucky|questing) FORCE_LTS=0 ;;
    *) echo "不支持的系统: $CODENAME，退出"; exit 1 ;;
esac

# ---------- CPU 检测 ----------
FLAGS=$(grep -m1 flags /proc/cpuinfo 2>/dev/null || true)
has() { echo "$FLAGS" | grep -qw "$1"; }
LEVEL=1
if has cx16 && has lahf_lm && has popcnt && has sse4_1 && has sse4_2 && has ssse3; then
    LEVEL=2
fi
if has avx && has avx2 && has bmi1 && has bmi2 && has f16c && has fma && has lzcnt && has movbe && has osxsave; then
    LEVEL=3
fi

# ---------- 步骤函数 ----------
step_install_deps() {
    echo "==> 安装依赖工具 (wget/gnupg/lsb-release)"
    apt-get update -qq
    apt-get install -y -qq wget gnupg lsb-release > /dev/null 2>&1
    echo "    完成"
}

step_add_repo() {
    # 前置: 依赖工具
    command -v wget >/dev/null 2>&1 || step_install_deps
    echo "==> 添加 XanMod APT 仓库"
    mkdir -p /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/xanmod-archive-keyring.gpg ]; then
        wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /etc/apt/keyrings/xanmod-archive-keyring.gpg
    fi
    echo "deb [signed-by=/etc/apt/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org $CODENAME main" \
        | tee /etc/apt/sources.list.d/xanmod-release.list > /dev/null
    apt-get update -qq
    echo "    仓库添加完成"
}

step_install_kernel() {
    # 前置: 仓库
    if [ ! -f /etc/apt/sources.list.d/xanmod-release.list ]; then
        echo "    检测到仓库未添加，先添加仓库"
        step_add_repo
    fi
    # 已安装提示
    if is_kernel_done; then
        echo "    XanMod 内核已安装"
        read -rp "    是否重新安装? [y/N] " re
        [[ "$re" =~ ^[Yy]$ ]] || return 0
    fi
    if [ "$FORCE_LTS" -eq 1 ]; then
        PKG="linux-xanmod-lts"
        echo "    Debian 12 只有 LTS 版，已自动选择"
    else
        echo "请选择要安装的版本:"
        echo "  1) 主线版 (7.x, 功能最新)"
        echo "  2) LTS 版 (6.18, 代理服务器推荐)"
        read -rp "输入 1 或 2 [默认 2]: " ver
        case "$ver" in
            1) PKG="linux-xanmod" ;;
            *) PKG="linux-xanmod-lts" ;;
        esac
    fi
    if [ "$LEVEL" -eq 1 ] && [ "$PKG" = "linux-xanmod" ]; then
        echo "    注意: 主线版没有 x64v1 包，已自动切换到 LTS 版"
        PKG="linux-xanmod-lts"
    fi
    echo "==> 安装 ${PKG}-x64v${LEVEL} (需要几分钟)"
    echo "    CPU 等级: x86-64-v$LEVEL"
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${PKG}-x64v${LEVEL}"
    echo "    安装完成，重启后生效"
}

step_check_update() {
    if ! dpkg -l | grep -q "^ii.*linux-image.*xanmod"; then
        echo "    未安装 XanMod 内核，无需检查更新"
        return
    fi
    echo "==> 检查 XanMod 内核更新"
    apt-get update -qq
    UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -i xanmod || true)
    if [ -z "$UPGRADABLE" ]; then
        echo "    已是最新版本，无可用更新"
        return
    fi
    echo "    发现可更新:"
    echo "$UPGRADABLE" | sed 's/^/      /'
    read -rp "是否升级? [Y/n] " up
    if [[ ! "$up" =~ ^[Nn]$ ]]; then
        apt-get install -y --only-upgrade $(echo "$UPGRADABLE" | cut -d/ -f1)
        echo "    升级完成，重启后生效"
    fi
}

# ---------- 状态检查 ----------
is_deps_done() { command -v wget >/dev/null 2>&1 && command -v gpg >/dev/null 2>&1; }
is_repo_done() { [ -f /etc/apt/sources.list.d/xanmod-release.list ]; }
is_kernel_done() { dpkg -l 2>/dev/null | grep -q "^ii.*linux-image.*xanmod"; }

step_uninstall_kernel() {
    if ! is_kernel_done; then
        echo "    未安装 XanMod 内核，无需卸载"
        return
    fi
    if uname -r | grep -q xanmod; then
        echo "    警告: 当前正在运行 XanMod 内核，卸载后重启会回到系统原生内核"
    fi
    echo "    将卸载以下包:"
    dpkg -l | grep "^ii.*xanmod" | awk '{print "      " $2}'
    read -rp "    确认卸载? [y/N] " cf
    [[ "$cf" =~ ^[Yy]$ ]] || { echo "    已取消"; return; }
    echo "==> 卸载 XanMod 内核"
    PKGS=$(dpkg -l | grep "^ii.*xanmod" | awk '{print $2}')
    # shellcheck disable=SC2086
    DEBIAN_FRONTEND=noninteractive apt-get purge -y $PKGS
    update-grub 2>/dev/null || true
    echo "    卸载完成，重启后生效"
}

# ---------- 主菜单 ----------
while true; do
    clear
    echo "========================================"
    echo " 当前内核: $(uname -r)"
    if uname -r | grep -q xanmod; then
        echo " XanMod 内核: 已安装"
    else
        if is_kernel_done; then
            echo " XanMod 内核: 已安装但未运行 (重启后生效)"
        else
            echo " XanMod 内核: 未安装"
        fi
    fi
    echo " 系统版本: $PRETTY"
    echo "========================================"

    # 各步骤完成状态
    s1=""; is_deps_done && s1=" (已完成)"
    s2=""; is_repo_done && s2=" (已完成)"
    s3=""; is_kernel_done && s3=" (已完成)"

    echo ""
    echo "请选择操作:"
    echo "  1) 安装依赖工具$s1"
    echo "  2) 添加 XanMod APT 仓库$s2"
    echo "  3) 安装 XanMod 内核$s3"
    echo "  4) 检查内核更新"
    echo "  5) 卸载 XanMod 内核"
    echo "  6) 重启系统"
    echo "  0) 退出"
    read -rp "输入选项 [0-6]: " opt
    case "$opt" in
        1) step_install_deps ;;
        2) step_add_repo ;;
        3) step_install_kernel ;;
        4) step_check_update ;;
        5) step_uninstall_kernel ;;
        6) reboot ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac
done
