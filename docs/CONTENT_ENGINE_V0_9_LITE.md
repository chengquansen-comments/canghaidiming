# Content Engine v0.9-lite

## 1）阶段定位

v0.9-lite 的目标是 **管线收敛与简化入口**，不是新增 runtime 能力。  
本阶段不接入正式 loader，不替换正式奖励数据源，不改变战斗主流程。

## 2）为什么要简化

v0.8-v0.9d 已形成完整高级链路，但日常使用命令较多，操作成本高。  
v0.9-lite 通过少量稳定入口，把“日常导出、日常校验、日常 Godot 只读探测”收敛到可重复执行的固定流程，降低误操作风险。

## 3）本阶段保留的安全能力

- battle_reward 导出仍复用既有 hydration + manifest 更新逻辑
- runtime 目录白名单检查继续保留
- manifest `sha256` 与计数一致性检查继续保留
- gate 默认 `disabled` 约束继续保留
- 高风险文件未改动检查继续保留
- Godot headless 只读探测继续保留

## 4）转为 advanced / audit mode 的能力

以下能力继续保留，但不作为日常首选入口：

- dry-run / approval overlay / diff report
- exporter scaffold / guarded write / manifest 深度审计
- loader preflight / loader scaffold / negative fixtures
- regression runner 与 CI draft

这些能力用于审计、排障和深度验证，不删除、不降级。

## 5）v0.9-lite 交付的简化入口

- `tools/content_engine/content_engine_export.py`
- `tools/content_engine/content_engine_validate.py`
- `tools/content_engine/content_engine_godot_probe.py`
- `tools/content_engine/content_engine_check.py`

其中 `content_engine_check.py` 作为日常总入口，统一执行导出、校验、Godot 探测与基础 hygiene 命令。

## 6）进入正式接入前的前置条件

在考虑正式接入前，至少需满足：

- 日常 lite 流程持续稳定 PASS
- advanced/audit 链路可复现实证 PASS
- `runtime_loader_config` 的 gate 策略具备灰度控制与可回滚方案
- battle_reward 与主流程接点有明确 fail-closed 行为
- card_pool 若要进入正式接入，需要先完成独立 hydration/校验方案并通过审计
- Godot 侧 RID/ObjectDB/resource leak warning 有明确治理计划（当前仍为独立 non-blocking hygiene issue）
