# xm

XanMod 内核一键安装脚本，自动检测 CPU 指令集等级和系统版本。

## 快捷安装

```bash
sudo curl -sSL https://raw.githubusercontent.com/hao6789/xanmod-toolkit/main/install-xanmod.sh -o /usr/local/bin/xt \
  && sudo chmod +x /usr/local/bin/xt
```

之后直接运行：

```bash
sudo xt
```

## 功能

```
========================================
 当前内核: 6.12.48-amd64
 XanMod 内核: 未安装
 系统版本: Debian GNU/Linux 13 (trixie)
========================================

请选择操作:
  1) 安装依赖工具
  2) 添加 XanMod APT 仓库
  3) 安装 XanMod 内核
  4) 检查内核更新
  5) 重启系统
  0) 退出
```

- 开头显示当前内核版本、XanMod 是否已安装、系统版本
- 自动检测 CPU 等级（x86-64-v1/v2/v3），选择对应的内核包
- Debian 12 自动使用 LTS 版（官方只给 Debian 12 提供 LTS）
- 可选主线版 / LTS 版（LTS 为代理服务器推荐）

## 支持的系统

| 系统 | 说明 |
|---|---|
| Debian 12 (bookworm) | 仅 LTS 版 |
| Debian 13+ (trixie/forky/sid) | 主线版 / LTS 版 |
| Ubuntu 24.04+ (noble/plucky/questing) | 主线版 / LTS 版 |

XanMod 官方仅支持 Debian 系，其他系统请勿使用。

## 说明

本脚本仅安装 XanMod 官方内核，不修改任何系统调优参数。
BBR 等调优请自行配置。
