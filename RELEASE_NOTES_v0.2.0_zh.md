# mihomo-menu v0.2.0

`mihomo-menu` 是一个面向 Linux / SSH / 无图形环境的 Mihomo 管理工具集。

本次 `v0.2.0` 的重点，是把项目从“管理脚本集合”推进到“更完整的一键部署基础版”。

## 亮点

- 安装脚本现在会先检测系统里是否已经有 Mihomo
- 如果系统没有 Mihomo，会自动安装官方 Mihomo 核心
- 如果系统已经有 Mihomo，会尽量沿用已有二进制和现有配置
- 新增默认 `mihomo.service` 模板
- 支持在安装时通过环境变量直接传入订阅
- 如果已有 `config.yaml`，会先备份，再做最小必要接入
- 如果没有 `config.yaml`，会尝试从订阅生成配置，或者创建最小可启动配置
- 补充了英文 README
- 补充了 `CHANGELOG.md`

## 适合谁

这个版本尤其适合：

- 已经在服务器上有 Mihomo，希望无痛接入管理菜单的人
- 没有现成 Mihomo 环境，希望快速拉起一套基础系统的人
- 主要通过 SSH 管理 Mihomo 的 Linux 用户

## 一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/sunset-move/mihomo-menu/main/install.sh | sudo bash
```

如果安装时想顺手写入订阅：

```bash
curl -fsSL https://raw.githubusercontent.com/sunset-move/mihomo-menu/main/install.sh | \
sudo env MIHOMO_SUBSCRIPTION_NAME=airport1 MIHOMO_SUBSCRIPTION_URL='你的订阅链接' bash
```

## 核心能力

- `mihomo-menu`
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
- 延迟测速与按排名切换：
  - `mihomo-delay`
- 代理联通性测试：
  - `mihomo-test`
- WebUI 更新：
  - `mihomo-ui-update`
- 当前订阅更新：
  - `mihomo-update`
- 开机健康检查：
  - `mihomo-startup-check.service`
  - `mihomo-startup-check.timer`

## 边界说明

`v0.2.0` 已经支持：

- 自动检测已有 Mihomo
- 自动安装 Mihomo
- 自动创建基础运行环境

但它仍然不是“替所有用户自动设计完整代理规则”的工具。

更准确地说：

- 它负责部署基础管理层
- 它负责尽量接入现有环境
- 它负责从已有订阅生成配置
- 它不负责替用户创造一套适合所有机场、所有地区、所有用途的最终业务规则策略

## 版本标签

- Tag: `v0.2.0`
