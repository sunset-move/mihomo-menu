# mihomo-menu

一个面向 Linux / SSH / 无图形环境的 Mihomo 命令行管理工具集。

这个项目的出发点很简单：

- 很多服务器只有命令行，没有桌面环境
- `metacubexd` / WebUI 适合切换**当前订阅下的节点**
- 但在终端里管理**多个机场订阅源**、测速、切换节点、做开机自检，往往不够顺手

所以有了这个项目。

## 功能

- 交互式菜单：`mihomo-menu`
- 多订阅管理：
  - `mihomo-sub-add`
  - `mihomo-sub-list`
  - `mihomo-sub-current`
  - `mihomo-sub-use`
- 节点管理：
  - `mihomo-list`
  - `mihomo-current`
  - `mihomo-select`
  - `mihomo-select-index`
- 节点测速：
  - `mihomo-delay`
  - 支持按测速排名直接切换
- 代理测试：
  - `mihomo-test`
- WebUI 更新：
  - `mihomo-ui-update`
- 当前订阅更新：
  - `mihomo-update`
- 开机健康检查：
  - `mihomo-startup-check.sh`
  - `mihomo-startup-check.timer`

## 适用场景

- Ubuntu / Debian / CentOS / Rocky / AlmaLinux / Fedora / Arch / Alpine 等常见 Linux
- 通过 SSH 远程管理 Mihomo
- 没有图形界面
- 想保留 WebUI，但又希望 CLI 能做多订阅切换和批量操作

## 一键安装

在目标机器上执行：

```bash
curl -fsSL https://raw.githubusercontent.com/sunset-move/mihomo-menu/main/install.sh | sudo bash
```

这个安装脚本会：

1. 下载当前仓库
2. 把脚本安装到 `/usr/local/bin/`
3. 把 systemd 文件安装到 `/etc/systemd/system/`
4. 自动创建：
   - `/etc/mihomo/subscriptions.d`
   - `/etc/mihomo/secret.key`（如果不存在）
5. 尝试安装 `whiptail`（可选，失败不影响基本功能）
6. 启用开机健康检查 timer

## 前置要求

这个项目**不负责安装 Mihomo 核心本体**，它是管理层。

你需要已经有这些基础条件：

- `mihomo` 可执行文件
  - 推荐路径：`/usr/local/bin/mihomo`
- Mihomo 主配置目录：
  - `/etc/mihomo/`
- 当前活动订阅文件：
  - `/etc/mihomo/subscription.url`
- Mihomo 控制 API 可用
  - 默认示例：`127.0.0.1:9090` 或 `0.0.0.0:9090`

## 当前目录结构

```text
scripts/
  mihomo-menu.sh
  mihomo-main-group.py
  mihomo-list.sh
  mihomo-current.sh
  mihomo-select.sh
  mihomo-select-index.sh
  mihomo-delay.py
  mihomo-test.sh
  mihomo-sub-add.sh
  mihomo-sub-list.sh
  mihomo-sub-current.sh
  mihomo-sub-use.sh
  mihomo-sub2config.py
  mihomo-update.sh
  mihomo-ui-update.sh
  mihomo-startup-check.sh

systemd/
  mihomo-startup-check.service
  mihomo-startup-check.timer
```

## 快速开始

### 1. 添加第一个订阅

```bash
mihomo-sub-add airport1 '你的订阅链接'
```

### 2. 切换到这个订阅

```bash
mihomo-sub-use airport1
```

### 3. 打开交互式菜单

```bash
mihomo-menu
```

### 4. 手动测速

```bash
mihomo-delay --timeout 4000
```

### 5. 一键切到最快节点

```bash
mihomo-delay --timeout 4000 --select 1
```

## WebUI 和本项目的关系

`metacubexd` / WebUI 适合做：

- 查看当前节点
- 切换当前订阅里的节点
- 看连接
- 看日志
- 看流量

但它**不适合直接切换多个机场订阅源**。

因为“切机场”不只是换节点，而是：

1. 切换当前订阅文件
2. 重生成 `config.yaml`
3. 重启 Mihomo

所以：

- 节点管理：WebUI 很方便
- 订阅源切换：`mihomo-menu` / `mihomo-sub-use` 更合适

## 支持的订阅格式

当前脚本支持：

1. `base64 + vmess://...` 原始订阅
2. 完整 `Clash YAML` 订阅

不保证 100% 通吃所有格式，尤其是未来新的混合格式：

- `vless://`
- `trojan://`
- `hysteria://`
- `tuic://`

如果遇到新格式，可能需要继续扩展 `mihomo-sub2config.py`。

## 菜单说明

`mihomo-menu` 支持两种交互模式：

1. 如果系统有 `whiptail`
   - 优先使用类对话框菜单
   - 闪烁更少
   - 支持上下键

2. 如果终端兼容性较差
   - 自动退回成普通数字菜单
   - 至少能稳定使用

节点选择时：

- 支持上下键选择
- 显示最近延迟
- 支持 `Esc` 退出

## 开机健康检查

安装后会启用：

- `mihomo-startup-check.timer`

日志文件：

```text
/var/log/mihomo-startup-check.log
```

手动立即跑一次：

```bash
sudo systemctl start mihomo-startup-check.service
```

看日志：

```bash
tail -n 50 /var/log/mihomo-startup-check.log
```

## 常用命令

```bash
mihomo-menu
mihomo-sub-list
mihomo-sub-current
mihomo-sub-use airport1
mihomo-list
mihomo-current
mihomo-delay --timeout 4000
mihomo-delay --timeout 4000 --select 1
mihomo-test
mihomo-update
mihomo-ui-update
```

## 安全说明

- 不要把真实订阅链接提交到公开仓库
- 不要把 `/etc/mihomo/secret.key` 提交到公开仓库
- 不要把生成后的完整节点配置公开上传

## License

MIT
