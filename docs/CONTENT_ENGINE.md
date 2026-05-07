# Content Engine 日常使用说明

## 1）Content Engine 是什么

Content Engine 是本项目用于策划数据生成、runtime 数据整理、只读校验与 Godot 探测的工具链。  
它的目标是把设计层产物与 runtime 文件保持可追踪、可校验、可回归，而不是直接改写战斗主流程逻辑。

当前阶段（v0.9-lite）仍保持：

- 不接入正式 loader 到战斗主流程
- 不替换正式游戏数据源
- `runtime_loader_config.json` 默认 `disabled`

## 2）日常如何启动

日常推荐只使用一个总入口：

```bash
python3 tools/content_engine/content_engine_check.py
```

该命令会依次执行：

1. `content_engine_export.py --domain battle_reward --write`
2. `content_engine_validate.py`
3. `content_engine_godot_probe.py`
4. `git diff --check`
5. `godot --headless --path . --quit`
6. `godot --headless --path . --quit scenes/MainVisual.tscn`

并生成日常检查报告：

- `data/design/generated_content_engine_lite_check_report.tsv`
- `data/design/generated_content_engine_lite_check_report.md`

## 3）如何导出 battle_reward

简化导出入口：

```bash
python3 tools/content_engine/content_engine_export.py --domain battle_reward --write
python3 tools/content_engine/content_engine_export.py --domain all --write
```

说明：

- `--domain all` 当前仅包含 `battle_reward` 与 `card_pool`
- `battle_reward` 会复用既有 hydration/manifest 更新逻辑
- `card_pool` 目前保持安全保留，不伪造业务数据

## 4）如何校验 runtime

简化校验入口：

```bash
python3 tools/content_engine/content_engine_validate.py
```

会校验：

- runtime 四个 JSON 可解析
- manifest `sha256`、`record_count`、`field_count` 与实际文件一致
- `battle_reward` 记录数与设计源对齐（当前目标 45）
- runtime 目录仅包含允许文件
- `runtime_loader_config.json` 保持 disabled
- 现有 `.gd` 文件没有引用 loader/gate/probe
- 高风险文件未被改动

## 5）如何跑 Godot probe

简化 Godot 探测入口：

```bash
python3 tools/content_engine/content_engine_godot_probe.py
```

该入口会确认：

- Godot headless 探测退出码为 0
- manifest/runtime 读取成功
- `battle_reward` 的 Godot/Python/legacy 记录数对齐（当前目标 45/45/45）
- `error_count=0`
- gate 仍为 disabled

## 6）简化入口与高级审计入口的区别

简化入口（lite）：

- 面向日常执行与快速回归
- 入口少，命令稳定，适合持续使用

高级审计入口（advanced / audit）：

- 保留 v0.8-v0.9d 的完整链路（dry-run、overlay、diff、manifest、negative fixtures、regression runner 等）
- 适合做深度追踪、问题定位、审计证明

## 7）当前接入边界与现状

- 当前仍未替换正式游戏数据源
- 当前 `battle_reward` 已完成设计源 / runtime / Godot 读取 45 条对齐
- 当前 `card_pool` 仍是 out_of_scope，不作为正式接入目标
